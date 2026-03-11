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
from fastapi import HTTPException
from backend.auth import (
    hash_pw,
    verify_password,
    authenticate_user,
    create_access_token,
    get_current_user,
    check_user_role,
    get_db
)
from backend.models import User, Song
import jwt
from jwt.exceptions import InvalidTokenError as JWTError
from unittest.mock import Mock


def test_hash_pw():
    """Test password hashing."""
    password = "testpassword123"
    hashed = hash_pw(password)

    assert hashed.startswith("$2b$")  # bcrypt hash should start with $2b$
    assert len(hashed) > 10
    # Same password should always produce same hash
    assert verify_password(password, hashed)


def test_verify_password_correct():
    """Test password verification with correct password."""
    password = "mypassword"
    hashed = hash_pw(password)

    assert verify_password(password, hashed) is True


def test_verify_password_incorrect():
    """Test password verification with incorrect password."""
    password = "mypassword"
    wrong_password = "wrongpassword"
    hashed = hash_pw(password)

    assert verify_password(wrong_password, hashed) is False


def test_authenticate_user_success(db_session):
    """Test successful user authentication."""
    user = User(
        user_name="testuser",
        user_pw=hash_pw("testpassword"),
        user_group="musician",
        email="test@example.com",
        clear_name="Test User",
        musician=True
    )
    db_session.add(user)
    db_session.commit()

    authenticated = authenticate_user(db_session, "testuser", "testpassword")

    assert authenticated is not None
    assert authenticated.user_name == "testuser"
    assert authenticated.user_group == "musician"


def test_authenticate_user_wrong_password(db_session):
    """Test authentication with wrong password."""
    user = User(
        user_name="testuser",
        user_pw=hash_pw("testpassword"),
        user_group="musician",
        email="test@example.com",
        clear_name="Test User",
        musician=True
    )
    db_session.add(user)
    db_session.commit()

    authenticated = authenticate_user(db_session, "testuser", "wrongpassword")

    assert authenticated is None


def test_authenticate_user_nonexistent(db_session):
    """Test authentication with non-existent user."""
    authenticated = authenticate_user(db_session, "nonexistent", "password")

    assert authenticated is None


def test_create_access_token():
    """Test JWT token creation."""
    data = {"sub": "testuser", "role": "musician"}
    token = create_access_token(data)

    assert isinstance(token, str)
    assert len(token) > 0

    # Verify token can be decoded
    from backend.auth import SECRET_KEY, ALGORITHM
    payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    assert payload["sub"] == "testuser"
    assert payload["role"] == "musician"


def test_get_current_user_valid_token(db_session, client, auth_headers):
    """Test getting current user with valid token."""
    data = {"sub": "testuser", "role": "musician"}
    token = create_access_token(data)

    # Mock Request object
    mock_request = Mock()
    mock_request.headers.get.return_value = f"Bearer {token}"
    mock_request.cookies.get.return_value = None

    user_data = get_current_user(mock_request, db_session)

    assert user_data["user_name"] == "testuser"
    assert user_data["user_group"] == "musician"


def test_get_current_user_invalid_token(db_session, client, auth_headers):
    """Test getting current user with invalid token."""
    invalid_token = "invalid.token.here"

    # Mock Request object
    mock_request = Mock()
    mock_request.headers.get.return_value = f"Bearer {invalid_token}"
    mock_request.cookies.get.return_value = None

    with pytest.raises(HTTPException) as exc_info:
        get_current_user(mock_request, db_session)

    assert exc_info.value.status_code == 401
    assert "Could not validate credentials" in str(exc_info.value.detail)


def test_get_current_user_missing_sub(db_session, client, auth_headers):
    """Test getting current user with token missing 'sub' field."""
    # Create token without 'sub'
    from backend.auth import SECRET_KEY, ALGORITHM
    token = jwt.encode({"role": "musician"}, SECRET_KEY, algorithm=ALGORITHM)

    #mock Request object
    mock_request = Mock()
    mock_request.headers.get.return_value = f"Bearer {token}"
    mock_request.cookies.get.return_value = None

    with pytest.raises(HTTPException) as exc_info:
        get_current_user(mock_request, db_session)

    assert exc_info.value.status_code == 401


