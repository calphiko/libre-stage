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
Token Cleanup Utility
Entfernt abgelaufene Tokens aus der Datenbank
"""
import logging
from datetime import datetime, timezone, timedelta
from sqlalchemy.orm import Session
from backend import models

logger = logging.getLogger("uvicorn.error")


def cleanup_expired_tokens(db: Session):
    """
    Entfernt abgelaufene Tokens aus der Datenbank:
    - UsedPasswordResetToken älter als 48h
    - TokenBlacklist Einträge die bereits abgelaufen sind
    - RefreshToken Einträge die revoked und älter als 48h sind
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

