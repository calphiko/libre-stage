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
Tests für den User-Status-Flow (active / deactivated).

Abgedeckte Szenarien:
- Deaktivierungs-Flow: Tokens widerrufen, Login gesperrt
- Aktivierungs-Flow: Login danach wieder möglich
- Selbst-Deaktivierungs-Schutz für Admins
- Gefilterter /user_list-Endpoint
"""

import pytest
from fastapi import status
from backend import auth, models


# ---------------------------------------------------------------------------
# Hilfsfunktion
# ---------------------------------------------------------------------------

def _make_user(db_session, *, user_name, password="Test1234!", group="user",
               musician=False, status_val="active"):
    user = models.User(
        user_name=user_name,
        user_pw=auth.hash_pw(password),
        user_group=group,
        musician=musician,
        clear_name=user_name,
        email=f"{user_name}@example.com",
        status=status_val,
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


# ---------------------------------------------------------------------------
# Deaktivierungs-Flow
# ---------------------------------------------------------------------------

def test_deactivate_user_sets_status(client, test_user, auth_headers, db_session):
    """DELETE /admin/users/{id} setzt status auf 'deactivated'."""
    target = _make_user(db_session, user_name="victim", group="user")

    response = client.delete(f"/admin/users/{target.id}", headers=auth_headers)
    assert response.status_code == status.HTTP_200_OK

    db_session.refresh(target)
    assert target.status == "deactivated"


def test_deactivate_user_revokes_refresh_tokens(client, test_user, auth_headers, db_session):
    """Beim Deaktivieren werden alle Refresh-Tokens des Users widerrufen."""
    target = _make_user(db_session, user_name="victim2", group="user")

    # Refresh-Token für target anlegen
    rt = models.RefreshToken(
        token_hash="abc123hashXYZ",
        user_id=target.id,
        expires_at=__import__("datetime").datetime(2099, 1, 1),
        revoked=False,
    )
    db_session.add(rt)
    db_session.commit()

    client.delete(f"/admin/users/{target.id}", headers=auth_headers)

    db_session.refresh(rt)
    assert rt.revoked is True


def test_deactivated_user_cannot_login(client, db_session):
    """Ein deaktivierter User kann sich nicht einloggen."""
    _make_user(db_session, user_name="locked", password="Test1234!", status_val="deactivated")

    response = client.post("/login", json={"username": "locked", "password": "Test1234!"})
    assert response.status_code == status.HTTP_401_UNAUTHORIZED


def test_deactivated_user_token_rejected(client, db_session):
    """Ein Token eines deaktivierten Users wird bei jedem Endpoint abgelehnt."""
    user = _make_user(db_session, user_name="locked2", group="admin", status_val="deactivated")
    token = auth.create_access_token({"sub": user.user_name, "role": user.user_group})
    headers = {"Authorization": f"Bearer {token}"}

    response = client.get("/me", headers=headers)
    assert response.status_code == status.HTTP_401_UNAUTHORIZED
    assert response.json()["detail"] == "Account is deactivated"


def test_deactivate_nonexistent_user(client, test_user, auth_headers):
    """Deaktivieren eines nicht vorhandenen Users → 404."""
    response = client.delete("/admin/users/999999", headers=auth_headers)
    assert response.status_code == status.HTTP_404_NOT_FOUND


def test_deactivate_already_deactivated_user(client, test_user, auth_headers, db_session):
    """Bereits deaktivierter User kann nicht nochmals deaktiviert werden → 400."""
    target = _make_user(db_session, user_name="already_off", status_val="deactivated")

    response = client.delete(f"/admin/users/{target.id}", headers=auth_headers)
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "already deactivated" in response.json()["detail"]


# ---------------------------------------------------------------------------
# Selbst-Deaktivierungs-Schutz
# ---------------------------------------------------------------------------

def test_admin_cannot_deactivate_own_account(client, test_user, auth_headers):
    """Ein Admin darf seinen eigenen Account nicht deaktivieren."""
    response = client.delete(f"/admin/users/{test_user.id}", headers=auth_headers)
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert "own account" in response.json()["detail"]


def test_admin_cannot_deactivate_self_via_update(client, test_user, auth_headers):
    """Admin darf eigenen Status nicht via PUT auf deactivated setzen."""
    payload = {
        "id": test_user.id,
        "user_name": test_user.user_name,
        "clear_name": test_user.clear_name,
        "email": test_user.email,
        "user_group": test_user.user_group,
        "musician": test_user.musician,
        "is_singer": False,
        "mm_username": "",
        "status": "deactivated",
    }
    response = client.put(f"/admin/users/{test_user.id}", json=payload, headers=auth_headers)
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert "own account" in response.json()["detail"]


# ---------------------------------------------------------------------------
# Aktivierungs-Flow
# ---------------------------------------------------------------------------

def test_activate_user(client, test_user, auth_headers, db_session):
    """PUT /admin/users/{id}/activate setzt status zurück auf 'active'."""
    target = _make_user(db_session, user_name="comeback", status_val="deactivated")

    response = client.put(f"/admin/users/{target.id}/activate", headers=auth_headers)
    assert response.status_code == status.HTTP_200_OK

    db_session.refresh(target)
    assert target.status == "active"


def test_activated_user_can_login(client, db_session, test_user, auth_headers):
    """Nach Reaktivierung kann sich der User wieder einloggen."""
    target = _make_user(db_session, user_name="returnee", password="Test1234!", status_val="deactivated")

    # Reaktivieren
    client.put(f"/admin/users/{target.id}/activate", headers=auth_headers)

    # Login
    response = client.post("/login", json={"username": "returnee", "password": "Test1234!"})
    assert response.status_code == status.HTTP_200_OK
    assert "access_token" in response.json()


def test_activate_already_active_user(client, test_user, auth_headers, db_session):
    """Bereits aktiven User aktivieren → 400."""
    target = _make_user(db_session, user_name="alreadyon", status_val="active")

    response = client.put(f"/admin/users/{target.id}/activate", headers=auth_headers)
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "already active" in response.json()["detail"]


def test_activate_nonexistent_user(client, test_user, auth_headers):
    """Aktivieren eines nicht vorhandenen Users → 404."""
    response = client.put("/admin/users/999999/activate", headers=auth_headers)
    assert response.status_code == status.HTTP_404_NOT_FOUND


# ---------------------------------------------------------------------------
# Gefilterter /user_list-Endpoint
# ---------------------------------------------------------------------------

def test_user_list_excludes_deactivated(client, db_session, test_user, auth_headers):
    """GET /user_list liefert nur aktive Musiker."""
    _make_user(db_session, user_name="active_musician", musician=True, status_val="active")
    _make_user(db_session, user_name="deactivated_musician", musician=True, status_val="deactivated")

    response = client.get("/user_list", headers=auth_headers)
    assert response.status_code == status.HTTP_200_OK
    names = [u["user_name"] for u in response.json()]
    assert "active_musician" in names
    assert "deactivated_musician" not in names

