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




def test_internal_calendar_json_returns_month_entries(client, auth_headers, db_session):
    db_session.add_all([
        Gig(name="Juni-Gig", datum=date(2026, 6, 30), publish="0"),
        Gig(name="Juli-Gig", datum=date(2026, 7, 1), publish="1"),
        Rehearsal(comment="", ical="", begin=datetime(2026, 6, 30, 19), end=datetime(2026, 6, 30, 21)),
        Rehearsal(comment="", ical="", begin=datetime(2026, 7, 2, 19), end=datetime(2026, 7, 2, 21)),
    ])
    db_session.commit()

    response = client.get("/ical/internal?month=2026-06", headers=auth_headers)

    assert response.status_code == 200
    data = response.json()
    assert [g["name"] for g in data["gigs"]] == ["Juni-Gig"]
    assert len(data["rehearsals"]) == 1
    assert client.get("/ical/internal?month=bad", headers=auth_headers).status_code == 400
