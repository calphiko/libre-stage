"""
Rehearsal router.

Handles CRUD operations for rehearsals: creating and updating
rehearsal sessions, managing the per-rehearsal song list and
per-user to-do items.

Requires authentication. Create/update/delete operations additionally
require the ``editor`` or ``admin`` role.

Prefix: ``/rehearsals``  |  Tag: ``rehearsals``
"""

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

from fastapi import APIRouter, Depends, HTTPException, Response, Query, Path
from datetime import time, timedelta
import logging

from sqlalchemy.orm import Session
from typing import List

from backend import models, schemas, auth
from backend.utils.check_permissions import  check_editor, check_admin

import os
from dotenv import load_dotenv

router = APIRouter(
    prefix="/reh", tags=["rehearsals"], dependencies=[Depends(auth.get_current_user_dep)]
)

def get_reh_list(db, limit=20, offset=0):
    return (
        db.query(models.Rehearsal)
        .order_by(models.Rehearsal.begin.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )

logger = logging.getLogger("uvicorn.error")
load_dotenv(".env")

MM_CHANNEL = os.getenv("MM_CHANNEL_REH")

@router.get("/", response_model = List[schemas.RehListElem])
def get_rehearsal_list(
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user)
):
    reh_db = get_reh_list(db)

    if not reh_db:
        raise HTTPException(status_code=404, detail="No rehearsals found")

    return reh_db

@router.post("/", response_model = List[schemas.RehListElem])
def create_new_rehearsal(
    data: schemas.NewRehDict,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user),
):
    end_dt = data.end or (data.begin + timedelta(hours=2))
    logger.info(
        f"User {current['user_name']} creates new rehearsal from {data.begin} to {end_dt}"
    )

    if current['user_group'] != 'admin' and current['user_group'] != 'editor':
        logger.error(f"Permission denied: User {current['user_name']} is not admin or editor")
        raise HTTPException(status_code=401, detail="User role does not allow to create a new rehearsal!")

    reh_to_add = models.Rehearsal(
        begin=data.begin,
        end=end_dt,
        ical= "",
        comment=data.comment,
        songs=[],
    )

    db.add(reh_to_add)
    db.commit()

    # Send Mattermost Messages
    try:
        from backend.utils import mattermost
        message = (
            f":mega: Neue Probe von {current['user_name']} erstellt.\n"
            f"\tDiese findet am {data.begin.strftime('%d.%m.%Y')} von "
            f"{data.begin.strftime('%H:%M')} bis {end_dt.strftime('%H:%M Uhr')} statt."
        )
        if data.comment:
            message += f"\n> {data.comment}"
        mattermost.send_mm_message(channel=MM_CHANNEL, text=message)
    except Exception as e:
        logger.error(f"Failed to send Mattermost message: {e}")

    reh_db = get_reh_list(db)
    if not reh_db:
        raise HTTPException(status_code=404, detail="No rehearsals found") # pragma: no cover

    return reh_db


