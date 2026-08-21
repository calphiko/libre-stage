# libre-stage - Band rehearsal and gig management software
# Copyright (C) 2026  libre-stage contributors
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

"""
Song catalogue router.

Handles CRUD operations for songs in the band's repertoire, song
candidate proposals (member submissions), voting/feedback on
candidates, and per-song rehearsal and gig statistics.

Requires authentication. Create/update/delete operations additionally
require the ``editor`` or ``admin`` role.

Prefix: ``/songs``  |  Tag: ``songs``
"""

from fastapi import APIRouter, Depends, HTTPException, Response, Query
from datetime import time, datetime, date
import logging
import os
import hashlib
import json
import csv
from io import StringIO
from types import SimpleNamespace

from sqlalchemy.orm import Session, joinedload
from typing import List, Literal

from backend import models, schemas, auth
from backend.utils import mattermost
from backend.utils import audioscrawler
from backend.pdf.generator import SetlistPDF

from dotenv import load_dotenv

from backend.utils.check_permissions import check_editor, check_admin


router = APIRouter(
    prefix="/songs", tags=["songs"], dependencies=[Depends(auth.get_current_user_dep)]
)

logger = logging.getLogger("uvicorn.error")
# suppress progress polls to reduce log clutter
block_endpoints = ["/songs/log"]

# Mattermost stuff
load_dotenv(".env")
MM_CHANNEL = os.getenv("MM_CHANNEL_SONG_VOTES")


