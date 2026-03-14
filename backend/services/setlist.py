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

# services/setlist.py
"""
Setlist service.

Provides :class:`SetlistService` which encapsulates all business logic
for loading a gig with its full set/song structure and calculating the
expected start time for each song based on the gig start time, song
durations and set-break durations.
"""

from datetime import datetime, timedelta
from collections import defaultdict
from sqlalchemy.orm import Session, joinedload
from ..database import get_db
from ..models import Gig, GigSet, Set, SetSong
import colorsys

class SetlistService:
    """
    Business-logic service for setlist operations.

    Args:
        session (Session): An active SQLAlchemy database session.
    """

    DEFAULT_BREAK = 35  # Sekunden

    def __init__(self, session: Session) -> None:
        self.session = session

    def load_gig(self, gig_id: int) -> Gig:
        """
        Load a :class:`~backend.models.Gig` with all related sets and songs
        eagerly loaded in a single query.

        Args:
            gig_id (int): Primary key of the gig to load.

        Returns:
            Gig | None: The gig object with all relationships populated,
            or ``None`` if not found.
        """
        return (
        self.session.query(Gig)
        .options(
            joinedload(Gig.sets)
                .joinedload(GigSet.set)
                .joinedload(Set.songs)
                .joinedload(SetSong.song)
        )
        .get(gig_id)
    )

    def calc_schedule(self, gig: Gig) -> dict[int, list[datetime]]:
        """
        Calculate the expected start time for every song in every set of
        the gig.

        The calculation walks the sets in their :attr:`GigSet.position`
        order, accumulates song durations (defaulting to 4 minutes when
        unknown) plus a short inter-song gap of ``DEFAULT_BREAK`` seconds,
        and then adds the full set-break duration between sets.

        Args:
            gig (Gig): A fully-loaded gig object (use :meth:`load_gig`).

        Returns:
            dict[int, list[datetime]]: A mapping of
            ``{set_position: [song_start_datetime, ...]}``.
        """
        from collections import defaultdict
        from datetime import datetime, timedelta, time

        DEFAULT_BREAK = 30  # Sekunden

        # Startzeit-Basis für den Gig
        gig_start = datetime.combine(
            gig.datum,
            gig.begin or time(19, 0)
        )  # ggf. Fallback 19:00
        schedule = defaultdict(list)
        current_time = gig_start

        # Gehe über die Sets in Auftrittsreihenfolge!
        for gs in sorted(gig.sets, key=lambda s: s.position):
            set_obj = gs.set  # Das eigentliche Set

            # Songs innerhalb des Sets in Setlist-Reihenfolge!
            for setsong in sorted(set_obj.songs, key=lambda ss: ss.position):
                # Aktuelle Zeit als Start für diesen Song merken
                schedule[gs.position].append(current_time)

                # Dauer ermitteln
                raw_dur = setsong.song.duration
                if raw_dur:
                    # raw_dur ist normalerweise ein time-Objekt – in timedelta umrechnen:
                    duration = timedelta(
                        hours=raw_dur.hour if hasattr(raw_dur, "hour") else 0,
                        minutes=raw_dur.minute if hasattr(raw_dur, "minute") else 0,
                        seconds=raw_dur.second if hasattr(raw_dur, "second") else 0
                    )
                else:
                    duration = timedelta(minutes=4)

                # Zeit weiterschieben: Song-Dauer + kurze Pause zum nächsten Song
                current_time = current_time + duration + timedelta(seconds=DEFAULT_BREAK)

            # Jetzt steht current_time NACH dem letzten Song + DEFAULT_BREAK
            # Das ist die Zeit, zu der die Set-Pause beginnt

            # Pause nach Set
            pause = set_obj.pause or timedelta(minutes=10)
            if isinstance(pause, time):
                pause = timedelta(
                    hours=pause.hour, minutes=pause.minute, seconds=pause.second)

            # Addiere die Set-Pause zur aktuellen Zeit
            current_time = current_time + pause

        return schedule

    def dump_gig_struct(self, gig, schedule=None):
        """
        Print a human-readable, Markdown-style overview of the gig
        structure including live-mode annotations to stdout.

        Args:
            gig: A fully-loaded gig object.
            schedule (dict | None): Optional schedule dict as returned by
                :meth:`calc_schedule`.  If supplied, song start times are
                printed next to each song.
        """
        print(f"\n=== Gig {gig.id}: {gig.name} am {gig.datum} ===\n")
        print(f"  Beginn: {gig.begin}")
        for gigset in sorted(gig.sets, key=lambda x: x.position):
            set_obj = gigset.set
            print(f"  -> Set {gigset.position}: {set_obj.setlist_name or set_obj.id} Id: {set_obj.id} (Pause: {set_obj.pause})")

            setsonglist = sorted(set_obj.songs, key=lambda ss: ss.position)
            for idx, setsong in enumerate(setsonglist, start=1):
                song = setsong.song
                zeit_str = (
                    schedule[gigset.position][idx - 1].strftime('%H:%M')
                    if schedule and gigset.position in schedule and idx - 1 < len(schedule[gigset.position])
                    else "-"
                )

                # Markierungen für Live-Mode-Status
                prefix = ""
                suffix = ""

                if setsong.uebersprungen:
                    # Übersprungene Songs durchstreichen
                    prefix = "~~"
                    suffix = "~~"
                elif setsong.eingeschoben:
                    # Eingeschobene Songs markieren
                    prefix = "[NEU] "

                # Feedback-Symbol hinzufügen
                feedback_symbol = ""
                if setsong.feedback == 1:
                    feedback_symbol = " [o]"
                elif setsong.feedback == 2:
                    feedback_symbol = " [+]"
                elif setsong.feedback == 3:
                    feedback_symbol = " [++]"

                print(f"     [{zeit_str}] {prefix}{setsong.position}. {song.title} / {song.singer_lead} / {song.duration}{suffix}{feedback_symbol}")