@router.put("/", response_model = List[schemas.RehListElem])
def update_rehearsal(
    data: schemas.RehListElem,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user)
):
    logger.info(f"Update Rehearsal {data.id}")
    reh_tbu = db.query(models.Rehearsal).get(data.id)
    if not reh_tbu:
        raise HTTPException(status_code=404, detail="Rehearsal not found")

    if not check_editor(current):
        logger.error(f"Permission denied: User {current['user_name']} is not editor")
        raise HTTPException(status_code=403, detail="Not enough permissions")

    # Primitive Felder updaten (alles außer Songs)
    for k, v in data.model_dump(exclude_unset=True, exclude={"songs"}).items():
        setattr(reh_tbu, k, v)

    # Songs synchronisieren
    payload_songs = {s.id: s for s in (data.songs or []) if s.id}
    current_songs = {s.id: s for s in reh_tbu.songs}
    incoming_song_ids = set(payload_songs.keys())
    added_song_ids = []

    rehsong_fields = ["id_song", "comment", "todo", "done"]
    #song_fields = ["title", "interpret", "status", "setlist_comment"]

    song_field_map = {
        "setlist_comment": "comment",  # API-Feld : DB-Feld
        "status": "status",
        # weitere Felder nach Bedarf
    }

    for s in (data.songs or []):
        if s.id in current_songs:
            db_song = current_songs[s.id]
            for field in rehsong_fields:
                if hasattr(s, field):
                    setattr(db_song, field, getattr(s, field))
            for src_field, db_field in song_field_map.items():
                if hasattr(s, src_field):
                    setattr(db_song.song, db_field, getattr(s, src_field))


        else:
            logger.info(f"Add Song {s.id_song} to Rehearsal {s.id_rehearsal}")
            db_song = models.RehSong(
                id_rehearsal=reh_tbu.id,
                id_song=s.id_song,
                comment=s.comment,
                todo=s.todo,
                done=s.done
            )

            db.add(db_song)
            db.flush() # Damit db_song.id zur Verfügung steht
            added_song_ids.append(db_song.id)

            #reh_tbu.songs.append(db_song)

        # Todos synchronisieren für jeden Song
        payload_todos = {t.id: t for t in (getattr(s, "song_todos", []) or []) if t.id}
        current_todos = {t.id: t for t in getattr(db_song, "todos", [])}
        incoming_todo_ids = set(payload_todos.keys())
        added_todo_ids = []

        # Update und Hinzufügen Todos
        for t in (getattr(s, "song_todos", []) or []):
            if t.id in current_todos:
                db_todo = current_todos[t.id]
                for attr in ["todo", "dt", "done"]:
                    setattr(db_todo, attr, getattr(t, attr))
            else:
                logger.info(f"add todo to song {db_song.id_song}, {t.id_reh}, {t.id_user}")
                db_todo = models.RehTodo(
                    id_song=db_song.id_song,
                    id_reh=t.id_reh,
                    id_user=t.id_user,
                    todo=t.todo,
                    dt=t.dt,
                    done=t.done
                )
                db.add(db_todo)
                db.flush()
                added_todo_ids.append(db_todo.id)
                # Falls du SQLAlchemy-Relation benutzt:
                # db_song.todos.append(db_todo) (je nach deiner Konfiguration)

        # Todos entfernen, die nicht mehr enthalten sind
        all_valid_todo_ids = incoming_todo_ids.union(added_todo_ids)
        for todo in list(getattr(db_song, "todos", [])):
            if todo.id not in all_valid_todo_ids:
                logger.info(f"delete todo from song {db_song.id_song}, {todo.id_reh}, {todo.id_user}")
                db.delete(todo)

    all_valid_ids = incoming_song_ids.union(added_song_ids)
    # Songs entfernen, die nicht mehr vorhanden sind
    for song in list(reh_tbu.songs):
        if song.id not in all_valid_ids:
            logger.info (f"Delete Song: {song.id} from rehearsal {reh_tbu.id}")
            # Alle zugehörigen Todos ebenfalls löschen
            for todo in list(getattr(song, "todos", [])):
                db.delete(todo)
            db.delete(song)

    db.commit()
    db.refresh(reh_tbu)

    reh_db = get_reh_list(db)

    logger.info("Update finalized")

    return reh_db

@router.delete("/{reh_id}", response_model=List[schemas.RehListElem])
def delete_rehearsal(
    reh_id: int = Path(..., description="ID der zu löschenden Probe"),
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user)
):
    logger.info(f"User {current['user_name']} attempts to delete rehearsal {reh_id}")

    # Nur Admins dürfen löschen
    if not check_admin(current):
        logger.error(f"Permission denied: User {current['user_name']}")
        raise HTTPException(status_code=401, detail="User role does not allow to delete rehearsal!")

    reh_to_del = db.query(models.Rehearsal).get(reh_id)
    if not reh_to_del:
        raise HTTPException(status_code=404, detail="Rehearsal not found")

    # Alle verknüpften Songs und deren Todos löschen
    for song in list(reh_to_del.songs):
        for todo in list(getattr(song, "todos", [])):
            db.delete(todo)
        db.delete(song)

    db.delete(reh_to_del)
    db.commit()

    reh_db = get_reh_list(db)
    if not reh_db:
        raise HTTPException(status_code=404, detail="No rehearsals found")

    logger.info(f"Rehearsal {reh_id} deleted by user {current['user_name']}")
    return reh_db