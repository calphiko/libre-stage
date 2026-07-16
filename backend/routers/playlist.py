"""
Playlist router.

Manages the band's inspiration playlist with Spotify and Tidal sync.

Public endpoint (no auth):
  GET /playlist/config  – enabled flags for the frontend

Authenticated endpoints (all users):
  GET    /playlist/songs              – list all songs with ratings
  POST   /playlist/songs              – propose a new song
  DELETE /playlist/songs/{id}         – remove a song (own or admin)
  POST   /playlist/songs/{id}/rate    – submit / update own rating
  DELETE /playlist/songs/{id}/rate    – withdraw own rating
  GET    /playlist/search             – search Spotify / Tidal

Admin-only endpoints:
  POST   /playlist/sync               – trigger full platform sync
  GET    /playlist/sync/log           – show sync history
  GET    /playlist/oauth/{p}/connect  – start OAuth flow
  GET    /playlist/oauth/{p}/callback – OAuth callback (called by provider)
  GET    /playlist/oauth/status       – connection status per platform
  DELETE /playlist/oauth/{p}/disconnect

Prefix: /playlist  |  Tag: playlist
"""

from datetime import datetime, timezone, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session

from backend import auth, models
from backend.app_config import get_config
from backend.services import playlist_service as svc
from backend.utils.check_permissions import check_admin

import logging

logger = logging.getLogger("uvicorn.error")

router = APIRouter(prefix="/playlist", tags=["playlist"])


# ── Helpers ───────────────────────────────────────────────────────────────────

def _playlist_cfg() -> dict:
    """Return playlist feature flags from appConfig. Raise 404 if disabled.

    Credentials (client_id, client_secret, playlist_id) are NOT read here –
    they live in the DB and are fetched per-request in the service layer.
    """
    cfg = get_config()
    pcfg = cfg.get("playlist", {})
    if not pcfg.get("enabled", False):
        raise HTTPException(status_code=404, detail="Playlist-Feature ist deaktiviert")
    return pcfg


def _get_user(db: Session, user_name: str) -> models.User:
    user = db.query(models.User).filter_by(user_name=user_name).first()
    if not user:
        raise HTTPException(status_code=404, detail="User nicht gefunden")
    return user


def _song_to_dict(song: models.PlaylistSong, current_user_id: int) -> dict:
    ratings = [r.rating for r in song.ratings]
    avg_rating = round(sum(ratings) / len(ratings), 2) if ratings else None
    my = next((r for r in song.ratings if r.user_id == current_user_id), None)
    return {
        "id": song.id,
        "title": song.title,
        "artist": song.artist,
        "album": song.album,
        "isrc": song.isrc,
        "spotify_track_id": song.spotify_track_id,
        "tidal_track_id": song.tidal_track_id,
        "cover_url": song.cover_url,
        "proposed_by": song.proposer.clear_name if song.proposer else None,
        "proposed_by_id": song.proposed_by,
        "created_at": song.created_at.isoformat() if song.created_at else None,
        "avg_rating": avg_rating,
        "rating_count": len(ratings),
        "my_rating": my.rating if my else None,
        "my_comment": my.comment if my else None,
        "is_synced_spotify": song.is_synced_spotify,
        "is_synced_tidal": song.is_synced_tidal,
    }


# ── Public config ─────────────────────────────────────────────────────────────

@router.get("/config")
def get_playlist_config():
    """Return the public playlist feature flags (no auth needed)."""
    cfg = get_config()
    pcfg = cfg.get("playlist", {})
    return {
        "enabled": pcfg.get("enabled", False),
        "spotify_enabled": pcfg.get("spotify", {}).get("enabled", False),
        "tidal_enabled": pcfg.get("tidal", {}).get("enabled", False),
        "min_rating_for_sync": pcfg.get("min_rating_for_sync", 3.5),
        "max_playlist_size": pcfg.get("max_playlist_size", 50),
    }


# ── Songs ────────────────────────────────────────────────────────────────���────

@router.get("/songs")
def get_playlist_songs(
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user_dep),
    pcfg: dict = Depends(_playlist_cfg),
):
    """Return all playlist songs sorted by average rating (descending)."""
    user = _get_user(db, current["user_name"])
    songs = db.query(models.PlaylistSong).all()
    result = [_song_to_dict(s, user.id) for s in songs]
    result.sort(key=lambda x: x["avg_rating"] or 0, reverse=True)
    return result


