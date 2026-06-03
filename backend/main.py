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
FastAPI application entry point.

Creates the :class:`fastapi.FastAPI` instance, registers all middleware
(CORS, GZip, rate limiting), mounts all API routers and defines the
core endpoints that do not belong to a specific sub-resource:

- ``POST /login`` – password-based login, returns access + refresh tokens
- ``POST /refresh`` – exchange a refresh token for a new access token
- ``POST /logout`` – revoke tokens and clear cookies
- ``GET  /me`` – return the authenticated user's profile
- ``PUT  /update_user`` – update own user profile
- ``PUT  /change_password`` – change own password
- ``GET  /user_list`` – list all users (authenticated)
- ``GET  /user_todo_list`` – personal to-do and feedback list
- ``GET  /app_info`` – application metadata
- ``GET  /db_health`` – database connectivity probe
"""

import logging

from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
import json

#slowapi
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from sqlalchemy import func, text
from sqlalchemy.orm import Session
from backend import database, models, schemas, auth
from backend.app_config import app_config  # Validiert appConfig.json beim Startup
from datetime import datetime, timezone
from dotenv import load_dotenv

from typing import List
import os
from pathlib import Path


from backend.routers import gigs, songs, rehearsals, surveys, cal, admin, password_reset, public, gigs_livemode
from backend.utils.token_cleanup import cleanup_expired_tokens
from backend.utils.password_validator import validate_password

import asyncio

# Limiter initialisieren
limiter = Limiter(key_func=get_remote_address)

api_prefix = ""
assert type(api_prefix) is str

logger = logging.getLogger("uvicorn")
load_dotenv()

log_level_name = os.getenv("LOG_LEVEL", "INFO").upper()
log_level = getattr(logging, log_level_name, None)
if not isinstance(log_level, int):
    logger.warning("Invalid LOG_LEVEL '%s'. Falling back to INFO.", log_level_name)
    log_level = logging.INFO

# Ensure LOG_LEVEL consistently applies to server and app loggers.
for logger_name in (
    "uvicorn",
    "uvicorn.error",
    "uvicorn.access",
    "gunicorn.error",
    "gunicorn.access",
    "granian",
    "granian.access",
):
    logging.getLogger(logger_name).setLevel(log_level)

logging.getLogger().setLevel(log_level)

docs_url = os.getenv("DOCS_URL", None)
openapi_url = os.getenv("OPENAPI_URL", None)

version_path = Path(__file__).parent.parent / "version.json"
try:
    logger.info(f"Searching for version dict in:\n\t {version_path}")
    with open(version_path, "r") as f:
        version_dict = json.load(f) # pragma: no cover
except FileNotFoundError:
    logger.info("Version file not found.")
    version_dict = {
        "release": "0.0.0",
        "date": "1970-01-01T12:00:00Z",
        "title": "Band Manager",
        "Description": "Internal band management platform.",
    }


app = FastAPI(
    root_path=api_prefix,
    redoc_url=None,
    docs_url=docs_url,
    openapi_url=openapi_url,
    version=version_dict.get("release", "0.0.0"),
    title=version_dict.get("title", "Band Manager"),
    description=version_dict.get("Description", "")
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# ===== EXCEPTION HANDLERS =====
from fastapi.responses import JSONResponse

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Excepts all unhandled exceptions, logs them and returns a generic error message"""
    logger.error(f"Unhandled error on {request.url.path}: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "Ein interner Fehler ist aufgetreten"}
    )

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """Specific handler for HTTPExceptions with logging"""
    logger.warning(f"HTTP {exc.status_code} on {request.url.path}: {exc.detail}")
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail}
    )

origins_env = os.getenv("CORS_ORIGINS", "")
origins = [origin.strip() for origin in origins_env.split(",") if origin.strip()]

print (origins)

# CORS für Entwicklung (Frontend <-> Backend)
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(GZipMiddleware, minimum_size=1000, compresslevel=5)


@app.on_event("startup")
async def startup_event():
    """Führe Token-Cleanup bei Startup aus"""
    logger.info("Running token cleanup on startup...")
    db = database.SessionLocal()
    try:
        cleanup_expired_tokens(db)
    except Exception as e:
        logger.error(f"Token cleanup failed: {e}")
    finally:
        db.close()


async def periodic_token_cleanup():
    """Background Task für periodisches Token-Cleanup (alle 24h)"""
    while True:
        await asyncio.sleep(86400)  # 24 Stunden
        logger.info("Running periodic token cleanup...")
        db = database.SessionLocal()
        try:
            cleanup_expired_tokens(db)
        except Exception as e:
            logger.error(f"Periodic token cleanup failed: {e}")
        finally:
            db.close()


