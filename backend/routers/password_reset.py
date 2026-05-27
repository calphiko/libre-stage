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
Password reset router.

Implements the self-service password reset flow:

1. An admin triggers a reset for a user via the admin router.
2. A time-limited JWT is sent to the user by e-mail or Mattermost.
3. The user submits the new password together with the token.
4. The token is marked as used to prevent replay attacks.

Rate limiting: 3 requests per minute per IP.

Prefix: ``/password_reset``  |  Tag: ``pw_reset``
"""

from fastapi import APIRouter, Depends, HTTPException, Request
import logging
from sqlalchemy.orm import Session
from backend import models, schemas, auth
from backend.utils.mailer import send_email
import hashlib

from datetime import datetime, timezone
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)


def mark_token_as_used(db: Session, token: str):
    """
    Record a password-reset token as consumed.

    Stores the SHA-256 hash of *token* in
    :class:`models.UsedPasswordResetToken` so that the same token
    cannot be used twice.

    Args:
        db (Session): Active database session.
        token (str): The raw password-reset JWT string.
    """
    token_hash = hashlib.sha256(token.encode()).hexdigest()
    used_token = models.UsedPasswordResetToken(token_hash=token_hash, used_at=datetime.now(timezone.utc))
    db.add(used_token)
    db.commit()

router = APIRouter(
    prefix="/password_reset", tags=["pw_reset"]
)

logger = logging.getLogger("uvicorn.error")
# suppress progress polls to reduce log clutter
block_endpoints = ["/admin/log"]

@router.get("/verify_reset_token")
@limiter.limit("5/minute")
def verify_reset_token(
    request: Request,
    auth_data = Depends(auth.verify_password_reset_token),
    db: Session = Depends(auth.get_db)
):
    try:
        user_name, token = auth_data
        user = db.query(models.User).filter(models.User.user_name == user_name).first()
        return {"user_name": user_name}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/new_password")
@limiter.limit("5/minute")
def set_new_password(
    request:  Request,
    data: schemas.PasswordResetRequest,
    auth_data = Depends(auth.verify_password_reset_token),
    db: Session = Depends(auth.get_db)
):
    try:
        user_name, token = auth_data
        user = db.query(models.User).filter(models.User.user_name == user_name).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        user.user_pw = auth.hash_pw(data.new_password)
        mark_token_as_used(db, token)
        db.commit()
        logger.info(f"Password reset successful for user {user_name}")
        return {"message": "Password reset successful"}
    except Exception as e:
        logger.error(f"Error during password reset for user {user_name}: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))