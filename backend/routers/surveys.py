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

from dataclasses import fields

from fastapi import APIRouter, Depends, HTTPException, Response, Query
from datetime import time
import logging

from sqlalchemy.orm import Session
from typing import List

from backend import models, schemas, auth

from datetime import datetime, timezone

import os
from dotenv import load_dotenv

router = APIRouter(
    prefix="/surveys", tags=["surveys"], dependencies=[Depends(auth.get_current_user_dep)]
)

logger = logging.getLogger("uvicorn.error")
load_dotenv(".env")

MM_CHANNEL = os.getenv("MM_CHANNEL_VOTES")

def get_surveys_from_db(db: Session, skip: int = 0, limit: int = 20):
    return db.query(models.Surveys).order_by(models.Surveys.datum.desc()).offset(skip).limit(limit).all()

@router.get("/", response_model=List[schemas.SurveyList])
def read_surveys(
    db: Session = Depends(auth.get_db),
    skip: int = 0,
    limit: int = Query(20, le=100),
    current=Depends(auth.get_current_user)
):
    """
    Returns a list of surveys.

    :param db: Database session (injected automatically)
    :type db: sqlalchemy.orm.Session
    :param skip: Number of entries to skip (pagination)
    :type skip: int
    :param limit: Maximum number of surveys to return (max. 100)
    :type limit: int
    :param current: Currently authenticated user (injected automatically)
    :type current: User
    :return: List of surveys, sorted by release date (descending)
    :rtype: List[schemas.SurveyList]
    """
    logger.info("Fetching surveys from database")
    polls = get_surveys_from_db(db, skip=skip, limit=limit)

    return polls

@router.post("/", response_model=List[schemas.SurveyList])
def create_survey(
    survey: schemas.SurveyIn,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user)
):
    """
    Create a new survey.
    :param survey: Survey data
    :param db: Database session (injected automatically)
    :param current: Currently authenticated user (injected automatically)
    :return: The created survey
    """
    logger.info("Creating a new survey in the database")
    user_db = db.query(models.User).filter(models.User.user_name == current["user_name"]).first()
    if not user_db:
        raise HTTPException(status_code=403, detail="Your User is not found")

    new_survey = models.Surveys(
        kind_of_survey=survey.kind_of_survey,
        datum=datetime.now(tz=timezone.utc),
        rf_survey=survey.rf_survey,
        released=survey.released,
        release_date=datetime.now(tz=timezone.utc),
        closed=survey.closed,
        user_created=user_db.id
    )
    db.add(new_survey)
    db.commit()
    db.refresh(new_survey)
    for field in survey.fields:
        new_field = models.SurveyFields(
            id_survey=new_survey.id,
            field_text=field.field_text
        )
        db.add(new_field)
    db.commit()
    db.refresh(new_survey)

    # mattermost notificarion
    try:
        from backend.utils import mattermost
        message = f":mega: Es wurde eine neue Umfrage zum Thema  **{survey.rf_survey}** erstellt. Bitte gib zügig dein Feedback im internen Bereich ab.\n"

        mattermost.send_mm_message(channel=MM_CHANNEL, text=message)
    except Exception as e:
        logger.error(f"Failed to send Mattermost message: {e}")


    return get_surveys_from_db(db)



@router.get("/{survey_id}", response_model=schemas.SurveyQuestionOut)
def read_survey(
    survey_id: int,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user)
):
    """
    Returns a single survey by its ID.

    :param survey_id: The ID of the survey
    :type survey_id: int
    :param db: Database session (injected automatically)
    :type db: sqlalchemy.orm.Session
    :param current: Currently authenticated user (injected automatically)
    :type current: User
    :return: The survey with its associated questions
    :rtype: schemas.SurveyQuestionOut
    :raises HTTPException 404: If no survey with the given ID is found
    """
    logger.info(f"Fetching survey with id {survey_id} from database")

    poll = (
        db.query(models.Surveys)
        .filter(models.Surveys.id == survey_id)
        .first()
    )
    if poll is None:
        logger.error(f"Survey with id {survey_id} not found")
        raise HTTPException(status_code=404, detail="Survey not found")
    return poll

