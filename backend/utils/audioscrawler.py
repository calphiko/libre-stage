from requests import get
from requests.exceptions import RequestException
from time import sleep
import re


def _normalize_text(value):
    return " ".join((value or "").lower().split())

def _ms_to_datetime(value):
    if value is None:
        return None
    total_seconds = int(value) // 1000
    hours, remainder = divmod(total_seconds, 3600)
    minutes, seconds = divmod(remainder, 60)
    return f"{hours:02d}:{minutes:02d}:{seconds:02d}"


def _extract_people_names(raw_value):
    text = (raw_value or "").strip()
    if not text:
        return []

    # Entfernt Label-Praefixe wie "Texter und Komponist(in):"
    if ":" in text:
        left, right = text.split(":", 1)
        left_normalized = _normalize_text(left)
        if any(keyword in left_normalized for keyword in ("texter", "komponist", "lyricist", "composer", "writer")):
            text = right.strip()

    # Entfernt Klammer-Zusaetze wie "(keyboardist)"
    text = re.sub(r"\s*\([^)]*\)", "", text)

    # Vereinheitlicht Trennzeichen
    text = re.sub(r"\s+(und|and|&)\s+", ",", text, flags=re.IGNORECASE)
    text = text.replace(";", ",")

    names = [part.strip() for part in text.split(",") if part.strip()]
    return names


def _artist_credit_matches(artist_credit, interpret):
    normalized_artist = _normalize_text(interpret)
    if not normalized_artist:
        return False
    artist_names = [
        _normalize_text((credit.get("artist") or {}).get("name"))
        for credit in artist_credit or []
    ]
    return normalized_artist in artist_names or any(
        normalized_artist in name for name in artist_names
    )


def _recording_score(recording, interpret, title):
    score = 0
    normalized_title = _normalize_text(title)
    normalized_recording_title = _normalize_text(recording.get("title"))
    if normalized_recording_title == normalized_title:
        score += 60
    elif normalized_title and normalized_title in normalized_recording_title:
        score += 35

    if _artist_credit_matches(recording.get("artist-credit", []), interpret):
        score += 50

    if recording.get("length"):
        score += 5

    score += int(recording.get("score", recording.get("ext:score", 0)) or 0)
    return score


def _best_recording(recordings, interpret, title):
    return max(recordings, key=lambda item: _recording_score(item, interpret, title))


def _work_score(work, interpret, title):
    score = 0
    normalized_title = _normalize_text(title)
    normalized_work_title = _normalize_text(work.get("title"))
    if normalized_work_title == normalized_title:
        score += 60
    elif normalized_title and normalized_title in normalized_work_title:
        score += 35

    if _artist_credit_matches(work.get("artist-credit", []), interpret):
        score += 40

    score += int(work.get("score", work.get("ext:score", 0)) or 0)
    return score


def _best_work(works, interpret, title):
    return max(works, key=lambda item: _work_score(item, interpret, title))


def _extract_youtube_link(relations):
    for rel in relations or []:
        resource = ((rel.get("url") or {}).get("resource") or "").strip()
        if not resource:
            continue
        normalized = resource.lower()
        if "youtube.com/" in normalized or "youtu.be/" in normalized:
            return resource
    return None


def _extract_youtube_link_from_release_chain(releases, headers):
    # Manche YouTube-Links sind an Release oder Release-Group statt am Recording gespeichert.
    for release in releases or []:
        release_id = release.get("id")
        if not release_id:
            continue

        try:
            sleep(1.1)
            release_data = get(
                url=f"https://musicbrainz.org/ws/2/release/{release_id}",
                params={"inc": "url-rels release-groups", "fmt": "json"},
                headers=headers,
                timeout=10,
            )
            release_data.raise_for_status()
            release_json = release_data.json()
        except RequestException:
            continue

        ytlink = _extract_youtube_link(release_json.get("relations", []))
        if ytlink:
            return ytlink

        release_group_id = (release_json.get("release-group") or {}).get("id")
        if not release_group_id:
            continue

        try:
            sleep(1.1)
            release_group_data = get(
                url=f"https://musicbrainz.org/ws/2/release-group/{release_group_id}",
                params={"inc": "url-rels", "fmt": "json"},
                headers=headers,
                timeout=10,
            )
            release_group_data.raise_for_status()
            release_group_json = release_group_data.json()
        except RequestException:
            continue

        ytlink = _extract_youtube_link(release_group_json.get("relations", []))
        if ytlink:
            return ytlink

    return None


def _fallback_metadata_from_audiodb(interpret, title):
    try:
        track = search_track(interpret, title)
    except RequestException:
        return None

    if not track:
        return None

    composers = _extract_people_names(track.get("strComposer") or track.get("strWriter"))
    lyricists = _extract_people_names(track.get("strLyricist") or track.get("strWriter"))

    ytlink = track.get("strMusicVid")
    if ytlink and not str(ytlink).startswith("http"):
        ytlink = f"https://www.youtube.com/watch?v={ytlink}"

    return {
        "recording_id": None,
        "duration": _ms_to_datetime(track.get("intDuration")),
        "work_id": None,
        "ytlink": ytlink,
        "composers": sorted(set(composers)),
        "lyricists": sorted(set(lyricists)),
    }

def search_track (interpret, title):
    res = get(f"https://www.theaudiodb.com/api/v1/json/123/searchtrack.php?s={interpret}&t={title}")
    if res.status_code == 200:
        data = res.json()
        if data["track"] is not None:
            return data["track"][0]
    return None