@router.post("/songs", status_code=201)
def add_playlist_song(
    body: dict,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user_dep),
    pcfg: dict = Depends(_playlist_cfg),
):
    """Propose a new song for the playlist."""
    user = _get_user(db, current["user_name"])
    title = (body.get("title") or "").strip()
    artist = (body.get("artist") or "").strip()
    if not title or not artist:
        raise HTTPException(status_code=422, detail="Titel und Interpret sind erforderlich")

    song = models.PlaylistSong(
        title=title,
        artist=artist,
        album=body.get("album"),
        isrc=body.get("isrc"),
        spotify_track_id=body.get("spotify_track_id"),
        tidal_track_id=body.get("tidal_track_id"),
        cover_url=body.get("cover_url"),
        proposed_by=user.id,
        created_at=datetime.now(timezone.utc),
    )
    db.add(song)
    db.commit()
    db.refresh(song)
    return {"id": song.id, "message": "Song hinzugefügt"}


@router.delete("/songs/{song_id}")
def delete_playlist_song(
    song_id: int,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user_dep),
    pcfg: dict = Depends(_playlist_cfg),
):
    """Remove a song (admin or the original proposer only)."""
    song = db.get(models.PlaylistSong, song_id)
    if not song:
        raise HTTPException(status_code=404, detail="Song nicht gefunden")
    user = _get_user(db, current["user_name"])
    if not check_admin(current) and song.proposed_by != user.id:
        raise HTTPException(status_code=403, detail="Keine Berechtigung")
    db.delete(song)
    db.commit()
    return {"message": "Song entfernt"}


# ── Ratings ───────────────────────────────────────────────────────────────────

@router.post("/songs/{song_id}/rate")
def rate_playlist_song(
    song_id: int,
    body: dict,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user_dep),
    pcfg: dict = Depends(_playlist_cfg),
):
    """Submit or update own rating for a playlist song (1–5 stars)."""
    song = db.get(models.PlaylistSong, song_id)
    if not song:
        raise HTTPException(status_code=404, detail="Song nicht gefunden")

    rating_val = body.get("rating")
    if not isinstance(rating_val, int) or not (1 <= rating_val <= 5):
        raise HTTPException(status_code=422, detail="Bewertung muss zwischen 1 und 5 liegen")

    user = _get_user(db, current["user_name"])
    existing = db.query(models.PlaylistRating).filter_by(song_id=song_id, user_id=user.id).first()

    if existing:
        existing.rating = rating_val
        existing.comment = body.get("comment")
        existing.updated_at = datetime.now(timezone.utc)
    else:
        now = datetime.now(timezone.utc)
        db.add(models.PlaylistRating(
            song_id=song_id,
            user_id=user.id,
            rating=rating_val,
            comment=body.get("comment"),
            created_at=now,
            updated_at=now,
        ))

    db.commit()
    return {"message": "Bewertung gespeichert"}


@router.delete("/songs/{song_id}/rate")
def delete_own_rating(
    song_id: int,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user_dep),
    pcfg: dict = Depends(_playlist_cfg),
):
    """Withdraw own rating from a playlist song."""
    user = _get_user(db, current["user_name"])
    existing = db.query(models.PlaylistRating).filter_by(song_id=song_id, user_id=user.id).first()
    if existing:
        db.delete(existing)
        db.commit()
    return {"message": "Bewertung entfernt"}


# ── Search ────────────────────────────────────────────────────────────────────