@app.on_event("startup")
async def start_background_tasks():
    """Starte Background Tasks"""
    asyncio.create_task(periodic_token_cleanup())

def get_todo_list(user_name: str, db: Session):
    user = db.query(models.User).filter_by(user_name=user_name).first()
    db_todos = (db.query(models.RehTodo, models.Song.title, models.Song.interpret)
                .filter_by(id_user=user.id)
                .join(models.Song, models.RehTodo.id_song == models.Song.id)
                .all()
                )

    db_songs_to_todo = (
        db.query(models.Song)
        .filter(models.Song.status == 'vorschlag')
        .outerjoin(
            models.SongCandidateFeedback,
            (models.SongCandidateFeedback.song_id == models.Song.id) &
            (models.SongCandidateFeedback.user_id == user.id)
        )
        .filter(models.SongCandidateFeedback.id == None)
        .all()
    )

    db_surveys_to_todo = (
        db.query(models.Surveys)
        .filter(models.Surveys.released == True)
        .filter(models.Surveys.closed == False)
        .outerjoin(
            models.SurveyFields,
            models.SurveyFields.id_survey == models.Surveys.id
        )
        .outerjoin(
            models.SurveyFeedback,
            (models.SurveyFeedback.id_sv_field == models.SurveyFields.id) &
            (models.SurveyFeedback.id_user == user.id)
        )
        .group_by(models.Surveys.id)
        .having(func.count(models.SurveyFeedback.id) == 0)
        .all()
    )

    result_list = {
        "todo":  [
            {
                "id": todo.id,
                "todo": todo.todo,
                "user_name": user.user_name,
                "done": todo.done,
                "song_title": title,
                "song_interpret": interpret,
                "dt": todo.dt
            } for todo, title, interpret in db_todos
        ],
        "songs_to_feedback": [
            {
                "id": song.id,
                "title": song.title,
                "interpret": song.interpret,
                "status": song.status
            } for song in db_songs_to_todo
        ],
        "surveys_to_feedback": [
            {
                "id": survey.id,
                "kind_of_survey": survey.kind_of_survey,
                "rf_survey": survey.rf_survey,
                "release_date": survey.release_date.isoformat() if survey.release_date else None
            } for survey in db_surveys_to_todo
        ]
    }
    return result_list

@app.post("/login")
@limiter.limit("10/minute")
def login(
        request: Request,
        data: schemas.LoginRequest,
        db: Session = Depends(auth.get_db)
):
    user = auth.authenticate_user(db, data.username, data.password)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    # Access Token mit kurzer Laufzeit (15 Min)
    access_token = auth.create_access_token({
        "sub": user.user_name,
        "role": user.user_group
    })

    # Refresh Token mit langer Laufzeit (30 Tage)
    refresh_token = auth.create_refresh_token(user.id, db)

    # Tokens im Response Body zurückgeben (nicht in Cookies)
    # Client speichert diese im localStorage
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": auth.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        "message": "Login successful"
    }


@app.post("/refresh")
@limiter.limit("30/minute")
def refresh_token(
        request: Request,
        refresh_data: schemas.RefreshRequest,
        db: Session = Depends(auth.get_db)
):
    """
    Refresh Token aus Request Body lesen und neuen Access Token generieren.
    Erwartet: { "refresh_token": "..." }

    Multi-Device Support: Der Refresh Token wird NICHT rotiert/revoked,
    damit mehrere Geräte gleichzeitig eingeloggt bleiben können.
    """
    refresh_token = refresh_data.refresh_token
    if not refresh_token:
        raise HTTPException(status_code=401, detail="No refresh token provided")

    # Verifiziere Refresh Token und hole User
    user = auth.verify_refresh_token(refresh_token, db)

    # Erstelle nur neuen Access Token - behalte Refresh Token bei
    new_access_token = auth.create_access_token({
        "sub": user.user_name,
        "role": user.user_group
    })

    # Gebe den gleichen Refresh Token zurück (kein neuer Token)
    return {
        "access_token": new_access_token,
        "refresh_token": refresh_token,  # Gleicher Token
        "token_type": "bearer",
        "expires_in": auth.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        "message": "Token refreshed"
    }


@app.post("/logout")
def logout(
        request: Request,
        logout_data: schemas.LogoutRequest = None,
        db: Session = Depends(auth.get_db)
):
    """
    Logout: Blacklist Access Token und revoke Refresh Token.
    Token wird aus Authorization Header gelesen.
    """
    # Token aus Header extrahieren
    token = auth.get_token_from_cookie_or_header(request)

    # Blacklist Access Token
    if token:
        auth.blacklist_access_token(token, db)

    # Revoke Refresh Token wenn im Body mitgeschickt
    if logout_data and logout_data.refresh_token:
        try:
            auth.revoke_refresh_token(logout_data.refresh_token, db)
        except Exception as e:
            logger.warning(f"Could not revoke refresh token during logout: {e}")

    return {"message": "Logged out successfully"}

