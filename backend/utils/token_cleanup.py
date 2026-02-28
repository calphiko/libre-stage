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

