"""
Streaming playlist synchronization service.

Handles OAuth2 PKCE flows and playlist management for Spotify and Tidal.
OAuth tokens are stored Fernet-encrypted in the database.
"""

import base64
import hashlib
import os
import secrets
import time as time_module
from datetime import datetime, timezone, timedelta
from typing import Optional

import requests
import logging

from cryptography.fernet import Fernet, InvalidToken

logger = logging.getLogger("uvicorn.error")


# ── Token Encryption ──────────────────────────────────────────────────────────

def _get_fernet() -> Fernet:
    """Derive a Fernet key from the application SECRET_KEY."""
    secret = (os.getenv("SECRET_KEY") or "libre-stage-fallback-key").encode()
    key_bytes = hashlib.sha256(secret).digest()
    fernet_key = base64.urlsafe_b64encode(key_bytes)
    return Fernet(fernet_key)


def encrypt_token(plain: str) -> str:
    return _get_fernet().encrypt(plain.encode()).decode()


def decrypt_token(enc: str) -> Optional[str]:
    try:
        return _get_fernet().decrypt(enc.encode()).decode()
    except (InvalidToken, Exception):
        return None


# ── DB credential helpers ─────────────────────────────────────────────────────

def get_platform_record(db, platform: str):
    """Return the StreamingToken DB record for a platform, or None."""
    from backend import models
    return db.query(models.StreamingToken).filter_by(platform=platform).first()


def build_platform_cfg(db, platform: str) -> Optional[dict]:
    """
    Build a platform config dict from the DB record.
    Returns None if no record exists or client_id is missing.
    """
    rec = get_platform_record(db, platform)
    if not rec or not rec.client_id:
        return None
    return {
        "client_id": rec.client_id,
        "client_secret": decrypt_token(rec.client_secret_enc) if rec.client_secret_enc else "",
        "playlist_id": rec.playlist_id or "",
    }


def save_credentials(db, platform: str, client_id: str, client_secret: Optional[str], playlist_id: str) -> None:
    """Persist platform credentials in the DB (upsert)."""
    from backend import models
    rec = db.query(models.StreamingToken).filter_by(platform=platform).first()
    if not rec:
        rec = models.StreamingToken(platform=platform)
        db.add(rec)
    rec.client_id = client_id.strip() or None
    rec.client_secret_enc = encrypt_token(client_secret) if client_secret and client_secret.strip() else None
    rec.playlist_id = playlist_id.strip() or None
    rec.updated_at = datetime.now(timezone.utc)
    db.commit()


# ── OAuth State Store (in-memory, short-lived) ────────────────────────────────

_oauth_states: dict = {}
_STATE_TTL = 600  # 10 minutes


def create_oauth_state(platform: str, code_verifier: str) -> str:
    """Create a new PKCE OAuth state. Returns the state token."""
    state = secrets.token_urlsafe(32)
    _oauth_states[state] = {
        "platform": platform,
        "code_verifier": code_verifier,
        "expires": time_module.time() + _STATE_TTL,
    }
    # Cleanup expired states
    expired = [k for k, v in list(_oauth_states.items()) if v["expires"] < time_module.time()]
    for k in expired:
        _oauth_states.pop(k, None)
    return state


def consume_oauth_state(state: str) -> Optional[dict]:
    """Consume a state token. Returns data dict or None if invalid/expired."""
    entry = _oauth_states.pop(state, None)
    if entry is None:
        return None
    if entry["expires"] < time_module.time():
        return None
    return entry


# ── PKCE Helpers ─────────────────────────────────────────���────────────────────

def generate_pkce_pair() -> tuple[str, str]:
    """Returns (code_verifier, code_challenge) for OAuth2 PKCE."""
    verifier = secrets.token_urlsafe(64)
    digest = hashlib.sha256(verifier.encode()).digest()
    challenge = base64.urlsafe_b64encode(digest).rstrip(b"=").decode()
    return verifier, challenge


# ══════════════════════════════════════════════════════════════════════════════
# SPOTIFY
# ══════════════���═══════════════════════════════════════════════════════════════

_SPOTIFY_AUTH_URL = "https://accounts.spotify.com/authorize"
_SPOTIFY_TOKEN_URL = "https://accounts.spotify.com/api/token"
_SPOTIFY_API_BASE = "https://api.spotify.com/v1"
_SPOTIFY_SCOPES = "playlist-modify-public playlist-modify-private"


