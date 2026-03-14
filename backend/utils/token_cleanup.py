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
Token cleanup utility.

Removes expired and revoked tokens from the database to keep the token
tables lean. Intended to be called once at application startup and
optionally on a recurring schedule.

Cleaned up tables:
    - :class:`models.UsedPasswordResetToken` – entries older than 48 h
    - :class:`models.TokenBlacklist` – entries whose ``expires_at`` is in the past
    - :class:`models.RefreshToken` – revoked entries older than 48 h and
      all entries whose ``expires_at`` is in the past
"""
import logging
from datetime import datetime, timezone, timedelta
from sqlalchemy.orm import Session
from backend import models

logger = logging.getLogger("uvicorn.error")


def cleanup_expired_tokens(db: Session):
    """
    Delete expired and revoked tokens from the database.

    Args:
        db (Session): Active SQLAlchemy database session.

    Returns:
        dict: A summary dictionary with the number of removed rows per
        category::

            {
                "password_reset": int,
                "blacklist": int,
                "revoked_refresh": int,
                "expired_refresh": int,
            }

    Raises:
        Exception: Re-raises any database exception after rolling back
            the transaction.
    """
    cutoff_time = datetime.now(timezone.utc) - timedelta(hours=48)
    now = datetime.now(timezone.utc)

    try:
        # Cleanup UsedPasswordResetToken
        deleted_pw_reset = db.query(models.UsedPasswordResetToken).filter(
            models.UsedPasswordResetToken.used_at < cutoff_time
        ).delete()

        # Cleanup TokenBlacklist (bereits abgelaufen)
        deleted_blacklist = db.query(models.TokenBlacklist).filter(
            models.TokenBlacklist.expires_at < now
        ).delete()

        # Cleanup revoked RefreshTokens
        deleted_refresh = db.query(models.RefreshToken).filter(
            models.RefreshToken.revoked == True,
            models.RefreshToken.created_at < cutoff_time
        ).delete()

        # Cleanup abgelaufene RefreshTokens
        deleted_expired_refresh = db.query(models.RefreshToken).filter(
            models.RefreshToken.expires_at < now
        ).delete()

        db.commit()

        logger.info(
            f"Token cleanup: {deleted_pw_reset} password reset tokens, "
            f"{deleted_blacklist} blacklist entries, "
            f"{deleted_refresh} revoked refresh tokens, "
            f"{deleted_expired_refresh} expired refresh tokens removed"
        )

        return {
            "password_reset": deleted_pw_reset,
            "blacklist": deleted_blacklist,
            "revoked_refresh": deleted_refresh,
            "expired_refresh": deleted_expired_refresh
        }

    except Exception as e:
        db.rollback()
        logger.error(f"Error during token cleanup: {e}")
        raise

