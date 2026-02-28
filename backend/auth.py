import base64
import hashlib
from fastapi import Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from jose import jwt, JWTError
from fastapi.security import OAuth2PasswordBearer
from backend import database, models
from datetime import datetime, timezone, timedelta
import logging
import bcrypt

logger = logging.getLogger("uvicorn.error")



# Deadline für alte Hash-Formate
LEGACY_HASH_DEADLINE = datetime(2026, 4, 30, 23, 59, 59, tzinfo=timezone.utc)

import os
from dotenv import load_dotenv

load_dotenv(".env")

SECRET_KEY = os.getenv("SECRET_KEY")
RESET_PASSWORD_TOKEN_EXPIRE_MINUTES = 15
ACCESS_TOKEN_EXPIRE_MINUTES = 15
REFRESH_TOKEN_EXPIRE_DAYS = 30
ALGORITHM = "HS256"
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login", auto_error=False)
oauth2_password_reset_scheme = OAuth2PasswordBearer(tokenUrl="password_reset", auto_error=False)


def get_token_from_cookie_or_header(request: Request) -> str | None:
    """Extrahiert Token aus Authorization Header oder Cookie (Fallback)"""
    # 1. Versuche Authorization Header (primäre Methode)
    auth_header = request.headers.get("Authorization")
    if auth_header and auth_header.startswith("Bearer "):
        return auth_header[7:]

    # 2. Fallback auf Cookie (für Abwärtskompatibilität)
    cookie_token = request.cookies.get("access_token")
    if cookie_token:
        return cookie_token.removeprefix("Bearer ")

    # 3. Kein Token gefunden
    logger.warning("No authentication token found in request")
    return None


def hash_pw(plain_pw: str) -> str:
    return bcrypt.hashpw(plain_pw.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def verify_password(plain: str, hashed: str) -> bool:
    # Neues bcrypt-Format
    if hashed.startswith(('$2b$', '$2a$', '$2y$')):
        try:
            return bcrypt.checkpw(plain.encode('utf-8'), hashed.encode('utf-8'))
        except Exception:
            return False

    # Alte Formate nur bis Deadline akzeptieren
    if datetime.now(timezone.utc) > LEGACY_HASH_DEADLINE:
        logger.warning("Legacy hash format rejected - deadline exceeded")
        return False

    # LDAP-Style SHA1: {SHA}Base64EncodedHash
    if hashed.startswith('{SHA}'):
        sha1_b64 = hashed[5:]  # Entferne "{SHA}" Prefix
        computed = base64.b64encode(hashlib.sha1(plain.encode()).digest()).decode()
        return computed == sha1_b64

    return False

def authenticate_user(db: Session, username: str, password: str):
    user = db.query(models.User).filter(models.User.user_name == username).first()
    if not user:
        return None

    if not verify_password(password, user.user_pw):
        return None

    # Auto-Upgrade: Alten Hash auf bcrypt umstellen
    if not user.user_pw.startswith(('$2b$', '$2a$', '$2y$')):
        logger.info(f"Upgrading password hash for user {username}")
        user.user_pw = hash_pw(password)
        db.commit()

    return user

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def create_refresh_token(user_id: int, db: Session) -> str:
    """Erstellt ein Refresh Token und speichert es in der DB"""
    import secrets
    token = secrets.token_urlsafe(32)
    token_hash = hashlib.sha256(token.encode()).hexdigest()

    expires_at = datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)

    db_token = models.RefreshToken(
        token_hash=token_hash,
        user_id=user_id,
        expires_at=expires_at
    )
    db.add(db_token)
    db.commit()

    return token


