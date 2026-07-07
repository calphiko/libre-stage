"""
Gig Checklist router.

CRUD operations for per-gig preparation checklist items.
Items can be categorised (e.g. Equipment, Soundcheck, Abbau),
assigned to a user or a free-text name, and optionally scheduled
with a due date/time (used by the Gantt-chart view in the frontend).

Prefix: ``/gigs/{gig_id}/checklist``  |  Tag: ``checklist``
"""

# libre-stage - Band rehearsal and gig management software
# Copyright (C) 2026  libre-stage contributors
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

import logging
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Path
from sqlalchemy.orm import Session

from backend import models, schemas, auth
from backend.utils.check_permissions import check_editor

logger = logging.getLogger("uvicorn.error")

router = APIRouter(
    tags=["checklist"],
    dependencies=[Depends(auth.get_current_user_dep)],
)


# ── helpers ──────────────────────────────────────────────────────────────────

def _get_gig_or_404(gig_id: int, db: Session) -> models.Gig:
    gig = db.query(models.Gig).get(gig_id)
    if not gig:
        raise HTTPException(status_code=404, detail="Gig not found")
    return gig


def _get_item_or_404(item_id: int, gig_id: int, db: Session) -> models.GigChecklistItem:
    item = (
        db.query(models.GigChecklistItem)
        .filter_by(id=item_id, gig_id=gig_id)
        .first()
    )
    if not item:
        raise HTTPException(status_code=404, detail="Checklist item not found")
    return item


def _serialize(item: models.GigChecklistItem) -> schemas.GigChecklistItemOut:
    assignee_clear = (
        item.assignee.clear_name if item.assignee else None
    )
    return schemas.GigChecklistItemOut(
        id=item.id,
        gig_id=item.gig_id,
        title=item.title,
        category=item.category,
        assignee_user_id=item.assignee_user_id,
        assignee_name=item.assignee_name,
        assignee_clear_name=assignee_clear,
        done=item.done,
        due_datetime=item.due_datetime,
        position=item.position,
        comment=item.comment,
    )


def _list_items(gig_id: int, db: Session) -> List[schemas.GigChecklistItemOut]:
    items = (
        db.query(models.GigChecklistItem)
        .filter_by(gig_id=gig_id)
        .order_by(models.GigChecklistItem.position, models.GigChecklistItem.id)
        .all()
    )
    return [_serialize(i) for i in items]


# ── endpoints ─────────────────────────────────────────────────────────────────

@router.get(
    "/gigs/{gig_id}/checklist",
    response_model=List[schemas.GigChecklistItemOut],
)
def get_checklist(
    gig_id: int = Path(...),
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user),
):
    """Return all checklist items for a gig, ordered by position."""
    _get_gig_or_404(gig_id, db)
    return _list_items(gig_id, db)


@router.post(
    "/gigs/{gig_id}/checklist",
    response_model=List[schemas.GigChecklistItemOut],
)
def create_checklist_item(
    data: schemas.GigChecklistItemIn,
    gig_id: int = Path(...),
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user),
):
    """Add a new checklist item to a gig."""
    _get_gig_or_404(gig_id, db)
    if not check_editor(current):
        raise HTTPException(status_code=403, detail="Not enough permissions")

    # Validate assignee
    if data.assignee_user_id is not None:
        if not db.query(models.User).get(data.assignee_user_id):
            raise HTTPException(status_code=404, detail="Assignee user not found")

    # Auto-position: append after last item
    max_pos = db.query(models.GigChecklistItem).filter_by(gig_id=gig_id).count()
    item = models.GigChecklistItem(
        gig_id=gig_id,
        title=data.title,
        category=data.category,
        assignee_user_id=data.assignee_user_id,
        assignee_name=data.assignee_name,
        done=data.done,
        due_datetime=data.due_datetime,
        position=data.position if data.position else max_pos,
        comment=data.comment,
    )
    db.add(item)
    db.commit()
    logger.info(f"User {current['user_name']} added checklist item '{data.title}' to gig {gig_id}")
    return _list_items(gig_id, db)


@router.put(
    "/gigs/{gig_id}/checklist/{item_id}",
    response_model=List[schemas.GigChecklistItemOut],
)
def update_checklist_item(
    data: schemas.GigChecklistItemIn,
    gig_id: int = Path(...),
    item_id: int = Path(...),
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user),
):
    """Update all fields of a checklist item."""
    _get_gig_or_404(gig_id, db)
    if not check_editor(current):
        raise HTTPException(status_code=403, detail="Not enough permissions")

    item = _get_item_or_404(item_id, gig_id, db)

    if data.assignee_user_id is not None:
        if not db.query(models.User).get(data.assignee_user_id):
            raise HTTPException(status_code=404, detail="Assignee user not found")

    item.title = data.title
    item.category = data.category
    item.assignee_user_id = data.assignee_user_id
    item.assignee_name = data.assignee_name
    item.done = data.done
    item.due_datetime = data.due_datetime
    item.position = data.position
    item.comment = data.comment
    db.commit()
    return _list_items(gig_id, db)


@router.patch(
    "/gigs/{gig_id}/checklist/{item_id}/done",
    response_model=List[schemas.GigChecklistItemOut],
)
def toggle_done(
    gig_id: int = Path(...),
    item_id: int = Path(...),
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user),
):
    """Toggle the done-state of a single checklist item (editor/admin only)."""
    _get_gig_or_404(gig_id, db)
    if not check_editor(current):
        raise HTTPException(status_code=403, detail="Not enough permissions")
    item = _get_item_or_404(item_id, gig_id, db)
    item.done = not item.done
    db.commit()
    logger.info(
        f"User {current['user_name']} toggled item {item_id} done={item.done}"
    )
    return _list_items(gig_id, db)


@router.delete(
    "/gigs/{gig_id}/checklist/{item_id}",
    response_model=List[schemas.GigChecklistItemOut],
)
def delete_checklist_item(
    gig_id: int = Path(...),
    item_id: int = Path(...),
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user),
):
    """Delete a checklist item."""
    _get_gig_or_404(gig_id, db)
    if not check_editor(current):
        raise HTTPException(status_code=403, detail="Not enough permissions")

    item = _get_item_or_404(item_id, gig_id, db)
    db.delete(item)
    db.commit()
    logger.info(f"User {current['user_name']} deleted checklist item {item_id}")
    return _list_items(gig_id, db)


