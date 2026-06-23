# libre-stage - Band rehearsal and gig management software
# Copyright (C) 2026  libre-stage contributors

from datetime import datetime

from backend.models import Rehearsal


def test_ical_rehearsal_includes_time_range_summary_and_description(client, db_session):
    reh = Rehearsal(
        comment="Soundcheck und Warmup",
        begin=datetime(2026, 3, 20, 18, 0),
        end=datetime(2026, 3, 20, 20, 30),
        ical=""
    )
    db_session.add(reh)
    db_session.commit()

    response = client.get("/ical/")
    assert response.status_code == 200

    ical_text = response.text
    assert "BEGIN:VEVENT" in ical_text
    assert "SUMMARY:[Probe] 18:00-20:30 Uhr" in ical_text
    assert "Zeit: 18:00-20:30 Uhr" in ical_text
    assert "Kommentar: Soundcheck und Warmup" in ical_text