def _calculate_setlist_version(payload: dict) -> str:
    version_input = {
        "id": payload.get("id"),
        "begin": payload.get("begin"),
        "end": payload.get("end"),
        "sets": payload.get("sets", []),
    }
    canonical = json.dumps(version_input, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()[:16]


def _build_repertoire_setlist_payload(repertoire_setlist: models.RepertoireSetlist) -> dict:
    payload = {
        "id": repertoire_setlist.id,
        "name": repertoire_setlist.name,
        "datum": None,
        "organizer": None,
        "kind_of_gig": None,
        "venue": None,
        "doors": None,
        "begin": None,
        "end": None,
        "status": None,
        "publish": None,
        "notes": None,
        "sets": [
            {
                "id": listset.id,
                "listset_id": listset.id,
                "set_id": listset.set.id,
                "set_name": listset.set.name,
                "pause": listset.set.pause.strftime("%H:%M:%S") if listset.set.pause else "00:10:00",
                "setlist_name": listset.set.setlist_name,
                "songs": [setsong.to_setlist_dict() for setsong in listset.set.songs],
            }
            for listset in sorted(repertoire_setlist.sets, key=lambda x: x.position)
        ],
        "timing": None,
    }
    payload["setlist_version"] = _calculate_setlist_version(payload)
    return payload


def _delete_set_if_orphaned(db: Session, set_id: int) -> None:
    has_gig_links = db.query(models.GigSet).filter_by(id_set=set_id).first() is not None
    has_repertoire_links = db.query(models.RepertoireSetlistSet).filter_by(set_id=set_id).first() is not None
    if has_gig_links or has_repertoire_links:
        return
    db.query(models.SetSong).filter_by(id_set=set_id).delete()
    db.query(models.Set).filter_by(id=set_id).delete()


def _sanitize_filename(name: str) -> str:
    safe = "".join(ch if ch.isalnum() or ch in (" ", "-", "_") else "_" for ch in (name or "").strip())
    safe = "_".join(safe.split())
    return safe or "repertoire_setlist"


_SINGER_COLOR_PALETTE = [
    "#29B619", "#227FFF", "#E644C3", "#FF8C00", "#8B5CF6",
    "#059669", "#DC2626", "#CA8A04", "#0891B2", "#6366F1",
]


def _build_repertoire_singer_colors(entry: models.RepertoireSetlist) -> dict[str, str]:
    singers = sorted({
        (setsong.song.singer_lead or "").replace("+", " ").replace(",", " ").split(" ")[0]
        for listset in entry.sets
        for setsong in listset.set.songs
        if setsong.song and setsong.song.singer_lead
    })
    return {
        singer: _SINGER_COLOR_PALETTE[idx % len(_SINGER_COLOR_PALETTE)]
        for idx, singer in enumerate(singers)
    }


def _build_repertoire_setlist_pdf(entry: models.RepertoireSetlist, design: Literal["dark", "print"] = "dark") -> bytes:
    ordered_listsets = sorted(entry.sets, key=lambda x: x.position)
    virtual_sets = [
        SimpleNamespace(position=idx, set=listset.set)
        for idx, listset in enumerate(ordered_listsets, start=1)
    ]
    virtual_gig = SimpleNamespace(
        name=f"Repertoire: {entry.name}",
        datum=date.today(),
        begin=time(19, 0),
        sets=virtual_sets,
    )

    singer_colors = _build_repertoire_singer_colors(entry)

    return SetlistPDF(
        virtual_gig,
        {},
        singer_colors,
        style_mode=design,
        slot_durations={},
    ).build().getvalue()


def _build_repertoire_setlist_csv(entry: models.RepertoireSetlist) -> str:
    payload = _build_repertoire_setlist_payload(entry)
    out = StringIO()
    writer = csv.writer(out, delimiter=';')
    writer.writerow(["Set", "Position", "Interpret", "Titel", "Dauer", "Lead-Sänger", "Kommentar"])

    for set_idx, set_entry in enumerate(payload.get("sets", []), start=1):
        set_label = set_entry.get("setlist_name") or set_entry.get("set_name") or f"Set {set_idx}"
        songs = set_entry.get("songs", [])
        if not songs:
            writer.writerow([set_label, "", "", "", "", "", ""])
            continue

        for song_pos, song in enumerate(songs, start=1):
            writer.writerow([
                set_label,
                song_pos,
                song.get("interpret") or "",
                song.get("title") or "",
                song.get("duration") or "",
                song.get("singer_lead") or "",
                song.get("comment") or "",
            ])

    return out.getvalue()

@router.get("/", response_model = List[schemas.SongOut])
def get_songs(db: Session = Depends(auth.get_db),
              current=Depends(auth.get_current_user),
              ):
    songs = db.query(models.Song).filter(models.Song.status != "vorschlag").all()
    if not songs:
        raise HTTPException(status_code=404, detail="No songs found")
    return songs

@router.get("/candidates/", response_model = List[schemas.SongCandidateOut])
def get_song_candidates(db: Session = Depends(auth.get_db),
              current=Depends(auth.get_current_user)
                  ):
    songs = db.query(models.Song).options(joinedload(models.Song.feedbacks)).filter(models.Song.status == "vorschlag").all()
    if not songs:
        raise HTTPException(status_code=404, detail="No song candidates found")
    return songs


@router.get("/repertoire_setlists", response_model=List[schemas.RepertoireSetlistSummaryOut])
def get_repertoire_setlists(
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user),
):
    setlists = (
        db.query(models.RepertoireSetlist)
        .order_by(models.RepertoireSetlist.name.asc(), models.RepertoireSetlist.id.asc())
        .all()
    )
    return [
        schemas.RepertoireSetlistSummaryOut(
            id=setlist.id,
            name=setlist.name,
            set_count=len(setlist.sets),
        )
        for setlist in setlists
    ]


@router.post("/repertoire_setlists", response_model=schemas.RepertoireSetlistSummaryOut)
def create_repertoire_setlist(
    repertoire_setlist: schemas.RepertoireSetlistCreateIn,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user),
):
    if not check_editor(current):
        raise HTTPException(status_code=403, detail="Not enough permissions")

    name = (repertoire_setlist.name or "").strip()
    if not name:
        raise HTTPException(status_code=400, detail="Name darf nicht leer sein")

    entry = models.RepertoireSetlist(name=name)
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return schemas.RepertoireSetlistSummaryOut(id=entry.id, name=entry.name, set_count=0)


