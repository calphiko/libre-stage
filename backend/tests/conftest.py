import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from backend.main import app
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

    # Override both get_db functions
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[auth.get_db] = override_get_db

    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture
def test_user(db_session):
    """Create a test user."""
    user = models.User(
        user_name="testuser",
        user_pw=auth.hash_pw("testpassword123"),
        user_group="admin",
        musician=True,
        clear_name="Test User",
        email="test@example.com"
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
        email="testuser2@example.com"
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