@router.get("/search")
def search_tracks(
    q: str = Query(..., min_length=2, description="Suchbegriff"),
    platform: str = Query("spotify", description="spotify oder tidal"),
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user_dep),
    pcfg: dict = Depends(_playlist_cfg),
):
    """Search for tracks on a streaming platform to propose a song."""
    if platform == "spotify":
        if not pcfg.get("spotify", {}).get("enabled"):
            raise HTTPException(status_code=400, detail="Spotify ist nicht aktiviert")
        spot_cfg = svc.build_platform_cfg(db, "spotify")
        if not spot_cfg:
            raise HTTPException(status_code=400, detail="Spotify-Zugangsdaten nicht konfiguriert")
        token = svc.spotify_get_access_token(db, spot_cfg)
        if not token:
            raise HTTPException(status_code=400, detail="Spotify nicht verbunden – Admin muss OAuth durchführen")
        return svc.spotify_search_track(token, q)
    elif platform == "tidal":
        if not pcfg.get("tidal", {}).get("enabled"):
            raise HTTPException(status_code=400, detail="Tidal ist nicht aktiviert")
        tidal_cfg = svc.build_platform_cfg(db, "tidal")
        if not tidal_cfg:
            raise HTTPException(status_code=400, detail="Tidal-Zugangsdaten nicht konfiguriert")
        token = svc.tidal_get_access_token(db, tidal_cfg)
        if not token:
            raise HTTPException(status_code=400, detail="Tidal nicht verbunden – Admin muss OAuth durchführen")
        return svc.tidal_search_track(token, tidal_cfg["client_id"], q)
    else:
        raise HTTPException(status_code=400, detail="Unbekannte Plattform (spotify oder tidal)")


# ── Sync (Admin only) ─────────────────────────────────────────────────────────

@router.post("/sync")
def trigger_sync(
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user_dep),
    pcfg: dict = Depends(_playlist_cfg),
):
    """Trigger a full playlist sync with all configured platforms (admin only)."""
    if not check_admin(current):
        raise HTTPException(status_code=403, detail="Nur Admins können den Sync auslösen")
    # Build full config merging appConfig flags with DB credentials
    merged = _build_sync_cfg(db, pcfg)
    results = svc.sync_playlists(db, merged)
    return results


def _build_sync_cfg(db: Session, pcfg: dict) -> dict:
    """Merge appConfig flags with per-platform credentials from DB."""
    cfg = dict(pcfg)
    for platform in ("spotify", "tidal"):
        platform_flags = pcfg.get(platform, {})
        db_creds = svc.build_platform_cfg(db, platform) or {}
        cfg[platform] = {**platform_flags, **db_creds}
    return cfg


@router.get("/sync/log")
def get_sync_log(
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user_dep),
    pcfg: dict = Depends(_playlist_cfg),
):
    """Return the last 100 sync log entries (admin only)."""
    if not check_admin(current):
        raise HTTPException(status_code=403, detail="Nur Admins")
    logs = (
        db.query(models.PlaylistSyncLog)
        .order_by(models.PlaylistSyncLog.timestamp.desc())
        .limit(100)
        .all()
    )
    return [
        {
            "id": l.id,
            "song_id": l.song_id,
            "platform": l.platform,
            "action": l.action,
            "timestamp": l.timestamp.isoformat() if l.timestamp else None,
            "error_message": l.error_message,
        }
        for l in logs
    ]


# ── OAuth ─────────────────────────────────────────────────────────────────────

def _redirect_uri(request: Request, platform: str) -> str:
    base = str(request.base_url).rstrip("/")
    return f"{base}/playlist/oauth/{platform}/callback"


@router.get("/oauth/status")
def oauth_status(
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user_dep),
    pcfg: dict = Depends(_playlist_cfg),
):
    """Return OAuth connection status for each platform (admin only)."""
    if not check_admin(current):
        raise HTTPException(status_code=403, detail="Nur Admins")

    def _status(platform: str) -> dict:
        rec = db.query(models.StreamingToken).filter_by(platform=platform).first()
        connected = bool(rec and rec.access_token_enc)
        expires = rec.token_expires_at.isoformat() if (rec and rec.token_expires_at) else None
        return {"connected": connected, "expires_at": expires, "scope": rec.scope if rec else None}

    return {"spotify": _status("spotify"), "tidal": _status("tidal")}


@router.delete("/oauth/{platform}/disconnect")
def disconnect_platform(
    platform: str,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user_dep),
    pcfg: dict = Depends(_playlist_cfg),
):
    """Remove stored OAuth tokens for a platform (admin only)."""
    if not check_admin(current):
        raise HTTPException(status_code=403, detail="Nur Admins")
    if platform not in ("spotify", "tidal"):
        raise HTTPException(status_code=400, detail="Unbekannte Plattform")
    rec = db.query(models.StreamingToken).filter_by(platform=platform).first()
    if rec:
        db.delete(rec)
        db.commit()
    return {"message": f"{platform.capitalize()} getrennt"}


