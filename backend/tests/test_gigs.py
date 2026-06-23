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

import pytest
import copy
from datetime import date, time, datetime
import pprint

from pydantic_core.core_schema import set_schema


def test_get_gigs(client, auth_headers, db_session):
    """Test getting all gigs."""
    # Create test gig
    from backend.models import Gig
    gig = Gig(
        name="Test Concert",
        datum=date(2024, 12, 25),
        organizer="Test Organizer",
        kind_of_gig="Concert",
        venue="Test Venue",
        doors=time(18, 0),
        begin=time(19, 0),
        end=time(23, 0),
        status="confirmed",
        publish=1
    )
    db_session.add(gig)
    db_session.commit()

    response = client.get("/gigs", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["name"] == "Test Concert"
    assert data[0]["venue"] == "Test Venue"

def test_get_gigs_with_year(client, auth_headers, db_session):
    """Test getting all gigs."""
    # Create test gig
    from backend.models import Gig
    gig = Gig(
        name="Test Concert",
        datum=date(2024, 12, 25),
        organizer="Test Organizer",
        kind_of_gig="Concert",
        venue="Test Venue",
        doors=time(18, 0),
        begin=time(19, 0),
        end=time(23, 0),
        status="confirmed",
        publish=1
    )
    db_session.add(gig)
    db_session.commit()

    response = client.get("/gigs?jahr=2024", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["name"] == "Test Concert"
    assert data[0]["venue"] == "Test Venue"
    response = client.get("/gigs?jahr=2025", headers=auth_headers)
    assert response.status_code  == 200
    assert response.json() == []


def test_get_genre_palette_returns_deterministic_mapping(client, auth_headers, db_session):
    from backend.models import Song

    db_session.add_all([
        Song(title="Palette Rock", interpret="Band A", genre="Rock"),
        Song(title="Palette Synth", interpret="Band B", genre="Synthwave"),
    ])
    db_session.commit()

    response1 = client.get("/gigs/genre_palette", headers=auth_headers)
    response2 = client.get("/gigs/genre_palette", headers=auth_headers)

    assert response1.status_code == 200
    assert response2.status_code == 200

    payload1 = response1.json()
    payload2 = response2.json()
    assert "palette" in payload1
    assert payload1 == payload2

    palette = payload1["palette"]
    assert "Rock" in palette
    assert "Synthwave" in palette
    assert isinstance(palette["Rock"], str) and palette["Rock"].startswith("#")
    assert isinstance(palette["Synthwave"], str) and palette["Synthwave"].startswith("#")

def test_create_gig(client, auth_headers, db_session):
    """Test creating a new gig."""
    gig_data = {
        "name": "New Concert",
        "datum": "2032-12-31",
        "organizer": "Event Organizer",
        "kind_of_gig": "Festival",
        "venue": "Main Stage",
        "doors": "17:00:00",
        "begin": "18:00:00",
        "end": "22:00:00",
        "status": "pending",
        "publish": 0
    }

    response = client.post("/gigs", json=gig_data, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data[-1]["name"] == "New Concert"
    assert data[-1]["venue"] == "Main Stage"
    assert "id" in data[-1]

def test_create_gig_w_non_authorized_user(client, auth_headers2, db_session):
    """Test creating a new gig."""
    gig_data = {
        "name": "New Concert",
        "datum": "2032-12-31",
        "organizer": "Event Organizer",
        "kind_of_gig": "Festival",
        "venue": "Main Stage",
        "doors": "17:00:00",
        "begin": "18:00:00",
        "end": "22:00:00",
        "status": "pending",
        "publish": 0
    }

    response = client.post("/gigs", json=gig_data, headers=auth_headers2)
    assert response.status_code == 401
    data = response.json()
    assert data["detail"] == f"User role does not allow to create a new gig!"

def test_create_gig_w_year_string(client, auth_headers, db_session):
    """Test creating a new gig."""
    gig_data = {
        "name": "New Concert",
        "datum": "2032-12-31",
        "organizer": "Event Organizer",
        "kind_of_gig": "Festival",
        "venue": "Main Stage",
        "doors": "17:00:00",
        "begin": "18:00:00",
        "end": "22:00:00",
        "status": "pending",
        "publish": 0
    }

    response = client.post("/gigs?jahr=2032", json=gig_data, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data[-1]["name"] == "New Concert"
    assert data[-1]["venue"] == "Main Stage"
    assert "id" in data[-1]

def test_update_gig(client, auth_headers, db_session):
    """Test updating an existing gig."""
    from backend.models import Gig
    gig = Gig(
        id=1,
        name="Original Concert",
        datum=date(2034, 12, 25),
        organizer="Test Organizer",
        kind_of_gig="Concert",
        venue="Old Venue",
        status="pending"
    )
    db_session.add(gig)
    db_session.commit()
    db_session.refresh(gig)

    update_data = {
        "name": "Updated Concert",
        "venue": "New Venue",
        "kind_of_gig": "Concert",
        "datum": "2035-12-25",
        "status": "confirmed",
        "publish":1
    }

    response = client.put(f"/gigs/{gig.id}", json=update_data, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()

    assert data["name"] == "Updated Concert"
    assert data["venue"] == "New Venue"
    assert data["status"] == "confirmed"

def test_update_gig_with_nonexistent_gig_id(client, auth_headers, db_session):
    """Test updating an existing gig."""
    from backend.models import Gig
    gig = Gig(
        id=1,
        name="Original Concert",
        datum=date(2034, 12, 25),
        organizer="Test Organizer",
        kind_of_gig="Concert",
        venue="Old Venue",
        status="pending"
    )
    db_session.add(gig)
    db_session.commit()
    db_session.refresh(gig)

    update_data = {
        "name": "Updated Concert",
        "venue": "New Venue",
        "kind_of_gig": "Concert",
        "datum": "2035-12-25",
        "status": "confirmed",
        "publish": 1
    }

    response = client.put(f"/gigs/{gig.id+1}", json=update_data, headers=auth_headers)
    assert response.status_code == 404
    assert response.json()["detail"] == "Gig not found"

def test_delete_gig(client, auth_headers, db_session):
    """Test deleting a gig."""
    from backend.models import Gig, Set, Song, GigSet, SetSong
    gig = Gig(
        name="Concert to Delete",
        datum=date(2024, 12, 25),
        organizer="Test Organizer",
        kind_of_gig="Concert",
        venue="Test Venue"
    )
    test_set = Set(name="Opening Set", pause=time(0, 10))
    test_song = Song(title="Test Song", interpret="Test Artist", singer_lead="Calle", duration=time(0, 3, 0),
                     genre="Rock", brass=True, status="angenommen")
    db_session.add_all([gig, test_set, test_song])
    db_session.commit()
    db_session.refresh(gig)
    db_session.refresh(test_set)
    db_session.refresh(test_song)

    test_gigset = GigSet (id_gig = gig.id, id_set = test_set.id, position=1)
    test_setsong= SetSong(id_set = test_set.id, id_song=test_song.id, position=1)

    db_session.add_all([test_gigset, test_setsong])
    db_session.commit()
    db_session.refresh(gig)
    db_session.refresh(test_setsong)
    db_session.refresh(test_gigset)

    response = client.delete(f"/gigs/{gig.id}", headers=auth_headers)
    db_session.refresh(test_setsong)

    pprint.pprint(gig.debug_dump())

    assert response.status_code == 200

def test_delete_nonexisting_gig(client, auth_headers, db_session):
    """Test deleting a gig."""
    from backend.models import Gig, Set, Song, GigSet, SetSong
    gig = Gig(
        name="Concert to Delete",
        datum=date(2024, 12, 25),
        organizer="Test Organizer",
        kind_of_gig="Concert",
        venue="Test Venue"
    )
    test_set = Set(name="Opening Set", pause=time(0, 10))
    test_song = Song(title="Test Song", interpret="Test Artist", singer_lead="Calle", duration=time(0, 3, 0),
                     genre="Rock", brass=True, status="angenommen")
    db_session.add_all([gig, test_set, test_song])
    db_session.commit()
    db_session.refresh(gig)
    db_session.refresh(test_set)
    db_session.refresh(test_song)

    test_gigset = GigSet (id_gig = gig.id, id_set = test_set.id, position=1)
    test_setsong= SetSong(id_set = test_set.id, id_song=test_song.id, position=1)

    db_session.add_all([test_gigset, test_setsong])
    db_session.commit()

    response = client.delete(f"/gigs/{gig.id+1}", headers=auth_headers)
    assert response.status_code == 404
    assert response.json()["detail"] == "Gig not found"

def test_delete_gig_w_non_authorized_user(client, auth_headers2, db_session):
    """Test deleting a gig with a non-authorized user."""
    from backend.models import Gig
    gig = Gig(
        name="Concert to Delete",
        datum=date(2024, 12, 25),
        organizer="Test Organizer",
        kind_of_gig="Concert",
        venue="Test Venue"
    )
    db_session.add(gig)
    db_session.commit()
    db_session.refresh(gig)

    response = client.delete(f"/gigs/{gig.id}", headers=auth_headers2)
    assert response.status_code == 401
    data = response.json()
    assert data["detail"] == "User role does not allow to delete a gig!"

def test_add_set_to_gig(client, auth_headers, db_session):
    """Test adding a set to a gig."""
    from backend.models import Gig, Set

    gig = Gig(name="Test Concert", datum=date(2024, 12, 25), publish=0)
    test_set = Set(name="Opening Set", pause=time(0, 10))
    db_session.add_all([gig, test_set])
    db_session.commit()
    db_session.refresh(gig)
    db_session.refresh(test_set)

    pprint.pprint(test_set.to_setlist_dict())

    # Get the gig, add the set to its sets list, and update
    response = client.get(f"/gigs/{gig.id}/setlist", headers=auth_headers)
    assert response.status_code == 200
    gig_data = response.json()

    # Add the set to the gig's sets list
    gig_data["sets"].append(
        {
            "set_name": "TestSet",
            "setlist_name": "TestSet_Setlistname",
            "songs":[],
            "pause": "00:10:00",
        }
    )

    # Update the gig
    response = client.put(f"/gigs/{gig.id}/update_setlist", json=gig_data, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    pprint.pprint(data)

    assert "sets" in data
    assert len(data["sets"]) == 1

def test_add_set_to_gig_w_wrong_gig_id(client, auth_headers, db_session):
    """Test adding a set to a gig."""
    from backend.models import Gig, Set

    gig = Gig(name="Test Concert", datum=date(2024, 12, 25), publish=0)
    db_session.add_all([gig])
    db_session.commit()
    db_session.refresh(gig)


    # Get the gig, add the set to its sets list, and update
    response = client.get(f"/gigs/{gig.id}/setlist", headers=auth_headers)
    assert response.status_code == 200
    gig_data = response.json()

    # Add the set to the gig's sets list
    gig_data["sets"].append(
        {
            "set_name": "TestSet",
            "setlist_name": "TestSet_Setlistname",
            "songs":[],
            "pause": "00:10:00",
        }
    )

    # Update the gig
    response = client.put(f"/gigs/{gig.id+1}/update_setlist", json=gig_data, headers=auth_headers)
    assert response.status_code == 404
    assert response.json()["detail"] == "Gig not found"

def test_add_set_to_gig_w_non_admin_user(client, auth_headers2, db_session):
    """Test adding a set to a gig."""
    from backend.models import Gig, Set

    gig = Gig(name="Test Concert", datum=date(2024, 12, 25), publish=0)
    db_session.add_all([gig])
    db_session.commit()
    db_session.refresh(gig)

    # Get the gig, add the set to its sets list, and update
    response = client.get(f"/gigs/{gig.id}/setlist", headers=auth_headers2)
    assert response.status_code == 200
    gig_data = response.json()

    # Add the set to the gig's sets list
    gig_data["sets"].append(
        {
            "set_name": "TestSet",
            "setlist_name": "TestSet_Setlistname",
            "songs": [],
            "pause": "00:10:00",
        }
    )

    # Update the gig
    response = client.put(f"/gigs/{gig.id}/update_setlist", json=gig_data, headers=auth_headers2)
    assert response.status_code == 403
    assert response.json()["detail"] == "Not enough permissions"

def test_get_gig_setlist(client,  auth_headers, db_session):
    """Helper function to get gig setlist."""
    from backend.models import Gig, Set, GigSet

    gig = Gig(name="Test Concert", datum=date(2024, 12, 25), publish=0)
    test_set = Set(name="Opening Set", pause=time(0, 10))
    db_session.add_all([gig, test_set])
    db_session.commit()
    db_session.refresh(gig)

    gig_set = GigSet(id_gig=gig.id, id_set=test_set.id, position=1)
    db_session.add(gig_set)
    db_session.commit()

    response = client.get(f"/gigs/{gig.id}/setlist", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert "sets" in data
    assert len(data["sets"]) == 1
    assert data["sets"][0]["set_name"] == "Opening Set"


def test_get_gig_setlist_contains_setlist_version(client, auth_headers, db_session):
    from backend.models import Gig, Set, GigSet

    gig = Gig(name="Test Concert", datum=date(2024, 12, 25), publish=0)
    test_set = Set(name="Opening Set", pause=time(0, 10))
    db_session.add_all([gig, test_set])
    db_session.commit()
    db_session.refresh(gig)

    gig_set = GigSet(id_gig=gig.id, id_set=test_set.id, position=1)
    db_session.add(gig_set)
    db_session.commit()

    response = client.get(f"/gigs/{gig.id}/setlist", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data.get("setlist_version"), str)
    assert len(data["setlist_version"]) == 16


def test_update_setlist_rejects_stale_setlist_version(client, auth_headers, db_session):
    from backend.models import Gig, Set, GigSet

    gig = Gig(name="Test Concert", datum=date(2024, 12, 25), publish=0)
    initial_set = Set(name="Opening Set", pause=time(0, 10))
    db_session.add_all([gig, initial_set])
    db_session.commit()
    db_session.refresh(gig)

    gig_set = GigSet(id_gig=gig.id, id_set=initial_set.id, position=1)
    db_session.add(gig_set)
    db_session.commit()

    initial_response = client.get(f"/gigs/{gig.id}/setlist", headers=auth_headers)
    assert initial_response.status_code == 200
    stale_payload = initial_response.json()

    newer_payload = copy.deepcopy(stale_payload)
    newer_payload["sets"].append(
        {
            "set_name": "Neues Set",
            "setlist_name": "Neues Set",
            "songs": [],
            "pause": "00:10:00",
        }
    )

    update_newer_response = client.put(
        f"/gigs/{gig.id}/update_setlist",
        json=newer_payload,
        headers=auth_headers,
    )
    assert update_newer_response.status_code == 200
    newest_version = update_newer_response.json().get("setlist_version")
    assert isinstance(newest_version, str)

    stale_payload["name"] = "Veralteter Versuch"
    stale_update_response = client.put(
        f"/gigs/{gig.id}/update_setlist",
        json=stale_payload,
        headers=auth_headers,
    )

    assert stale_update_response.status_code == 409
    detail = stale_update_response.json().get("detail", {})
    assert detail.get("code") == "SETLIST_CONFLICT"
    assert "current_setlist" in detail
    assert detail["current_setlist"].get("setlist_version") == newest_version

def test_add_song_to_existing_set_in_gig(client, auth_headers, db_session):
    """Test adding a song to an existing set in a gig."""
    from backend.models import Gig, Set, GigSet, Song, SetSong

    gig = Gig(name="Test Concert", datum=date(2024, 12, 25), begin=time(19, 00, 00), kind_of_gig="Schützenfest", publish=False)
    test_set = Set(name="Opening Set", pause=time(0, 10))
    test_song = Song(title="Test Song", interpret="Test Artist", singer_lead="Calle", duration=time(0, 3, 0), genre="Rock", brass=True, status="angenommen")
    test_song2 = Song(title="Test Song2", interpret="Test Artist2", singer_lead="Calle", duration=time(0, 3, 0),
                     genre="Rock", brass=True, status="angenommen")

    db_session.add_all([gig, test_set, test_song, test_song2])
    db_session.commit()
    db_session.refresh(gig)
    db_session.refresh(test_set)
    db_session.refresh(test_song)
    db_session.refresh(test_song2)
    test_set_song = SetSong(id_set=test_set.id, id_song=test_song2.id, position=1)
    db_session.add(test_set_song)
    db_session.commit()
    db_session.refresh(test_set_song)
    pprint.pprint(test_set_song.to_setlist_dict())
    gig_set = GigSet(id_gig=gig.id, id_set=test_set.id, position=1)
    db_session.add(gig_set)
    db_session.commit()

    # Get the gig with its setlist
    response = client.get(f"/gigs/{gig.id}/setlist", headers=auth_headers)
    assert response.status_code == 200
    gig_data = response.json()
    assert len(gig_data["sets"]) == 1

    # Get the song-obj by its id
    test_song_db = client.get(f"/songs/info/{test_song.id}", headers=auth_headers)
    assert response.status_code == 200
    song_data = test_song_db.json()
    song_data["setsong_id"] = -1

    # Add the song to the existing set's songs list
    gig_data["sets"][0]["songs"].append(
        song_data
    )

    pprint.pprint(gig_data)

    # Update the gig
    response = client.put(f"/gigs/{gig.id}/update_setlist", json=gig_data, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert len(data["sets"][0]["songs"]) == 2
    assert data["sets"][0]["songs"][1]["title"] == "Test Song"

def test_add_nonexistant_song_to_existing_set_in_gig(client, auth_headers, db_session):
    """Test adding a non-existing song to an existing set in a gig."""
    from backend.models import Gig, Set, GigSet, Song, SetSong

    gig = Gig(name="Test Concert", datum=date(2024, 12, 25), begin=time(19, 00, 00), kind_of_gig="Schützenfest", publish=False)
    test_set = Set(name="Opening Set", pause=time(0, 10))
    test_song = Song(title="Test Song", interpret="Test Artist", singer_lead="Calle", duration=time(0, 3, 0), genre="Rock", brass=True, status="angenommen")
    db_session.add_all([gig, test_set, test_song])
    db_session.commit()
    db_session.refresh(gig)
    db_session.refresh(test_set)
    db_session.refresh(test_song)

    gig_set = GigSet(id_gig=gig.id, id_set=test_set.id, position=1)
    db_session.add(gig_set)
    db_session.commit()

    # Get the gig with its setlist
    response = client.get(f"/gigs/{gig.id}/setlist", headers=auth_headers)
    assert response.status_code == 200
    gig_data = response.json()
    assert len(gig_data["sets"]) == 1

    # Get the song-obj by its id
    test_song_db = client.get(f"/songs/info/{test_song.id}", headers=auth_headers)
    assert response.status_code == 200
    song_data = test_song_db.json()
    song_data["setsong_id"] = -1
    song_data["song_id"] += 1

    # Add the song to the existing set's songs list
    gig_data["sets"][0]["songs"].append(
        song_data
    )

    pprint.pprint(gig_data)

    # Update the gig
    response = client.put(f"/gigs/{gig.id}/update_setlist", json=gig_data, headers=auth_headers)
    assert response.status_code == 400
    data = response.json()
    assert data["detail"] == "Song not found"

def test_get_gig_setlist_with_nonexistent_gig_id(client, auth_headers, db_session):
    """Helper function to get gig setlist."""
    from backend.models import Gig, Set

    gig = Gig(name="Test Concert", datum=date(2024, 12, 25), publish=0)
    test_set = Set(name="Opening Set", pause=time(0, 10))
    db_session.add_all([gig, test_set])
    db_session.commit()
    db_session.refresh(gig)
    response = client.get(f"/gigs/{gig.id+1}/setlist", headers=auth_headers)
    assert response.status_code == 404
    assert response.json()["detail"] == "Gig not found"

def test_remove_set_from_gig(client, auth_headers, db_session):
    """Test removing a set from a gig."""
    from backend.models import Gig, Set, GigSet

    gig = Gig(name="Test Concert", datum=date(2024, 12, 25), publish=0)
    test_set = Set(name="Opening Set", pause=time(0, 10))
    db_session.add_all([gig, test_set])
    db_session.commit()

    gig_set = GigSet(id_gig=gig.id, id_set=test_set.id, position=1)
    db_session.add(gig_set)
    db_session.commit()
    db_session.refresh(gig)

    # Get the gig with its setlist
    response = client.get(f"/gigs/{gig.id}/setlist", headers=auth_headers)
    assert response.status_code == 200
    gig_data = response.json()
    assert len(gig_data["sets"]) == 1

    # Remove the set from the gig's sets list
    gig_data["sets"] = []

    # Update the gig
    response = client.put(f"/gigs/{gig.id}/update_setlist", json=gig_data, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert len(data["sets"]) == 0

def test_unauthorized_access(client):
    """Test that endpoints require authentication."""
    response = client.get("/gigs")
    assert response.status_code == 401

    response = client.post("/gigs", json={})
    assert response.status_code == 401

def test_download_setlist_pdf(client, auth_headers, db_session):
    """Test removing a set from a gig."""
    from backend.models import Gig, Set, GigSet, SetSong, Song
    gig = Gig(name="Test Concert", datum=date(2024, 12, 25), publish=0)
    test_set = Set(name="Opening Set", pause=time(0, 10))
    test_set2 = Set(name="Opening Set2", pause=time(0, 10))
    test_song1 = Song(title="Testsong", interpret="Testsinger", singer_lead="Calle", brass=0, duration=time(0, 3, 0))
    test_song2 = Song(title="Testsong2", interpret="Testsinger2", singer_lead="Dana", brass=0, duration=time(0, 3, 15))
    test_song3 = Song(title="Testsong3", interpret="Testsinger3", singer_lead="Olli", brass=0, duration=time(0, 3, 30))
    test_song4 = Song(title="Testsong4", interpret="Testsinger4", singer_lead="Olli", brass=0, duration=time(0, 3, 30))
    test_song5 = Song(title="Testsong5", interpret="Testsinger5", singer_lead="Dana", brass=0, duration=time(0, 3, 30))
    test_song6 = Song(title="Testsong6", interpret="Testsinger6", singer_lead="Dana", brass=1, duration=None)

    db_session.add_all([gig, test_set, test_set2, test_song1, test_song2, test_song3, test_song4, test_song5, test_song6])
    db_session.commit()
    db_session.refresh(test_song1)
    db_session.refresh(test_song2)
    db_session.refresh(test_song3)
    db_session.refresh(test_song4)
    db_session.refresh(test_song5)
    db_session.refresh(test_song6)
    db_session.refresh(test_set)
    db_session.refresh(test_set2)

    set_song1 = SetSong(id_set=test_set.id, id_song=test_song1.id, position=1)
    set_song2 = SetSong(id_set=test_set.id, id_song=test_song2.id, position=2)
    set_song3 = SetSong(id_set=test_set.id, id_song=test_song3.id, position=3)
    db_session.add_all([set_song1, set_song2, set_song3])
    db_session.commit()

    set_song4 = SetSong(id_set=test_set2.id, id_song=test_song4.id, position=1)
    set_song5 = SetSong(id_set=test_set2.id, id_song=test_song5.id, position=2)
    set_song6 = SetSong(id_set=test_set2.id, id_song=test_song6.id, position=3)
    db_session.add_all([set_song4, set_song5, set_song6])
    db_session.commit()

    gig_set = GigSet(id_gig=gig.id, id_set=test_set.id, position=1)
    gig_set2 = GigSet(id_gig=gig.id, id_set=test_set2.id, position=2)
    db_session.add(gig_set)
    db_session.commit()
    db_session.add(gig_set2)
    db_session.commit()
    db_session.refresh(gig)

    response = client.get(f"/gigs/{gig.id}/setlist.pdf", headers=auth_headers)
    assert response.status_code == 200
    assert response.headers["content-type"] == "application/pdf"
    assert response.content.startswith(b"%PDF-")


def test_download_setlist_pdf_print_design(client, auth_headers, db_session):
    from backend.models import Gig, Set, GigSet, SetSong, Song

    gig = Gig(name="Print Concert", datum=date(2024, 12, 25), publish=0)
    test_set = Set(name="Opening Set", pause=time(0, 10))
    test_song = Song(
        title="Testsong",
        interpret="Testsinger",
        singer_lead="Calle",
        brass=0,
        duration=time(0, 3, 0),
    )

    db_session.add_all([gig, test_set, test_song])
    db_session.commit()
    db_session.refresh(gig)
    db_session.refresh(test_set)
    db_session.refresh(test_song)

    set_song = SetSong(id_set=test_set.id, id_song=test_song.id, position=1)
    db_session.add(set_song)
    db_session.commit()

    gig_set = GigSet(id_gig=gig.id, id_set=test_set.id, position=1)
    db_session.add(gig_set)
    db_session.commit()

    response = client.get(f"/gigs/{gig.id}/setlist.pdf?design=print", headers=auth_headers)
    assert response.status_code == 200
    assert response.headers["content-type"] == "application/pdf"
    assert "druckfreundlich" in response.headers.get("content-disposition", "")
    assert response.content.startswith(b"%PDF-")

def test_download_setlist_pdf_w_nonexistent_gig_id(client, auth_headers, db_session):
    """Test removing a set from a gig."""
    from backend.models import Gig, Set, GigSet, SetSong, Song
    gig = Gig(name="Test Concert", datum=date(2024, 12, 25), publish=0)
    test_set = Set(name="Opening Set", pause=time(0, 10))
    test_song1 = Song(title="Testsong", interpret="Testsinger", singer_lead="Calle", duration=time(0, 3, 0))
    test_song2 = Song(title="Testsong2", interpret="Testsinger2", singer_lead="Dana", duration=time(0, 3, 15))
    test_song3 = Song(title="Testsong3", interpret="Testsinger3", singer_lead="Olli", duration=time(0, 3, 30))
    db_session.add_all([gig, test_set, test_song1, test_song2, test_song3])
    db_session.commit()
    db_session.refresh(test_song1)
    db_session.refresh(test_song2)
    db_session.refresh(test_song3)
    db_session.refresh(test_set)

    set_song1 = SetSong(id_set=test_set.id, id_song=test_song1.id, position=1)
    set_song2 = SetSong(id_set=test_set.id, id_song=test_song2.id, position=2)
    set_song3 = SetSong(id_set=test_set.id, id_song=test_song3.id, position=3)
    db_session.add_all([set_song1, set_song2, set_song3])
    db_session.commit()

    gig_set = GigSet(id_gig=gig.id, id_set=test_set.id, position=1)
    db_session.add(gig_set)
    db_session.commit()
    db_session.refresh(gig)

    response = client.get(f"/gigs/{gig.id+1}/setlist.pdf", headers=auth_headers)
    assert response.status_code == 404
    assert response.json()["detail"] == "Gig not found"

def test_download_forscore_setlist(client, auth_headers, db_session):
    """Test downloading the forScore .4ss setlist (PLIST XML)."""
    from backend.models import Gig, Set, GigSet, SetSong, Song
    import plistlib

    gig = Gig(name="Test Concert ForScore", datum=date(2027, 5, 22), publish=0)
    test_set = Set(name="Set 1", pause=time(0, 15))
    test_song1 = Song(title="Bohemian Rhapsody", interpret="Queen")
    test_song2 = Song(title="Hotel California", interpret="Eagles")

    db_session.add_all([gig, test_set, test_song1, test_song2])
    db_session.commit()
    db_session.refresh(test_song1)
    db_session.refresh(test_song2)
    db_session.refresh(test_set)

    set_song1 = SetSong(id_set=test_set.id, id_song=test_song1.id, position=1)
    set_song2 = SetSong(id_set=test_set.id, id_song=test_song2.id, position=2)
    db_session.add_all([set_song1, set_song2])
    db_session.commit()

    gig_set = GigSet(id_gig=gig.id, id_set=test_set.id, position=1)
    db_session.add(gig_set)
    db_session.commit()
    db_session.refresh(gig)

    response = client.get(f"/gigs/{gig.id}/forscore-setlist", headers=auth_headers)
    assert response.status_code == 200
    assert response.headers["content-type"] == "application/x-forscore-setlist"
    assert "attachment; filename=\"Setlist-2027-05-22-Test_Concert_ForScore.4ss\"" in response.headers["content-disposition"]

    # Decode and parse the Plist xml
    parsed = plistlib.loads(response.content)
    assert isinstance(parsed, list)
    assert len(parsed) == 2
    assert parsed[0]["title"] == "Bohemian Rhapsody"
    assert parsed[1]["title"] == "Hotel California"
    assert parsed[0]["setlist"] == "Test Concert ForScore"
    assert parsed[1]["setlist"] == "Test Concert ForScore"

def test_download_forscore_setlist_nonexistent(client, auth_headers, db_session):
    """Test downloading the forScore setlist for a nonexistent gig."""
    response = client.get("/gigs/99999/forscore-setlist", headers=auth_headers)
    assert response.status_code == 404
    assert response.json()["detail"] == "Gig not found"

def test_season_statistics_generation (season_client):
    client, headers, data = season_client

    response = client.get(f"/gigs/statistics?jahr={date.today().year}", headers=headers)
    assert response.status_code == 200
    stats = response.json()
    assert stats["gig_count"] == 3
    assert stats["genre_distribution"] == {'Disco': 8, 'Oldies': 2, 'Pop': 2, 'Rock': 11}
    assert len(stats["genre_timeline"]) >= 1
    assert all("kind_of_gig" in point for point in stats["genre_timeline"])
    assert sum(point["total"] for point in stats["genre_timeline"]) == sum(stats["genre_distribution"].values())

    response = client.get(f"/gigs/statistics?jahr={date.today().year+1}", headers=headers)
    assert response.status_code == 200
    stats = response.json()
    assert stats["gig_count"] == 0
    assert stats["genre_timeline"] == []


def test_gig_statistics_genre_timeline(client, auth_headers, db_session):
    from backend.models import Gig, Set, Song, SetSong, GigSet

    gig = Gig(name="Timeline Gig", datum=date(2033, 8, 10), publish=0)
    set_one = Set(name="Set 1", pause=time(0, 10))
    set_two = Set(name="Set 2", pause=time(0, 10))

    song_rock = Song(title="Song Rock", interpret="Band", genre="Rock")
    song_pop = Song(title="Song Pop", interpret="Band", genre="Pop")
    song_disco = Song(title="Song Disco", interpret="Band", genre="Disco")

    db_session.add_all([gig, set_one, set_two, song_rock, song_pop, song_disco])
    db_session.commit()

    db_session.add_all([
        SetSong(id_set=set_one.id, id_song=song_rock.id, position=1),
        SetSong(id_set=set_one.id, id_song=song_pop.id, position=2),
        SetSong(id_set=set_two.id, id_song=song_rock.id, position=1),
        SetSong(id_set=set_two.id, id_song=song_disco.id, position=2),
    ])
    db_session.commit()

    db_session.add_all([
        GigSet(id_gig=gig.id, id_set=set_one.id, position=1),
        GigSet(id_gig=gig.id, id_set=set_two.id, position=2),
    ])
    db_session.commit()

    response = client.get(f"/gigs/{gig.id}/statistics", headers=auth_headers)
    assert response.status_code == 200

    stats = response.json()
    assert stats["genre_distribution"] == {"Disco": 1, "Pop": 1, "Rock": 2}
    assert len(stats["genre_timeline"]) == 2
    assert all(point["kind_of_gig"] in (None, "") for point in stats["genre_timeline"])
    assert stats["genre_timeline"][0]["genre_counts"] == {"Pop": 1, "Rock": 1}
    assert stats["genre_timeline"][1]["genre_counts"] == {"Disco": 1, "Rock": 1}


def test_get_livemode_available_batch(season_client):
    client, headers, data = season_client

    gig_ids = [1,2]

    response = client.post(
        "/gigs/livemode_available_batch",
        headers=headers,
        json = gig_ids
    )
    assert response.status_code == 200
    batch_info = response.json()
    pprint.pprint(batch_info)
    assert batch_info["1"]["available"] == False
    assert len(batch_info.keys())== 2


def test_get_gig_schedule_includes_fixed_and_dynamic_items(client, auth_headers, db_session):
    from backend.models import Gig, GigScheduleItem

    gig = Gig(
        name="Schedule Gig",
        datum=date(2030, 5, 20),
        kind_of_gig="Concert",
        venue="Hall",
        doors=time(18, 0),
        begin=time(19, 0),
        end=time(22, 0),
        publish=0,
    )
    db_session.add(gig)
    db_session.commit()
    db_session.refresh(gig)

    db_session.add(GigScheduleItem(
        gig_id=gig.id,
        item_datetime=datetime(2030, 5, 20, 17, 30, 0),
        was="Soundcheck",
        wer="Band",
        wo="Stage",
    ))
    db_session.commit()

    response = client.get(f"/gigs/{gig.id}/schedule/", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert len(data["items"]) == 4
    assert data["items"][0]["item_datetime"] == "2030-05-20T17:30:00"
    assert data["items"][0]["is_fixed"] is False
    assert data["items"][1]["is_fixed"] is True
    assert data["items"][1]["was"] == "Einlass"


def test_create_gig_schedule_item_conflict_with_fixed_time_returns_409(client, auth_headers, db_session):
    from backend.models import Gig

    gig = Gig(
        name="Schedule Conflict",
        datum=date(2031, 6, 15),
        kind_of_gig="Festival",
        venue="Main Stage",
        doors=time(18, 0),
        begin=time(19, 0),
        end=time(22, 0),
        publish=0,
    )
    db_session.add(gig)
    db_session.commit()
    db_session.refresh(gig)

    payload = {
        "item_datetime": "2031-06-15T19:00:00",
        "was": "Eigener Eintrag",
        "wer": "Band",
        "wo": "Backstage",
    }
    response = client.post(f"/gigs/{gig.id}/schedule/", json=payload, headers=auth_headers)
    assert response.status_code == 409
    assert "festem Eintrag" in response.json()["detail"]


def test_schedule_write_requires_editor_permissions(client, auth_headers2, db_session):
    from backend.models import Gig

    gig = Gig(
        name="Schedule Perm",
        datum=date(2032, 7, 1),
        kind_of_gig="Open Air",
        venue="Park",
        begin=time(20, 0),
        publish=0,
    )
    db_session.add(gig)
    db_session.commit()
    db_session.refresh(gig)

    payload = {
        "item_datetime": "2032-07-01T18:00:00",
        "was": "Aufbau",
        "wer": "Crew",
        "wo": "Park",
    }
    response = client.post(f"/gigs/{gig.id}/schedule/", json=payload, headers=auth_headers2)
    assert response.status_code == 403
    assert response.json()["detail"] == "Not enough permissions"


def test_get_gig_schedule_pdf(client, auth_headers, db_session):
    from backend.models import Gig, GigScheduleItem

    gig = Gig(
        name="Schedule PDF",
        datum=date(2033, 8, 10),
        organizer="Event Team",
        kind_of_gig="Festival",
        venue="Open Air",
        doors=time(17, 0),
        begin=time(18, 0),
        end=time(21, 0),
        publish=0,
    )
    db_session.add(gig)
    db_session.commit()
    db_session.refresh(gig)

    db_session.add(GigScheduleItem(
        gig_id=gig.id,
        item_datetime=datetime(2033, 8, 10, 16, 30, 0),
        was=(
            "Aufbau mit sehr langem Beschreibungstext fuer die komplette Produktionsabnahme "
            "inklusive Backline, Licht und Stageplot LONGTEXTENDMARKER"
        ),
        wer="Crew Team A und Team B fuer Monitor und FoH",
        wo="Buehne Nordseite mit Nebenbuehne und Lagerflaeche",
    ))
    db_session.commit()

    response = client.get(f"/gigs/{gig.id}/schedule.pdf", headers=auth_headers)
    assert response.status_code == 200
    assert response.headers["content-type"] == "application/pdf"
    assert response.content.startswith(b"%PDF-")

    content = response.content
    media_box_idx = content.find(b"/MediaBox")
    assert media_box_idx >= 0
    media_box = content[media_box_idx:media_box_idx + 100]
    assert b"595.2756" in media_box
    assert b"841.8898" in media_box
    assert media_box.find(b"595.2756") < media_box.find(b"841.8898")

    # Keep checks robust against internal PDF text encoding/layout changes.
    assert len(content) > 10_000
    assert b"/Subtype /Image" in content


def test_bulk_update_gig_schedule_allows_time_swap(client, auth_headers, db_session):
    from backend.models import Gig, GigScheduleItem

    gig = Gig(
        name="Bulk Swap",
        datum=date(2034, 1, 10),
        kind_of_gig="Concert",
        venue="Hall",
        doors=time(18, 0),
        begin=time(19, 0),
        end=time(22, 0),
        publish=0,
    )
    db_session.add(gig)
    db_session.commit()
    db_session.refresh(gig)

    item1 = GigScheduleItem(gig_id=gig.id, item_datetime=datetime(2034, 1, 10, 14, 0), was="Aufbau", wer="Crew", wo="Buehne")
    item2 = GigScheduleItem(gig_id=gig.id, item_datetime=datetime(2034, 1, 10, 15, 0), was="Soundcheck", wer="Band", wo="Buehne")
    db_session.add_all([item1, item2])
    db_session.commit()
    db_session.refresh(item1)
    db_session.refresh(item2)

    payload = {
        "items": [
            {
                "id": item1.id,
                "item_datetime": "2034-01-10T15:00:00",
                "was": "Aufbau",
                "wer": "Crew",
                "wo": "Buehne",
            },
            {
                "id": item2.id,
                "item_datetime": "2034-01-10T14:00:00",
                "was": "Soundcheck",
                "wer": "Band",
                "wo": "Buehne",
            },
        ]
    }

    response = client.put(f"/gigs/{gig.id}/schedule/", json=payload, headers=auth_headers)
    assert response.status_code == 200
    items = [i for i in response.json()["items"] if not i["is_fixed"]]
    assert len(items) == 2
    assert sorted(i["item_datetime"] for i in items) == ["2034-01-10T14:00:00", "2034-01-10T15:00:00"]


def test_bulk_update_gig_schedule_rejects_fixed_collision(client, auth_headers, db_session):
    from backend.models import Gig

    gig = Gig(
        name="Bulk Conflict",
        datum=date(2034, 1, 11),
        kind_of_gig="Concert",
        venue="Hall",
        doors=time(18, 0),
        begin=time(19, 0),
        end=time(22, 0),
        publish=0,
    )
    db_session.add(gig)
    db_session.commit()
    db_session.refresh(gig)

    payload = {
        "items": [
            {
                "item_datetime": "2034-01-11T19:00:00",
                "was": "Kollision",
                "wer": "Band",
                "wo": "Backstage",
            }
        ]
    }

    response = client.put(f"/gigs/{gig.id}/schedule/", json=payload, headers=auth_headers)
    assert response.status_code == 409