@router.delete("/repertoire_setlists/{setlist_id}", response_model=schemas.RepertoireSetlistSummaryOut)
def delete_repertoire_setlist(
    setlist_id: int,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user),
):
    if not check_editor(current):
        raise HTTPException(status_code=403, detail="Not enough permissions")

    entry = db.query(models.RepertoireSetlist).filter_by(id=setlist_id).first()
    if not entry:
        raise HTTPException(status_code=404, detail="Repertoire setlist not found")

    linked_set_ids = [link.set_id for link in entry.sets]
    db.delete(entry)
    db.flush()
    for set_id in linked_set_ids:
        _delete_set_if_orphaned(db, set_id)
    db.commit()

    return schemas.RepertoireSetlistSummaryOut(id=setlist_id, name=entry.name, set_count=0)


@router.get("/repertoire_setlists/{setlist_id}/setlist", response_model=schemas.GigSetlistOut)
def get_repertoire_setlist(
    setlist_id: int,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user),
):
    entry = db.query(models.RepertoireSetlist).filter_by(id=setlist_id).first()
    if not entry:
        raise HTTPException(status_code=404, detail="Repertoire setlist not found")
    return _build_repertoire_setlist_payload(entry)


@router.get("/repertoire_setlists/{setlist_id}/setlist.pdf", response_class=Response)
def export_repertoire_setlist_pdf(
    setlist_id: int,
    design: Literal["dark", "print"] = Query(
        "dark",
        description="Design-Variante fuer die Setlisten-PDF (dark oder print).",
    ),
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user),
):
    entry = db.query(models.RepertoireSetlist).filter_by(id=setlist_id).first()
    if not entry:
        raise HTTPException(status_code=404, detail="Repertoire setlist not found")

    filename = f"repertoire_setlist_{_sanitize_filename(entry.name)}.pdf"
    pdf_bytes = _build_repertoire_setlist_pdf(entry, design=design)
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/repertoire_setlists/{setlist_id}/setlist.csv", response_class=Response)
def export_repertoire_setlist_csv(
    setlist_id: int,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user),
):
    entry = db.query(models.RepertoireSetlist).filter_by(id=setlist_id).first()
    if not entry:
        raise HTTPException(status_code=404, detail="Repertoire setlist not found")

    filename = f"repertoire_setlist_{_sanitize_filename(entry.name)}.csv"
    csv_content = _build_repertoire_setlist_csv(entry)
    return Response(
        content=csv_content,
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.put("/repertoire_setlists/{setlist_id}/setlist", response_model=schemas.GigSetlistOut)
def update_repertoire_setlist(
    setlist_id: int,
    repertoire_setlist: schemas.GetSetlistIn,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user),
):
    if not check_editor(current):
        raise HTTPException(status_code=403, detail="Not enough permissions")

    db_setlist = db.query(models.RepertoireSetlist).filter_by(id=setlist_id).first()
    if not db_setlist:
        raise HTTPException(status_code=404, detail="Repertoire setlist not found")

    current_payload = _build_repertoire_setlist_payload(db_setlist)
    if (
        repertoire_setlist.setlist_version
        and repertoire_setlist.setlist_version != current_payload["setlist_version"]
    ):
        raise HTTPException(
            status_code=409,
            detail={
                "code": "SETLIST_CONFLICT",
                "message": "Setliste wurde zwischenzeitlich geaendert. Bitte erneut versuchen.",
                "current_setlist": current_payload,
            },
        )

    input_song_ids = {
        song_data.song_id
        for set_data in repertoire_setlist.sets
        for song_data in set_data.songs
    }
    existing_songs = db.query(models.Song).filter(models.Song.id.in_(input_song_ids)).all() if input_song_ids else []
    songs_by_id = {song.id: song for song in existing_songs}
    missing_song_ids = sorted(input_song_ids - set(songs_by_id.keys()))
    if missing_song_ids:
        raise HTTPException(status_code=400, detail="Song not found")

    try:
        db_setlist.name = (repertoire_setlist.name or db_setlist.name).strip()

        old_listsets = db.query(models.RepertoireSetlistSet).filter_by(repertoire_setlist_id=setlist_id).all()
        existing_sets = {listset.set.id: listset.set for listset in old_listsets}
        existing_listsets_by_set_id = {listset.set.id: listset for listset in old_listsets}
        input_set_ids = {set_data.set_id for set_data in repertoire_setlist.sets if getattr(set_data, "set_id", None)}

        for listset in old_listsets:
            if listset.set.id not in input_set_ids:
                db.delete(listset)

        db.flush()

        for set_id in existing_sets:
            if set_id not in input_set_ids:
                _delete_set_if_orphaned(db, set_id)

        for set_pos, set_data in enumerate(repertoire_setlist.sets, start=1):
            if getattr(set_data, "set_id", None) and set_data.set_id in existing_sets:
                set_obj = existing_sets[set_data.set_id]
                set_obj.name = set_data.set_name
                set_obj.pause = time.fromisoformat(set_data.pause) if set_data.pause else time(0, 10, 0)
                set_obj.setlist_name = set_data.setlist_name
                db.flush()
                db.query(models.SetSong).filter_by(id_set=set_obj.id).delete()
            else:
                set_obj = models.Set(
                    name=set_data.set_name,
                    pause=time.fromisoformat(set_data.pause) if set_data.pause else time(0, 10, 0),
                    setlist_name=set_data.setlist_name,
                )
                db.add(set_obj)
                db.flush()

            for song_pos, song_data in enumerate(set_data.songs, start=1):
                song = songs_by_id.get(song_data.song_id)
                if not song:
                    raise HTTPException(status_code=400, detail="Song not found")
                db.add(
                    models.SetSong(
                        id_set=set_obj.id,
                        id_song=song.id,
                        position=song_pos,
                    )
                )

            listset = existing_listsets_by_set_id.get(set_obj.id)
            if not listset:
                listset = models.RepertoireSetlistSet(
                    repertoire_setlist_id=db_setlist.id,
                    set_id=set_obj.id,
                    position=set_pos,
                )
                db.add(listset)
            else:
                listset.position = set_pos

        db.commit()
    except HTTPException:
        db.rollback()
        raise
    except Exception:
        db.rollback()
        raise

    db.refresh(db_setlist)
    return _build_repertoire_setlist_payload(db_setlist)

