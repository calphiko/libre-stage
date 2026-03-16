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
iCal calendar feed router.

Provides unauthenticated iCal (RFC 5545) feeds for rehearsals and gigs
so that band members can subscribe to band events in any calendar
application.

Prefix: ``/ical``  |  Tag: ``ical``
"""

from fastapi import APIRouter, Depends, HTTPException, Response, Query
from fastapi.responses import StreamingResponse
from datetime import time, datetime, timedelta
import pytz
import logging
import os
from sqlalchemy.orm import Session

from typing import List
from backend import models, schemas, auth
from backend.app_config import app_config

router = APIRouter(
    prefix="/ical", tags=["ical"], dependencies=[]
)

logger = logging.getLogger("uvicorn.error")

ICAL_DOMAIN = app_config.get("ical_domain", "example.com")
ICAL_PRODID = app_config.get("ical_prodid", "-//Band Calendar//EN")
ICAL_CALNAME = app_config.get("ical_calendar_name", "Band Termine")
ICAL_REH_PREFIX = app_config.get("ical_rehearsal_prefix", "[Probe]")
ICAL_GIG_PREFIX = app_config.get("ical_gig_prefix", "[Gig]")
APP_TIMEZONE = os.getenv("TIMEZONE", app_config.get("timezone", "Europe/Berlin"))
# suppress progress polls to reduce log clutter
block_endpoints = ["/ical/log"]


class LogFilter(logging.Filter):  # pragma: no cover
    def filter(self, record):
        if record.args and len(record.args) >= 3:
            if record.args[2] in block_endpoints:  # type: ignore
                return False
        return True


uvicorn_logger = logging.getLogger("uvicorn.access")
uvicorn_logger.addFilter(LogFilter())


@router.get("/")
def get_iCal_Abo(
        db: Session = Depends(auth.get_db),
):
    from icalendar import Calendar, Event
    from io import BytesIO

    berlin_tz = pytz.timezone(APP_TIMEZONE)

    logger.info("Fetching gigs from database")
    gigs = db.query(models.Gig).order_by(models.Gig.datum.desc()).all()
    logger.info("Fetching rehearsals from database")
    reh = db.query(models.Rehearsal).order_by(models.Rehearsal.begin.desc()).all()

    cal = Calendar()
    cal.add('prodid', ICAL_PRODID)
    cal.add('version', '2.0')
    cal.add('X-WR-CALNAME', ICAL_CALNAME)
    cal.add('X-WR-TIMEZONE', APP_TIMEZONE)
    cal.add('X-WR-CALDESC', 'Proben und Gigs')

    # Add gigs
    for gig in gigs:
        event = Event()
        event.add('summary', f'{ICAL_GIG_PREFIX} {gig.name or "Auftritt"}')

        # Stable UID basierend auf Gig-ID
        event.add('uid', f'gig-{gig.id}@{ICAL_DOMAIN}')

        # DTSTAMP sollte Creation-Zeit sein, nicht jetzt
        if hasattr(gig, 'created_at') and gig.created_at:
            dtstamp = berlin_tz.localize(gig.created_at) if gig.created_at.tzinfo is None else gig.created_at
        else:
            dtstamp = berlin_tz.localize(datetime.combine(gig.datum, time(0, 0)))
        event.add('dtstamp', dtstamp)

        # Rest deines Codes für dtstart/dtend...
        if gig.begin:
            dtstart = berlin_tz.localize(datetime.combine(gig.datum, gig.begin))
        else:
            dtstart = berlin_tz.localize(datetime.combine(gig.datum, time(20, 0)))
        event.add('dtstart', dtstart)

        if gig.end:
            if gig.begin and gig.end < gig.begin:
                dtend = berlin_tz.localize(datetime.combine(gig.datum + timedelta(days=1), gig.end))
            else:
                dtend = berlin_tz.localize(datetime.combine(gig.datum, gig.end))
        else:
            dtend = dtstart + timedelta(hours=3)
        event.add('dtend', dtend)

        if hasattr(gig, 'kind_of_gig') and gig.kind_of_gig:
            event.add('description', gig.kind_of_gig)
        cal.add_component(event)

    # Add rehearsals - analog mit stabilen UIDs
    for rehearsal in reh:
        event = Event()
        event.add('uid', f'rehearsal-{rehearsal.id}@{ICAL_DOMAIN}')

        # Stable DTSTAMP
        if hasattr(rehearsal, 'created_at') and rehearsal.created_at:
            dtstamp = berlin_tz.localize(
                rehearsal.created_at) if rehearsal.created_at.tzinfo is None else rehearsal.created_at
        else:
            dtstamp = rehearsal.begin if rehearsal.begin.tzinfo else berlin_tz.localize(rehearsal.begin)
        event.add('dtstamp', dtstamp)

        if rehearsal.begin.tzinfo is None:
            dtstart = berlin_tz.localize(rehearsal.begin)
        else:
            dtstart = rehearsal.begin.astimezone(berlin_tz)
        event.add('dtstart', dtstart)

        if rehearsal.end:
            if rehearsal.end.tzinfo is None:
                dtend = berlin_tz.localize(rehearsal.end)
            else:
                dtend = rehearsal.end.astimezone(berlin_tz)
        else:
            dtend = dtstart + timedelta(hours=2)
        event.add('dtend', dtend)

        start_label = dtstart.strftime('%H:%M')
        end_label = dtend.strftime('%H:%M')
        event.add('summary', f'{ICAL_REH_PREFIX} {start_label}-{end_label} Uhr')

        description_lines = [f'Zeit: {start_label}-{end_label} Uhr']
        if getattr(rehearsal, 'comment', None):
            description_lines.append(f'Kommentar: {rehearsal.comment}')

        if hasattr(rehearsal, 'songs'):
            song_titles = [song.title for song in rehearsal.songs if hasattr(song, 'title')]
            if song_titles:
                description_lines.append('Agenda:')
                description_lines.extend([f'- {t}' for t in song_titles])

        event.add('description', "\n".join(description_lines))

        if hasattr(rehearsal, 'ort') and rehearsal.ort:
            event.add('location', rehearsal.ort)

        cal.add_component(event)

    ical_bytes = BytesIO(cal.to_ical())
    return StreamingResponse(
        ical_bytes,
        media_type="text/calendar; charset=utf-8",
        headers={
            "Content-Disposition": "attachment; filename=termine.ics",
            "Cache-Control": "no-cache, no-store, must-revalidate",
            "Pragma": "no-cache",
            "Expires": "0"
        }
    )
