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

import pprint

import pytest
from datetime import time
from backend.models import Song
from backend.routers import songs as songs_router

def test_unauthenticated(client):
    """Test that unauthenticated access is denied."""
    response = client.get("/songs")
    assert response.status_code == 401

def test_get_songs(client, auth_headers, db_session):
    """Test getting all songs."""
    song1 = Song(
        title="Test Song 1",
        interpret="Artist 1",
        genre="Rock",
        singer_lead="John",
        status="active",
        duration=time(0, 3, 30)
    )
    song2 = Song(
        title="Test Song 2",
        interpret="Artist 2",
        genre="Pop",
        singer_lead="Jane",
        status="active",
        duration=time(0, 4, 15)
    )
    db_session.add_all([song1, song2])
    db_session.commit()

    response = client.get("/songs", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2
    assert data[0]["title"] == "Test Song 1"
    assert data[1]["title"] == "Test Song 2"

def test_get_songs_wo_songs(client, auth_headers, db_session):
    """Test getting all songs without songs."""


    response = client.get("/songs", headers=auth_headers)
    assert response.status_code == 404
    assert response.json()["detail"] == "No songs found"


def test_get_song_by_id(client, auth_headers, db_session):
    """Test getting a specific song by ID."""
    song = Song(
        title="Test Song",
        interpret="Test Artist",
        genre="Jazz",
        singer_lead="Bob",
        status="active",
        duration=time(0, 5, 0)
    )
    db_session.add(song)
    db_session.commit()
    db_session.refresh(song)

    response = client.get(f"/songs/info/{song.id}", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["title"] == "Test Song"
    assert data["interpret"] == "Test Artist"
    assert data["genre"] == "Jazz"

def test_get_song_by_id_w_wrong_id(client, auth_headers, db_session):
    """Test getting a specific song by ID."""
    song = Song(
        title="Test Song",
        interpret="Test Artist",
        genre="Jazz",
        singer_lead="Bob",
        status="active",
        duration=time(0, 5, 0)
    )
    db_session.add(song)
    db_session.commit()
    db_session.refresh(song)

    response = client.get(f"/songs/info/{song.id+1}", headers=auth_headers)
    assert response.status_code == 404
    assert response.json()["detail"] == "Song not found"

def test_get_nonexistent_song(client, auth_headers):
    """Test getting a song that doesn't exist."""
    response = client.get("/songs/info/99999", headers=auth_headers)
    assert response.status_code == 404


def test_create_song(client, auth_headers):
    """Test creating a new song."""
    song_data = {
        "title": "New Song",
        "interpret": "New Artist",
        "genre": "Blues",
        "singer_lead": "Alice",
        "status": "active",
        "duration": "00:04:30",
        "tone_key": "Am",
        "brass": 2
    }

    response = client.post("/songs", json=song_data, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["title"] == "New Song"
    assert data["interpret"] == "New Artist"
    assert data["tone_key"] == "Am"
    assert "id" in data


def test_update_song(client, auth_headers, db_session):
    """Test updating an existing song."""
    song = Song(
        title="Original Title",
        interpret="Original Artist",
        genre="Rock",
        singer_lead="Charlie",
        status="active"
    )
    db_session.add(song)
    db_session.commit()
    db_session.refresh(song)

    updated_data = {
        "title": "Updated Title",
        "interpret": "Updated Artist",
        "genre": "Metal",
        "singer_lead": "Charlie",
        "status": "active",
        "id": song.id,
        "duration": None
    }

    response = client.put(f"/songs/{song.id}", json=updated_data, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["title"] == "Updated Title"
    assert data["interpret"] == "Updated Artist"
    assert data["genre"] == "Metal"

    response = client.put(f"/songs/{song.id+1}", json=updated_data, headers=auth_headers)
    assert response.status_code == 404
    assert response.json()["detail"] == "Song not found"

    updated_data2 = {
        "title": "Updated Title2",
        "interpret": "Updated Artist",
        "genre": "Metal",
        "singer_lead": "Charlie",
        "status": "active",
        "duration": "00:40:00",
        "brass": 1,
        "ytlink": "None"
    }
    updated_data3 = {
        "title": "Updated Title2",
        "interpret": "Updated Artist",
        "genre": "Metal",
        "singer_lead": "Charlie",
        "status": "active",
        "duration": time(0,15,0),
        "brass": 1,
        "ytlink": "None"
    }

    response = client.put(f"/songs/{song.id}", json=updated_data2, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    pprint.pprint(data)
    assert data["title"] == "Updated Title2"
    assert data["interpret"] == "Updated Artist"
    assert data["duration"] == "00:40:00"
    assert data["brass"] == 1


def test_delete_song(client, auth_headers, db_session):
    """Test deleting a song."""
    song = Song(
        title="Song to Delete",
        interpret="Artist",
        genre="Pop",
        singer_lead="David",
        status="active"
    )
    db_session.add(song)
    db_session.commit()
    db_session.refresh(song)

    response = client.delete(f"/songs/{song.id+1}", headers=auth_headers)
    assert response.status_code == 404
    assert response.json()["detail"] == "Song not found"

    response = client.delete(f"/songs/{song.id}", headers=auth_headers)
    assert response.status_code == 200

    # Verify song is deleted
    response = client.get(f"/songs/info/{song.id}", headers=auth_headers)
    assert response.status_code == 200
    pprint.pprint(response.json())
    assert response.json()["status"] == "retired"

def test_delete_song_wo_priviliges(client, auth_headers2, db_session):
    """Test deleting a song."""
    song = Song(
        title="Song to Delete",
        interpret="Artist",
        genre="Pop",
        singer_lead="David",
        status="active"
    )
    db_session.add(song)
    db_session.commit()
    db_session.refresh(song)

    response = client.delete(f"/songs/{song.id}", headers=auth_headers2)
    assert response.status_code == 403
    assert response.json()["detail"] == "Not authorized to delete songs"

def test_create_song_with_optional_fields(client, auth_headers):
    """Test creating a song with all optional fields."""
    song_data = {
        "title": "Complete Song",
        "interpret": "Complete Artist",
        "genre": "Folk",
        "singer_lead": "Eve",
        "singer_background": "Frank+George",
        "composer": "Composer Name",
        "texter": "Lyricist Name",
        "publisher": "Publisher Name",
        "arrangement": "Band",
        "tone_key": "G",
        "status": "active",
        "comment": "Test comment",
        "ytlink": "https://youtube.com/watch?v=test",
        "duration": "00:03:45",
        "brass": 1,
        "text": "Song lyrics here"
    }

    response = client.post("/songs", json=song_data, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["title"] == "Complete Song"
    assert data["composer"] == "Composer Name"
    assert data["ytlink"] == "https://youtube.com/watch?v=test"


def test_get_song_scrawls(client, auth_headers, monkeypatch):
    def fake_search_track_musicbrainz(interpret, title):
        assert interpret == "Bon Jovi"
        assert title == "Always"
        return {
            "recording_id": "rec-1",
            "work_id": "work-1",
            "duration": "00:03:08",
            "ytlink": "https://youtu.be/test123",
            "composers": ["Jon Bon Jovi", "Richie Sambora"],
            "lyricists": ["Jon Bon Jovi"],
        }

    monkeypatch.setattr(songs_router.audioscrawler, "search_track_musicbrainz", fake_search_track_musicbrainz)

    response = client.get(
        "/songs/crawler/metadata",
        params={"interpret": "Bon Jovi", "title": "Always"},
        headers=auth_headers,
    )

    assert response.status_code == 200
    data = response.json()
    assert data["duration"] == "00:03:08"
    assert data["ytlink"] == "https://youtu.be/test123"
    assert data["composer"] == "Jon Bon Jovi, Richie Sambora"
    assert data["texter"] == "Jon Bon Jovi"


def test_get_song_scrawls_not_found(client, auth_headers, monkeypatch):
    monkeypatch.setattr(songs_router.audioscrawler, "search_track_musicbrainz", lambda interpret, title: None)

    response = client.get(
        "/songs/crawler/metadata",
        params={"interpret": "Unknown", "title": "Unknown"},
        headers=auth_headers,
    )

    assert response.status_code == 404
    assert response.json()["detail"] == "No metadata found"


