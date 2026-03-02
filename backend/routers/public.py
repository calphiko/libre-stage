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

from fastapi import APIRouter, Depends, HTTPException, Response, Query
from fastapi.responses import JSONResponse, FileResponse
from datetime import time, datetime, timedelta
import pytz
import logging
from sqlalchemy.orm import Session

from backend import models, schemas, auth
from backend.app_config import get_frontend_config
import os

router = APIRouter(
    prefix="/public", tags=["public"], dependencies=[]
)

logger = logging.getLogger("uvicorn.error")
# suppress progress polls to reduce log clutter
block_endpoints = ["/public/log"]


class LogFilter(logging.Filter):  # pragma: no cover
    def filter(self, record):
        if record.args and len(record.args) >= 3:
            if record.args[2] in block_endpoints:  # type: ignore
                return False
        return True


uvicorn_logger = logging.getLogger("uvicorn.access")
uvicorn_logger.addFilter(LogFilter())


@router.get("/app_config")
def get_app_config():
    """Gibt die frontend-relevante App-Konfiguration zurück (öffentlich, kein Auth nötig)."""
    return JSONResponse(
        content=get_frontend_config(),
        headers={"Cache-Control": "public, max-age=300"},
    )


@router.get("/song_histo")
def get_song_histogram(
        db: Session = Depends(auth.get_db),
):
    logger.info("Getting song histogram")
    gigs = db.query(models.Gig).all()

    histogram = {}


    for gig in gigs:
        # GET YEAR FROM GIG
        year = gig.datum.year if hasattr(gig, "datum") and gig.datum else None
        if not year:
            continue
        if year not in histogram:
            histogram[year] = {}

        # GET KIND OF GIG
        kind_of_gig = gig.kind_of_gig if hasattr(gig, "kind_of_gig") and gig.kind_of_gig else "Sonstiges"
        if kind_of_gig not in histogram:
            histogram[year][kind_of_gig] = {}

        for gigset in gig.sets:
            # gigset ist vom Typ GigSet, nicht Set
            if not hasattr(gigset, "set") or not gigset.set:
                print("no set in gigset")
                continue

            set_obj = gigset.set  # Das ist das eigentliche Set-Objekt

            for setsong in set_obj.songs:
                # setsong ist vom Typ SetSong, nicht Song
                song = setsong.song  # Das ist das eigentliche Song-Objekt
                genre = song.genre.strip() if hasattr(song, "genre") and song.genre else "Sonstiges"

                if genre not in histogram[year][kind_of_gig]:
                    histogram[year][kind_of_gig][genre] = 0
                histogram[year][kind_of_gig][genre] += 1

    return histogram

@router.get("/dates")
def get_dates(
        db: Session = Depends(auth.get_db),
):
    logger.info("Getting all dates for public")
    gigs = db.query(models.Gig).where(models.Gig.publish == "1").all()
    return {"data":[schemas.PublicDate.from_gig(gig) for gig in gigs]}




@router.get("/logo")
def get_logo():
    """Gibt das Logo zurück (öffentlich, kein Auth nötig)."""
    for filename in ("LogoCustom.png", "Logo.png"):
        if os.path.isfile(filename):
            return FileResponse(filename, media_type="image/png")
    raise HTTPException(status_code=404, detail="Logo not found")