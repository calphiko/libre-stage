import pprint

import pytest
from datetime import time
from backend.models import Song

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