def spotify_get_auth_url(client_id: str, redirect_uri: str) -> tuple[str, str]:
    """Build Spotify OAuth URL with PKCE. Returns (url, state)."""
    verifier, challenge = generate_pkce_pair()
    state = create_oauth_state("spotify", verifier)
    from urllib.parse import urlencode
    params = {
        "response_type": "code",
        "client_id": client_id,
        "scope": _SPOTIFY_SCOPES,
        "redirect_uri": redirect_uri,
        "state": state,
        "code_challenge_method": "S256",
        "code_challenge": challenge,
    }
    return f"{_SPOTIFY_AUTH_URL}?{urlencode(params)}", state


def spotify_exchange_code(client_id: str, redirect_uri: str, code: str, code_verifier: str) -> dict:
    """Exchange authorization code for tokens (PKCE – no client_secret needed)."""
    resp = requests.post(
        _SPOTIFY_TOKEN_URL,
        data={
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirect_uri,
            "client_id": client_id,
            "code_verifier": code_verifier,
        },
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        timeout=10,
    )
    resp.raise_for_status()
    return resp.json()


def _spotify_refresh(client_id: str, refresh_token: str) -> dict:
    resp = requests.post(
        _SPOTIFY_TOKEN_URL,
        data={
            "grant_type": "refresh_token",
            "refresh_token": refresh_token,
            "client_id": client_id,
        },
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        timeout=10,
    )
    resp.raise_for_status()
    return resp.json()


def spotify_get_access_token(db, spot_cfg: dict) -> Optional[str]:
    """Return a valid Spotify access token, refreshing if necessary.

    ``spot_cfg`` must contain at least ``client_id``.
    Falls back to reading client_id from the DB record if not provided.
    """
    from backend import models

    record = db.query(models.StreamingToken).filter_by(platform="spotify").first()
    if not record or not record.access_token_enc:
        return None

    client_id = spot_cfg.get("client_id") or record.client_id
    if not client_id:
        return None

    now = datetime.now(timezone.utc)
    expires = record.token_expires_at
    if expires:
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=timezone.utc)
        if expires > now + timedelta(minutes=5):
            return decrypt_token(record.access_token_enc)

    # Access token expired → refresh
    if not record.refresh_token_enc:
        return None
    refresh_token = decrypt_token(record.refresh_token_enc)
    if not refresh_token:
        return None
    try:
        data = _spotify_refresh(client_id, refresh_token)
    except Exception as exc:
        logger.error("Spotify token refresh failed: %s", exc)
        return None

    record.access_token_enc = encrypt_token(data["access_token"])
    if "refresh_token" in data:
        record.refresh_token_enc = encrypt_token(data["refresh_token"])
    record.token_expires_at = now + timedelta(seconds=data.get("expires_in", 3600))
    record.updated_at = now
    db.commit()
    return data["access_token"]


def spotify_search_track(access_token: str, query: str, limit: int = 8) -> list[dict]:
    resp = requests.get(
        f"{_SPOTIFY_API_BASE}/search",
        params={"q": query, "type": "track", "limit": limit},
        headers={"Authorization": f"Bearer {access_token}"},
        timeout=10,
    )
    resp.raise_for_status()
    items = resp.json().get("tracks", {}).get("items", [])
    return [
        {
            "title": t["name"],
            "artist": ", ".join(a["name"] for a in t["artists"]),
            "album": t["album"]["name"],
            "isrc": t.get("external_ids", {}).get("isrc"),
            "spotify_track_id": t["id"],
            "tidal_track_id": None,
            "cover_url": (t["album"]["images"][0]["url"] if t["album"]["images"] else None),
            "duration_ms": t["duration_ms"],
        }
        for t in items
    ]


def _spotify_get_playlist_track_ids(access_token: str, playlist_id: str) -> set[str]:
    ids: set[str] = set()
    url: Optional[str] = f"{_SPOTIFY_API_BASE}/playlists/{playlist_id}/tracks"
    params: dict = {"fields": "items(track(id)),next", "limit": 100}
    while url:
        resp = requests.get(url, params=params, headers={"Authorization": f"Bearer {access_token}"}, timeout=10)
        resp.raise_for_status()
        data = resp.json()
        for item in data.get("items", []):
            track = item.get("track")
            if track and track.get("id"):
                ids.add(track["id"])
        url = data.get("next")
        params = {}
    return ids


