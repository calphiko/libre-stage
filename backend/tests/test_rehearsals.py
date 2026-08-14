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

from http.client import responses
from pprint import pprint
import pytest
from datetime import datetime, timedelta
from backend.models import Rehearsal, RehSong, Song, RehTodo, User
from backend import auth


def test_get_rehearsals(client, auth_headers, db_session):
    """Test getting all rehearsals."""
    reh1 = Rehearsal(
        comment="First Rehearsal",
        begin=datetime(2024, 12, 1, 18, 0),
        end=datetime(2024, 12, 1, 21, 0),
        ical="ical_string_1"
    )
    reh2 = Rehearsal(
        comment="Second Rehearsal",
        begin=datetime(2024, 12, 8, 18, 0),
        end=datetime(2024, 12, 8, 21, 0),
        ical="ical_string_2"
    )
    db_session.add(reh1)
    db_session.commit()
    db_session.add(reh2)
    db_session.commit()

    response = client.get("/reh/", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2
    assert data[1]["comment"] == "First Rehearsal"
    assert data[0]["comment"] == "Second Rehearsal"

def test_get_rehearsals_with_skip_and_limit(client, auth_headers, db_session):
    for idx in range(5):
        db_session.add(
            Rehearsal(
                comment=f"Rehearsal {idx}",
                begin=datetime(2024, 12, 1 + idx, 18, 0),
                end=datetime(2024, 12, 1 + idx, 21, 0),
                ical=f"ical_{idx}",
            )
        )
    db_session.commit()

    response = client.get("/reh/?skip=1&limit=2", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2
    assert data[0]["comment"] == "Rehearsal 3"
    assert data[1]["comment"] == "Rehearsal 2"

def test_get_past_rehearsals_pagination_and_search(client, auth_headers, db_session):
    now = datetime.now()

    old_rehearsals = []
    for idx in range(25):
        day = datetime(2023, 1, 1) + timedelta(days=idx)
        comment = "Needle rehearsal" if idx == 0 else f"Past rehearsal {idx}"
        old_rehearsals.append(
            Rehearsal(
                comment=comment,
                begin=day.replace(hour=18, minute=0),
                end=day.replace(hour=21, minute=0),
                ical=f"old_{idx}",
            )
        )

    recent_rehearsal = Rehearsal(
        comment="Too recent for past bucket",
        begin=now - timedelta(hours=2),
        end=now + timedelta(hours=1),
        ical="recent_now",
    )

    db_session.add_all(old_rehearsals + [recent_rehearsal])
    db_session.commit()

    first_page = client.get("/reh/past?skip=0&limit=20", headers=auth_headers)
    assert first_page.status_code == 200
    first_data = first_page.json()
    assert first_data["total"] == 25
    assert len(first_data["items"]) == 20
    assert first_data["has_more"] is True

    second_page = client.get("/reh/past?skip=20&limit=20", headers=auth_headers)
    assert second_page.status_code == 200
    second_data = second_page.json()
    assert second_data["total"] == 25
    assert len(second_data["items"]) == 5
    assert second_data["has_more"] is False

    search = client.get("/reh/past?q=needle&limit=20", headers=auth_headers)
    assert search.status_code == 200
    search_data = search.json()
    assert search_data["total"] == 1
    assert len(search_data["items"]) == 1
    assert search_data["items"][0]["comment"] == "Needle rehearsal"

def test_get_with_no_rehearsals(client, auth_headers):
    """Test getting rehearsals when none exist."""
    response = client.get("/reh/", headers=auth_headers)
    assert response.status_code == 404
    assert response.json()["detail"] == "No rehearsals found"

def test_create_rehearsal(client, auth_headers):
    """Test creating a new rehearsal."""
    rehearsal_data = {
        "comment": "New Rehearsal",
        "begin": "2024-12-20T18:00:00"
    }

    response = client.post("/reh/", json=rehearsal_data, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()[0]
    assert data["comment"] == "New Rehearsal"
    assert "id" in data

def test_create_rehearsal_wo_privileges(client, auth_headers2):
    """Test creating a new rehearsal."""
    rehearsal_data = {
        "comment": "New Rehearsal",
        "begin": "2024-12-20T18:00:00"
    }

    response = client.post("/reh/", json=rehearsal_data, headers=auth_headers2)
    assert response.status_code == 401
    data = response.json()
    assert data["detail"] == "User role does not allow to create a new rehearsal!"

def test_create_rehearsal_defaults_end_to_two_hours(client, auth_headers):
    rehearsal_data = {
        "comment": "Default End",
        "begin": "2024-12-20T18:00:00"
    }

    response = client.post("/reh/", json=rehearsal_data, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()[0]
    assert data["begin"] == "2024-12-20T18:00:00"
    assert data["end"] == "2024-12-20T20:00:00"

def test_create_rehearsal_with_explicit_end(client, auth_headers):
    rehearsal_data = {
        "comment": "Mit Endzeit",
        "begin": "2024-12-20T18:00:00",
        "end": "2024-12-20T21:15:00"
    }

    response = client.post("/reh/", json=rehearsal_data, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()[0]
    assert data["begin"] == "2024-12-20T18:00:00"
    assert data["end"] == "2024-12-20T21:15:00"

def test_create_rehearsal_rejects_end_before_begin(client, auth_headers):
    rehearsal_data = {
        "comment": "Ungueltig",
        "begin": "2024-12-20T18:00:00",
        "end": "2024-12-20T17:30:00"
    }

    response = client.post("/reh/", json=rehearsal_data, headers=auth_headers)
    assert response.status_code == 422

def test_update_rehearsal(client, auth_headers, db_session):
    """Test updating an existing rehearsal."""
    reh = Rehearsal(
        comment="Original Comment",
        begin=datetime(2024, 12, 10, 18, 0),
        end=datetime(2024, 12, 10, 21, 0),
        ical="original_ical"
    )
    db_session.add(reh)
    db_session.commit()
    db_session.refresh(reh)

    # Get the rehearsal
    response = client.get(f"/reh/", headers=auth_headers)
    assert response.status_code == 200
    reh_data = response.json()[0]

    # Update the rehearsal
    reh_data["comment"] = "Updated Comment"
    response = client.put(f"/reh/", json=reh_data, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()[0]
    assert data["comment"] == "Updated Comment"

def test_update_rehearsal_stammdaten_as_editor(client, auth_headers, db_session):
    reh = Rehearsal(
        comment="Original Stammdaten",
        begin=datetime(2024, 12, 10, 18, 0),
        end=datetime(2024, 12, 10, 21, 0),
        ical="original_ical"
    )
    editor = User(
        user_name="editoruser",
        user_pw=auth.hash_pw("editorpassword123"),
        user_group="editor",
        musician=True,
        clear_name="Editor User",
        email="editor@example.com",
        status="active"
    )
    db_session.add_all([reh, editor])
    db_session.commit()

    editor_token = auth.create_access_token({"sub": editor.user_name, "role": editor.user_group})
    editor_headers = {"Authorization": f"Bearer {editor_token}"}

    response = client.get("/reh/", headers=editor_headers)
    assert response.status_code == 200
    reh_data = response.json()[0]

    reh_data["begin"] = "2024-12-10T19:15:00"
    reh_data["end"] = "2024-12-10T22:30:00"
    reh_data["comment"] = "Bearbeitet durch Editor"

    response = client.put("/reh/", json=reh_data, headers=editor_headers)
    assert response.status_code == 200
    data = response.json()[0]
    assert data["begin"] == "2024-12-10T19:15:00"
    assert data["end"] == "2024-12-10T22:30:00"
    assert data["comment"] == "Bearbeitet durch Editor"

def test_update_nonexistent_rehearsal(client, auth_headers, db_session):
    """Test updating an existing rehearsal."""
    reh = Rehearsal(
        comment="Original Comment",
        begin=datetime(2024, 12, 10, 18, 0),
        end=datetime(2024, 12, 10, 21, 0),
        ical="original_ical"
    )
    db_session.add(reh)
    db_session.commit()
    db_session.refresh(reh)

    # Get the rehearsal
    response = client.get(f"/reh/", headers=auth_headers)
    assert response.status_code == 200
    reh_data = response.json()[0]

    # Update the rehearsal
    reh_data["comment"] = "Updated Comment"
    reh_data["id"] = 5
    response = client.put(f"/reh/", json=reh_data, headers=auth_headers)
    assert response.status_code == 404
    data = response.json()
    assert data["detail"] == "Rehearsal not found"

def test_delete_rehearsal(client, auth_headers, auth_headers2, db_session):
    """Test deleting a rehearsal."""
    reh = Rehearsal(
        comment="Rehearsal to Delete",
        begin=datetime(2024, 12, 5, 18, 0),
        end=datetime(2024, 12, 5, 21, 0),
        ical="delete_ical"
    )
    reh2 = Rehearsal(
        comment="Rehearsal to Delete",
        begin=datetime(2025, 12, 5, 18, 0),
        end=datetime(2025, 12, 5, 21, 0),
        ical="delete_ical"
    )
    user = User(
        user_name="testuserix",
        user_pw="hashed_pw",
        user_group="musician",
        email="test@example.com",
        clear_name="Test User",
        musician=True
    )
    song = Song(
        title="Test Song",
        interpret="Test Artist",
        genre="Rock",
        singer_lead="John",
        status="active"
    )
    db_session.add_all([user, song])
    db_session.commit()
    db_session.refresh(user)
    db_session.commit()
    db_session.refresh(song)
    db_session.commit()
    db_session.add_all([reh, reh2])
    db_session.commit()
    db_session.refresh(reh)
    db_session.refresh(reh2)

    reh_song = RehSong(
        id_rehearsal=reh.id,
        id_song=song.id,
        comment="Practice",
        done=False
    )
    todo = RehTodo(
        id_song=song.id,
        id_reh=reh.id,
        id_user=user.id,
        todo="Practice solo",
        done=False,
        dt=datetime.now()
    )
    db_session.add(reh_song)
    db_session.commit()
    db_session.add(todo)
    db_session.commit()

    response = client.delete(f"/reh/{reh.id}", headers=auth_headers2)
    assert response.status_code == 401

    response = client.delete(f"/reh/{reh.id}", headers=auth_headers)
    assert response.status_code == 200

    response = client.delete(f"/reh/{reh.id}", headers=auth_headers)
    assert response.status_code == 404
    assert response.json()["detail"] == "Rehearsal not found"

    # Verify rehearsal is deleted
    response = client.get(f"/reh/", headers=auth_headers)
    assert response.status_code == 200
    assert len(response.json()) == 1

    response = client.delete(f"/reh/{reh2.id}", headers=auth_headers)
    assert response.status_code == 404

def test_add_song_to_rehearsal(client, auth_headers, auth_headers2, db_session):
    """Test adding a song to a rehearsal."""
    reh = Rehearsal(
        comment="Test Rehearsal",
        begin=datetime(2024, 12, 15, 18, 0),
        end=datetime(2024, 12, 15, 21, 0),
        ical="test_ical"
    )
    song = Song(
        title="Test Song",
        interpret="Test Artist",
        genre="Rock",
        singer_lead="John",
        status="active"
    )
    db_session.add_all([reh, song])
    db_session.commit()
    db_session.refresh(reh)
    db_session.refresh(song)

    # Get the rehearsal
    response = client.get(f"/reh/", headers=auth_headers)
    assert response.status_code == 200
    reh_data = response.json()[0]

    pprint(reh_data)

    # Add the song to the rehearsal's songs list
    reh_data["songs"].append({
        "id_rehearsal": reh.id,
        "id_song": song.id,
        "interpret": song.interpret,
        "title": song.title,
        "status": song.status,
        "todo": "Prictise Chorus",
        "comment": "Calle Gitarre",
        "setlist_comment": "",
        "done": False
    })

    pprint(reh_data)

    # Update the rehearsal
    response = client.put(f"/reh/", json=reh_data, headers=auth_headers)
    assert response.status_code == 200

    data = response.json()[0]
    assert len(data["songs"]) == 1
    assert data["songs"][0]["id_song"] == song.id

def test_remove_song_from_rehearsal(client, auth_headers, db_session):
    """Test removing a song from a rehearsal."""
    reh = Rehearsal(
        comment="Test Rehearsal",
        begin=datetime(2024, 12, 15, 18, 0),
        end=datetime(2024, 12, 15, 21, 0),
        ical="test_ical"
    )
    song = Song(
        title="Test Song",
        interpret="Test Artist",
        genre="Rock",
        singer_lead="John",
        status="active"
    )
    db_session.add_all([reh, song])
    db_session.commit()

    reh_song = RehSong(id_rehearsal=reh.id, id_song=song.id, comment="Test", done=False)
    db_session.add(reh_song)
    db_session.commit()
    db_session.refresh(reh)

    # Get the rehearsal with its songs
    response = client.get(f"/reh/", headers=auth_headers)
    assert response.status_code == 200
    reh_data = response.json()[0]

    # Remove the song from the rehearsal's songs list
    reh_data["songs"] = []

    # Update the rehearsal
    response = client.put(f"/reh/", json=reh_data, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()[0]
    assert len(data["songs"]) == 0

def test_update_rehearsal_song_comment(client, auth_headers, db_session):
    """Test updating a song's comment in a rehearsal."""
    reh = Rehearsal(
        comment="Test Rehearsal",
        begin=datetime(2024, 12, 15, 18, 0),
        end=datetime(2024, 12, 15, 21, 0),
        ical="test_ical"
    )
    song = Song(
        title="Test Song",
        interpret="Test Artist",
        genre="Rock",
        singer_lead="John",
        status="active"
    )
    db_session.add_all([reh, song])
    db_session.commit()

    reh_song = RehSong(
        id_rehearsal=reh.id,
        id_song=song.id,
        comment="Original comment",
        done=False
    )
    db_session.add(reh_song)
    db_session.commit()
    db_session.refresh(reh)

    # Get the rehearsal
    response = client.get(f"/reh/", headers=auth_headers)
    assert response.status_code == 200
    reh_data = response.json()[0]

    # Update the song comment
    reh_data["songs"][0]["comment"] = "Updated comment"

    # Update the rehearsal
    response = client.put(f"/reh/", json=reh_data, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()[0]
    assert data["songs"][0]["comment"] == "Updated comment"

def test_mark_rehearsal_song_as_done(client, auth_headers, db_session):
    """Test marking a song as done in a rehearsal."""
    reh = Rehearsal(
        comment="Test Rehearsal",
        begin=datetime(2024, 12, 15, 18, 0),
        end=datetime(2024, 12, 15, 21, 0),
        ical="test_ical"
    )
    song = Song(
        title="Test Song",
        interpret="Test Artist",
        genre="Rock",
        singer_lead="John",
        status="active"
    )
    db_session.add_all([reh, song])
    db_session.commit()

    reh_song = RehSong(
        id_rehearsal=reh.id,
        id_song=song.id,
        comment="Practice",
        done=False
    )
    db_session.add(reh_song)
    db_session.commit()
    db_session.refresh(reh)

    # Get the rehearsal
    response = client.get(f"/reh/", headers=auth_headers)
    assert response.status_code == 200
    reh_data = response.json()[0]

    # Mark as done
    reh_data["songs"][0]["done"] = True

    # Update the rehearsal
    response = client.put(f"/reh/", json=reh_data, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()[0]
    assert data["songs"][0]["done"] is True

def test_rehearsal_with_todos(client, auth_headers, db_session):
    """Test rehearsal with todos attached to songs."""
    user = User(
        user_name="testuserix",
        user_pw="hashed_pw",
        user_group="musician",
        email="test@example.com",
        clear_name="Test User",
        musician=True
    )
    reh = Rehearsal(
        comment="Test Rehearsal",
        begin=datetime(2024, 12, 15, 18, 0),
        end=datetime(2024, 12, 15, 21, 0),
        ical="test_ical"
    )
    song = Song(
        title="Test Song",
        interpret="Test Artist",
        genre="Rock",
        singer_lead="John",
        status="active"
    )
    db_session.add_all([user, reh, song])
    db_session.commit()

    reh_song = RehSong(
        id_rehearsal=reh.id,
        id_song=song.id,
        comment="Practice",
        done=False
    )
    db_session.add(reh_song)
    db_session.commit()

    todo = RehTodo(
        id_song=song.id,
        id_reh=reh.id,
        id_user=user.id,
        todo="Practice solo",
        done=False,
        dt=datetime.now()
    )
    db_session.add(todo)
    db_session.commit()
    db_session.refresh(reh)

    # Get the rehearsal
    response = client.get(f"/reh/", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()[0]
    assert len(data["songs"]) == 1
    assert len(data["songs"][0]["song_todos"]) == 1
    assert data["songs"][0]["song_todos"][0]["todo"] == "Practice solo"

def test_add_todo_to_song(client, auth_headers, db_session):
    user = User(
        user_name="testuserix",
        user_pw="hashed_pw",
        user_group="musician",
        email="test@example.com",
        clear_name="Test User",
        musician=True
    )
    reh = Rehearsal(
        comment="Test Rehearsal",
        begin=datetime(2024, 12, 15, 18, 0),
        end=datetime(2024, 12, 15, 21, 0),
        ical="test_ical"
    )
    song = Song(
        title="Test Song",
        interpret="Test Artist",
        genre="Rock",
        singer_lead="John",
        status="active"
    )
    db_session.add_all([user, reh, song])
    db_session.commit()

    song2 = Song(
        title="Test Song 2",
        interpret="Test Artist",
        genre="Rock",
        singer_lead="John",
        status="active"
    )

    db_session.add(song2)
    db_session.commit()

    song3 = Song(
        title="Test Song 3",
        interpret="Test Artist",
        genre="Rock",
        singer_lead="John",
        status="active"
    )

    db_session.add(song3)
    db_session.commit()

    reh_song = RehSong(
        id_rehearsal=reh.id,
        id_song=song.id,
        comment="Practice",
        done=False,
        todo="üben"
    )
    db_session.add(reh_song)
    db_session.commit()

    reh_song = RehSong(
        id_rehearsal=reh.id,
        id_song=song2.id,
        comment="Practice one more ",
        done=False,
        todo="üben"
    )
    db_session.add(reh_song)
    db_session.commit()

    reh_song3= RehSong(
        id_rehearsal=reh.id,
        id_song=song3.id,
        comment="Practice twice ",
        done=False,
        todo="2xüben"
    )
    db_session.add(reh_song3)
    db_session.commit()

    todo = RehTodo(
        id_song=song.id,
        id_reh=reh.id,
        id_user=user.id,
        todo="Practice solo",
        done=False,
        dt=datetime.now()
    )
    db_session.add(todo)
    db_session.commit()
    db_session.refresh(reh)
    todo = RehTodo(
        id_song=song.id,
        id_reh=reh.id,
        id_user=user.id,
        todo="Practice solo",
        done=False,
        dt=datetime.now()
    )
    db_session.add(todo)
    db_session.commit()
    todo2 = RehTodo(
        id_song=song3.id,
        id_reh=reh.id,
        id_user=user.id,
        todo="Practice solo advanced",
        done=False,
        dt=datetime.now()
    )
    db_session.add(todo2)
    db_session.commit()
    db_session.refresh(reh)

    response = client.get(f"/reh/", headers=auth_headers)
    assert response.status_code == 200
    pprint(response.json())
    data = response.json()[0]
    assert len(data["songs"]) == 3

    todo_to_add = {
        "id": None,
        "id_reh": reh.id,
        "id_song": song.id,
        "id_user": user.id,
        "dt": datetime.now().isoformat(),
        "todo": "Practise solo more",
        "done": False
    }

    data["songs"][1]["song_todos"].append(todo_to_add)
    data["songs"][0]["song_todos"].pop()
    data["songs"].pop()
    pprint(data)
    response = client.put(f"/reh/", json=data, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()[0]
    assert len(data["songs"]) == 2
    assert len(data["songs"][1]["song_todos"]) == 1
    assert data["songs"][1]["song_todos"][0]["todo"] == "Practise solo more"
