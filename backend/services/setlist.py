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

from datetime import datetime
from sqlalchemy.orm import Session, joinedload
from ..models import Gig, GigSet, Set, SetSong
from ..utils.setlist_timing import calculate_setlist_timing

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
        timing = calculate_setlist_timing(gig)
        return timing["schedule"]

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
