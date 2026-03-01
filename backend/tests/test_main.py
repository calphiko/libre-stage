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
from fastapi import status
from datetime import datetime, time
from pprint import pprint
from backend import auth

from pydantic.v1.typing import is_union


def test_login_success(client, test_user):
    """Test successful login."""
    response = client.post("/login", json={
        "username": "testuser",
        "password": "testpassword123"
    })
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"


def test_login_invalid_credentials(client, test_user):
    """Test login with invalid credentials."""
    response = client.post("/login", json={
        "username": "testuser",
        "password": "wrongpassword"
    })
    assert response.status_code == status.HTTP_401_UNAUTHORIZED
    assert response.json()["detail"] == "Invalid credentials"


def test_get_me(client, test_user, auth_headers):
    """Test getting current user information."""
    response = client.get("/me", headers=auth_headers)
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["user_name"] == "testuser"
    assert data["email"] == "test@example.com"


def test_get_me_unauthorized(client):
    """Test getting user info without authentication."""
    response = client.get("/me")
    assert response.status_code == status.HTTP_401_UNAUTHORIZED

def test_me_with_nonexistent_user(client):
    wrong_token = auth.create_access_token({
        "sub": "Franz",
        "role": "admin"
    })
    response = client.get("/me", headers = {"Authorization": f"Bearer {wrong_token}"})
    assert response.status_code == status.HTTP_404_NOT_FOUND


def test_update_user(client, test_user, auth_headers):
    """Test updating user information."""
    response = client.put("/update_user", headers=auth_headers, json={
        "id": test_user.id,
        "user_name": "testuser",
        "email": "newemail@example.com",
        "clear_name": "Updated",
        "user_group": "new_group",
    })
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["email"] == "newemail@example.com"
    assert data["clear_name"] == "Updated"

def test_update_another_user(client, test_user2, auth_headers):
    """Test updating user information. Should fail because trying to update another user."""
    response = client.put("/update_user", headers=auth_headers, json={
        "id": test_user2.id,
        "user_name": "testuser",
        "email": "newemail@example.com",
        "clear_name": "Updated",
        "user_group": "new_group",
    })
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert response.json()["detail"] == "Your are not allowed to update this user!"

def test_update_forbidden_user_field(client, test_user, auth_headers):
    """Test updating user information with forbidden field change."""
    response = client.put("/update_user", headers=auth_headers, json={
        "id": test_user.id,
        "user_name": "new_testuser",
        "email": "newemail@example.com",
        "clear_name": "Updated",
        "user_group": "new_group",
    })
    assert response.status_code == status.HTTP_403_FORBIDDEN
    pprint (response.json())
    assert response.json()["detail"] == "Not allowed to update field 'user_name'"



def test_change_password(client, test_user, auth_headers):
    """Test changing password."""
    response = client.put("/change_password", headers=auth_headers, json={
        "user_id": test_user.id,
        "old_password": "testpassword123",
        "new_password": "newpassword123"
    })
    assert response.status_code == status.HTTP_200_OK
    assert response.json()["msg"] == "Password updates successfully"


def test_change_password_wrong_old(client, test_user, auth_headers):
    """Test changing password with wrong old password."""
    response = client.put("/change_password", headers=auth_headers, json={
        "user_id": test_user.id,
        "old_password": "wrongpassword",
        "new_password": "newpassword123"
    })
    assert response.status_code == status.HTTP_403_FORBIDDEN

def test_change_password_with_user_not_found(client, test_user, auth_headers):
    test_json = {
        "user_id": test_user.id,
        "old_password": "wrongpassword",
        "new_password": "newpassword123"
    }
    token_with_test_user = auth.create_access_token({"sub": "Franz", "role":"admin"})
    response = client.put(
        "/change_password",
        headers={"Authorization": f"Bearer {token_with_test_user}"},
        json=test_json
    )

    assert response.status_code == status.HTTP_404_NOT_FOUND
    assert response.json()["detail"] == "User not found"

def test_change_password_with_wrong_user(client, test_user, test_user2, auth_headers):
    response = client.put("/change_password", headers=auth_headers, json={
        "user_id": test_user2.id,
        "old_password": "wrongpassword",
        "new_password": "newpassword123"
    })
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert response.json()["detail"] == "Your are not allowed to update this user!"


def test_change_password_with_short_password(client, test_user, auth_headers):
    response = client.put("/change_password", headers=auth_headers, json={
        "user_id": test_user.id,
        "old_password": "testpassword123",
        "new_password": "newp"
    })
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert response.json()["detail"] == "New password too short"

def test_change_password_with_identical_password(client, test_user, auth_headers):
    response = client.put("/change_password", headers=auth_headers, json={
        "user_id": test_user.id,
        "old_password": "testpassword123",
        "new_password": "testpassword123"
    })
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert response.json()["detail"] == "Old and new passwords are identical"

def test_get_user_list(client, test_user, auth_headers):
    """Test getting user list."""
    response = client.get("/user_list", headers=auth_headers)
    assert response.status_code == status.HTTP_200_OK
    assert isinstance(response.json(), list)

def test_get_user_todo_list(client, test_user, auth_headers, db_session):
    from backend.models import Rehearsal, RehSong, RehTodo, Song
    test_rehearsal = Rehearsal(
        comment="Testprobe",
        begin=datetime(1970,1,1, 22,00,00),
        end=datetime(1970,1,1, 23,59,00),
        ical=""
    )
    test_song1 = Song(title="Testsong", interpret="Testsinger", singer_lead="Calle", duration=time(0, 3, 0))
    db_session.add_all([test_rehearsal, test_song1])
    db_session.commit()
    db_session.refresh(test_rehearsal)
    db_session.refresh(test_song1)

    rehsong = RehSong(id_rehearsal=test_rehearsal.id, id_song=test_song1.id, comment="Testcomment", todo="practise", done=False)
    rehtodo = RehTodo(id_song=test_song1.id, id_reh=test_rehearsal.id, id_user=test_user.id, todo="practise", dt=datetime.now(), done=False)
    rehtodo2 = RehTodo(id_song=test_song1.id, id_reh=test_rehearsal.id, id_user=test_user.id, todo="practise2", dt=datetime.now(), done=True)
    db_session.add_all([rehsong, rehtodo, rehtodo2])
    db_session.commit()

    response= client.get("/user_todos", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    pprint(data)
    assert data[0]["todo"] == "practise"
    assert data[0]["done"] == False

    response = client.put("/user_todos_done", headers=auth_headers, json=data[0])
    assert response.status_code == 200
    data = response.json()
    assert data[0]["todo"] == "practise"
    assert data[0]["done"] == True