def verify_refresh_token(token: str, db: Session) -> models.User:
    """Verifiziert ein Refresh Token und gibt den User zurück"""
    token_hash = hashlib.sha256(token.encode()).hexdigest()

    db_token = db.query(models.RefreshToken).filter(
        models.RefreshToken.token_hash == token_hash
    ).first()

    if not db_token:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    if db_token.revoked:
        raise HTTPException(status_code=401, detail="Refresh token has been revoked")

    if db_token.expires_at.replace(tzinfo=timezone.utc) < datetime.now(timezone.utc):
        raise HTTPException(status_code=401, detail="Refresh token has expired")

    user = db.query(models.User).filter(models.User.id == db_token.user_id).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    return user


def revoke_refresh_token(token: str, db: Session):
    """Markiert ein Refresh Token als revoked"""
    token_hash = hashlib.sha256(token.encode()).hexdigest()

    db_token = db.query(models.RefreshToken).filter(
        models.RefreshToken.token_hash == token_hash
    ).first()

    if db_token:
        db_token.revoked = True
        db.commit()


def blacklist_access_token(token: str, db: Session):
    """Fügt ein Access Token zur Blacklist hinzu"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        exp = payload.get("exp")
        if not exp:
            return

        token_hash = hashlib.sha256(token.encode()).hexdigest()
        expires_at = datetime.fromtimestamp(exp, tz=timezone.utc)

        # Nur blacklisten wenn noch nicht abgelaufen
        if expires_at > datetime.now(timezone.utc):
            blacklist_entry = models.TokenBlacklist(
                token_hash=token_hash,
                expires_at=expires_at
            )
            db.add(blacklist_entry)
            db.commit()
    except JWTError:
        pass  # Invalid token, ignore

def create_password_reset_token(user_name: str):
    current_ts = datetime.now(timezone.utc).isoformat()
    data = {"sub": user_name, "ts": current_ts, "scope": "password_reset_token"}
    return jwt.encode(data, SECRET_KEY, algorithm=ALGORITHM)

def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_current_user(request: Request, db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
    )

    # Token aus Cookie oder Header extrahieren
    token = get_token_from_cookie_or_header(request)
    if not token:
        raise credentials_exception

    try:
        # Blacklist-Check
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        blacklisted = db.query(models.TokenBlacklist).filter(
            models.TokenBlacklist.token_hash == token_hash
        ).first()

        if blacklisted:
            raise HTTPException(status_code=401, detail="Token has been revoked")

        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username = payload.get("sub")
        user_group = payload.get("role")

        # JWT exp wird automatisch von jose geprüft
        if username is None or user_group is None:
            raise credentials_exception
        return {"user_name": username, "user_group": user_group}
    except JWTError:
        raise credentials_exception


# Wrapper für Router-Level Dependencies (FastAPI injiziert Request automatisch)
async def get_current_user_dep(request: Request, db: Session = Depends(get_db)):
    """Async wrapper for router-level dependencies"""
    return get_current_user(request, db)

def check_user_role(token: str, expected_role: str):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_group = payload.get("role")
        if user_group == expected_role:
            return True
        return False
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
        )

def verify_password_reset_token(token: str = Depends(oauth2_password_reset_scheme), db: Session = Depends(get_db)) -> tuple[str, str]:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("scope") != "password_reset_token":
            raise HTTPException(status_code=400, detail="Invalid token scope")

        if payload.get("ts") is None:
            raise HTTPException(status_code=400, detail="Invalid token timestamp")
        ts = datetime.fromisoformat(payload.get("ts"))
        if ts < (datetime.now(timezone.utc) - timedelta(minutes=int(RESET_PASSWORD_TOKEN_EXPIRE_MINUTES))):
            raise HTTPException(status_code=400, detail="Token has expired")
        if payload.get("sub") is None:
            raise HTTPException(status_code=400, detail="Invalid token subject")

        # Check if token already used
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        used_token = db.query(models.UsedPasswordResetToken).filter(
        models.UsedPasswordResetToken.token_hash == token_hash).first()

        if used_token:
            raise HTTPException(status_code=400, detail="Token has already been used")

        return payload.get("sub"), token
    except JWTError:
        raise HTTPException(status_code=400, detail="Invalid token")