@router.put("/{survey_id}/feedback", response_model=schemas.SurveyQuestionOut)
def update_survey_feedback(
    survey_id: int,
    feedbacks: List[schemas.SurveyFeedbackOut],
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user)
):
    """
    Update or create feedback entries for survey fields.

    :param survey_id: The ID of the survey
    :param feedbacks: List of feedback entries to update or create
    :param db: Database session (injected automatically)
    :param current: Currently authenticated user (injected automatically)
    :return: The updated survey with all fields and feedback
    :raises HTTPException 404: If survey or survey field not found
    """

    user_db = db.query(models.User).filter(models.User.user_name == current["user_name"]).first()
    if not user_db:
        raise HTTPException(status_code=403, detail="Your User is not found")

    logger.info(f"Updating feedback for survey with id {survey_id}")
    poll = db.query(models.Surveys).filter(models.Surveys.id == survey_id).first()
    if poll is None:
        logger.error(f"Survey with id {survey_id} not found")
        raise HTTPException(status_code=404, detail="Survey not found")

    if poll.closed:
        logger.error(f"Survey with id {survey_id} is closed for feedback")
        raise HTTPException(status_code=403, detail="Survey is closed for feedback")

    # Get all valid field IDs for this survey
    valid_field_ids = {field.id for field in poll.fields}

    # Collect field IDs where current user should have feedback
    current_user_feedback_fields = {
        fb.id_sv_field for fb in feedbacks
        if fb.id_user == user_db.id and fb.value is not None
    }

    # Delete only current user's feedbacks that are not in the new list
    db.query(models.SurveyFeedback).filter(
        models.SurveyFeedback.id_sv_field.in_(valid_field_ids),
        models.SurveyFeedback.id_user == user_db.id,
        ~models.SurveyFeedback.id_sv_field.in_(current_user_feedback_fields)
    ).delete(synchronize_session=False)

    for feedback in feedbacks:
        # Skip feedbacks from other users
        if feedback.id_user != user_db.id:
            continue

        if feedback.id_sv_field not in valid_field_ids:
            logger.error(f"Survey field {feedback.id_sv_field} does not belong to survey {survey_id}")
            raise HTTPException(
                status_code=400,
                detail=f"Survey field {feedback.id_sv_field} does not belong to this survey"
            )

        if feedback.value is None:
            db.query(models.SurveyFeedback).filter(
                models.SurveyFeedback.id_sv_field == feedback.id_sv_field,
                models.SurveyFeedback.id_user == user_db.id
            ).delete(synchronize_session=False)
            continue

        # Update or create feedback
        existing_feedback = (
            db.query(models.SurveyFeedback)
            .filter(
                models.SurveyFeedback.id_sv_field == feedback.id_sv_field,
                models.SurveyFeedback.id_user == user_db.id
            )
            .first()
        )

        if existing_feedback:
            existing_feedback.value = feedback.value
            existing_feedback.comment = feedback.comment
            existing_feedback.datum = datetime.now(tz=timezone.utc)
        else:
            new_feedback = models.SurveyFeedback(
                id_sv_field=feedback.id_sv_field,
                id_user=user_db.id,
                value=feedback.value,
                comment=feedback.comment,
                datum=datetime.now(tz=timezone.utc)
            )
            db.add(new_feedback)

    db.commit()
    db.refresh(poll)
    logger.info(f"Successfully updated feedback for survey {survey_id}")
    return poll

@router.delete("/{survey_id}", response_model=List[schemas.SurveyList])
def delete_survey(
    survey_id: int,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user)
):
    """
    Delete a survey by its ID.

    :param survey_id: The ID of the survey to delete
    :param db: Database session (injected automatically)
    :param current: Currently authenticated user (injected automatically)
    :return: List of remaining surveys after deletion
    :raises HTTPException 404: If no survey with the given ID is found
    """
    user_db = db.query(models.User).filter(models.User.user_name == current["user_name"]).first()
    if not user_db:
        raise HTTPException(status_code=403, detail="Your User is not found")

    survey = db.query(models.Surveys).filter(models.Surveys.id == survey_id).first()

    if survey is None:
        logger.error(f"Survey with id {survey_id} not found")
        raise HTTPException(status_code=404, detail="Survey not found")

    if not user_db.id == survey.user_created and not user_db.user_group =="admin":
        raise HTTPException(status_code=403, detail="You do not have permission to delete this survey")

    # Get all field IDs for this survey
    field_ids = [field.id for field in survey.fields]

    # Check if any feedback exists
    if field_ids:
        feedback_count = db.query(models.SurveyFeedback).filter(
            models.SurveyFeedback.id_sv_field.in_(field_ids)
        ).count()

        if feedback_count > 0:
            logger.warning(f"Cannot delete survey {survey_id} - has {feedback_count} feedback entries")
            raise HTTPException(
                status_code=403,
                detail="Cannot delete survey with existing feedback"
            )

    logger.info(f"Deleting survey with id {survey_id} from database")

    # Delete all fields associated with this survey
    db.query(models.SurveyFields).filter(
        models.SurveyFields.id_survey == survey_id
    ).delete(synchronize_session=False)

    db.delete(survey)
    db.commit()

    return get_surveys_from_db(db)

@router.put("/close/{survey_id}", response_model=List[schemas.SurveyList])
def close_survey(
    survey_id: int,
    db: Session = Depends(auth.get_db),
    current=Depends(auth.get_current_user)
):
    """
    Close a survey by its ID.

    :param survey_id: The ID of the survey to close
    :param db: Database session (injected automatically)
    :param current: Currently authenticated user (injected automatically)
    :return: The closed survey
    :raises HTTPException 404: If no survey with the given ID is found
    """
    user_db = db.query(models.User).filter(models.User.user_name == current["user_name"]).first()
    if not user_db:
        raise HTTPException(status_code=403, detail="Your User is not found")

    survey = db.query(models.Surveys).filter(models.Surveys.id == survey_id).first()

    if survey is None:
        logger.error(f"Survey with id {survey_id} not found")
        raise HTTPException(status_code=404, detail="Survey not found")

    if not user_db.id == survey.user_created and not user_db.user_group =="admin":
        raise HTTPException(status_code=403, detail="You do not have permission to close this survey")

    logger.info(f"Closing survey with id {survey_id}")
    survey.closed = True
    db.commit()

    # Mattermost notification
    # Je nach Typ

    return get_surveys_from_db(db)