def _spotify_add_tracks(access_token: str, playlist_id: str, track_ids: list[str]) -> None:
    uris = [f"spotify:track:{tid}" for tid in track_ids]
    for i in range(0, len(uris), 100):
        resp = requests.post(
            f"{_SPOTIFY_API_BASE}/playlists/{playlist_id}/tracks",
            json={"uris": uris[i : i + 100]},
            headers={"Authorization": f"Bearer {access_token}", "Content-Type": "application/json"},
            timeout=10,
        )
        resp.raise_for_status()


def _spotify_remove_tracks(access_token: str, playlist_id: str, track_ids: list[str]) -> None:
    uris = [{"uri": f"spotify:track:{tid}"} for tid in track_ids]
    for i in range(0, len(uris), 100):
        resp = requests.delete(
            f"{_SPOTIFY_API_BASE}/playlists/{playlist_id}/tracks",
            json={"tracks": uris[i : i + 100]},
            headers={"Authorization": f"Bearer {access_token}", "Content-Type": "application/json"},
            timeout=10,
        )
        resp.raise_for_status()


# ══════════════════════════════════════════════════════════════════════════════
# TIDAL
# ══════════════════════════════════════════════════════════════════════════════

_TIDAL_AUTH_URL = "https://login.tidal.com/oauth2/authorize"
_TIDAL_TOKEN_URL = "https://auth.tidal.com/v1/oauth2/token"
_TIDAL_API_BASE = "https://openapi.tidal.com/v2"
_TIDAL_SCOPES = "playlists.read playlists.write"


def tidal_get_auth_url(client_id: str, redirect_uri: str) -> tuple[str, str]:
    """Build Tidal OAuth URL (standard Authorization Code flow, no PKCE).
    Returns (url, state).
    """
    state = create_oauth_state("tidal", "")
    from urllib.parse import urlencode
    params = {
        "response_type": "code",
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "state": state,
    }
    # Only add scope if defined and non-empty
    if _TIDAL_SCOPES:
        params["scope"] = _TIDAL_SCOPES
    return f"{_TIDAL_AUTH_URL}?{urlencode(params)}", state


def tidal_exchange_code(client_id: str, client_secret: str, redirect_uri: str, code: str, code_verifier: str) -> dict:
    """Exchange Tidal authorization code for tokens.
    Uses Basic Auth with client_secret (no PKCE code_verifier).
    """
    credentials = base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()
    resp = requests.post(
        _TIDAL_TOKEN_URL,
        data={
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirect_uri,
            "client_id": client_id,
        },
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Authorization": f"Basic {credentials}",
        },
        timeout=10,
    )
    resp.raise_for_status()
    return resp.json()


def _tidal_refresh(client_id: str, client_secret: str, refresh_token: str) -> dict:
    credentials = base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()
    resp = requests.post(
        _TIDAL_TOKEN_URL,
        data={
            "grant_type": "refresh_token",
            "refresh_token": refresh_token,
            "client_id": client_id,
        },
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Authorization": f"Basic {credentials}",
        },
        timeout=10,
    )
    resp.raise_for_status()
    return resp.json()


def tidal_get_access_token(db, tidal_cfg: dict) -> Optional[str]:
    """Return a valid Tidal access token, refreshing if necessary.

    ``tidal_cfg`` must contain ``client_id`` and ``client_secret``.
    Falls back to reading them from the DB record if not provided.
    """
    from backend import models

    record = db.query(models.StreamingToken).filter_by(platform="tidal").first()
    if not record or not record.access_token_enc:
        return None

    client_id = tidal_cfg.get("client_id") or record.client_id
    client_secret = tidal_cfg.get("client_secret") or (
        decrypt_token(record.client_secret_enc) if record.client_secret_enc else None
    )
    if not client_id:
        return None

    now = datetime.now(timezone.utc)
    expires = record.token_expires_at
    if expires:
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=timezone.utc)
        if expires > now + timedelta(minutes=5):
            return decrypt_token(record.access_token_enc)

    if not record.refresh_token_enc:
        return None
    refresh_token = decrypt_token(record.refresh_token_enc)
    if not refresh_token:
        return None
    try:
        data = _tidal_refresh(client_id, client_secret or "", refresh_token)
    except Exception as exc:
        logger.error("Tidal token refresh failed: %s", exc)
        return None

    record.access_token_enc = encrypt_token(data["access_token"])
    if "refresh_token" in data:
        record.refresh_token_enc = encrypt_token(data["refresh_token"])
    record.token_expires_at = now + timedelta(seconds=data.get("expires_in", 3600))
    record.updated_at = now
    db.commit()
    return data["access_token"]