@router.get("/info/{song_id}", response_model = schemas.SongInSetOut)
def get_songs(song_id: int, db: Session = Depends(auth.get_db),
              current=Depends(auth.get_current_user),
              ):
    song = db.query(models.Song).get(song_id)

    if not song:
        raise HTTPException(status_code=404, detail="Song not found")
    song = song.to_setlist_element()

    return song


@router.get("/{song_id:int}", response_model=schemas.SongOut)
def get_song_details(
    song_id: int,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user),
):
    """Return full song details for the song modal/edit form."""
    song = db.query(models.Song).get(song_id)
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")
    return song


@router.get("/{song_id}/rehearsal_history", response_model=List[schemas.SongRehearsalHistoryEntry])
def get_song_rehearsal_history(
    song_id: int,
    limit: int = Query(default=3, ge=1, le=10),
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user),
):
    """Gibt die letzten N Proben zurück, in denen dieser Song geprobt wurde."""
    song = db.query(models.Song).get(song_id)
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")

    # Alle RehSong-Einträge für diesen Song, absteigend nach Probe-Datum
    reh_songs = (
        db.query(models.RehSong)
        .join(models.Rehearsal, models.RehSong.id_rehearsal == models.Rehearsal.id)
        .filter(models.RehSong.id_song == song_id)
        .order_by(models.Rehearsal.begin.desc())
        .limit(limit)
        .all()
    )

    result = []
    for rs in reh_songs:
        todos = (
            db.query(models.RehTodo)
            .filter(
                models.RehTodo.id_song == song_id,
                models.RehTodo.id_reh == rs.id_rehearsal,
            )
            .all()
        )

        result.append(schemas.SongRehearsalHistoryEntry(
            rehearsal_id=rs.id_rehearsal,
            rehearsal_date=rs.rehearsal.begin,
            comment=rs.comment,
            todo=rs.todo,
            done=rs.done or False,
            rehearsal_comment=rs.rehearsal.comment,
            todos=[
                schemas.SongRehearsalHistoryTodo(
                    id=t.id, id_user=t.id_user, todo=t.todo, done=t.done or False
                )
                for t in todos
            ],
        ))

    return result


