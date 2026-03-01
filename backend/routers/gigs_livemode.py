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

from fastapi import APIRouter, Depends, HTTPException, Query
import logging
from sqlalchemy.orm import Session

from backend import models, schemas, auth

from backend.utils.check_permissions import check_editor

router = APIRouter(
    prefix="/gigs_lm", tags=["gigs_lm"], dependencies=[Depends(auth.get_current_user_dep)]
)

logger = logging.getLogger("uvicorn.error")
# suppress progress polls to reduce log clutter
block_endpoints = ["/gigs/log"]

class LogFilter(logging.Filter):  # pragma: no cover
    def filter(self, record):
        if record.args and len(record.args) >= 3:
            if record.args[2] in block_endpoints:  # type: ignore
                return False
        return True


uvicorn_logger = logging.getLogger("uvicorn.access")
uvicorn_logger.addFilter(LogFilter())

@router.get("/{gig_id}", response_model=schemas.GigSetListLiveMode)
def get_gigs_lm(
    gig_id: int,
    db: Session = Depends(auth.get_db),
    current_user: models.User = Depends(auth.get_current_user_dep)
):
    if not check_editor(current_user):
        raise HTTPException(status_code=403, detail="Not enough permissions")

    gig = db.query(models.Gig).filter(models.Gig.id == gig_id).first()
    if not gig:
        raise HTTPException(status_code=404, detail="Gig not found")

    # Prüfe auf korrupte SetSongs (ohne Song-Referenz) und entferne sie
    for gigset in gig.sets:
        set_obj = gigset.set
        corrupted_setsongs = [ss for ss in set_obj.songs if not ss.song]
        if corrupted_setsongs:
            logger.warning(f"Found {len(corrupted_setsongs)} corrupted SetSongs in Set {set_obj.id}, removing them")
            for ss in corrupted_setsongs:
                db.delete(ss)
            db.commit()

    # Manuell serialisieren um Live-Mode-Felder einzuschließen
    sets_data = []
    for gigset in sorted(gig.sets, key=lambda x: x.position):
        set_obj = gigset.set
        songs_data = []

        for setsong in sorted(set_obj.songs, key=lambda ss: ss.position):
            song_dict = {
                "id": setsong.id,  # SetSong ID!
                "title": setsong.song.title if setsong.song else "⚠️ Song gelöscht",
                "interpret": setsong.song.interpret if setsong.song else "",
                "position": setsong.position,
                "tone_key": setsong.song.tone_key if setsong.song else None,
                "comment": setsong.song.comment if setsong.song else None,
                "uebersprungen": setsong.uebersprungen,
                "eingeschoben": setsong.eingeschoben,
                "feedback": setsong.feedback
            }
            songs_data.append(song_dict)

        set_dict = {
            "id": set_obj.id,
            "position": gigset.position,
            "pause": set_obj.pause.strftime('%H:%M:%S') if set_obj.pause else None,
            "setlist_name": set_obj.setlist_name,
            "songs": songs_data
        }
        sets_data.append(set_dict)

    return {
        "id": gig.id,
        "name": gig.name,
        "datum": gig.datum.strftime('%Y-%m-%d') if gig.datum else None,
        "doors": gig.doors.strftime('%H:%M:%S') if gig.doors else None,
        "begin": gig.begin.strftime('%H:%M:%S') if gig.begin else None,
        "end": gig.end.strftime('%H:%M:%S') if gig.end else None,
        "sets": sets_data
    }

@router.put("/{gig_id}/", response_model=schemas.SongInSetLM)
def update_songs_lm(
    gig_id: int,
    data: schemas.SongInSetLMUpdate,
    db: Session = Depends(auth.get_db),
    current_user: models.User = Depends(auth.get_current_user_dep)
):
    if not check_editor(current_user):
        raise HTTPException(status_code=403, detail="Not enough permissions")

    gig = db.query(models.Gig).filter(models.Gig.id == gig_id).first()
    if not gig:
        raise HTTPException(status_code=404, detail="Gig not found")

    # Finde den SetSong-Eintrag
    set_song = db.query(models.SetSong).filter(models.SetSong.id == data.id).first()
    if not set_song:
        raise HTTPException(status_code=404, detail="Song in set not found")

    # Aktualisiere nur die Live-Mode-Felder
    update_data = data.model_dump(exclude_unset=True, exclude={'id', 'title', 'interpret', 'position', 'tone_key', 'comment'})

    for field, value in update_data.items():
        if hasattr(set_song, field):
            setattr(set_song, field, value)

    db.commit()
    db.refresh(set_song)

    # Serialisiere für Response
    return {
        "id": set_song.id,
        "title": set_song.song.title if set_song.song else "⚠️ Song gelöscht",
        "interpret": set_song.song.interpret if set_song.song else "",
        "position": set_song.position,
        "tone_key": set_song.song.tone_key if set_song.song else None,
        "comment": set_song.song.comment if set_song.song else None,
        "uebersprungen": set_song.uebersprungen,
        "eingeschoben": set_song.eingeschoben,
        "feedback": set_song.feedback
    }


@router.post("/{gig_id}/insert-song", response_model=schemas.SongInSetLM)
def insert_song_after(
    gig_id: int,
    after_setsong_id: int = Query(..., description="ID des SetSong, nach dem eingefügt werden soll"),
    song_id: int = Query(..., description="ID des einzufügenden Songs"),
    db: Session = Depends(auth.get_db),
    current_user: models.User = Depends(auth.get_current_user_dep)
):
    if not check_editor(current_user):
        raise HTTPException(status_code=403, detail="Not enough permissions")

    # Gig existiert?
    gig = db.query(models.Gig).filter(models.Gig.id == gig_id).first()
    if not gig:
        raise HTTPException(status_code=404, detail="Gig not found")

    # SetSong existiert?
    after_setsong = db.query(models.SetSong).filter(models.SetSong.id == after_setsong_id).first()
    if not after_setsong:
        raise HTTPException(status_code=404, detail="SetSong not found")

    # Song existiert?
    song = db.query(models.Song).filter(models.Song.id == song_id).first()
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")

    # Alle Songs im gleichen Set mit Position > after_setsong.position um 1 erhöhen
    db.query(models.SetSong).filter(
        models.SetSong.id_set == after_setsong.id_set,
        models.SetSong.position > after_setsong.position
    ).update({"position": models.SetSong.position + 1}, synchronize_session=False)

    # Neuen SetSong erstellen
    new_setsong = models.SetSong(
        id_set=after_setsong.id_set,
        id_song=song_id,
        position=after_setsong.position + 1,
        eingeschoben=True,
        uebersprungen=None,
        feedback=None
    )

    db.add(new_setsong)
    db.commit()
    db.refresh(new_setsong)

    return {
        "id": new_setsong.id,
        "title": new_setsong.song.title if new_setsong.song else "⚠️ Song gelöscht",
        "interpret": new_setsong.song.interpret if new_setsong.song else "",
        "position": new_setsong.position,
        "tone_key": new_setsong.song.tone_key if new_setsong.song else None,
        "comment": new_setsong.song.comment if new_setsong.song else None,
        "uebersprungen": new_setsong.uebersprungen,
        "eingeschoben": new_setsong.eingeschoben,
        "feedback": new_setsong.feedback
    }
