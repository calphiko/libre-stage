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

import copy
from datetime import time

from backend.models import GigSet, Song


def test_repertoire_setlist_crud(client, auth_headers):
    created = client.post(
        "/songs/repertoire_setlists",
        json={"name": "Party-Repertoire"},
        headers=auth_headers,
    )
    assert created.status_code == 200
    created_data = created.json()
    assert created_data["name"] == "Party-Repertoire"

    listing = client.get("/songs/repertoire_setlists", headers=auth_headers)
    assert listing.status_code == 200
    assert any(entry["id"] == created_data["id"] for entry in listing.json())

    setlist = client.get(
        f"/songs/repertoire_setlists/{created_data['id']}/setlist",
        headers=auth_headers,
    )
    assert setlist.status_code == 200
    setlist_data = setlist.json()
    assert setlist_data["name"] == "Party-Repertoire"
    assert setlist_data["sets"] == []
    assert isinstance(setlist_data["setlist_version"], str)
    assert len(setlist_data["setlist_version"]) == 16

    deleted = client.delete(
        f"/songs/repertoire_setlists/{created_data['id']}",
        headers=auth_headers,
    )
    assert deleted.status_code == 200


def test_update_repertoire_setlist_with_song_is_gig_independent(client, auth_headers, db_session):
    song = Song(
        title="Test Song",
        interpret="Test Artist",
        genre="Rock",
        singer_lead="Alice",
        status="active",
        duration=time(0, 3, 0),
        brass=0,
    )
    db_session.add(song)
    db_session.commit()
    db_session.refresh(song)

    created = client.post(
        "/songs/repertoire_setlists",
        json={"name": "Probeabend"},
        headers=auth_headers,
    )
    setlist_id = created.json()["id"]

    song_info = client.get(f"/songs/info/{song.id}", headers=auth_headers)
    assert song_info.status_code == 200

    current_setlist = client.get(
        f"/songs/repertoire_setlists/{setlist_id}/setlist",
        headers=auth_headers,
    ).json()
    current_setlist["sets"].append(
        {
            "set_name": "Set 1",
            "setlist_name": "Set 1",
            "songs": [song_info.json()],
            "pause": "00:10:00",
        }
    )

    updated = client.put(
        f"/songs/repertoire_setlists/{setlist_id}/setlist",
        json=current_setlist,
        headers=auth_headers,
    )
    assert updated.status_code == 200
    updated_data = updated.json()
    assert len(updated_data["sets"]) == 1
    assert len(updated_data["sets"][0]["songs"]) == 1
    assert updated_data["sets"][0]["songs"][0]["song_id"] == song.id
    assert db_session.query(GigSet).count() == 0


def test_update_repertoire_setlist_rejects_stale_setlist_version(client, auth_headers):
    created = client.post(
        "/songs/repertoire_setlists",
        json={"name": "Stale Check"},
        headers=auth_headers,
    )
    setlist_id = created.json()["id"]

    initial = client.get(
        f"/songs/repertoire_setlists/{setlist_id}/setlist",
        headers=auth_headers,
    )
    assert initial.status_code == 200
    stale_payload = initial.json()

    newer_payload = copy.deepcopy(stale_payload)
    newer_payload["sets"].append(
        {
            "set_name": "Neu",
            "setlist_name": "Neu",
            "songs": [],
            "pause": "00:10:00",
        }
    )

    updated = client.put(
        f"/songs/repertoire_setlists/{setlist_id}/setlist",
        json=newer_payload,
        headers=auth_headers,
    )
    assert updated.status_code == 200

    stale_payload["name"] = "Veraltet"
    stale = client.put(
        f"/songs/repertoire_setlists/{setlist_id}/setlist",
        json=stale_payload,
        headers=auth_headers,
    )
    assert stale.status_code == 409
    detail = stale.json().get("detail", {})
    assert detail.get("code") == "SETLIST_CONFLICT"


def test_repertoire_setlist_metadata_update(client, auth_headers):
    created = client.post(
        "/songs/repertoire_setlists",
        json={"name": "Alt", "is_public": False},
        headers=auth_headers,
    )
    assert created.status_code == 200
    setlist_id = created.json()["id"]

    updated = client.patch(
        f"/songs/repertoire_setlists/{setlist_id}",
        json={"name": "Neu", "is_public": True},
        headers=auth_headers,
    )
    assert updated.status_code == 200
    updated_data = updated.json()
    assert updated_data["name"] == "Neu"
    assert updated_data["is_public"] is True

    listing = client.get("/songs/repertoire_setlists", headers=auth_headers)
    assert any(entry["id"] == setlist_id and entry["name"] == "Neu" and entry["is_public"] is True for entry in listing.json())


def test_repertoire_setlist_export_pdf_and_csv(client, auth_headers):
    created = client.post(
        "/songs/repertoire_setlists",
        json={"name": "Export Test"},
        headers=auth_headers,
    )
    setlist_id = created.json()["id"]

    pdf_response = client.get(
        f"/songs/repertoire_setlists/{setlist_id}/setlist.pdf",
        headers=auth_headers,
    )
    assert pdf_response.status_code == 200
    assert pdf_response.headers["content-type"].startswith("application/pdf")
    assert len(pdf_response.content) > 100
    assert b"/Title (Setliste - Repertoire: Export Test" in pdf_response.content

    csv_response = client.get(
        f"/songs/repertoire_setlists/{setlist_id}/setlist.csv",
        headers=auth_headers,
    )
    assert csv_response.status_code == 200
    assert csv_response.headers["content-type"].startswith("text/csv")
    csv_text = csv_response.content.decode("utf-8")
    assert "Set;Position;Interpret;Titel;Dauer;Lead-Sänger;Kommentar" in csv_text


def test_repertoire_setlist_privacy_and_public_access(client, test_user, test_user2, auth_headers, auth_headers2):
    private_creation = client.post(
        "/songs/repertoire_setlists",
        json={"name": "Meine private Liste", "is_public": False},
        headers=auth_headers,
    )
    assert private_creation.status_code == 200
    private_id = private_creation.json()["id"]

    public_creation = client.post(
        "/songs/repertoire_setlists",
        json={"name": "Öffentliche Liste", "is_public": True},
        headers=auth_headers2,
    )
    assert public_creation.status_code == 200
    public_id = public_creation.json()["id"]

    listing = client.get("/songs/repertoire_setlists", headers=auth_headers2)
    assert listing.status_code == 200
    ids = {entry["id"] for entry in listing.json()}
    assert public_id in ids
    assert private_id not in ids

    private_access = client.get(
        f"/songs/repertoire_setlists/{private_id}/setlist",
        headers=auth_headers2,
    )
    assert private_access.status_code == 403

    public_access = client.get(
        f"/songs/repertoire_setlists/{public_id}/setlist",
        headers=auth_headers2,
    )
    assert public_access.status_code == 200
    assert public_access.json()["name"] == "Öffentliche Liste"

    public_update = client.put(
        f"/songs/repertoire_setlists/{public_id}/setlist",
        json={**public_access.json(), "name": "Geänderte öffentliche Liste"},
        headers=auth_headers2,
    )
    assert public_update.status_code == 200
    assert public_update.json()["name"] == "Geänderte öffentliche Liste"
