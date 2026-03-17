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
import uuid
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from backend.main import app, limiter
from backend.models import Base
from backend import auth, models
from backend.database import get_db

from pprint import pprint

# Use in-memory SQLite for testing
SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(autouse=True)
def mock_mattermost(monkeypatch):
    """
    Mock requests.post in the mattermost module so no real HTTP calls
    are made during tests. The fixture is automatically used by every test.
    The returned MagicMock can be requested by name to assert call details.

    Example::

        def test_something(client, auth_headers, mock_mattermost):
            client.post(...)
            assert mock_mattermost.call_count == 1
            assert "Songvorschlag" in mock_mattermost.call_args.kwargs["json"]["text"]
    """
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.raise_for_status = MagicMock()

    with patch("backend.utils.mattermost.requests.post", return_value=mock_response) as mock_post:
        yield mock_post


@pytest.fixture(scope="function")
def db_session():
    """Create a fresh database for each test."""
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(db_session):
    """Create a test client with database dependency override."""

    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    # Each test gets a unique "IP" so rate limit counters never bleed between tests
    test_id = str(uuid.uuid4())
    original_key_func = limiter._key_func
    limiter._key_func = lambda request: test_id

    # Override both get_db functions
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[auth.get_db] = override_get_db

    try:
        with TestClient(app) as test_client:
            yield test_client
    finally:
        app.dependency_overrides.clear()
        limiter._key_func = original_key_func


@pytest.fixture
def test_user(db_session):
    """Create a test user."""
    user = models.User(
        user_name="testuser",
        user_pw=auth.hash_pw("testpassword123"),
        user_group="admin",
        musician=True,
        is_singer=False,
        clear_name="Test User",
        email="test@example.com",
        status="active"
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    pprint(user.id)

    return user

@pytest.fixture
def test_user2(db_session):
    """Create a second test user."""
    user = models.User(
        user_name="testuser2",
        user_pw=auth.hash_pw("testpassword456"),
        user_group="user",
        musician=True,
        clear_name="Test User 2",
        email="testuser2@example.com",
        status="active"
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user

@pytest.fixture
def auth_token(test_user):
    """Generate authentication token for test user."""
    # Use the same SECRET_KEY and ALGORITHM from auth.py
    return auth.create_access_token({
        "sub": test_user.user_name,
        "role": test_user.user_group
    })


@pytest.fixture
def auth_headers(auth_token):
    """Create authorization headers."""
    return {"Authorization": f"Bearer {auth_token}"}


@pytest.fixture
def auth_token2(test_user2):
    """Generate authentication token for test user."""
    # Use the same SECRET_KEY and ALGORITHM from auth.py
    return auth.create_access_token({
        "sub": test_user2.user_name,
        "role": test_user2.user_group
    })


@pytest.fixture
def auth_headers2(auth_token2):
    """Create authorization headers."""
    return {"Authorization": f"Bearer {auth_token2}"}

@pytest.fixture
def wrong_auth_header():
    wrong_token = auth.create_access_token(
        {
            "sub": "Franz2",
            "role": "admin"
        }
    )
    return {"Authorization": f"Bearer {wrong_token}"}