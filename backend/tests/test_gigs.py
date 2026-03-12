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