def tidal_search_track(access_token: str, client_id: str, query: str, limit: int = 8) -> list[dict]:
    from urllib.parse import quote
    resp = requests.get(
        f"{_TIDAL_API_BASE}/searchresults/{quote(query)}",
        params={"include": "tracks", "countryCode": "DE"},
        headers={
            "Authorization": f"Bearer {access_token}",
            "X-Tidal-Token": client_id,
        },
        timeout=10,
    )
    if resp.status_code == 404:
        return []
    resp.raise_for_status()
    data = resp.json()
    tracks = [t for t in data.get("included", []) if t.get("type") == "tracks"][:limit]
    return [
        {
            "title": t.get("attributes", {}).get("title", ""),
            "artist": t.get("attributes", {}).get("artistName", ""),
            "album": t.get("attributes", {}).get("albumTitle", ""),
            "isrc": t.get("attributes", {}).get("isrc"),
            "spotify_track_id": None,
            "tidal_track_id": t.get("id"),
            "cover_url": None,
            "duration_ms": None,
        }
        for t in tracks
    ]


def _tidal_get_playlist_track_ids(access_token: str, client_id: str, playlist_id: str) -> set[str]:
    ids: set[str] = set()
    url: Optional[str] = f"{_TIDAL_API_BASE}/playlists/{playlist_id}/relationships/items"
    params: dict = {"countryCode": "DE"}
    headers = {"Authorization": f"Bearer {access_token}", "X-Tidal-Token": client_id}
    while url:
        resp = requests.get(url, params=params, headers=headers, timeout=10)
        if resp.status_code == 404:
            break
        resp.raise_for_status()
        data = resp.json()
        for item in data.get("data", []):
            if item.get("id"):
                ids.add(item["id"])
        url = data.get("links", {}).get("next")
        params = {}
    return ids


def _tidal_add_tracks(access_token: str, client_id: str, playlist_id: str, track_ids: list[str]) -> None:
    payload = {"data": [{"id": tid, "type": "tracks"} for tid in track_ids]}
    resp = requests.post(
        f"{_TIDAL_API_BASE}/playlists/{playlist_id}/relationships/items",
        json=payload,
        headers={
            "Authorization": f"Bearer {access_token}",
            "X-Tidal-Token": client_id,
            "Content-Type": "application/vnd.api+json",
        },
        timeout=10,
    )
    resp.raise_for_status()


def _tidal_remove_tracks(access_token: str, client_id: str, playlist_id: str, track_ids: list[str]) -> None:
    headers = {
        "Authorization": f"Bearer {access_token}",
        "X-Tidal-Token": client_id,
    }
    for tid in track_ids:
        resp = requests.delete(
            f"{_TIDAL_API_BASE}/playlists/{playlist_id}/relationships/items/{tid}",
            headers=headers,
            timeout=10,
        )
        if resp.status_code not in (200, 204, 404):
            resp.raise_for_status()


# ══════════════════════════════════════════════════════════════════════════════
# SYNC LOGIC
# ══════════════════════════════════════════════════════════════════════════════

