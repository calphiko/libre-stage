"""
Availability router.

Allows users to declare their availability for rehearsals and gigs.
Supports an optional substitute entry (name or registered user) when
the user is unavailable.

Prefix: ``/availability``  |  Tag: ``availability``
"""

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

import logging
from datetime import date
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Path
from sqlalchemy.orm import Session

from backend import models, schemas, auth

logger = logging.getLogger("uvicorn.error")

VALID_EVENT_TYPES = {"rehearsal", "gig"}

router = APIRouter(
    prefix="/availability",
    tags=["availability"],
    dependencies=[Depends(auth.get_current_user_dep)],
)


def _get_user_id(current: dict, db: Session) -> int:
    """Resolve the integer user-id from the JWT payload dict."""
    user = db.query(models.User).filter_by(user_name=current["user_name"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user.id


def _build_response(
    event_type: str,
    event_id: int,
    db: Session,
    current_user_id: int,
) -> schemas.EventAvailabilityOut:
    """Fetch all availability entries for an event and build the response."""
    entries = (
        db.query(models.Availability)
        .filter_by(event_type=event_type, event_id=event_id)
        .all()
    )

    result: List[schemas.AvailabilityOut] = []
    for entry in entries:
        user = entry.user
        sub_user = entry.substitute_user
        result.append(
            schemas.AvailabilityOut(
                id=entry.id,
                user_id=entry.user_id,
                user_name=user.user_name if user else "",
                clear_name=user.clear_name if user else None,
                status=entry.status,
                comment=entry.comment,
                substitute_name=entry.substitute_name,
                substitute_user_id=entry.substitute_user_id,
                substitute_clear_name=sub_user.clear_name if sub_user else None,
            )
        )

    summary = {
        "available": sum(1 for r in result if r.status == "available"),
        "unavailable": sum(1 for r in result if r.status == "unavailable"),
        "maybe": sum(1 for r in result if r.status == "maybe"),
    }

    my_entry = next((r for r in result if r.user_id == current_user_id), None)

    return schemas.EventAvailabilityOut(
        availabilities=result,
        summary=summary,
        my_status=my_entry.status if my_entry else None,
    )


@router.get("/pending_gigs", response_model=List[schemas.PendingAvailabilityGigOut])
def get_pending_availability_gigs(
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user),
):
    """Return upcoming gigs for which the current user has not yet submitted availability."""
    current_user_id = _get_user_id(current, db)
    today = date.today()

    upcoming_gigs = (
        db.query(models.Gig)
        .filter(models.Gig.datum >= today)
        .filter(models.Gig.status != "abgelehnt")
        .order_by(models.Gig.datum)
        .all()
    )

    # Filter out gigs that already have an availability entry for the current user
    submitted_gig_ids = {
        row.event_id
        for row in db.query(models.Availability.event_id)
        .filter_by(user_id=current_user_id, event_type="gig")
        .all()
    }

    pending = [g for g in upcoming_gigs if g.id not in submitted_gig_ids]

    return [
        schemas.PendingAvailabilityGigOut(
            id=g.id,
            name=g.name,
            datum=g.datum,
            kind_of_gig=g.kind_of_gig,
        )
        for g in pending
    ]


@router.get("/{event_type}/{event_id}", response_model=schemas.EventAvailabilityOut)
def get_availability(
    event_type: str = Path(..., description="'rehearsal' or 'gig'"),
    event_id: int = Path(..., description="ID of the rehearsal or gig"),
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user),
):
    """Return all availability entries for a given event."""
    if event_type not in VALID_EVENT_TYPES:
        raise HTTPException(status_code=400, detail="Invalid event_type. Use 'rehearsal' or 'gig'.")

    return _build_response(event_type, event_id, db, _get_user_id(current, db))


@router.put("/{event_type}/{event_id}", response_model=schemas.EventAvailabilityOut)
def set_availability(
    data: schemas.AvailabilityIn,
    event_type: str = Path(..., description="'rehearsal' or 'gig'"),
    event_id: int = Path(..., description="ID of the rehearsal or gig"),
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user),
):
    """Create or update the current user's availability for an event."""
    if event_type not in VALID_EVENT_TYPES:
        raise HTTPException(status_code=400, detail="Invalid event_type. Use 'rehearsal' or 'gig'.")

    current_user_id = _get_user_id(current, db)

    # Validate substitute_user_id if provided
    if data.substitute_user_id is not None:
        sub_user = db.query(models.User).get(data.substitute_user_id)
        if not sub_user:
            raise HTTPException(status_code=404, detail="Substitute user not found")

    entry = (
        db.query(models.Availability)
        .filter_by(
            user_id=current_user_id,
            event_type=event_type,
            event_id=event_id,
        )
        .first()
    )

    if entry:
        entry.status = data.status
        entry.comment = data.comment
        entry.substitute_name = data.substitute_name
        entry.substitute_user_id = data.substitute_user_id
        logger.info(
            f"User {current['user_name']} updated availability for {event_type} {event_id}: {data.status}"
        )
    else:
        entry = models.Availability(
            user_id=current_user_id,
            event_type=event_type,
            event_id=event_id,
            status=data.status,
            comment=data.comment,
            substitute_name=data.substitute_name,
            substitute_user_id=data.substitute_user_id,
        )
        db.add(entry)
        logger.info(
            f"User {current['user_name']} set availability for {event_type} {event_id}: {data.status}"
        )

    db.commit()

    return _build_response(event_type, event_id, db, current_user_id)


@router.delete("/{event_type}/{event_id}", response_model=schemas.EventAvailabilityOut)
def delete_availability(
    event_type: str = Path(..., description="'rehearsal' or 'gig'"),
    event_id: int = Path(..., description="ID of the rehearsal or gig"),
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user),
):
    """Remove the current user's availability entry for an event."""
    if event_type not in VALID_EVENT_TYPES:
        raise HTTPException(status_code=400, detail="Invalid event_type. Use 'rehearsal' or 'gig'.")

    current_user_id = _get_user_id(current, db)

    entry = (
        db.query(models.Availability)
        .filter_by(
            user_id=current_user_id,
            event_type=event_type,
            event_id=event_id,
        )
        .first()
    )

    if entry:
        db.delete(entry)
        db.commit()
        logger.info(
            f"User {current['user_name']} removed availability for {event_type} {event_id}"
        )

    return _build_response(event_type, event_id, db, current_user_id)
