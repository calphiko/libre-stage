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
Tests for the /availability router.

Covers:
- GET  /availability/{event_type}/{event_id}  – list entries
- PUT  /availability/{event_type}/{event_id}  – create / update own entry
- DELETE /availability/{event_type}/{event_id} – remove own entry
- Validation: invalid event_type, invalid substitute_user_id
- Multi-user scenarios and summary counts
- Substitute handling (registered user + free-text)
"""

import pytest
from datetime import datetime, timedelta

from backend import models, auth


# ---------------------------------------------------------------------------
# Helpers / fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def rehearsal(db_session):
    """Create a single rehearsal for testing."""
    reh = models.Rehearsal(
        begin=datetime.now() + timedelta(days=7),
        end=datetime.now() + timedelta(days=7, hours=3),
        comment="",
        ical="",
    )
    db_session.add(reh)
    db_session.commit()
    db_session.refresh(reh)
    return reh


@pytest.fixture
def gig(db_session):
    """Create a single gig for testing."""
    from datetime import date, time
    g = models.Gig(
        name="Test Gig",
        datum=date.today() + timedelta(days=14),
        kind_of_gig="Stadtfest",
        status="angenommen",
        publish="0",
    )
    db_session.add(g)
    db_session.commit()
    db_session.refresh(g)
    return g


# ---------------------------------------------------------------------------
# GET – unauthenticated
# ---------------------------------------------------------------------------

def test_get_availability_requires_auth(client, rehearsal):
    resp = client.get(f"/availability/rehearsal/{rehearsal.id}")
    assert resp.status_code in (401, 403)


# ---------------------------------------------------------------------------
# GET – empty result
# ---------------------------------------------------------------------------

def test_get_availability_empty(client, auth_headers, test_user, rehearsal):
    resp = client.get(f"/availability/rehearsal/{rehearsal.id}", headers=auth_headers)
    assert resp.status_code == 200
    body = resp.json()
    assert body["availabilities"] == []
    assert body["summary"] == {"available": 0, "unavailable": 0, "maybe": 0}
    assert body["my_status"] is None


def test_get_availability_empty_gig(client, auth_headers, test_user, gig):
    resp = client.get(f"/availability/gig/{gig.id}", headers=auth_headers)
    assert resp.status_code == 200
    body = resp.json()
    assert body["availabilities"] == []
    assert body["my_status"] is None


# ---------------------------------------------------------------------------
# GET – invalid event_type
# ---------------------------------------------------------------------------

def test_get_availability_invalid_event_type(client, auth_headers, test_user):
    resp = client.get("/availability/concert/1", headers=auth_headers)
    assert resp.status_code == 400


# ---------------------------------------------------------------------------
# PUT – set availability
# ---------------------------------------------------------------------------

def test_put_availability_available(client, auth_headers, test_user, rehearsal):
    payload = {"status": "available"}
    resp = client.put(
        f"/availability/rehearsal/{rehearsal.id}",
        json=payload,
        headers=auth_headers,
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["my_status"] == "available"
    assert body["summary"]["available"] == 1
    assert body["summary"]["unavailable"] == 0
    assert len(body["availabilities"]) == 1
    entry = body["availabilities"][0]
    assert entry["user_id"] == test_user.id
    assert entry["user_name"] == test_user.user_name
    assert entry["status"] == "available"
    assert entry["comment"] is None


def test_put_availability_maybe(client, auth_headers, test_user, gig):
    payload = {"status": "maybe", "comment": "Mal sehen"}
    resp = client.put(
        f"/availability/gig/{gig.id}",
        json=payload,
        headers=auth_headers,
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["my_status"] == "maybe"
    assert body["summary"]["maybe"] == 1
    entry = body["availabilities"][0]
    assert entry["comment"] == "Mal sehen"


def test_put_availability_unavailable(client, auth_headers, test_user, rehearsal):
    payload = {"status": "unavailable"}
    resp = client.put(
        f"/availability/rehearsal/{rehearsal.id}",
        json=payload,
        headers=auth_headers,
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["my_status"] == "unavailable"
    assert body["summary"]["unavailable"] == 1


# ---------------------------------------------------------------------------
# PUT – update existing entry
# ---------------------------------------------------------------------------

def test_put_availability_update(client, auth_headers, test_user, rehearsal):
    """Calling PUT twice should update, not duplicate."""
    client.put(
        f"/availability/rehearsal/{rehearsal.id}",
        json={"status": "available"},
        headers=auth_headers,
    )
    resp = client.put(
        f"/availability/rehearsal/{rehearsal.id}",
        json={"status": "maybe", "comment": "Vielleicht"},
        headers=auth_headers,
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["my_status"] == "maybe"
    assert len(body["availabilities"]) == 1  # still one entry, not two
    assert body["availabilities"][0]["comment"] == "Vielleicht"


# ---------------------------------------------------------------------------
# PUT – invalid status value
# ---------------------------------------------------------------------------

def test_put_availability_invalid_status(client, auth_headers, test_user, rehearsal):
    resp = client.put(
        f"/availability/rehearsal/{rehearsal.id}",
        json={"status": "yes_please"},
        headers=auth_headers,
    )
    assert resp.status_code == 422  # validation error from pydantic


# ---------------------------------------------------------------------------
# PUT – invalid event_type
# ---------------------------------------------------------------------------

def test_put_availability_invalid_event_type(client, auth_headers, test_user):
    resp = client.put(
        "/availability/concert/1",
        json={"status": "available"},
        headers=auth_headers,
    )
    assert resp.status_code == 400


# ---------------------------------------------------------------------------
# PUT – substitute (free-text)
# ---------------------------------------------------------------------------

def test_put_availability_with_substitute_name(client, auth_headers, test_user, rehearsal):
    payload = {
        "status": "unavailable",
        "substitute_name": "Max Mustermann",
    }
    resp = client.put(
        f"/availability/rehearsal/{rehearsal.id}",
        json=payload,
        headers=auth_headers,
    )
    assert resp.status_code == 200
    entry = resp.json()["availabilities"][0]
    assert entry["substitute_name"] == "Max Mustermann"
    assert entry["substitute_user_id"] is None
    assert entry["substitute_clear_name"] is None


# ---------------------------------------------------------------------------
# PUT – substitute (registered user)
# ---------------------------------------------------------------------------

def test_put_availability_with_substitute_user(
    client, auth_headers, test_user, test_user2, rehearsal
):
    payload = {
        "status": "unavailable",
        "substitute_user_id": test_user2.id,
    }
    resp = client.put(
        f"/availability/rehearsal/{rehearsal.id}",
        json=payload,
        headers=auth_headers,
    )
    assert resp.status_code == 200
    entry = resp.json()["availabilities"][0]
    assert entry["substitute_user_id"] == test_user2.id
    # clear_name of substitute should be resolved
    assert entry["substitute_clear_name"] == test_user2.clear_name


def test_put_availability_invalid_substitute_user(
    client, auth_headers, test_user, rehearsal
):
    payload = {
        "status": "unavailable",
        "substitute_user_id": 99999,
    }
    resp = client.put(
        f"/availability/rehearsal/{rehearsal.id}",
        json=payload,
        headers=auth_headers,
    )
    assert resp.status_code == 404


# ---------------------------------------------------------------------------
# DELETE – remove own entry
# ---------------------------------------------------------------------------

def test_delete_availability(client, auth_headers, test_user, rehearsal):
    # First set availability
    client.put(
        f"/availability/rehearsal/{rehearsal.id}",
        json={"status": "available"},
        headers=auth_headers,
    )
    # Then delete
    resp = client.delete(
        f"/availability/rehearsal/{rehearsal.id}",
        headers=auth_headers,
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["availabilities"] == []
    assert body["my_status"] is None
    assert body["summary"]["available"] == 0


def test_delete_availability_not_set(client, auth_headers, test_user, rehearsal):
    """Deleting a non-existent entry should succeed silently."""
    resp = client.delete(
        f"/availability/rehearsal/{rehearsal.id}",
        headers=auth_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["availabilities"] == []


def test_delete_availability_invalid_event_type(client, auth_headers, test_user):
    resp = client.delete("/availability/concert/1", headers=auth_headers)
    assert resp.status_code == 400


# ---------------------------------------------------------------------------
# Multi-user scenario
# ---------------------------------------------------------------------------

def test_multi_user_availability(
    client, auth_headers, auth_headers2,
    test_user, test_user2, rehearsal
):
    """Two users set different statuses; both appear in the response."""
    client.put(
        f"/availability/rehearsal/{rehearsal.id}",
        json={"status": "available"},
        headers=auth_headers,
    )
    resp2 = client.put(
        f"/availability/rehearsal/{rehearsal.id}",
        json={"status": "maybe"},
        headers=auth_headers2,
    )
    assert resp2.status_code == 200

    resp = client.get(
        f"/availability/rehearsal/{rehearsal.id}",
        headers=auth_headers,
    )
    body = resp.json()
    assert len(body["availabilities"]) == 2
    assert body["summary"]["available"] == 1
    assert body["summary"]["maybe"] == 1
    assert body["summary"]["unavailable"] == 0
    # The requesting user (test_user) is "available"
    assert body["my_status"] == "available"


def test_multi_user_my_status_correct_for_each_user(
    client, auth_headers, auth_headers2,
    test_user, test_user2, rehearsal
):
    """my_status must reflect the requesting user, not someone else."""
    client.put(
        f"/availability/rehearsal/{rehearsal.id}",
        json={"status": "unavailable"},
        headers=auth_headers,
    )
    client.put(
        f"/availability/rehearsal/{rehearsal.id}",
        json={"status": "available"},
        headers=auth_headers2,
    )

    body1 = client.get(
        f"/availability/rehearsal/{rehearsal.id}", headers=auth_headers
    ).json()
    body2 = client.get(
        f"/availability/rehearsal/{rehearsal.id}", headers=auth_headers2
    ).json()

    assert body1["my_status"] == "unavailable"
    assert body2["my_status"] == "available"


# ---------------------------------------------------------------------------
# Isolation: rehearsal vs gig entries are independent
# ---------------------------------------------------------------------------

def test_availability_event_type_isolation(
    client, auth_headers, test_user, rehearsal, gig
):
    """An entry for a rehearsal must not appear under a gig and vice versa."""
    client.put(
        f"/availability/rehearsal/{rehearsal.id}",
        json={"status": "available"},
        headers=auth_headers,
    )

    gig_body = client.get(
        f"/availability/gig/{gig.id}", headers=auth_headers
    ).json()
    assert gig_body["availabilities"] == []

    reh_body = client.get(
        f"/availability/rehearsal/{rehearsal.id}", headers=auth_headers
    ).json()
    assert len(reh_body["availabilities"]) == 1


# ---------------------------------------------------------------------------
# Season-data smoke test (uses the full DB fixture)
# ---------------------------------------------------------------------------

def test_availability_season_gig(season_client):
    """Smoke-test: set + get availability for the first gig in the season data."""
    client, headers, data = season_client
    gig = data["gigs"][0]

    resp = client.put(
        f"/availability/gig/{gig.id}",
        json={"status": "available", "comment": "Bin dabei!"},
        headers=headers,
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["my_status"] == "available"
    assert body["summary"]["available"] == 1

    # Verify via GET
    get_resp = client.get(f"/availability/gig/{gig.id}", headers=headers)
    assert get_resp.status_code == 200
    assert get_resp.json()["my_status"] == "available"

