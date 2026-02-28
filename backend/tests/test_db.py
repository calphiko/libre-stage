import pytest

from backend.database import (
    get_db
)

from backend.auth import (hash_pw)
from backend.models import User



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
