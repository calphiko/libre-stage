# libre-stage - Band rehearsal and gig management software
# Copyright (C) 2026  libre-stage contributors

from datetime import datetime, date, time

from backend import auth
from backend.models import Rehearsal, Gig


def test_public_ical_excludes_rehearsals_and_unpublished_gigs(client, db_session):
    db_session.add(
        Rehearsal(
            comment="Soundcheck und Warmup",
            begin=datetime(2026, 3, 20, 18, 0),
            end=datetime(2026, 3, 20, 20, 30),
            ical="",
        )
    )
    db_session.add(
        Gig(
            name="Public Gig",
            datum=date(2026, 3, 25),
            begin=time(20, 0),
            end=time(22, 0),
            publish="1",
        )
    )
    db_session.add(
        Gig(
            name="Private Gig",
            datum=date(2026, 3, 26),
            begin=time(20, 0),
            end=time(22, 0),
            publish="0",
        )
    )
    db_session.commit()

    response = client.get("/ical/")
    assert response.status_code == 200

    ical_text = response.text
    assert "BEGIN:VEVENT" in ical_text
    assert "SUMMARY:[Gig] Public Gig" in ical_text
    assert "SUMMARY:[Gig] Private Gig" not in ical_text
    assert "SUMMARY:[Probe]" not in ical_text
    assert "Kommentar: Soundcheck und Warmup" not in ical_text


def test_internal_ical_includes_rehearsal_time_range_summary_and_description(client, db_session, test_user):
    reh = Rehearsal(
        comment="Soundcheck und Warmup",
        begin=datetime(2026, 3, 20, 18, 0),
        end=datetime(2026, 3, 20, 20, 30),
        ical="",
    )
    db_session.add(reh)
    db_session.commit()

    token = auth.generate_ical_token(test_user.user_name)
    response = client.get(f"/ical/{token}")
    assert response.status_code == 200

    ical_text = response.text
    assert "BEGIN:VEVENT" in ical_text
    assert "SUMMARY:[Probe] 18:00-20:30 Uhr" in ical_text
    assert "Zeit: 18:00-20:30 Uhr" in ical_text
    assert "Kommentar: Soundcheck und Warmup" in ical_text