def sync_playlists(db, playlist_cfg: dict) -> dict:
    """
    Full bi-directional sync between DB playlist and remote platforms.

    Songs whose average rating is at or above ``min_rating_for_sync``
    are added to the remote playlist; all others are removed.

    Returns a dict ``{"spotify": {...}, "tidal": {...}}`` with results
    per enabled platform.
    """
    from backend import models
    from sqlalchemy import func

    min_rating: float = playlist_cfg.get("min_rating_for_sync", 3.5)
    max_size: int = playlist_cfg.get("max_playlist_size", 50)

    qualifying = (
        db.query(models.PlaylistSong)
        .outerjoin(models.PlaylistRating, models.PlaylistSong.id == models.PlaylistRating.song_id)
        .group_by(models.PlaylistSong.id)
        .having(func.coalesce(func.avg(models.PlaylistRating.rating), 0) >= min_rating)
        .limit(max_size)
        .all()
    )

    results: dict = {}

    spot_cfg = playlist_cfg.get("spotify", {})
    if spot_cfg.get("enabled") and spot_cfg.get("playlist_id") and spot_cfg.get("client_id"):
        results["spotify"] = _sync_spotify(db, spot_cfg, qualifying)

    tidal_cfg = playlist_cfg.get("tidal", {})
    if tidal_cfg.get("enabled") and tidal_cfg.get("playlist_id") and tidal_cfg.get("client_id"):
        results["tidal"] = _sync_tidal(db, tidal_cfg, qualifying)

    return results


def _sync_spotify(db, spot_cfg: dict, qualifying_songs: list) -> dict:
    from backend import models

    access_token = spotify_get_access_token(db, spot_cfg)
    if not access_token:
        return {"status": "error", "message": "Nicht verbunden – bitte Spotify-OAuth durchführen"}

    playlist_id = spot_cfg["playlist_id"]
    try:
        current_ids = _spotify_get_playlist_track_ids(access_token, playlist_id)
    except Exception as exc:
        return {"status": "error", "message": str(exc)}

    target_ids = {s.spotify_track_id for s in qualifying_songs if s.spotify_track_id}
    to_add = list(target_ids - current_ids)
    to_remove = list(current_ids - target_ids)
    added, removed, errors = 0, 0, []

    try:
        if to_add:
            _spotify_add_tracks(access_token, playlist_id, to_add)
            added = len(to_add)
    except Exception as exc:
        errors.append(f"Add: {exc}")

    try:
        if to_remove:
            _spotify_remove_tracks(access_token, playlist_id, to_remove)
            removed = len(to_remove)
    except Exception as exc:
        errors.append(f"Remove: {exc}")

    # Update sync flags
    for song in qualifying_songs:
        if song.spotify_track_id:
            song.is_synced_spotify = True
    db.commit()

    log = models.PlaylistSyncLog(
        song_id=None,
        platform="spotify",
        action="full_sync",
        error_message="; ".join(errors) if errors else None,
    )
    db.add(log)
    db.commit()

    return {"status": "ok" if not errors else "partial", "added": added, "removed": removed, "errors": errors}


def _sync_tidal(db, tidal_cfg: dict, qualifying_songs: list) -> dict:
    from backend import models

    access_token = tidal_get_access_token(db, tidal_cfg)
    if not access_token:
        return {"status": "error", "message": "Nicht verbunden – bitte Tidal-OAuth durchführen"}

    playlist_id = tidal_cfg["playlist_id"]
    client_id = tidal_cfg["client_id"]
    try:
        current_ids = _tidal_get_playlist_track_ids(access_token, client_id, playlist_id)
    except Exception as exc:
        return {"status": "error", "message": str(exc)}

    target_ids = {s.tidal_track_id for s in qualifying_songs if s.tidal_track_id}
    to_add = list(target_ids - current_ids)
    to_remove = list(current_ids - target_ids)
    added, removed, errors = 0, 0, []

    try:
        if to_add:
            _tidal_add_tracks(access_token, client_id, playlist_id, to_add)
            added = len(to_add)
    except Exception as exc:
        errors.append(f"Add: {exc}")

    try:
        if to_remove:
            _tidal_remove_tracks(access_token, client_id, playlist_id, to_remove)
            removed = len(to_remove)
    except Exception as exc:
        errors.append(f"Remove: {exc}")

    for song in qualifying_songs:
        if song.tidal_track_id:
            song.is_synced_tidal = True
    db.commit()

    log = models.PlaylistSyncLog(
        song_id=None,
        platform="tidal",
        action="full_sync",
        error_message="; ".join(errors) if errors else None,
    )
    db.add(log)
    db.commit()

    return {"status": "ok" if not errors else "partial", "added": added, "removed": removed, "errors": errors}