# ── Spotify OAuth flow ────────────────────────────���───────────────────────────

@router.get("/oauth/spotify/connect")
def spotify_connect(
    request: Request,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user_dep),
    pcfg: dict = Depends(_playlist_cfg),
):
    """Redirect admin to Spotify OAuth consent page."""
    if not check_admin(current):
        raise HTTPException(status_code=403, detail="Nur Admins")
    spot_cfg = svc.build_platform_cfg(db, "spotify")
    if not spot_cfg or not spot_cfg.get("client_id"):
        raise HTTPException(status_code=400, detail="Spotify client_id fehlt – bitte zuerst Zugangsdaten speichern")
    url, _ = svc.spotify_get_auth_url(spot_cfg["client_id"], _redirect_uri(request, "spotify"))
    return RedirectResponse(url)


@router.get("/oauth/spotify/callback")
def spotify_callback(
    request: Request,
    db: Session = Depends(auth.get_db),
    code: Optional[str] = Query(None),
    state: Optional[str] = Query(None),
    error: Optional[str] = Query(None),
    error_description: Optional[str] = Query(None),
    pcfg: dict = Depends(_playlist_cfg),
):
    """Handle Spotify OAuth callback and store encrypted tokens."""
    logger.info("Spotify OAuth callback: code=%s state=%s error=%s", bool(code), bool(state), error)
    if error:
        raise HTTPException(status_code=400, detail=f"Spotify-Fehler: {error} – {error_description or ''}")
    if not code or not state:
        raise HTTPException(status_code=400, detail="Fehlende OAuth-Parameter")

    state_data = svc.consume_oauth_state(state)
    if not state_data or state_data["platform"] != "spotify":
        raise HTTPException(status_code=400, detail="Ungültiger oder abgelaufener OAuth-State (evtl. >10 min gewartet?)")

    spot_cfg = svc.build_platform_cfg(db, "spotify")
    if not spot_cfg:
        raise HTTPException(status_code=400, detail="Spotify-Zugangsdaten nicht konfiguriert")

    redirect_uri = _redirect_uri(request, "spotify")
    logger.info("Spotify token exchange: client_id=%s redirect_uri=%s", spot_cfg["client_id"], redirect_uri)
    try:
        token_data = svc.spotify_exchange_code(
            spot_cfg["client_id"],
            redirect_uri,
            code,
            state_data["code_verifier"],
        )
    except Exception as exc:
        logger.error("Spotify token exchange failed: %s", exc)
        raise HTTPException(status_code=400, detail=f"Token-Austausch fehlgeschlagen: {exc}")

    _store_token(db, "spotify", token_data)
    logger.info("Spotify OAuth completed successfully")
    return RedirectResponse("/admin/streaming?spotify=connected")


# ── Tidal OAuth flow ──────────────────────────────────────────────────────────

@router.get("/oauth/tidal/connect")
def tidal_connect(
    request: Request,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user_dep),
    pcfg: dict = Depends(_playlist_cfg),
):
    """Redirect admin to Tidal OAuth consent page."""
    if not check_admin(current):
        raise HTTPException(status_code=403, detail="Nur Admins")
    tidal_cfg = svc.build_platform_cfg(db, "tidal")
    if not tidal_cfg or not tidal_cfg.get("client_id"):
        raise HTTPException(status_code=400, detail="Tidal client_id fehlt – bitte zuerst Zugangsdaten speichern")
    url, _ = svc.tidal_get_auth_url(tidal_cfg["client_id"], _redirect_uri(request, "tidal"))
    return RedirectResponse(url)