def search_track_musicbrainz(interpret, title):
    headers = {
        # MusicBrainz möchte einen klaren User-Agent
        "User-Agent": "libre-stage/1.0 ( kontakt@example.com )"
    }
    try:
        # 1) Suche nach passender Recording-ID
        res = get(
            url="https://musicbrainz.org/ws/2/recording",
            params={
                "query": f'recording:"{title}" AND artist:"{interpret}"',
                "fmt": "json",
                "limit": 10,
            },
            headers=headers,
            timeout=10,
        )
        res.raise_for_status()
        data = res.json()
    except RequestException:
        return _fallback_metadata_from_audiodb(interpret, title)

    recordings = data.get("recordings", [])
    if not recordings:
        try:
            sleep(1.1)
            fallback_res = get(
                url="https://musicbrainz.org/ws/2/recording",
                params={
                    "query": f'recording:"{title}"',
                    "fmt": "json",
                    "limit": 10,
                },
                headers=headers,
                timeout=10,
            )
            fallback_res.raise_for_status()
            fallback_data = fallback_res.json()
            fallback_recordings = fallback_data.get("recordings", [])
            if not fallback_recordings:
                return _fallback_metadata_from_audiodb(interpret, title)

            fallback_recordings = [
                recording
                for recording in fallback_recordings
                if _artist_credit_matches(recording.get("artist-credit", []), interpret)
            ]
            if not fallback_recordings:
                return _fallback_metadata_from_audiodb(interpret, title)

            recordings = [_best_recording(fallback_recordings, interpret, title)]
        except RequestException:
            return _fallback_metadata_from_audiodb(interpret, title)

    rec = _best_recording(recordings, interpret, title)
    recording_id = rec.get("id")
    duration_ms = rec.get("length")  # Dauer in Millisekunden
    work_id = None
    ytlink = None
    composers = []
    lyricists = []

    # 2) Recording-Details mit Work-Relationen laden
    try:
        sleep(1.1)  # MusicBrainz empfiehlt max. 1 Request pro Sekunde.
        rec_details = get(
            url=f"https://musicbrainz.org/ws/2/recording/{recording_id}",
            params={"inc": "work-rels url-rels releases", "fmt": "json"},
            headers=headers,
            timeout=10,
        )
        rec_details.raise_for_status()
        rec_data = rec_details.json()
        ytlink = _extract_youtube_link(rec_data.get("relations", []))
        if not ytlink:
            ytlink = _extract_youtube_link_from_release_chain(rec_data.get("releases", []), headers)
        for rel in rec_data.get("relations", []):
            if rel.get("type") == "performance" and rel.get("work"):
                work_id = rel["work"].get("id")
                break
    except RequestException:
        pass

    # Fallback: Nicht alle Recordings haben eine direkte Work-Relation.
    if not work_id:
        try:
            sleep(1.1)
            work_search = get(
                url="https://musicbrainz.org/ws/2/work",
                params={
                    "query": f'work:"{title}" AND artist:"{interpret}"',
                    "fmt": "json",
                    "limit": 10,
                },
                headers=headers,
                timeout=10,
            )
            work_search.raise_for_status()
            work_search_data = work_search.json()
            works = work_search_data.get("works", [])
            if not works:
                sleep(1.1)
                work_search = get(
                    url="https://musicbrainz.org/ws/2/work",
                    params={
                        "query": f'work:"{title}"',
                        "fmt": "json",
                        "limit": 10,
                    },
                    headers=headers,
                    timeout=10,
                )
                work_search.raise_for_status()
                work_search_data = work_search.json()
                works = work_search_data.get("works", [])

                works = [
                    work
                    for work in works
                    if _artist_credit_matches(work.get("artist-credit", []), interpret)
                ]

            if works:
                work_id = _best_work(works, interpret, title).get("id")
        except RequestException:
            pass

    # 3) Work-Details für Komponist/Texter
    if work_id:
        try:
            sleep(1.1)
            work_url = f"https://musicbrainz.org/ws/2/work/{work_id}"
            work_params = {"inc": "artist-rels url-rels", "fmt": "json"}
            wr = get(work_url, params=work_params, headers=headers, timeout=10)
            wr.raise_for_status()
            work = wr.json()

            if not ytlink:
                ytlink = _extract_youtube_link(work.get("relations", []))

            for rel in work.get("relations", []):
                rel_type = rel.get("type")
                rel_type_normalized = _normalize_text(rel_type)
                raw_credit = (
                    (rel.get("artist") or {}).get("name")
                    or rel.get("target-credit")
                    or rel.get("name")
                )
                names = _extract_people_names(raw_credit)
                if not names:
                    continue

                is_composer = rel_type_normalized == "composer" or (
                    "composer" in rel_type_normalized and ("lyricist" in rel_type_normalized or "writer" in rel_type_normalized or "texter" in rel_type_normalized)
                )
                is_lyricist = rel_type_normalized == "lyricist" or (
                    "lyricist" in rel_type_normalized and "composer" in rel_type_normalized
                )
                is_writer = rel_type_normalized == "writer" or "texter" in rel_type_normalized

                if is_composer or is_writer:
                    composers.extend(names)
                if is_lyricist or is_writer:
                    lyricists.extend(names)
        except RequestException:
            pass

    return {
        "recording_id": recording_id,
        "duration": _ms_to_datetime(duration_ms),
        "work_id": work_id,
        "ytlink": ytlink,
        "composers": sorted(set(composers)),
        "lyricists": sorted(set(lyricists)),
    }