@router.get("/{song_id}/feedback", response_model=schemas.SongFeedbackSummary)
def get_song_feedback_history(
    song_id: int,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user),
):
    """Gibt anonymisierte Abstimmungssummen aus der Tabelle song_feedback zurück."""
    song = db.query(models.Song).get(song_id)
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")

    feedback_rows = (
        db.query(models.SongCandidateFeedback.feedback)
        .filter(models.SongCandidateFeedback.song_id == song_id)
        .all()
    )

    yes_votes = 0
    no_votes = 0
    abstain_votes = 0
    unknown_votes = 0

    for (vote,) in feedback_rows:
        if vote == 'a':
            yes_votes += 1
        elif vote == 'na':
            no_votes += 1
        elif vote == 'o':
            abstain_votes += 1
        else:
            unknown_votes += 1

    return schemas.SongFeedbackSummary(
        song_id=song_id,
        total_votes=len(feedback_rows),
        yes_votes=yes_votes,
        no_votes=no_votes,
        abstain_votes=abstain_votes,
        unknown_votes=unknown_votes,
    )


@router.get("/{song_id}/statistics", response_model=schemas.SongStatistics)
def get_song_statistics(
    song_id: int,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user),
):
    """Gibt umfangreiche Statistiken über einen Song zurück."""
    song = db.query(models.Song).get(song_id)
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")

    # --- PROBEN-STATISTIKEN ---
    reh_songs = (
        db.query(models.RehSong)
        .join(models.Rehearsal, models.RehSong.id_rehearsal == models.Rehearsal.id)
        .filter(models.RehSong.id_song == song_id)
        .order_by(models.Rehearsal.begin.asc())
        .all()
    )
    rehearsal_count = len(reh_songs)
    first_rehearsal = reh_songs[0].rehearsal.begin.strftime('%Y-%m-%d') if reh_songs else None
    last_rehearsal = reh_songs[-1].rehearsal.begin.strftime('%Y-%m-%d') if reh_songs else None

    # --- GIG-STATISTIKEN ---
    # Finde alle SetSongs für diesen Song, mit zugehörigem Set → GigSet → Gig
    set_songs = (
        db.query(models.SetSong)
        .filter(models.SetSong.id_song == song_id)
        .all()
    )

    gigs_played = []
    seen_gig_ids = set()
    feedback_values = []
    skipped_count = 0
    inserted_count = 0

    for ss in set_songs:
        # Finde GigSet für dieses Set
        gig_set = (
            db.query(models.GigSet)
            .filter(models.GigSet.id_set == ss.id_set)
            .first()
        )
        if not gig_set:
            continue

        gig = gig_set.gig
        if gig.id not in seen_gig_ids:
            seen_gig_ids.add(gig.id)
            gigs_played.append(schemas.GigPlayedEntry(
                gig_id=gig.id,
                gig_name=gig.name,
                gig_date=gig.datum.strftime('%Y-%m-%d') if gig.datum else '',
                feedback=ss.feedback,
                uebersprungen=ss.uebersprungen,
                eingeschoben=ss.eingeschoben,
            ))

        if ss.feedback is not None:
            feedback_values.append(ss.feedback)
        if ss.uebersprungen:
            skipped_count += 1
        if ss.eingeschoben:
            inserted_count += 1

    # Sortiere Gigs nach Datum absteigend
    gigs_played.sort(key=lambda g: g.gig_date, reverse=True)

    # Feedback-Verteilung
    feedback_distribution = {}
    for fv in feedback_values:
        feedback_distribution[fv] = feedback_distribution.get(fv, 0) + 1
    feedback_avg = round(sum(feedback_values) / len(feedback_values), 2) if feedback_values else None

    # --- HÄUFIGE SET-BEGLEITER ---
    # Finde alle Sets, in denen dieser Song vorkommt
    set_ids = [ss.id_set for ss in set_songs]
    companion_counts = {}
    if set_ids:
        companions = (
            db.query(models.SetSong)
            .filter(
                models.SetSong.id_set.in_(set_ids),
                models.SetSong.id_song != song_id,
            )
            .all()
        )
        for c in companions:
            if c.id_song not in companion_counts:
                companion_counts[c.id_song] = 0
            companion_counts[c.id_song] += 1

    # Top 10 Begleiter
    top_companions = sorted(companion_counts.items(), key=lambda x: x[1], reverse=True)[:10]
    companion_songs = []
    for comp_song_id, count in top_companions:
        comp_song = db.query(models.Song).get(comp_song_id)
        if comp_song:
            companion_songs.append(schemas.CompanionSong(
                song_id=comp_song.id,
                title=comp_song.title,
                interpret=comp_song.interpret or '',
                count=count,
            ))

    return schemas.SongStatistics(
        rehearsal_count=rehearsal_count,
        first_rehearsal=first_rehearsal,
        last_rehearsal=last_rehearsal,
        gig_count=len(gigs_played),
        gigs_played=gigs_played,
        feedback_count=len(feedback_values),
        feedback_avg=feedback_avg,
        feedback_distribution=feedback_distribution,
        skipped_count=skipped_count,
        inserted_count=inserted_count,
        companion_songs=companion_songs,
    )


