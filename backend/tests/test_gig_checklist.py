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
Tests for the /gigs/{gig_id}/checklist router.

Covers:
- GET  /gigs/{gig_id}/checklist        – list items
- POST /gigs/{gig_id}/checklist        – create item (future gig OK, past gig → 403)
- Authentication / authorisation guards
"""

import pytest
from datetime import date, timedelta

from backend import models, auth


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def future_gig(db_session):
    """Gig taking place in the future."""
    g = models.Gig(
        name="Future Gig",
        datum=date.today() + timedelta(days=14),
        kind_of_gig="Konzert",
        status="angenommen",
        publish="0",
    )
    db_session.add(g)
    db_session.commit()
    db_session.refresh(g)
    return g


@pytest.fixture
def past_gig(db_session):
    """Gig that took place yesterday."""
    g = models.Gig(
        name="Past Gig",
        datum=date.today() - timedelta(days=1),
        kind_of_gig="Konzert",
        status="angenommen",
        publish="0",
    )
    db_session.add(g)
    db_session.commit()
    db_session.refresh(g)
    return g


# Minimal valid payload for a checklist item
ITEM_PAYLOAD = {
    "title": "PA-Anlage laden",
    "category": "Equipment",
    "done": False,
    "position": 0,
}


# ---------------------------------------------------------------------------
# GET – list items
# ---------------------------------------------------------------------------

def test_get_checklist_requires_auth(client, future_gig):
    resp = client.get(f"/gigs/{future_gig.id}/checklist")
    assert resp.status_code in (401, 403)


def test_get_checklist_empty(client, auth_headers, test_user, future_gig):
    resp = client.get(f"/gigs/{future_gig.id}/checklist", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json() == []


def test_get_checklist_unknown_gig(client, auth_headers, test_user):
    resp = client.get("/gigs/99999/checklist", headers=auth_headers)
    assert resp.status_code == 404


def test_get_checklist_past_gig_still_readable(client, auth_headers, test_user, db_session, past_gig):
    """Reading the checklist of a past gig must still work."""
    # Add an item directly so there's something to read
    item = models.GigChecklistItem(
        gig_id=past_gig.id,
        title="Altes Item",
        done=True,
        position=0,
    )
    db_session.add(item)
    db_session.commit()

    resp = client.get(f"/gigs/{past_gig.id}/checklist", headers=auth_headers)
    assert resp.status_code == 200
    items = resp.json()
    assert len(items) == 1
    assert items[0]["title"] == "Altes Item"


# ---------------------------------------------------------------------------
# POST – create item on a future gig
# ---------------------------------------------------------------------------

def test_create_checklist_item_future_gig(client, auth_headers, test_user, future_gig):
    """Admin can create a checklist item on a future gig."""
    resp = client.post(
        f"/gigs/{future_gig.id}/checklist",
        json=ITEM_PAYLOAD,
        headers=auth_headers,
    )
    assert resp.status_code == 200
    items = resp.json()
    assert len(items) == 1
    assert items[0]["title"] == "PA-Anlage laden"
    assert items[0]["category"] == "Equipment"
    assert items[0]["done"] is False
    assert items[0]["gig_id"] == future_gig.id


def test_create_checklist_item_returns_all_items(client, auth_headers, test_user, future_gig):
    """POST returns the full list (not just the new item)."""
    client.post(f"/gigs/{future_gig.id}/checklist", json={"title": "Item 1", "done": False, "position": 0}, headers=auth_headers)
    resp = client.post(f"/gigs/{future_gig.id}/checklist", json={"title": "Item 2", "done": False, "position": 1}, headers=auth_headers)
    assert resp.status_code == 200
    assert len(resp.json()) == 2


def test_create_checklist_item_unknown_gig(client, auth_headers, test_user):
    resp = client.post("/gigs/99999/checklist", json=ITEM_PAYLOAD, headers=auth_headers)
    assert resp.status_code == 404


def test_create_checklist_item_requires_auth(client, future_gig):
    resp = client.post(f"/gigs/{future_gig.id}/checklist", json=ITEM_PAYLOAD)
    assert resp.status_code in (401, 403)


def test_create_checklist_item_requires_editor(client, auth_headers2, test_user2, future_gig):
    """Regular user (role=user) must not be allowed to create items."""
    resp = client.post(
        f"/gigs/{future_gig.id}/checklist",
        json=ITEM_PAYLOAD,
        headers=auth_headers2,
    )
    assert resp.status_code == 403


# ---------------------------------------------------------------------------
# POST – past gig must be rejected
# ---------------------------------------------------------------------------

def test_create_checklist_item_past_gig_rejected(client, auth_headers, test_user, past_gig):
    """Creating a checklist item on a past gig must return 403."""
    resp = client.post(
        f"/gigs/{past_gig.id}/checklist",
        json=ITEM_PAYLOAD,
        headers=auth_headers,
    )
    assert resp.status_code == 403


def test_create_checklist_item_past_gig_error_message(client, auth_headers, test_user, past_gig):
    """The 403 for a past gig must include a meaningful German error message."""
    resp = client.post(
        f"/gigs/{past_gig.id}/checklist",
        json=ITEM_PAYLOAD,
        headers=auth_headers,
    )
    assert resp.status_code == 403
    assert "vergangen" in resp.json()["detail"].lower()


def test_create_checklist_item_past_gig_no_item_created(
    client, auth_headers, test_user, db_session, past_gig
):
    """After a rejected POST, no item must have been written to the database."""
    client.post(
        f"/gigs/{past_gig.id}/checklist",
        json=ITEM_PAYLOAD,
        headers=auth_headers,
    )
    count = (
        db_session.query(models.GigChecklistItem)
        .filter_by(gig_id=past_gig.id)
        .count()
    )
    assert count == 0

