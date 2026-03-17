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
Authentication and authorisation utilities.

Provides JWT-based access and refresh token handling, password hashing
(bcrypt with legacy SHA-1 fallback), user lookup and all FastAPI
dependency helpers required by the API routers.

Constants:
    ACCESS_TOKEN_EXPIRE_MINUTES (int): Lifetime of an access token in minutes (15).
    REFRESH_TOKEN_EXPIRE_DAYS (int): Lifetime of a refresh token in days (30).
    RESET_PASSWORD_TOKEN_EXPIRE_MINUTES (int): Lifetime of a password-reset token (15).
    ALGORITHM (str): JWT signing algorithm (``HS256``).
"""

import base64
import hashlib
from fastapi import Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
import jwt
from jwt.exceptions import InvalidTokenError as JWTError
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
    """
    Extract a Bearer token from the ``Authorization`` header or the
    ``access_token`` cookie.

    The header is checked first; the cookie serves as a backwards-
    compatible fallback.

    Args:
        request (Request): The incoming FastAPI request object.

    Returns:
        str | None: The raw JWT string, or ``None`` if no token was found.
    """
    # 1. Try Authorization Header
    auth_header = request.headers.get("Authorization")
    if auth_header and auth_header.startswith("Bearer "):
        return auth_header[7:]

    # 2. Fallback on Cookie
    cookie_token = request.cookies.get("access_token")
    if cookie_token:
        return cookie_token.removeprefix("Bearer ")

    # 3. No Token found
    logger.warning("No authentication token found in request")
    return None


def hash_pw(plain_pw: str) -> str:
    """
    Hash a plain-text password using bcrypt.

    Args:
        plain_pw (str): The plain-text password to hash.

    Returns:
        str: The bcrypt hash string.
    """
    return bcrypt.hashpw(plain_pw.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def verify_password(plain: str, hashed: str) -> bool:
    """
    Verify a plain-text password against a stored hash.

    Supports bcrypt hashes (``$2b$``, ``$2a$``, ``$2y$`` prefix) and,
    until :data:`LEGACY_HASH_DEADLINE`, LDAP-style SHA-1 hashes
    (``{SHA}`` prefix).

    Args:
        plain (str): The plain-text password provided by the user.
        hashed (str): The stored password hash.

    Returns:
        bool: ``True`` if the password matches, ``False`` otherwise.
    """
    # New bcrypt-Format
    if hashed.startswith(('$2b$', '$2a$', '$2y$')):
        try:
            return bcrypt.checkpw(plain.encode('utf-8'), hashed.encode('utf-8'))
        except Exception:
            return False

    # Accept old formats only until the deadline
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
    """
    Look up a user by username and verify their password.

    If the stored hash uses a legacy format it is automatically
    upgraded to bcrypt on successful login.

    Args:
        db (Session): Active database session.
        username (str): The username to look up.
        password (str): The plain-text password to verify.

    Returns:
        models.User | None: The authenticated user, or ``None`` if
        the credentials are invalid.
    """
    user = db.query(models.User).filter(models.User.user_name == username).first()
    if not user:
        return None

    if not verify_password(password, user.user_pw):
        return None

    if user.status == "deactivated":
        logger.warning(f"Login attempt by deactivated user: {username}")
        return None

    # Auto-Upgrade: convert old hash to bycrypt on successful login (only if not already bcrypt)
    if not user.user_pw.startswith(('$2b$', '$2a$', '$2y$')):
        logger.info(f"Upgrading password hash for user {username}")
        user.user_pw = hash_pw(password)
        db.commit()

    return user

def create_access_token(data: dict):
    """
    Create a signed JWT access token.

    The token expires after :data:`ACCESS_TOKEN_EXPIRE_MINUTES` minutes.

    Args:
        data (dict): Payload to encode (must contain at least ``sub`` and ``role``).

    Returns:
        str: The encoded JWT string.
    """
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def create_refresh_token(user_id: int, db: Session) -> str:
    """
    Create a refresh token, persist its hash in the database and return
    the raw token string.

    Args:
        user_id (int): Primary key of the user the token belongs to.
        db (Session): Active database session.

    Returns:
        str: The raw (unhashed) refresh token.
    """
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
    """
    Validate a refresh token and return the associated user.

    Args:
        token (str): The raw refresh token string.
        db (Session): Active database session.

    Returns:
        models.User: The user associated with the token.

    Raises:
        HTTPException 401: If the token is invalid, revoked or expired.
    """
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

    if user.status == "deactivated":
        raise HTTPException(status_code=401, detail="Account is deactivated")

    return user


def revoke_refresh_token(token: str, db: Session):
    """
    Mark a refresh token as revoked in the database.

    Args:
        token (str): The raw refresh token string.
        db (Session): Active database session.
    """
    token_hash = hashlib.sha256(token.encode()).hexdigest()

    db_token = db.query(models.RefreshToken).filter(
        models.RefreshToken.token_hash == token_hash
    ).first()

    if db_token:
        db_token.revoked = True
        db.commit()


def blacklist_access_token(token: str, db: Session):
    """
    Add an access token to the blacklist so it cannot be reused after
    logout.

    Only tokens that have not yet expired are stored; already-expired
    tokens are silently ignored.

    Args:
        token (str): The raw JWT access token string.
        db (Session): Active database session.
    """
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithm=ALGORITHM)
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
    """
    Create a short-lived JWT token scoped to password reset.

    Args:
        user_name (str): The username for which the reset is requested.

    Returns:
        str: The encoded JWT string with ``scope="password_reset_token"``.
    """
    current_ts = datetime.now(timezone.utc).isoformat()
    data = {"sub": user_name, "ts": current_ts, "scope": "password_reset_token"}
    return jwt.encode(data, SECRET_KEY, algorithm=ALGORITHM)

def get_db():
    """
    FastAPI dependency that yields a database session.

    Yields:
        Session: An active SQLAlchemy database session.
    """
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_current_user(request: Request, db: Session = Depends(get_db)):
    """
    FastAPI dependency that validates the access token and returns the
    current user's payload.

    Checks both the token blacklist and the JWT signature/expiry.

    Args:
        request (Request): The incoming request (token read from header or cookie).
        db (Session): Active database session.

    Returns:
        dict: A dictionary with keys ``user_name`` and ``user_group``.

    Raises:
        HTTPException 401: If the token is missing, invalid or blacklisted.
    """
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

        # DB-Lookup: Status sofort prüfen (deaktivierte User sofort sperren)
        user_db = db.query(models.User).filter(models.User.user_name == username).first()
        if user_db and user_db.status == "deactivated":
            raise HTTPException(status_code=401, detail="Account is deactivated")

        return {"user_name": username, "user_group": user_group}
    except JWTError:
        raise credentials_exception


# Wrapper für Router-Level Dependencies (FastAPI injiziert Request automatisch)
async def get_current_user_dep(request: Request, db: Session = Depends(get_db)):
    """
    Async wrapper for router-level dependencies

    Args:
        request (Request): The incoming request.
        db (Session): Active database session.

    Returns:
        dict: A dictionary with keys ``user_name`` and ``user_group``.
    """
    return get_current_user(request, db)

def check_user_role(token: str, expected_role: str):
    """
    Verify that a JWT token carries a specific role.

    Args:
        token (str): The raw JWT string.
        expected_role (str): The role to check against (e.g. ``"admin"``).

    Returns:
        bool: ``True`` if the token's ``role`` claim matches *expected_role*.

    Raises:
        HTTPException 401: If the token cannot be decoded.
    """
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
    """
    Validate a password-reset token and ensure it has not been used before.

    Args:
        token (str): The raw password-reset JWT.
        db (Session): Active database session.

    Returns:
        tuple[str, str]: A tuple of ``(username, raw_token)``.

    Raises:
        HTTPException 400: If the token is invalid, expired, has the wrong
            scope or has already been used.
    """
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