@app.get("/me", response_model=schemas.UserOut)
def get_me(current = Depends(auth.get_current_user), db: Session = Depends(auth.get_db)):
    user = db.query(models.User).filter(models.User.user_name == current["user_name"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    # Nullable DB columns – set defaults so Pydantic serialisation never fails
    if user.musician is None:
        user.musician = False
    if user.is_singer is None:
        user.is_singer = False
    if user.clear_name is None:
        user.clear_name = ""
    return user

@app.put("/update_user", response_model=schemas.UserOut)
@limiter.limit("10/minute")
def update_user(
        request: Request,
        user: schemas.UserOut,
        current=Depends(auth.get_current_user),
        db: Session = Depends(auth.get_db)):
    user_db = db.query(models.User).filter(models.User.user_name == current["user_name"]).first()
    if not user_db.id == user.id:
        raise HTTPException(status_code=403, detail="Your are not allowed to update this user!")

    # Felder, die niemals verändert werden dürfen:
    forbidden_fields = {"user_name", "user_role"}

    for k, v in user.model_dump(exclude_unset=True).items():
        if getattr(user_db, k) == v:
            continue
        # Wert unterschiedlich und Feld ist verboten -> Abbruch
        if k in forbidden_fields:
            raise HTTPException(status_code=403, detail=f"Not allowed to update field '{k}'")
        setattr(user_db, k, v)
    db.commit()
    db.refresh(user_db)
    # Null-Fallbacks (analog get_me)
    if user_db.musician is None:
        user_db.musician = False
    if user_db.is_singer is None:
        user_db.is_singer = False
    if user_db.clear_name is None:
        user_db.clear_name = ""
    return user_db

@app.put("/change_password")
@limiter.limit("5/minute")
def change_password(
        request: Request,
        data: schemas.PasswordUpdateRequest,
        current=Depends(auth.get_current_user),
        db: Session = Depends(auth.get_db)):
    user_db = db.query(models.User).filter(models.User.user_name == current["user_name"]).first()
    if not user_db:
        raise HTTPException(status_code=404, detail="User not found")
    if not user_db.id == data.user_id:
        raise HTTPException(status_code=403, detail="Your are not allowed to update this user!")
    if not auth.verify_password(data.old_password, user_db.user_pw):
        raise HTTPException(status_code=403, detail="Wrong password!")
    is_valid, error_msg = validate_password(data.new_password)
    if not is_valid:
        raise HTTPException(status_code=400, detail=error_msg)
    if auth.verify_password(data.new_password, user_db.user_pw):
        raise HTTPException(status_code=403, detail="Old and new passwords are identical")
    user_db.user_pw = auth.hash_pw(data.new_password)
    db.commit()
    return {"msg": "Password updates successfully"}

@app.get("/user_list", response_model=List[schemas.UserListElem])
def get_users_list(
    current=Depends(auth.get_current_user),
    db: Session = Depends(auth.get_db)
):
    users = db.query(models.User).filter(models.User.musician==1, models.User.status=="active")
    return users

@app.get("/user_todos", response_model=schemas.UserTodoList)
def get_user_todo(
    current=Depends(auth.get_current_user),
    db: Session = Depends(auth.get_db)
):

    return get_todo_list(current["user_name"], db)

@app.put("/user_todos_done", response_model=schemas.UserTodoList)
@limiter.limit("30/minute")
def set_user_todo_done(
    request: Request,
    todo: schemas.UserTodo,
    current= Depends(auth.get_current_user),
    db: Session = Depends(auth.get_db)

):
    db_todo = db.get(models.RehTodo, todo.id)
    db_todo.done = True

    db.commit()

    return get_todo_list(current["user_name"], db)

@app.get("/version", response_model=dict)
def get_version_dict():
    return version_dict

@app.get("/health")
def health_check(db: Session = Depends(auth.get_db)):
    """Überprüft ob API und DB erreichbar sind"""
    try:
        # Einfache DB-Query zum Testen
        db.execute(text("SELECT 1"))
        return {
            "status": "ok",
            "database": "connected",
            "version": version_dict.get("release", "0.0.0")
        }
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(status_code=503, detail="Service temporarily unavailable")

app.include_router(gigs.router)
app.include_router(songs.router)
app.include_router(rehearsals.router)
app.include_router(surveys.router)
app.include_router(cal.router)
app.include_router(admin.router)
app.include_router(password_reset.router)
app.include_router(public.router)
app.include_router(gigs_livemode.router)
