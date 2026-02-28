# services/setlist.py
from datetime import datetime, timedelta
from collections import defaultdict
from sqlalchemy.orm import Session, joinedload
from ..database import get_db
from ..models import Gig, GigSet, Set, SetSong
import colorsys

class SetlistService:
    DEFAULT_BREAK = 35  # Sekunden

    def __init__(self, session: Session) -> None:
        self.session = session

    def load_gig(self, gig_id: int) -> Gig:
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
        Für jeden Set (am Gig) berechne die Startzeit jedes Songs im Set.
        Liefert: {position_des_sets_im_gig: [datetime, ...]}
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