@router.put("/{song_id}", response_model=schemas.SongOut)
def update_song(song_id: int, song: schemas.SongIn, db: Session = Depends(auth.get_db), current=Depends(
    auth.get_current_user)):
    db_song = db.query(models.Song).get(song_id)
    if not db_song:
        raise HTTPException(status_code=404, detail="Song not found")

    logger.info(f"Updating song ID {song_id} with data: {song.model_dump(exclude_unset=True)} by user {current['user_name']}")

    if not check_editor(current):
        logger.error(f"Permission denied: User {current['user_name']} is not editor")
        raise HTTPException(status_code=403, detail="Not enough permissions")

    for k, v in song.model_dump(exclude_unset=True).items():
        if k == "brass" and v is not None:
            v = int(v)
        if k == "duration" and isinstance(v, str):
            # Fallback-Konvertierung
            h, m, s = map(int, v.split(":")) # pragma: no cover
            v = time(hour=h, minute=m, second=s)# pragma: no cover
        if k == "ytlink" and v in ("None", "", None):
            v = None
        setattr(db_song, k, v)
    db.commit()
    db.refresh(db_song)
    return db_song

@router.delete("/{song_id}", response_model=schemas.SongOut)
def delete_song(
        song_id: int,
        db: Session = Depends(auth.get_db), current=Depends(
        auth.get_current_user)
    ):
    db_song = db.query(models.Song).get(song_id)

    if not check_editor(current):
        raise HTTPException(status_code=403, detail="Not authorized to delete songs")

    if not db_song:
        raise HTTPException(status_code=404, detail="Song not found")

    logger.info(f"Deleting song ID {song_id} by user {current['user_name']}")

    #set db_song.status to 'retired' instead of deleting
    db_song.status = 'retired'
    db.commit()

    return db_song


@router.post("/", response_model=schemas.SongOut)
def create_song(
        song: schemas.SongIn,
        db: Session = Depends(auth.get_db), current=Depends(
        auth.get_current_user)
    ):
    new_song = models.Song(
        title=song.title,
        interpret=song.interpret,
        genre=song.genre,
        singer_background=song.singer_background,
        singer_lead=song.singer_lead,
        dance_styles=song.dance_styles,
        composer=song.composer,
        texter=song.texter,
        publisher=song.publisher,
        arrangement=song.arrangement,
        tone_key=song.tone_key,
        status=song.status,
        comment=song.comment,
        ytlink=song.ytlink,
        brass=int(song.brass) if song.brass is not None else 0,
        text=song.text,
        duration=song.duration
    )

    logger.info(f"Creating new song '{song.title}' by user {current['user_name']}")

    db.add(new_song)
    db.commit()
    db.refresh(new_song)
    # Notify Mattermost about the new song
    try:
        mattermost.send_mm_message(f" :mega: Neuer Songvorschlag:\n\t**{new_song.title}** von **{new_song.interpret}** wurde hinzugefügt.\n\tYoutube: [klick]({new_song.ytlink})\nBitte gib im internen Bereich deine Stimme ab.", channel=MM_CHANNEL)
    except Exception as e:
        logger.error(f"Fehler beim Senden der Benachrichtigung an Mattermost: {e}")
    return new_song


