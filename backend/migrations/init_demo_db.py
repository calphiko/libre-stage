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
import os
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
    Gig, Set, SetSong, GigSet,
    Surveys, SurveyFields, SurveyFeedback,
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
    print(f"→ Erstelle Demo-Datenbank: {db_path}")
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
        for user, fb in [(alice, "ja"), (bob, "vielleicht"), (carol, "ja")]:
            db.add(SongCandidateFeedback(
                song_id=song.id,
                user_id=user.id,
                feedback=fb,
                date=datetime.now(timezone.utc),
            ))

    # ── PROBEN ───────────────────────────────────────────────────────────────
    today = datetime.now().replace(hour=19, minute=0, second=0, microsecond=0)

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
    db.add_all([reh1, reh2, reh3])
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

    gig1 = Gig(
        name="Stadtfest Musterstadt",
        datum=date.today() - timedelta(days=30),
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

    gig2 = Gig(
        name="Clubabend im Blue Note",
        datum=date.today() + timedelta(days=14),
        organizer="Blue Note Club",
        kind_of_gig="Privatveranstaltung",
        venue="Blue Note Club, Hauptstraße 42",
        doors=time(19, 30),
        begin=time(20, 30),
        end=time(23, 30),
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
    gig3 = Gig(
        name="Sommerfest Musterfirma AG",
        datum=date.today() + timedelta(days=60),
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

    # ── UMFRAGE ──────────────────────────────────────────────────────────────
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

    db.commit()
    db.close()

    print(f"\n✅ Demo-Datenbank erfolgreich erstellt: {db_path}")
    print(f"\n👤 Demo-Accounts:")
    print(f"   admin  / Admin1234!  (Rolle: admin)")
    print(f"   alice  / Demo1234!   (Rolle: editor, Sängerin)")
    print(f"   bob    / Demo1234!   (Rolle: editor, Sänger)")
    print(f"   carol  / Demo1234!   (Rolle: user, Musikerin)")
    print(f"   dave   / Demo1234!   (Rolle: user, Musiker)")
    print(f"\n🎵 {len(song_objs)} Songs, 3 Proben, 3 Gigs, 1 Umfrage angelegt.")


if __name__ == "__main__":
    run()

