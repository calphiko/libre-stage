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

from fastapi import APIRouter, Depends, HTTPException, Response, Query
from datetime import time, datetime
import logging
import os

from sqlalchemy.orm import Session, joinedload
from typing import List

from backend import models, schemas, auth
from backend.utils import mattermost

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

@router.get("/info/{song_id}", response_model = schemas.SongInSetOut)
def get_songs(song_id: int, db: Session = Depends(auth.get_db),
              current=Depends(auth.get_current_user),
              ):
    song = db.query(models.Song).get(song_id)

    if not song:
        raise HTTPException(status_code=404, detail="Song not found")
    song = song.to_setlist_element()

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