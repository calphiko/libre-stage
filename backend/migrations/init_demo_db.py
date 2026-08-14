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
init_demo_db.py – Erstellt eine neue Datenbank mit realistischen Demo-Daten.

Usage:
    python backend/migrations/init_demo_db.py
    python backend/migrations/init_demo_db.py backend/db/app.db
"""

import sys
from pathlib import Path
from datetime import date, time, datetime, timedelta, timezone

# Projekt-Root ins Python-Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

import bcrypt
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from backend.models import (
    Base, User, Song, SongCandidateFeedback,
    Rehearsal, RehSong, RehTodo,
    Gig, Set, SetSong, GigSet, GigScheduleItem,
    Surveys, SurveyFields, SurveyFeedback,
    Availability,
)

# ─── DB-Pfad ────────────────────────────────────────────────────────────────

DEFAULT_DB = Path(__file__).parent.parent / "db" / "app.db"
db_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_DB
db_path.parent.mkdir(parents=True, exist_ok=True)

engine = create_engine(
    f"sqlite:///{db_path}",
    connect_args={"check_same_thread": False},
)
Session = sessionmaker(bind=engine)


def hash_pw(plain: str) -> str:
    return bcrypt.hashpw(plain.encode(), bcrypt.gensalt()).decode()


def run():
    reference_date = date.today()
    print(f"→ Erstelle Demo-Datenbank: {db_path}")
    print(f"→ Verwende Referenzdatum: {reference_date.isoformat()}")
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)

    db = Session()

    # ── USERS ────────────────────────────────────────────────────────────────
    # Passwort für alle Demo-User: Demo1234!
    demo_pw = hash_pw("Demo1234!")

    admin = User(
        user_name="admin",
        user_pw=hash_pw("Admin1234!"),
        user_group="admin",
        email="admin@example.com",
        clear_name="Admin User",
        musician=False,
        is_singer=False,
        mm_username="",
        status="active",
    )
    alice = User(
        user_name="alice",
        user_pw=demo_pw,
        user_group="editor",
        email="alice@example.com",
        clear_name="Alice",
        musician=True,
        is_singer=True,
        mm_username="alice",
        status="active",
    )
    bob = User(
        user_name="bob",
        user_pw=demo_pw,
        user_group="editor",
        email="bob@example.com",
        clear_name="Bob",
        musician=True,
        is_singer=True,
        mm_username="bob",
        status="active",
    )
    carol = User(
        user_name="carol",
        user_pw=demo_pw,
        user_group="user",
        email="carol@example.com",
        clear_name="Carol",
        musician=True,
        is_singer=False,
        mm_username="carol",
        status="active",
    )
    dave = User(
        user_name="dave",
        user_pw=demo_pw,
        user_group="user",
        email="dave@example.com",
        clear_name="Dave",
        musician=True,
        is_singer=False,
        mm_username="dave",
        status="active",
    )
    db.add_all([admin, alice, bob, carol, dave])
    db.flush()

    # ── SONGS ────────────────────────────────────────────────────────────────
    songs_data = [
        # (title, interpret, genre, singer_lead, tone_key, duration, brass, status, comment)
        ("Rockin' in the Free World", "Neil Young",      "Rock",    "Alice",       "E",   time(0,4,30), 0, "spielbar",  "Opener"),
        ("Sweet Home Chicago",        "Robert Johnson",  "Rock",    "Bob",         "E",   time(0,3,45), 0, "spielbar",  ""),
        ("Valerie",                   "Amy Winehouse",   "Pop",     "Alice",       "Bb",  time(0,3,52), 0, "spielbar",  ""),
        ("Mr. Brightside",            "The Killers",     "Rock",    "Bob",         "D",   time(0,3,42), 0, "spielbar",  ""),
        ("September",                 "Earth Wind & Fire","Disco",  "Alice+Bob",   "D",   time(0,3,35), 1, "spielbar",  "Bläser!"),
        ("Superstition",              "Stevie Wonder",   "Disco",   "Bob",         "Eb",  time(0,4,10), 1, "spielbar",  ""),
        ("Dancing Queen",             "ABBA",            "Disco",   "Alice",       "A",   time(0,3,51), 0, "spielbar",  ""),
        ("I Will Survive",            "Gloria Gaynor",   "Disco",   "Alice",       "Am",  time(0,3,15), 0, "spielbar",  ""),
        ("Johnny B. Goode",           "Chuck Berry",     "Rock",    "Bob",         "Bb",  time(0,2,42), 0, "spielbar",  "Closer"),
        ("Hotel California",          "Eagles",          "Rock",    "Alice",       "Bm",  time(0,6,30), 0, "spielbar",  "nur wenn Zeit"),
        ("Mustang Sally",             "Wilson Pickett",  "Oldies",  "Bob",         "C",   time(0,3,58), 1, "proben",    ""),
        ("Brown Eyed Girl",           "Van Morrison",    "Oldies",  "Alice",       "G",   time(0,3,5),  0, "proben",    ""),
        ("Proud Mary",                "Creedence",       "Rock",    "Alice+Bob",   "D",   time(0,3,10), 0, "proben",    ""),
        ("Sunny",                     "Bobby Hebb",      "Oldies",  "Bob",         "Am",  time(0,2,48), 0, "proben",    ""),
        ("Stand By Me",               "Ben E. King",     "Oldies",  "Alice",       "A",   time(0,3,0),  0, "angenommen",""),
        ("Rolling in the Deep",       "Adele",           "Pop",     "Alice",       "C",   time(0,3,48), 0, "angenommen",""),
        ("Uptown Funk",               "Bruno Mars",      "Pop",     "Bob",         "Dm",  time(0,4,30), 1, "angenommen","Bläser optional"),
        ("Shallow",                   "Lady Gaga",       "Pop",     "Alice+Bob",   "G",   time(0,3,35), 0, "proben",    "Duett"),
        ("Blinding Lights",           "The Weeknd",      "Pop",     "Bob",         "Fm",  time(0,3,20), 0, "vorschlag", ""),
        ("As It Was",                 "Harry Styles",    "Pop",     "Alice",       "F#m", time(0,2,37), 0, "vorschlag", ""),
    ]

    song_objs = []
    for title, interpret, genre, singer_lead, tone_key, duration, brass, status, comment in songs_data:
        s = Song(
            title=title, interpret=interpret, genre=genre,
            singer_lead=singer_lead, tone_key=tone_key,
            duration=duration, brass=brass,
            status=status, comment=comment,
            ytlink="",
        )
        db.add(s)
        song_objs.append(s)
    db.flush()

    # ── SONG-FEEDBACKS (Kandidaten-Feedback) ─────────────────────────────────
    for song in song_objs[-2:]:  # Die beiden Vorschläge
        for user, fb in [(alice, "a"), (bob, "na"), (carol, "o")]:
            db.add(SongCandidateFeedback(
                song_id=song.id,
                user_id=user.id,
                feedback=fb,
                date=datetime.now(timezone.utc),
            ))

    # ── PROBEN ───────────────────────────────────────────────────────────────
    today = datetime.combine(reference_date, time(19, 0))

    reh1 = Rehearsal(
        begin=today - timedelta(weeks=4),
        end=today - timedelta(weeks=4) + timedelta(hours=3),
        comment="Erste Probe der Saison. Fokus auf neue Songs.",
        ical="",
    )
    reh2 = Rehearsal(
        begin=today - timedelta(weeks=2),
        end=today - timedelta(weeks=2) + timedelta(hours=3),
        comment="Gute Fortschritte bei Proud Mary und Mustang Sally.",
        ical="",
    )
    reh3 = Rehearsal(
        begin=today + timedelta(weeks=1),
        end=today + timedelta(weeks=1) + timedelta(hours=3),
        comment="Vorbereitung auf den Auftritt nächsten Monat.",
        ical="",
    )
    reh4 = Rehearsal(
        begin=today - timedelta(weeks=10),
        end=today - timedelta(weeks=10) + timedelta(hours=3),
        comment="Jahresauftakt: Grobe Songauswahl und Tempofragen geklärt.",
        ical="",
    )
    reh5 = Rehearsal(
        begin=today - timedelta(weeks=8),
        end=today - timedelta(weeks=8) + timedelta(hours=3),
        comment="Detailprobe Bläsersätze, Übergänge zwischen Set 1 und Set 2.",
        ical="",
    )
    reh6 = Rehearsal(
        begin=today - timedelta(weeks=6),
        end=today - timedelta(weeks=6) + timedelta(hours=3),
        comment="Generalproben-Charakter mit Fokus auf Moderation und Endings.",
        ical="",
    )
    db.add_all([reh1, reh2, reh3, reh4, reh5, reh6])
    db.flush()

    # Songs in Proben
    # Probe 1 (vergangen)
    reh1_songs = [
        RehSong(id_rehearsal=reh1.id, id_song=song_objs[10].id,  # Mustang Sally
                comment="Intro noch unsicher", todo="Intro üben", done=False),
        RehSong(id_rehearsal=reh1.id, id_song=song_objs[11].id,  # Brown Eyed Girl
                comment="Läuft gut", todo="", done=True),
        RehSong(id_rehearsal=reh1.id, id_song=song_objs[14].id,  # Stand By Me
                comment="Noch nicht sicher", todo="Nochmal durchgehen", done=False),
    ]
    db.add_all(reh1_songs)
    db.flush()

    # Todos für Probe 1
    db.add(RehTodo(
        id_song=song_objs[10].id, id_reh=reh1.id,
        id_user=bob.id, todo="Intro-Riff 10x täglich üben", done=False,
        dt=reh1.begin,
    ))
    db.add(RehTodo(
        id_song=song_objs[14].id, id_reh=reh1.id,
        id_user=alice.id, todo="Text auswendig lernen", done=True,
        dt=reh1.begin,
    ))

    # Probe 2 (vergangen)
    reh2_songs = [
        RehSong(id_rehearsal=reh2.id, id_song=song_objs[10].id,  # Mustang Sally
                comment="Intro jetzt besser!", todo="", done=True),
        RehSong(id_rehearsal=reh2.id, id_song=song_objs[12].id,  # Proud Mary
                comment="Arrangement noch klären", todo="Arrangement festlegen", done=False),
        RehSong(id_rehearsal=reh2.id, id_song=song_objs[17].id,  # Shallow
                comment="Harmonien üben", todo="Harmonien", done=False),
    ]
    db.add_all(reh2_songs)
    db.flush()

    # Probe 3 (zukünftig)
    reh3_songs = [
        RehSong(id_rehearsal=reh3.id, id_song=song_objs[0].id,   # Rockin' in the Free World
                comment="", todo="Setlist-Opener üben", done=False),
        RehSong(id_rehearsal=reh3.id, id_song=song_objs[12].id,  # Proud Mary
                comment="", todo="Arrangement finalisieren", done=False),
        RehSong(id_rehearsal=reh3.id, id_song=song_objs[4].id,   # September
                comment="", todo="Bläser-Einsätze koordinieren", done=False),
    ]
    db.add_all(reh3_songs)
    db.flush()

    # Probe 4 (vergangen)
    reh4_songs = [
        RehSong(id_rehearsal=reh4.id, id_song=song_objs[1].id,   # Superstition
                comment="Timing in den Strophen schwankt noch", todo="Click mitlaufen lassen", done=False),
        RehSong(id_rehearsal=reh4.id, id_song=song_objs[5].id,   # Black Velvet
                comment="Dynamik im Refrain deutlich verbessert", todo="", done=True),
        RehSong(id_rehearsal=reh4.id, id_song=song_objs[13].id,  # Sunny
                comment="Bridge harmonisch unsauber", todo="Akkordwechsel langsam üben", done=False),
    ]
    db.add_all(reh4_songs)
    db.flush()
    db.add_all([
        RehTodo(
            id_song=song_objs[1].id, id_reh=reh4.id,
            id_user=carol.id, todo="Backbeat im Refrain stabilisieren", done=False,
            dt=reh4.begin,
        ),
        RehTodo(
            id_song=song_objs[13].id, id_reh=reh4.id,
            id_user=bob.id, todo="Bridge in drei Tempi mit Metronom", done=True,
            dt=reh4.begin,
        ),
    ])

    # Probe 5 (vergangen)
    reh5_songs = [
        RehSong(id_rehearsal=reh5.id, id_song=song_objs[2].id,   # Valerie
                comment="Outro-Länge final auf 4 Takte festgelegt", todo="", done=True),
        RehSong(id_rehearsal=reh5.id, id_song=song_objs[4].id,   # September
                comment="Bläsereinsatz in Takt 33 noch unsauber", todo="Cue im Intro klären", done=False),
        RehSong(id_rehearsal=reh5.id, id_song=song_objs[10].id,  # Mustang Sally
                comment="Call-and-response sitzt, aber zweite Strophe zu laut", todo="Lautstärke diszipliniert halten", done=False),
    ]
    db.add_all(reh5_songs)
    db.flush()
    db.add_all([
        RehTodo(
            id_song=song_objs[4].id, id_reh=reh5.id,
            id_user=alice.id, todo="Bläser-Cue vor Takt 33 ansagen", done=False,
            dt=reh5.begin,
        ),
        RehTodo(
            id_song=song_objs[10].id, id_reh=reh5.id,
            id_user=dave.id, todo="2. Strophe leiser spielen", done=False,
            dt=reh5.begin,
        ),
    ])

    # Probe 6 (vergangen)
    reh6_songs = [
        RehSong(id_rehearsal=reh6.id, id_song=song_objs[4].id,   # September
                comment="Break nach Solo sauber, End-Stab sitzt", todo="", done=True),
        RehSong(id_rehearsal=reh6.id, id_song=song_objs[15].id,  # Rolling in the Deep
                comment="Intro-Riff rhythmisch stabil, Solo noch Baustelle", todo="Solo in Phrasen aufteilen", done=False),
        RehSong(id_rehearsal=reh6.id, id_song=song_objs[17].id,  # Shallow
                comment="Duett-Parts harmonisch deutlich besser", todo="Bridge textlich sichern", done=False),
    ]
    db.add_all(reh6_songs)
    db.flush()
    db.add_all([
        RehTodo(
            id_song=song_objs[15].id, id_reh=reh6.id,
            id_user=bob.id, todo="Solo in 3 Abschnitten separat üben", done=False,
            dt=reh6.begin,
        ),
        RehTodo(
            id_song=song_objs[17].id, id_reh=reh6.id,
            id_user=alice.id, todo="Bridge-Text ohne Spickzettel", done=True,
            dt=reh6.begin,
        ),
    ])

    # Zusätzliche Archiv-Proben (vergangen), damit Historie > 20 testbar ist
    extra_past_count = 18
    archive_song_pool = list(range(18))  # keine Vorschlag-Songs
    archive_users = [alice, bob, carol, dave]
    for idx in range(extra_past_count):
        weeks_ago = 12 + idx
        archive_reh = Rehearsal(
            begin=today - timedelta(weeks=weeks_ago),
            end=today - timedelta(weeks=weeks_ago) + timedelta(hours=3),
            comment=f"Archivprobe #{idx + 1}: Schwerpunkt Timing, Übergänge und Bühnenablauf.",
            ical="",
        )
        db.add(archive_reh)
        db.flush()

        i1 = archive_song_pool[idx % len(archive_song_pool)]
        i2 = archive_song_pool[(idx + 5) % len(archive_song_pool)]
        i3 = archive_song_pool[(idx + 9) % len(archive_song_pool)]

        db.add_all([
            RehSong(
                id_rehearsal=archive_reh.id,
                id_song=song_objs[i1].id,
                comment=f"Archiv-Notiz A{idx + 1}: Intro und Groove prüfen",
                todo="Einstieg sauber zählen",
                done=(idx % 2 == 0),
            ),
            RehSong(
                id_rehearsal=archive_reh.id,
                id_song=song_objs[i2].id,
                comment=f"Archiv-Notiz B{idx + 1}: Dynamik im Refrain",
                todo="Refrain leiser anfahren",
                done=(idx % 3 == 0),
            ),
            RehSong(
                id_rehearsal=archive_reh.id,
                id_song=song_objs[i3].id,
                comment=f"Archiv-Notiz C{idx + 1}: Ending eindeutig festlegen",
                todo="Ending gemeinsam stoppen",
                done=False,
            ),
        ])

        db.add(RehTodo(
            id_song=song_objs[i2].id,
            id_reh=archive_reh.id,
            id_user=archive_users[idx % len(archive_users)].id,
            todo=f"Archiv-Todo #{idx + 1}: Übergang zwischen Strophe und Refrain festigen",
            done=(idx % 4 == 0),
            dt=archive_reh.begin,
        ))

    # ── SETS & GIGS ──────────────────────────────────────────────────────────
    def make_set(name, setlist_name, pause_min, song_indices):
        s = Set(
            name=name,
            setlist_name=setlist_name,
            pause=time(0, pause_min, 0),
        )
        db.add(s)
        db.flush()
        for pos, idx in enumerate(song_indices, start=1):
            db.add(SetSong(
                id_set=s.id,
                id_song=song_objs[idx].id,
                position=pos,
            ))
        db.flush()
        return s

    # Gig 1 – vergangener Gig mit Live-Mode Daten
    set1a = make_set("Set 1 – Stadtfest",   "1. Set",  20, [0, 3, 6, 2, 8])   # 5 Songs
    set1b = make_set("Set 2 – Stadtfest",   "2. Set",  15, [1, 5, 7, 4, 9])   # 5 Songs

    # Live-Mode Feedback auf vergangenen Gig setzen
    live_feedbacks = [(3, False, False), (2, False, False), (3, False, False),
                      (2, False, False), (3, False, False)]
    set1a_songs = db.query(SetSong).filter(SetSong.id_set == set1a.id).order_by(SetSong.position).all()
    for ss, (fb, ueber, ein) in zip(set1a_songs, live_feedbacks):
        ss.feedback = fb
        ss.uebersprungen = ueber
        ss.eingeschoben = ein
    # Einen Song überspringen
    set1b_songs = db.query(SetSong).filter(SetSong.id_set == set1b.id).order_by(SetSong.position).all()
    set1b_songs[1].uebersprungen = True   # Superstition übersprungen
    set1b_songs[2].feedback = 2
    set1b_songs[3].feedback = 3
    set1b_songs[4].feedback = 3

    gig1_date = reference_date - timedelta(days=30)
    gig1 = Gig(
        name="Stadtfest Musterstadt",
        datum=gig1_date,
        organizer="Stadtmarketing GmbH",
        kind_of_gig="Stadtfest",
        venue="Marktplatz Musterstadt",
        doors=time(17, 0),
        begin=time(18, 0),
        end=time(22, 0),
        status="angenommen",
        publish="1",
    )
    db.add(gig1)
    db.flush()
    db.add(GigSet(id_gig=gig1.id, id_set=set1a.id, position=1))
    db.add(GigSet(id_gig=gig1.id, id_set=set1b.id, position=2))
    db.flush()

    # Gig 2 – zukünftiger Gig
    set2a = make_set("Set 1 – Clubabend", "1. Set", 20, [0, 2, 6, 3, 4])
    set2b = make_set("Set 2 – Clubabend", "2. Set", 15, [1, 7, 5, 8, 9])
    set2c = make_set("Set 3 – Clubabend", "3. Set",  0, [11, 12, 13])

    gig2_date = reference_date + timedelta(days=14)
    gig2 = Gig(
        name="Clubabend im Blue Note",
        datum=gig2_date,
        organizer="Blue Note Club",
        kind_of_gig="Privatveranstaltung",
        venue="Blue Note Club, Hauptstraße 42",
        doors=time(19, 30),
        begin=time(20, 30),
        end=time(1, 30),
        status="angenommen",
        publish="0",
    )
    db.add(gig2)
    db.flush()
    db.add(GigSet(id_gig=gig2.id, id_set=set2a.id, position=1))
    db.add(GigSet(id_gig=gig2.id, id_set=set2b.id, position=2))
    db.add(GigSet(id_gig=gig2.id, id_set=set2c.id, position=3))
    db.flush()

    # Gig 3 – Anfrage (noch offen)
    gig3_date = reference_date + timedelta(days=60)
    gig3 = Gig(
        name="Sommerfest Musterfirma AG",
        datum=gig3_date,
        organizer="Musterfirma AG",
        kind_of_gig="Privatveranstaltung",
        venue="Firmencampus, Industriestraße 1",
        doors=time(16, 0),
        begin=time(17, 0),
        end=time(21, 0),
        status="anfrage",
        publish="0",
    )
    db.add(gig3)
    db.flush()

    # Zusätzliche Ablaufplan-Einträge (naive UTC datetimes, kollisionsfrei zu doors/begin/end)
    db.add_all([
        GigScheduleItem(
            gig_id=gig1.id,
            item_datetime=datetime.combine(gig1_date - timedelta(days=1), time(16, 0)),
            was="Aufbau",
            wer="Band + Technik",
            wo="Buehne",
        ),
        GigScheduleItem(
            gig_id=gig1.id,
            item_datetime=datetime.combine(gig1_date, time(15, 30)),
            was="Anfahrt",
            wer="Alle",
            wo="Treffpunkt Proberaum",
        ),
        GigScheduleItem(
            gig_id=gig1.id,
            item_datetime=datetime.combine(gig1_date, time(17, 30)),
            was="Soundcheck",
            wer="Band",
            wo="Buehne",
        ),
        GigScheduleItem(
            gig_id=gig1.id,
            item_datetime=datetime.combine(gig1_date, time(22, 30)),
            was="Abbau",
            wer="Band + Technik",
            wo="Buehne",
        ),
        GigScheduleItem(
            gig_id=gig2.id,
            item_datetime=datetime.combine(gig2_date - timedelta(days=1), time(20, 0)),
            was="Material checken",
            wer="Backline Team",
            wo="Proberaum",
        ),
        GigScheduleItem(
            gig_id=gig2.id,
            item_datetime=datetime.combine(gig2_date, time(18, 45)),
            was="Load in",
            wer="Band",
            wo="Seiteneingang",
        ),
        GigScheduleItem(
            gig_id=gig2.id,
            item_datetime=datetime.combine(gig2_date, time(20, 0)),
            was="Soundcheck",
            wer="Band",
            wo="Buehne",
        ),
        GigScheduleItem(
            gig_id=gig2.id,
            item_datetime=datetime.combine(gig2_date, time(23, 45)),
            was="Abbau",
            wer="Band + Club Crew",
            wo="Club",
        ),
        GigScheduleItem(
            gig_id=gig3.id,
            item_datetime=datetime.combine(gig3_date - timedelta(days=1), time(19, 0)),
            was="Generalprobe",
            wer="Band",
            wo="Proberaum",
        ),
        GigScheduleItem(
            gig_id=gig3.id,
            item_datetime=datetime.combine(gig3_date, time(15, 0)),
            was="Aufbau",
            wer="Band",
            wo="Firmencampus",
        ),
        GigScheduleItem(
            gig_id=gig3.id,
            item_datetime=datetime.combine(gig3_date, time(16, 30)),
            was="Soundcheck",
            wer="Band",
            wo="Buehne",
        ),
        GigScheduleItem(
            gig_id=gig3.id,
            item_datetime=datetime.combine(gig3_date, time(21, 30)),
            was="Abbau",
            wer="Band",
            wo="Buehne",
        ),
    ])

    # ── UMFRAGEN ─────────────────────────────────────────────────────────────
    survey = Surveys(
        kind_of_survey="Meinungsumfrage",
        rf_survey="Welche neuen Songs sollen wir ins Repertoire aufnehmen?",
        released=True,
        closed=False,
        user_created=admin.id,
        release_date=datetime.now(timezone.utc),
        datum=datetime.now(timezone.utc),
    )
    db.add(survey)
    db.flush()

    for song_title in ["Blinding Lights", "As It Was"]:
        db.add(SurveyFields(id_survey=survey.id, field_text=song_title))
    db.flush()

    fields = db.query(SurveyFields).filter(SurveyFields.id_survey == survey.id).all()
    votes = [
        (fields[0], alice, "ja",        "Super Song!"),
        (fields[0], bob,   "ja",        ""),
        (fields[0], carol, "vielleicht","Kenne ich nicht so gut"),
        (fields[1], alice, "ja",        ""),
        (fields[1], bob,   "nein",      "Nicht unser Stil"),
        (fields[1], carol, "ja",        "Toller Song"),
    ]
    for field, user, value, comment in votes:
        db.add(SurveyFeedback(
            id_sv_field=field.id,
            id_user=user.id,
            datum=datetime.now(timezone.utc),
            value=value,
            comment=comment,
        ))

    # Terminfindungs-Umfrage mit Datumsoptionen
    date_survey = Surveys(
        kind_of_survey="Terminfindung",
        rf_survey="Wann passt euch die Zusatzprobe fuer den Clubabend?",
        released=True,
        closed=False,
        user_created=admin.id,
        release_date=datetime.now(timezone.utc),
        datum=datetime.now(timezone.utc),
    )
    db.add(date_survey)
    db.flush()

    date_options = [
        datetime.combine(reference_date + timedelta(days=5), time(19, 30), tzinfo=timezone.utc),
        datetime.combine(reference_date + timedelta(days=7), time(19, 30), tzinfo=timezone.utc),
        datetime.combine(reference_date + timedelta(days=10), time(19, 30), tzinfo=timezone.utc),
    ]
    for option in date_options:
        db.add(SurveyFields(id_survey=date_survey.id, field_text=option.isoformat()))
    db.flush()

    date_fields = db.query(SurveyFields).filter(SurveyFields.id_survey == date_survey.id).all()
    date_votes = [
        (date_fields[0], alice, "a"),
        (date_fields[0], bob, "m"),
        (date_fields[0], carol, "a"),
        (date_fields[1], alice, "m"),
        (date_fields[1], bob, "a"),
        (date_fields[1], dave, "o"),
        (date_fields[2], carol, "o"),
        (date_fields[2], dave, "a"),
    ]
    for field, user, value in date_votes:
        db.add(SurveyFeedback(
            id_sv_field=field.id,
            id_user=user.id,
            datum=datetime.now(timezone.utc),
            value=value,
            comment=None,
        ))

    # ── AVAILABILITY ─────────────────────────────────────────────────────────
    # Vergangener Gig (gig1): alle dabei gewesen – rückblickende Einträge
    db.add_all([
        Availability(user_id=alice.id, event_type="gig", event_id=gig1.id,
                     status="available", comment="War ein toller Abend!"),
        Availability(user_id=bob.id,   event_type="gig", event_id=gig1.id,
                     status="available"),
        Availability(user_id=carol.id, event_type="gig", event_id=gig1.id,
                     status="available"),
        Availability(user_id=dave.id,  event_type="gig", event_id=gig1.id,
                     status="available"),
    ])

    # Zukünftiger Gig (gig2): gemischte Rückmeldungen
    db.add_all([
        Availability(user_id=alice.id, event_type="gig", event_id=gig2.id,
                     status="available"),
        Availability(user_id=bob.id,   event_type="gig", event_id=gig2.id,
                     status="available"),
        Availability(user_id=carol.id, event_type="gig", event_id=gig2.id,
                     status="unavailable",
                     comment="Bin leider verhindert.",
                     substitute_name="Klaus Müller"),   # externe Aushilfe
        # Dave hat noch nicht geantwortet → kein Eintrag
    ])

    # Zukünftiger Gig (gig3, Anfrage): erste Reaktionen
    db.add_all([
        Availability(user_id=alice.id, event_type="gig", event_id=gig3.id,
                     status="maybe", comment="Hängt vom Termin ab."),
        Availability(user_id=bob.id,   event_type="gig", event_id=gig3.id,
                     status="available"),
        # Carol und Dave noch ohne Rückmeldung
    ])

    # Zukünftige Probe (reh3): Verfügbarkeiten
    db.add_all([
        Availability(user_id=alice.id, event_type="rehearsal", event_id=reh3.id,
                     status="available"),
        Availability(user_id=bob.id,   event_type="rehearsal", event_id=reh3.id,
                     status="available"),
        Availability(user_id=carol.id, event_type="rehearsal", event_id=reh3.id,
                     status="unavailable",
                     substitute_user_id=dave.id),  # Dave springt ein
        Availability(user_id=dave.id,  event_type="rehearsal", event_id=reh3.id,
                     status="maybe", comment="Wahrscheinlich, aber nicht sicher."),
    ])

    db.commit()
    db.close()

    print(f"\n✅ Demo-Datenbank erfolgreich erstellt: {db_path}")
    print(f"\n👤 Demo-Accounts:")
    print(f"   admin  / Admin1234!  (Rolle: admin)")
    print(f"   alice  / Demo1234!   (Rolle: editor, Sängerin)")
    print(f"   bob    / Demo1234!   (Rolle: editor, Sänger)")
    print(f"   carol  / Demo1234!   (Rolle: user, Musikerin)")
    print(f"   dave   / Demo1234!   (Rolle: user, Musiker)")
    print(f"\n🎵 {len(song_objs)} Songs, {6 + extra_past_count} Proben, 3 Gigs, 2 Umfragen angelegt.")
    print(f"📅 Availability-Einträge: Gig1 (4×✅), Gig2 (2×✅ 1×❌), Gig3 (1×✅ 1×❓), Probe3 (2×✅ 1×❌ 1×❓)")


if __name__ == "__main__":
    run()
