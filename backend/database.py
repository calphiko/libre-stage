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
Database connection and session management.

Provides the SQLAlchemy engine, session factory and the
FastAPI dependency :func:`get_db`.

Configuration is done via the ``DATABASE_URL`` environment variable
(default: ``sqlite:///./backend/db/app.db``).
"""

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import os

SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./backend/db/app.db")

# SQLite-spezifische Konfiguration mit größerem Pool
# check_same_thread=False erlaubt Multi-Threading (notwendig für FastAPI)
# pool_pre_ping=True testet Verbindungen vor Verwendung
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    pool_size=20,           # Mehr Connections im Pool
    pool_pre_ping=True,     # Teste Connection vor Verwendung
    pool_recycle=3600,      # Recycle Connections nach 1h
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Dependency für FastAPI
def get_db():
    """
    FastAPI dependency that provides a database session per request.

    Opens a new :class:`sqlalchemy.orm.Session` and ensures it is
    closed after the request completes, even if an exception occurs.

    Yields:
        Session: An active SQLAlchemy database session.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