@router.get("/oauth/tidal/callback")
def tidal_callback(
    request: Request,
    db: Session = Depends(auth.get_db),
    code: Optional[str] = Query(None),
    state: Optional[str] = Query(None),
    error: Optional[str] = Query(None),
    error_description: Optional[str] = Query(None),
    pcfg: dict = Depends(_playlist_cfg),
):
    """Handle Tidal OAuth callback and store encrypted tokens."""
    logger.info("Tidal OAuth callback received: code=%s state=%s error=%s error_description=%s",
                bool(code), bool(state), error, error_description)
    if error:
        raise HTTPException(status_code=400, detail=f"Tidal-Fehler: {error} – {error_description or ''}")
    if not code or not state:
        raise HTTPException(status_code=400, detail="Fehlende OAuth-Parameter (code oder state fehlt)")

    state_data = svc.consume_oauth_state(state)
    if not state_data or state_data["platform"] != "tidal":
        raise HTTPException(status_code=400, detail="Ungültiger oder abgelaufener OAuth-State (evtl. >10 min gewartet?)")

    tidal_cfg = svc.build_platform_cfg(db, "tidal")
    if not tidal_cfg:
        raise HTTPException(status_code=400, detail="Tidal-Zugangsdaten nicht konfiguriert")

    redirect_uri = _redirect_uri(request, "tidal")
    logger.info("Tidal token exchange: client_id=%s redirect_uri=%s", tidal_cfg["client_id"], redirect_uri)
    try:
        token_data = svc.tidal_exchange_code(
            tidal_cfg["client_id"],
            tidal_cfg["client_secret"],
            redirect_uri,
            code,
            state_data["code_verifier"],
        )
    except Exception as exc:
        logger.error("Tidal token exchange failed: %s", exc)
        raise HTTPException(status_code=400, detail=f"Token-Austausch fehlgeschlagen: {exc}")

    _store_token(db, "tidal", token_data)
    logger.info("Tidal OAuth completed successfully")
    return RedirectResponse("/admin/streaming?tidal=connected")


def _store_token(db: Session, platform: str, token_data: dict) -> None:
    now = datetime.now(timezone.utc)
    rec = db.query(models.StreamingToken).filter_by(platform=platform).first()
    if not rec:
        rec = models.StreamingToken(platform=platform)
        db.add(rec)
    rec.access_token_enc = svc.encrypt_token(token_data["access_token"])
    if "refresh_token" in token_data:
        rec.refresh_token_enc = svc.encrypt_token(token_data["refresh_token"])
    rec.token_expires_at = now + timedelta(seconds=token_data.get("expires_in", 3600))
    rec.scope = token_data.get("scope")
    rec.updated_at = now
    db.commit()


# ── Credential management (Admin only) ───────────────────────────���────────────

@router.get("/credentials")
def get_credentials(
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user_dep),
    pcfg: dict = Depends(_playlist_cfg),
):
    """Return stored credentials (client_id and playlist_id only – no secrets)."""
    if not check_admin(current):
        raise HTTPException(status_code=403, detail="Nur Admins")

    def _creds(platform: str) -> dict:
        rec = db.query(models.StreamingToken).filter_by(platform=platform).first()
        return {
            "client_id": rec.client_id or "" if rec else "",
            "client_secret_set": bool(rec and rec.client_secret_enc) if rec else False,
            "playlist_id": rec.playlist_id or "" if rec else "",
        }

    return {"spotify": _creds("spotify"), "tidal": _creds("tidal")}


@router.put("/credentials/{platform}")
def save_credentials(
    platform: str,
    body: dict,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user_dep),
    pcfg: dict = Depends(_playlist_cfg),
):
    """Save platform credentials to the database (admin only).

    Body fields:
        client_id (str): OAuth application client ID.
        client_secret (str): Client secret – omit or send empty to keep existing.
        playlist_id (str): Target playlist ID on the platform.
    """
    if not check_admin(current):
        raise HTTPException(status_code=403, detail="Nur Admins")
    if platform not in ("spotify", "tidal"):
        raise HTTPException(status_code=400, detail="Unbekannte Plattform")

    client_id = (body.get("client_id") or "").strip()
    client_secret_raw = (body.get("client_secret") or "").strip()
    playlist_id = (body.get("playlist_id") or "").strip()

    if not client_id:
        raise HTTPException(status_code=422, detail="client_id darf nicht leer sein")

    # If client_secret is empty, keep the existing one in the DB
    rec = db.query(models.StreamingToken).filter_by(platform=platform).first()
    if not client_secret_raw and rec and rec.client_secret_enc:
        client_secret_raw = None  # signal: keep existing

    svc.save_credentials(db, platform, client_id, client_secret_raw, playlist_id)
    return {"message": f"{platform.capitalize()} Zugangsdaten gespeichert"}

