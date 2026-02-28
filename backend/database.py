from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import os

SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./backend/db/demo.db")

# SQLite-spezifische Konfiguration mit größerem Pool
# check_same_thread=False erlaubt Multi-Threading (notwendig für FastAPI)
# pool_pre_ping=True testet Verbindungen vor Verwendung
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    pool_size=20,           # Mehr Connections im Pool
    max_overflow=40,        # Zusätzliche Overflow-Connections
    pool_pre_ping=True,     # Teste Connection vor Verwendung
    pool_recycle=3600,      # Recycle Connections nach 1h
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Dependency für FastAPI
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