@router.put("/candidates/feedback/{song_id}", response_model=List[schemas.SongFeedbackBase])
def update_song_feedback(
        song_id: int,
        feedback: List[schemas.SongFeedbackIn],
        db: Session = Depends(auth.get_db),
        current=Depends(auth.get_current_user)
):
    song = db.query(models.Song).get(song_id)
    if not song:
        raise HTTPException(status_code=404, detail="Song candidate not found")
    if song.status != "vorschlag":
        raise HTTPException(status_code=400, detail="Feedback can only be added to song candidates")

    # Alle bestehenden Feedbacks für diesen Song abrufen
    existing_feedbacks = {
        fb.user_id: fb
        for fb in db.query(models.SongCandidateFeedback)
        .filter(models.SongCandidateFeedback.song_id == song_id)
        .all()
    }

    # Neue Feedbacks verarbeiten
    new_feedback_user_ids = set()
    for feedback_data in feedback:
        new_feedback_user_ids.add(feedback_data.user_id)

        existing_fb = existing_feedbacks.get(feedback_data.user_id)

        if existing_fb:
            # Feedback existiert bereits - prüfe ob es sich geändert hat
            if existing_fb.feedback != feedback_data.feedback:
                # Feedback hat sich geändert - aktualisiere es
                existing_fb.feedback = feedback_data.feedback
                existing_fb.date = datetime.now()
        else:
            # Neues Feedback - erstelle es
            new_feedback = models.SongCandidateFeedback(
                song_id=song_id,
                user_id=feedback_data.user_id,
                feedback=feedback_data.feedback,
                date=datetime.now()
            )
            db.add(new_feedback)

    # Feedbacks löschen, die nicht mehr vorhanden sind
    for user_id, old_fb in existing_feedbacks.items():
        if user_id not in new_feedback_user_ids:
            db.delete(old_fb)

    # Update song feedbacks from db
    db.commit()
    db.refresh(song)
    return song.feedbacks


@router.put("/candidates/accept/{song_id}", response_model=List[schemas.SongOut])
def accept_song_candidate(
        song_id: int,
        db: Session = Depends(auth.get_db),
        current=Depends(auth.get_current_user)
):
    if not check_editor(current):
        raise HTTPException(status_code=403, detail="Not authorized to accept song candidates")

    song = db.query(models.Song).get(song_id)
    if not song:
        raise HTTPException(status_code=404, detail="Song candidate not found")
    if song.status != "vorschlag":
        raise HTTPException(status_code=400, detail="Only song candidates can be accepted")

    song.status = "angenommen"
    db.commit()
    db.refresh(song)

    # Mattermost notification
    try:
        mattermost.send_mm_message(f" :tada: Der Songvorschlag **{song.title}** von **{song.interpret}** wurde angenommen! :tada:", channel=MM_CHANNEL)
    except Exception as e:
        logger.error(f"Fehler beim Senden der Benachrichtigung an Mattermost: {e}")

    return db.query(models.Song).filter(models.Song.status != "vorschlag").all()

@router.get("/singers", response_model=List[str])
def get_singers(
        db: Session = Depends(auth.get_db),
):
    users = db.query(models.User).filter(models.User.is_singer == 1).all()
    output = [u.clear_name for u in users]
    return output


@router.get("/crawler/metadata", response_model=schemas.SongScrawlOut)
def get_song_scrawls(
        interpret: str = Query(..., min_length=1),
        title: str = Query(..., min_length=1),
        current=Depends(auth.get_current_user),
):
    data = audioscrawler.search_track_musicbrainz(interpret=interpret, title=title)
    if not data:
        raise HTTPException(status_code=404, detail="No metadata found")

    composers = sorted(set(data.get("composers") or []))
    lyricists = sorted(set(data.get("lyricists") or []))

    return schemas.SongScrawlOut(
        recording_id=data.get("recording_id"),
        work_id=data.get("work_id"),
        duration=data.get("duration"),
        ytlink=data.get("ytlink"),
        composers=composers,
        lyricists=lyricists,
        composer=", ".join(composers) if composers else None,
        texter=", ".join(lyricists) if lyricists else None,
    )
