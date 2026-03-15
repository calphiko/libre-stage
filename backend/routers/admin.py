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
Admin router – user and system management.

All endpoints are protected by :func:`user_is_admin` which verifies
that the authenticated user holds the ``admin`` role.

Prefix: ``/admin``  |  Tag: ``admin``
"""

from fastapi import APIRouter, Depends, HTTPException, Request

import logging
from sqlalchemy.orm import Session
from typing import List
from backend import models, schemas, auth
from backend.utils.email import send_email
import os
from dotenv import load_dotenv
from backend.utils.check_permissions import check_admin

logger = logging.getLogger("uvicorn.error")
# suppress progress polls to reduce log clutter
block_endpoints = ["/admin/log"]
load_dotenv(".env")

async def user_is_admin(request: Request, db: Session = Depends(auth.get_db)):
    """
    Router-level dependency: allow access only for admin users.

    Reads the token from the request (header or cookie), validates it
    and checks the ``admin`` role.

    Args:
        request (Request): Incoming FastAPI request.
        db (Session): Active database session.

    Returns:
        dict: Current user payload (``user_name``, ``user_group``).

    Raises:
        HTTPException 403: If the authenticated user is not an admin.
        HTTPException 401: If authentication fails.
    """
    logger.info(f"[Admin-Check] Request Path: {request.url.path}")
    logger.info(f"[Admin-Check] Cookies: {list(request.cookies.keys())}")
    logger.info(f"[Admin-Check] Auth Header: {request.headers.get('Authorization', 'None')}")

    try:
        # Get current user using the cookie/header token
        user = auth.get_current_user(request, db)
        logger.info(f"[OK] User authenticated: {user.get('user_name')}, Group: {user.get('user_group')}")

        if check_admin(user):
            logger.info(f"[OK] User is admin - access granted")
            return user
        else:
            logger.warning(f"[DENIED] User {user.get('user_name')} is NOT admin: {user.get('user_group')}")
            raise HTTPException(status_code=403, detail="User is not Admin!")
    except HTTPException as e:
        logger.error(f"[ERROR] Auth failed with HTTPException: {e.detail}")
        raise
    except Exception as e:
        logger.error(f"[ERROR] Auth failed with Exception: {type(e).__name__}: {e}")
        raise HTTPException(status_code=401, detail="Authentication failed")

router = APIRouter(
    prefix="/admin", tags=["admin"], dependencies=[Depends(user_is_admin)]
)




class LogFilter(logging.Filter):  # pragma: no cover
    def filter(self, record):
        if record.args and len(record.args) >= 3:
            if record.args[2] in block_endpoints:  # type: ignore
                return False
        return True


uvicorn_logger = logging.getLogger("uvicorn.access")
uvicorn_logger.addFilter(LogFilter())

@router.get("/users", response_model=List[schemas.UserOut])
def get_all_users(
        db: Session = Depends(auth.get_db),
):
    users = db.query(models.User).all()
    for user in users:
        if user.musician == None:
            user.musician = False
    return users

@router.put("/users/{user_id}")#, response_model=schemas.UserOut)
def update_user(
        user_id: int,
        data: schemas.UserOut,
        db: Session = Depends(auth.get_db),
):
    logger.info(f"Admin updating user {user_id}")
    user_db = db.query(models.User).filter(models.User.id == user_id).first()
    if not user_db:
        raise HTTPException(status_code=404, detail="User not found")
    # check if user_name is changing and if the new one is already taken
    changes = []
    if user_db.user_name != data.user_name:
        existing_user = db.query(models.User).filter(models.User.user_name == data.user_name).first()
        if existing_user:
            raise HTTPException(status_code=400, detail="Username already taken")
        changes.append(f"Username: {user_db.user_name} → {data.user_name}")

    if user_db.user_group != data.user_group:
        changes.append(f"Rolle: {user_db.user_group} → {data.user_group}")

    if user_db.email != data.email:
        changes.append(f"E-Mail: {user_db.email} → {data.email}")

    if user_db.clear_name != data.clear_name:
        changes.append(f"Klarname: {user_db.clear_name} → {data.clear_name}")

    if user_db.mm_username != data.mm_username:
        from backend.utils.mattermost import send_mm_message
        test_status = False
        if data.mm_username == None or data.mm_username.strip() == "":
            changes.append(f"Mattermost Nutzername: {user_db.mm_username} → {data.mm_username}")
        else:
            try:
                test_status = send_mm_message(f"Dein Mattermost Nutzername wurde von '{user_db.mm_username}' zu '{data.mm_username}' geändert.", channel=f"@{data.mm_username}")
            except Exception as e:
                logger.error(f"Fehler beim Senden der Testnachricht an neuen Mattermost Nutzernamen '{data.mm_username}': {e}. Wird nicht geändet")
                raise HTTPException(status_code=400, detail=f"Error sending test message to new Mattermost @{data.mm_username}'. Change not applied.")
            if test_status:
                changes.append(f"Mattermost Nutzername: {user_db.mm_username} → {data.mm_username}")


    user_db.user_name = data.user_name
    user_db.clear_name = data.clear_name
    user_db.email = data.email
    user_db.user_group = data.user_group
    user_db.musician = data.musician
    user_db.is_singer = data.is_singer
    user_db.mm_username = data.mm_username
    db.commit()
    db.refresh(user_db)

    # E-Mail senden falls Änderungen vorgenommen wurden
    if changes and user_db.email:
        subject = "Dein Benutzerkonto wurde aktualisiert"
        body = f"Hallo {user_db.clear_name or user_db.user_name},\n\n"
        body += "Dein Benutzerkonto wurde von einem Administrator geändert:\n\n"
        body += "\n".join(changes)
        body += "\n\nBei Fragen wende dich an einen Admin."
        send_email(user_db.email, subject, body)

    return user_db

@router.delete("/users/{user_id}")
def delete_user(
        user_id: int,
        db: Session = Depends(auth.get_db),
):
    user_db = db.query(models.User).filter(models.User.id == user_id).first()
    if not user_db:
        raise HTTPException(status_code=404, detail="User not found")
    db.delete(user_db)
    db.commit()
    logger.info(f"Admin deleted user {user_id}")
    return {"message": f"User {user_id} deleted"}

@router.post("/users", response_model=schemas.UserOut)
def create_user(
        user: schemas.UserCreate,
        db: Session = Depends(auth.get_db),
):
    db_user = models.User(
        user_name=user.user_name,
        user_pw=auth.hash_pw(user.user_pw),
        user_group=user.user_group,
        musician=user.musician,
        clear_name=user.clear_name,
        email=user.email,
        is_singer=user.is_singer,
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

@router.put("/trigger_password_reset/{user_id}")
def trigger_password_reset(
        user_id: int,
        db: Session = Depends(auth.get_db),
):
    user_db = db.query(models.User).filter(models.User.id == user_id).first()
    if not user_db:
        raise HTTPException(status_code=404, detail="User not found")
    if not user_db.email:
        raise HTTPException(status_code=400, detail="User has no email address, cannot send reset link.")

    # Generate a password reset token (for simplicity, using a timestamp here)
    reset_token = auth.create_password_reset_token(user_db.user_name)
    reset_link = f"{os.getenv('FRONTEND_URL')}/password_reset?token={reset_token}"

    # Send the reset link via Mattermost if the user has a mm_username, otherwise send via email
    if user_db.mm_username:
        from backend.utils.mattermost import send_mm_message
        try:
            send_mm_message(f"Ein Passwort-Reset wurde für dein Konto angefordert. Klicke hier, um dein Passwort zurückzusetzen: {reset_link}\n\n**Dieser Link ist für 15 Minuten gültig!**", channel=f"@{user_db.mm_username}")
            logger.info(f"Password reset link sent to Mattermost user @{user_db.mm_username}")
        except Exception as e:
            logger.error(f"Error sending password reset link to Mattermost user @{user_db.mm_username}: {e}. Falling back to email.")
            send_email(user_db.email, "Password Reset Request", f"Ein Passwort-Reset wurde für dein Konto angefordert. Klicke hier, um dein Passwort zurückzusetzen: {reset_link}\n\nDieser Link ist für 15 Minuten gültig!")
    else:
        send_email(user_db.email, "Password Reset Request", f"Ein Passwort-Reset wurde für dein Konto angefordert. Klicke hier, um dein Passwort zurückzusetzen: {reset_link}\n\nDieser Link ist für 15 Minuten gültig!")
        logger.info(f"Password reset link sent to email {user_db.email}")




    return {"message": "Password reset link sent to user's email."}