def test_get_current_user_missing_role(db_session, client, auth_headers):
    """Test getting current user with token missing 'role' field."""
    # Create token without 'role'
    from backend.auth import SECRET_KEY, ALGORITHM
    token = jwt.encode({"sub": "testuser"}, SECRET_KEY, algorithm=ALGORITHM)

    # Mock Request object
    mock_request = Mock()
    mock_request.headers.get.return_value = f"Bearer {token}"
    mock_request.cookies.get.return_value = None

    with pytest.raises(HTTPException) as exc_info:
        get_current_user(mock_request, db_session)

    assert exc_info.value.status_code == 401


def test_check_user_role_correct():
    """Test checking user role with correct role."""
    data = {"sub": "testuser", "role": "admin"}
    token = create_access_token(data)

    result = check_user_role(token, "admin")

    assert result is True


def test_check_user_role_incorrect():
    """Test checking user role with incorrect role."""
    data = {"sub": "testuser", "role": "musician"}
    token = create_access_token(data)

    result = check_user_role(token, "admin")

    assert result is False


def test_check_user_role_invalid_token():
    """Test checking user role with invalid token."""
    invalid_token = "invalid.token.here"

    with pytest.raises(HTTPException) as exc_info:
        check_user_role(invalid_token, "admin")

    assert exc_info.value.status_code == 401


def test_login_endpoint(client, db_session):
    """Test the login endpoint."""
    user = User(
        user_name="loginuser",
        user_pw=hash_pw("loginpass"),
        user_group="musician",
        email="login@example.com",
        clear_name="Login User",
        musician=True
    )
    db_session.add(user)
    db_session.commit()

    response = client.post("/login", json={
        "username": "loginuser",
        "password": "loginpass"
    })

    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"


def test_login_endpoint_wrong_credentials(client, db_session):
    """Test login endpoint with wrong credentials."""
    user = User(
        user_name="loginuser",
        user_pw=hash_pw("loginpass"),
        user_group="musician",
        email="login@example.com",
        clear_name="Login User",
        musician=True
    )
    db_session.add(user)
    db_session.commit()

    response = client.post("/login", json={
        "username": "loginuser",
        "password": "wrongpass"
    })

    assert response.status_code == 401


def test_protected_endpoint_without_token(client, db_session):
    """Test accessing protected endpoint without token."""
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
    response = client.get("/songs")

    assert response.status_code == 401


def test_protected_endpoint_with_token(client, auth_headers, db_session):
    # add songs
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
    """Test accessing protected endpoint with valid token."""
    response = client.get("/songs", headers=auth_headers)

    assert response.status_code == 200


def test_password_change_flow(client, db_session):
    """Test complete password change flow."""
    # Create user with initial password
    user = User(
        user_name="changeuser",
        user_pw=hash_pw("oldpassword"),
        user_group="musician",
        email="change@example.com",
        clear_name="Change User",
        musician=True
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    # Login with old password
    response = client.post("/login", json={
        "username": "changeuser",
        "password": "oldpassword"
    })
    assert response.status_code == 200
    token = response.json()["access_token"]

    # Change password
    response = client.put(
        "/change_password",
        json={
            "user_id": user.id,
            "old_password": "oldpassword",
            "new_password": "Newpassword1!"
        },
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200

    # Verify old password no longer works
    response = client.post("/login", json={
        "username": "changeuser",
        "password": "oldpassword"
    })
    assert response.status_code == 401

    # Verify new password works
    response = client.post("/login", json={
        "username": "changeuser",
        "password": "Newpassword1!"
    })
    assert response.status_code == 200


def test_get_db(db_session, monkeypatch):
    """Test database session generator with test database."""
    from backend import database
    from sqlalchemy.orm import sessionmaker

    # Create a sessionmaker using the test engine (from conftest.py)
    TestSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=db_session.bind)

    # Mock database.SessionLocal to use test database
    monkeypatch.setattr(database, "SessionLocal", TestSessionLocal)

    # Get the generator
    gen = get_db()

    # Get the database session
    db = next(gen)

    # Verify it's a valid Session object
    from sqlalchemy.orm import Session
    assert isinstance(db, Session)

    # Verify we can use the session
    user = User(
        user_name="dbtestuser",
        user_pw=hash_pw("dbtestpass"),
        user_group="musician",
        email="dbtest@example.com",
        clear_name="DB Test User",
        musician=True
    )
    db.add(user)
    db.commit()

    # Verify the user was added
    result = db.query(User).filter(User.user_name == "dbtestuser").first()
    assert result is not None
    assert result.user_name == "dbtestuser"

    # Close the generator (triggers finally block)
    try:
        next(gen)
    except StopIteration:
        pass

    # Verify user only exists in test database, not real database
    assert db_session.query(User).filter(User.user_name == "dbtestuser").first() is not None
