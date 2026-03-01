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

import pytest
from datetime import datetime, timedelta
from backend.models import Surveys, SurveyFields, SurveyFeedback, User

from pprint import pprint


def test_get_surveys(client, auth_headers, db_session):
    """Test getting all surveys."""
    user = User(
        user_name="testuserix",
        user_pw="hashed_pw",
        user_group="admin",
        email="test@example.com",
        clear_name="Test User",
        musician=True
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    survey1 = Surveys(
        kind_of_survey="Band Feedback",
        rf_survey="How was the rehearsal?",
        released=True,
        closed=False,
        user_created=user.id,
        release_date=datetime.now(),
        datum=datetime.now()
    )
    survey2 = Surveys(
        kind_of_survey="Gig Feedback",
        rf_survey="How was the performance?",
        released=False,
        closed=False,
        user_created=user.id,
        release_date=datetime.now() + timedelta(days=1),
        datum=datetime.now() + timedelta(days=1)
    )
    db_session.add(survey1)
    db_session.commit()
    db_session.add(survey2)
    db_session.commit()

    response = client.get("/surveys", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2
    assert data[1]["kind_of_survey"] == "Band Feedback"
    assert data[0]["kind_of_survey"] == "Gig Feedback"


def test_get_survey_by_id(client, auth_headers, db_session):
    """Test getting a specific survey by ID."""
    user = User(
        user_name="testuserix",
        user_pw="hashed_pw",
        user_group="admin",
        email="test@example.com",
        clear_name="Test User",
        musician=True
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    survey = Surveys(
        kind_of_survey="Test Survey",
        rf_survey="Test question?",
        released=True,
        closed=False,
        user_created=user.id,
        release_date=datetime.now(),
        datum=datetime.now()
    )
    db_session.add(survey)
    db_session.commit()
    db_session.refresh(survey)

    response = client.get(f"/surveys/{survey.id}", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["kind_of_survey"] == "Test Survey"
    assert data["rf_survey"] == "Test question?"
    assert data["id"] == survey.id


def test_get_nonexistent_survey(client, auth_headers):
    """Test getting a survey that doesn't exist."""
    response = client.get("/surveys/99999", headers=auth_headers)
    assert response.status_code == 404


def test_create_survey(client, auth_headers, db_session):
    """Test creating a new survey."""
    user = User(
        user_name="testuserix",
        user_pw="hashed_pw",
        user_group="admin",
        email="test@example.com",
        clear_name="Test User",
        musician=True
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    survey_data = {
        "kind_of_survey": "New Survey",
        "rf_survey": "How do you rate this?",
        "released": False,
        "closed": False,
        "fields": [
            {"field_text": "Good Idea?"}
        ]
    }

    response = client.post("/surveys", json=survey_data, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()[0]
    pprint(data)
    assert data["kind_of_survey"] == "New Survey"
    assert data["rf_survey"] == "How do you rate this?"
    assert "id" in data

def test_create_survey_user_not_in_db(client, db_session):
    """Test creating a survey when authenticated user doesn't exist in database."""
    # Create auth headers with a user that doesn't exist in the database
    from backend import auth

    # Create a token for a non-existent user
    wrong_token = auth.create_access_token({
        "sub": "Franz",
        "role": "admin"
    })
    response = client.get("/me", headers={"Authorization": f"Bearer {wrong_token}"})
    headers = {"Authorization": f"Bearer {wrong_token}"}

    survey_data = {
        "kind_of_survey": "New Survey",
        "rf_survey": "How do you rate this?",
        "released": False,
        "closed": False,
        "fields": []
    }

    response = client.post("/surveys", json=survey_data, headers=headers)
    assert response.status_code == 403
    assert response.json()["detail"] == "Your User is not found"


def test_delete_survey(client, auth_headers, auth_headers2, wrong_auth_header, db_session):
    """Test deleting a survey."""
    user = User(
        user_name="testuserix",
        user_pw="hashed_pw",
        user_group="admin",
        email="test@example.com",
        clear_name="Test User",
        musician=True
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    survey = Surveys(
        kind_of_survey="Survey to Delete",
        rf_survey="Delete me?",
        released=False,
        closed=False,
        user_created=user.id,
        release_date=datetime.now(),
        datum=datetime.now()
    )
    db_session.add(survey)
    db_session.commit()
    db_session.refresh(survey)

    survey2 = Surveys(
        kind_of_survey="Feedback Survey",
        rf_survey="Give feedback",
        released=True,
        closed=True,
        user_created=user.id,
        release_date=datetime.now(),
        datum=datetime.now()
    )
    db_session.add(survey2)
    db_session.commit()

    field = SurveyFields(
        id_survey=survey.id,
        field_text="Rate this"
    )

    field2 = SurveyFields(
        id_survey=survey.id,
        field_text="Rate this"
    )

    field3 = SurveyFields(
        id_survey=survey2.id,
        field_text="Rate this"
    )

    field4 = SurveyFields(
        id_survey=survey2.id,
        field_text="Rate this"
    )


    db_session.add(field)
    db_session.commit()
    db_session.refresh(survey)
    db_session.refresh(field)

    db_session.add(field2)
    db_session.commit()
    db_session.refresh(field2)

    db_session.add(field3)
    db_session.commit()
    db_session.refresh(field3)

    db_session.add(field4)
    db_session.commit()
    db_session.refresh(field4)

    field3_feedback = SurveyFeedback(
        id_sv_field=field3.id,
        datum = datetime.now(),
        id_user=1,
        value="5",
        comment="Great!"
    )
    db_session.add(field3_feedback)
    db_session.commit()
    db_session.refresh(field3)

    response = client.delete(f"/surveys/{survey.id}", headers=wrong_auth_header)
    assert response.status_code == 403
    assert response.json()["detail"] == "Your User is not found"

    response = client.delete(f"/surveys/{survey.id + 2}", headers=auth_headers)
    assert response.status_code == 404
    assert response.json()["detail"] == "Survey not found"

    response = client.delete(f"/surveys/{survey.id}", headers=auth_headers2)
    assert response.status_code == 403
    assert response.json()["detail"] == "You do not have permission to delete this survey"

    response = client.delete(f"/surveys/{survey2.id}", headers=auth_headers)
    assert response.status_code == 403
    assert response.json()["detail"] == "Cannot delete survey with existing feedback"

    response = client.delete(f"/surveys/{survey.id}", headers=auth_headers)
    assert response.status_code == 200

    # Verify survey is deleted
    response = client.get(f"/surveys/{survey.id}", headers=auth_headers)
    assert response.status_code == 404


def test_add_feedback_to_survey(client, auth_headers, auth_headers2, wrong_auth_header, db_session):
    """Test adding feedback to a survey field."""
    user = User(
        user_name="testuserix",
        user_pw="hashed_pw",
        user_group="admin",
        email="test@example.com",
        clear_name="Test User",
        musician=True
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    survey = Surveys(
        kind_of_survey="Feedback Survey",
        rf_survey="Give feedback",
        released=True,
        closed=False,
        user_created=user.id,
        release_date=datetime.now(),
        datum=datetime.now()
    )
    db_session.add(survey)
    db_session.commit()

    survey2 = Surveys(
        kind_of_survey="Feedback Survey",
        rf_survey="Give feedback",
        released=True,
        closed=True,
        user_created=user.id,
        release_date=datetime.now(),
        datum=datetime.now()
    )
    db_session.add(survey2)
    db_session.commit()

    field = SurveyFields(
        id_survey=survey.id,
        field_text="Rate this"
    )

    field2 = SurveyFields(
        id_survey=survey2.id,
        field_text="Rate this"
    )
    db_session.add(field)
    db_session.commit()
    db_session.refresh(survey)
    db_session.refresh(field)

    db_session.add(field2)
    db_session.commit()
    db_session.refresh(survey2)
    db_session.refresh(field2)

    feedback_data = [
        {
            "id_sv_field": field.id,
            "id_user": 1,
            "value": "5",
            "comment": "Great!"
        }
    ]

    feedback_data_none = [
        {
            "id_sv_field": field.id,
            "id_user": 1,
            "value": None,
            "comment": "Great!"
        }
    ]

    feedback_data2 = [
        {
            "id_sv_field": field2.id,
            "id_user": 1,
            "value": "5",
            "comment": "Great!"
        }
    ]

    pprint(feedback_data)

    response = client.put(f"/surveys/{survey.id}/feedback", json=feedback_data, headers=wrong_auth_header)
    assert response.status_code == 403
    assert response.json()["detail"] == "Your User is not found"

    response = client.put(f"/surveys/{400}/feedback", json=feedback_data, headers=auth_headers)
    assert response.status_code == 404
    assert response.json()["detail"] == "Survey not found"

    response = client.put(f"/surveys/{survey2.id}/feedback", json=feedback_data2, headers=auth_headers)
    assert response.status_code == 403
    assert response.json()["detail"] == "Survey is closed for feedback"

    response = client.put(f"/surveys/{survey.id}/feedback", json=feedback_data, headers=auth_headers2)
    assert response.status_code == 403
    assert response.json()["detail"] == "You can only update your own feedback"

    response = client.put(f"/surveys/{survey.id}/feedback", json=feedback_data2, headers=auth_headers)
    assert response.status_code == 400
    assert response.json()["detail"] == f"Survey field {field2.id} does not belong to this survey"

    response = client.put(f"/surveys/{survey.id}/feedback", json=feedback_data_none, headers=auth_headers)
    assert response.status_code == 200

    response = client.put(f"/surveys/{survey.id}/feedback", json=feedback_data, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["fields"][0]["feedbacks"][0]["value"] == "5"
    assert data["fields"][0]["feedbacks"][0]["comment"] == "Great!"

    feedback_data = [
        {
            "id_sv_field": field.id,
            "id_user": 1,
            "value": "6",
            "comment": "Great!"
        }
    ]
    response = client.put(f"/surveys/{survey.id}/feedback", json=feedback_data, headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["fields"][0]["feedbacks"][0]["value"] == "6"


def test_get_survey_with_feedback(client, auth_headers, db_session):
    """Test getting a survey with existing feedback."""
    user = User(
        user_name="testuserix",
        user_pw="hashed_pw",
        user_group="admin",
        email="test@example.com",
        clear_name="Test User",
        musician=True
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    survey = Surveys(
        kind_of_survey="Survey with Feedback",
        rf_survey="Test",
        released=True,
        closed=False,
        user_created=user.id,
        release_date=datetime.now(),
        datum=datetime.now()
    )
    db_session.add(survey)
    db_session.commit()

    field = SurveyFields(
        id_survey=survey.id,
        field_text="Question 1"
    )
    db_session.add(field)
    db_session.commit()

    feedback = SurveyFeedback(
        id_sv_field=field.id,
        id_user=user.id,
        datum=datetime.now(),
        value="4",
        comment="Good"
    )
    db_session.add(feedback)
    db_session.commit()
    db_session.refresh(survey)

    response = client.get(f"/surveys/{survey.id}", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert len(data["fields"]) == 1
    assert len(data["fields"][0]["feedbacks"]) == 1
    assert data["fields"][0]["feedbacks"][0]["value"] == "4"
    assert data["fields"][0]["feedbacks"][0]["comment"] == "Good"


def test_close_survey(client, auth_headers, auth_headers2, wrong_auth_header, db_session):
    """Test closing a survey."""
    user = User(
        user_name="testuserix",
        user_pw="hashed_pw",
        user_group="admin",
        email="test@example.com",
        clear_name="Test User",
        musician=True
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    survey = Surveys(
        kind_of_survey="Open Survey",
        rf_survey="Test",
        released=True,
        closed=False,
        user_created=user.id,
        release_date=datetime.now(),
        datum=datetime.now()
    )
    db_session.add(survey)
    db_session.commit()
    db_session.refresh(survey)

    # Get and close the survey
    response = client.put(f"/surveys/close/{survey.id}", headers=wrong_auth_header)
    assert response.status_code == 403
    assert response.json()["detail"] == "Your User is not found"

    response = client.put(f"/surveys/close/{survey.id}", headers=auth_headers2)
    assert response.status_code == 403
    assert response.json()["detail"] == "You do not have permission to close this survey"

    response = client.put(f"/surveys/close/{survey.id +2 }", headers=auth_headers)
    assert response.status_code == 404
    assert response.json()["detail"] == "Survey not found"

    # Get and close the survey
    response = client.get(f"/surveys/{survey.id}", headers=auth_headers)
    assert response.status_code == 200
    survey_data = response.json()

    response = client.put(f"/surveys/close/{survey.id}", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()[0]
    assert data["closed"] is True

