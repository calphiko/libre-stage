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

import pytest
import uuid
from unittest.mock import patch, MagicMock
from datetime import date, time, datetime, timedelta, timezone
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from backend.main import app, limiter
from backend.models import (
    Base, User, Song, SongCandidateFeedback,
    Rehearsal, RehSong, RehTodo,
    Gig, Set, SetSong, GigSet,
    Surveys, SurveyFields, SurveyFeedback,
)
from backend import auth, models
from backend.database import get_db

from pprint import pprint

# Use in-memory SQLite for testing
SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(autouse=True)
def mock_mattermost(monkeypatch):
    """
    Mock requests.post in the mattermost module so no real HTTP calls
    are made during tests. The fixture is automatically used by every test.
    The returned MagicMock can be requested by name to assert call details.

    Example::

        def test_something(client, auth_headers, mock_mattermost):
            client.post(...)
            assert mock_mattermost.call_count == 1
            assert "Songvorschlag" in mock_mattermost.call_args.kwargs["json"]["text"]
    """
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.raise_for_status = MagicMock()

    with patch("backend.utils.mattermost.requests.post", return_value=mock_response) as mock_post:
        yield mock_post


@pytest.fixture(scope="function")
def db_session():
    """Create a fresh database for each test."""
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(db_session):
    """Create a test client with database dependency override."""

    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    # Each test gets a unique "IP" so rate limit counters never bleed between tests
    test_id = str(uuid.uuid4())
    original_key_func = limiter._key_func
    limiter._key_func = lambda request: test_id

    # Override both get_db functions
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[auth.get_db] = override_get_db

    try:
        with TestClient(app) as test_client:
            yield test_client
    finally:
        app.dependency_overrides.clear()
        limiter._key_func = original_key_func


@pytest.fixture
def test_user(db_session):
    """Create a test user."""
    user = models.User(
        user_name="testuser",
        user_pw=auth.hash_pw("testpassword123"),
        user_group="admin",
        musician=True,
        is_singer=False,
        clear_name="Test User",
        email="test@example.com",
        status="active"
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    pprint(user.id)

    return user

@pytest.fixture
def test_user2(db_session):
    """Create a second test user."""
    user = models.User(
        user_name="testuser2",
        user_pw=auth.hash_pw("testpassword456"),
        user_group="user",
        musician=True,
        clear_name="Test User 2",
        email="testuser2@example.com",
        status="active"
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user

@pytest.fixture
def auth_token(test_user):
    """Generate authentication token for test user."""
    # Use the same SECRET_KEY and ALGORITHM from auth.py
    return auth.create_access_token({
        "sub": test_user.user_name,
        "role": test_user.user_group
    })


@pytest.fixture
def auth_headers(auth_token):
    """Create authorization headers."""
    return {"Authorization": f"Bearer {auth_token}"}


@pytest.fixture
def auth_token2(test_user2):
    """Generate authentication token for test user."""
    # Use the same SECRET_KEY and ALGORITHM from auth.py
    return auth.create_access_token({
        "sub": test_user2.user_name,
        "role": test_user2.user_group
    })


@pytest.fixture
def auth_headers2(auth_token2):
    """Create authorization headers."""
    return {"Authorization": f"Bearer {auth_token2}"}

@pytest.fixture
def wrong_auth_header():
    wrong_token = auth.create_access_token(
        {
            "sub": "Franz2",
            "role": "admin"
        }
    )
    return {"Authorization": f"Bearer {wrong_token}"}


# ---------------------------------------------------------------------------
# Season-Data helpers
# ---------------------------------------------------------------------------

def create_season_data(db) -> dict:
    """
    Legt einen vollständigen Saison-Datensatz in der übergebenen DB-Session an.
    Entspricht strukturell dem init_demo_db.py Demo-Datensatz, arbeitet aber
    mit der In-Memory-Test-DB.

    Returns:
        dict mit allen angelegten Objekten (users, songs, rehearsals, gigs,
        survey) für direkten Zugriff in Tests.
    """
    demo_pw = auth.hash_pw("Demo1234!")

    admin = User(
        user_name="season_admin", user_pw=auth.hash_pw("Admin1234!"),
        user_group="admin", email="admin@season.test",
        clear_name="Season Admin", musician=False, is_singer=False,
        mm_username="", status="active",
    )
    alice = User(
        user_name="season_alice", user_pw=demo_pw,
        user_group="editor", email="alice@season.test",
        clear_name="Alice", musician=True, is_singer=True,
        mm_username="alice_mm", status="active",
    )
    bob = User(
        user_name="season_bob", user_pw=demo_pw,
        user_group="editor", email="bob@season.test",
        clear_name="Bob", musician=True, is_singer=True,
        mm_username="bob_mm", status="active",
    )
    carol = User(
        user_name="season_carol", user_pw=demo_pw,
        user_group="user", email="carol@season.test",
        clear_name="Carol", musician=True, is_singer=False,
        mm_username="carol_mm", status="active",
    )
    dave = User(
        user_name="season_dave", user_pw=demo_pw,
        user_group="user", email="dave@season.test",
        clear_name="Dave", musician=True, is_singer=False,
        mm_username="dave_mm", status="active",
    )
    db.add_all([admin, alice, bob, carol, dave])
    db.flush()

    songs_data = [
        # (title, interpret, genre, singer_lead, tone_key, duration, brass, status, comment)
        ("Rockin' in the Free World", "Neil Young",        "Rock",   "Alice",     "E",   time(0, 4, 30), 0, "spielbar",   "Opener"),
        ("Sweet Home Chicago",        "Robert Johnson",    "Rock",   "Bob",       "E",   time(0, 3, 45), 0, "spielbar",   ""),
        ("Valerie",                   "Amy Winehouse",     "Pop",    "Alice",     "Bb",  time(0, 3, 52), 0, "spielbar",   ""),
        ("Mr. Brightside",            "The Killers",       "Rock",   "Bob",       "D",   time(0, 3, 42), 0, "spielbar",   ""),
        ("September",                 "Earth Wind & Fire", "Disco",  "Alice+Bob", "D",   time(0, 3, 35), 1, "spielbar",   "Bläser!"),
        ("Superstition",              "Stevie Wonder",     "Disco",  "Bob",       "Eb",  time(0, 4, 10), 1, "spielbar",   ""),
        ("Dancing Queen",             "ABBA",              "Disco",  "Alice",     "A",   time(0, 3, 51), 0, "spielbar",   ""),
        ("I Will Survive",            "Gloria Gaynor",     "Disco",  "Alice",     "Am",  time(0, 3, 15), 0, "spielbar",   ""),
        ("Johnny B. Goode",           "Chuck Berry",       "Rock",   "Bob",       "Bb",  time(0, 2, 42), 0, "spielbar",   "Closer"),
        ("Hotel California",          "Eagles",            "Rock",   "Alice",     "Bm",  time(0, 6, 30), 0, "spielbar",   "nur wenn Zeit"),
        ("Mustang Sally",             "Wilson Pickett",    "Oldies", "Bob",       "C",   time(0, 3, 58), 1, "proben",     ""),
        ("Brown Eyed Girl",           "Van Morrison",      "Oldies", "Alice",     "G",   time(0, 3,  5), 0, "proben",     ""),
        ("Proud Mary",                "Creedence",         "Rock",   "Alice+Bob", "D",   time(0, 3, 10), 0, "proben",     ""),
        ("Sunny",                     "Bobby Hebb",        "Oldies", "Bob",       "Am",  time(0, 2, 48), 0, "proben",     ""),
        ("Stand By Me",               "Ben E. King",       "Oldies", "Alice",     "A",   time(0, 3,  0), 0, "angenommen", ""),
        ("Rolling in the Deep",       "Adele",             "Pop",    "Alice",     "C",   time(0, 3, 48), 0, "angenommen", ""),
        ("Uptown Funk",               "Bruno Mars",        "Pop",    "Bob",       "Dm",  time(0, 4, 30), 1, "angenommen", "Bläser optional"),
        ("Shallow",                   "Lady Gaga",         "Pop",    "Alice+Bob", "G",   time(0, 3, 35), 0, "proben",     "Duett"),
        ("Blinding Lights",           "The Weeknd",        "Pop",    "Bob",       "Fm",  time(0, 3, 20), 0, "vorschlag",  ""),
        ("As It Was",                 "Harry Styles",      "Pop",    "Alice",     "F#m", time(0, 2, 37), 0, "vorschlag",  ""),
    ]

    song_objs = []
    for title, interpret, genre, singer_lead, tone_key, duration, brass, status, comment in songs_data:
        s = Song(
            title=title, interpret=interpret, genre=genre,
            singer_lead=singer_lead, tone_key=tone_key,
            duration=duration, brass=brass,
            status=status, comment=comment, ytlink="",
        )
        db.add(s)
        song_objs.append(s)
    db.flush()

    # Song-Kandidaten-Feedbacks
    for song in song_objs[-2:]:
        for user, fb in [(alice, "ja"), (bob, "vielleicht"), (carol, "ja")]:
            db.add(SongCandidateFeedback(
                song_id=song.id, user_id=user.id,
                feedback=fb, date=datetime.now(timezone.utc),
            ))

    # Proben
    today = datetime.now().replace(hour=19, minute=0, second=0, microsecond=0)
    reh1 = Rehearsal(
        begin=today - timedelta(weeks=4),
        end=today - timedelta(weeks=4) + timedelta(hours=3),
        comment="Erste Probe der Saison. Fokus auf neue Songs.", ical="",
    )
    reh2 = Rehearsal(
        begin=today - timedelta(weeks=2),
        end=today - timedelta(weeks=2) + timedelta(hours=3),
        comment="Gute Fortschritte bei Proud Mary und Mustang Sally.", ical="",
    )
    reh3 = Rehearsal(
        begin=today + timedelta(weeks=1),
        end=today + timedelta(weeks=1) + timedelta(hours=3),
        comment="Vorbereitung auf den Auftritt nächsten Monat.", ical="",
    )
    db.add_all([reh1, reh2, reh3])
    db.flush()

    # Probe 1 – vergangen
    db.add_all([
        RehSong(id_rehearsal=reh1.id, id_song=song_objs[10].id,
                comment="Intro noch unsicher", todo="Intro üben", done=False),
        RehSong(id_rehearsal=reh1.id, id_song=song_objs[11].id,
                comment="Läuft gut", todo="", done=True),
        RehSong(id_rehearsal=reh1.id, id_song=song_objs[14].id,
                comment="Noch nicht sicher", todo="Nochmal durchgehen", done=False),
    ])
    db.flush()
    db.add_all([
        RehTodo(id_song=song_objs[10].id, id_reh=reh1.id, id_user=bob.id,
                todo="Intro-Riff 10x täglich üben", done=False, dt=reh1.begin),
        RehTodo(id_song=song_objs[14].id, id_reh=reh1.id, id_user=alice.id,
                todo="Text auswendig lernen", done=True, dt=reh1.begin),
    ])

    # Probe 2 – vergangen
    db.add_all([
        RehSong(id_rehearsal=reh2.id, id_song=song_objs[10].id,
                comment="Intro jetzt besser!", todo="", done=True),
        RehSong(id_rehearsal=reh2.id, id_song=song_objs[12].id,
                comment="Arrangement noch klären", todo="Arrangement festlegen", done=False),
        RehSong(id_rehearsal=reh2.id, id_song=song_objs[17].id,
                comment="Harmonien üben", todo="Harmonien", done=False),
    ])

    # Probe 3 – zukünftig
    db.add_all([
        RehSong(id_rehearsal=reh3.id, id_song=song_objs[0].id,
                comment="", todo="Setlist-Opener üben", done=False),
        RehSong(id_rehearsal=reh3.id, id_song=song_objs[12].id,
                comment="", todo="Arrangement finalisieren", done=False),
        RehSong(id_rehearsal=reh3.id, id_song=song_objs[4].id,
                comment="", todo="Bläser-Einsätze koordinieren", done=False),
    ])
    db.flush()

    # Sets & Gigs
    def make_set(name, setlist_name, pause_min, song_indices):
        s = Set(name=name, setlist_name=setlist_name, pause=time(0, pause_min, 0))
        db.add(s)
        db.flush()
        for pos, idx in enumerate(song_indices, start=1):
            db.add(SetSong(id_set=s.id, id_song=song_objs[idx].id, position=pos))
        db.flush()
        return s

    # Gig 1 – vergangener Gig mit Live-Mode-Daten
    set1a = make_set("Set 1 – Stadtfest", "1. Set", 20, [0, 3, 6, 2, 8])
    set1b = make_set("Set 2 – Stadtfest", "2. Set", 15, [1, 5, 7, 4, 9])

    for ss, (fb, ueber, ein) in zip(
        db.query(SetSong).filter(SetSong.id_set == set1a.id).order_by(SetSong.position).all(),
        [(3, False, False), (2, False, False), (3, False, False), (2, False, False), (3, False, False)],
    ):
        ss.feedback, ss.uebersprungen, ss.eingeschoben = fb, ueber, ein

    set1b_songs = db.query(SetSong).filter(SetSong.id_set == set1b.id).order_by(SetSong.position).all()
    set1b_songs[1].uebersprungen = True
    set1b_songs[2].feedback = 2
    set1b_songs[3].feedback = 3
    set1b_songs[4].eingeschoben = True

    gig1 = Gig(
        name="Stadtfest Musterstadt",
        datum=date.today() - timedelta(days=30),
        organizer="Stadtmarketing GmbH", kind_of_gig="Stadtfest",
        venue="Marktplatz Musterstadt",
        doors=time(17, 0), begin=time(18, 0), end=time(22, 0),
        status="angenommen", publish="1",
    )
    db.add(gig1)
    db.flush()
    db.add_all([
        GigSet(id_gig=gig1.id, id_set=set1a.id, position=1),
        GigSet(id_gig=gig1.id, id_set=set1b.id, position=2),
    ])

    # Gig 2 – zukünftiger Gig
    set2a = make_set("Set 1 – Clubabend", "1. Set", 20, [0, 2, 6, 3, 4])
    set2b = make_set("Set 2 – Clubabend", "2. Set", 15, [1, 7, 5, 8, 9])
    set2c = make_set("Set 3 – Clubabend", "3. Set",  0, [11, 12, 13])
    gig2 = Gig(
        name="Clubabend im Blue Note",
        datum=date.today() + timedelta(days=14),
        organizer="Blue Note Club", kind_of_gig="Privatveranstaltung",
        venue="Blue Note Club, Hauptstraße 42",
        doors=time(19, 30), begin=time(20, 30), end=time(23, 30),
        status="angenommen", publish="0",
    )
    db.add(gig2)
    db.flush()
    db.add_all([
        GigSet(id_gig=gig2.id, id_set=set2a.id, position=1),
        GigSet(id_gig=gig2.id, id_set=set2b.id, position=2),
        GigSet(id_gig=gig2.id, id_set=set2c.id, position=3),
    ])

    # Gig 3 – Anfrage (noch offen, kein Set)
    gig3 = Gig(
        name="Sommerfest Musterfirma AG",
        datum=date.today() + timedelta(days=60),
        organizer="Musterfirma AG", kind_of_gig="Privatveranstaltung",
        venue="Firmencampus, Industriestraße 1",
        doors=time(16, 0), begin=time(17, 0), end=time(21, 0),
        status="anfrage", publish="0",
    )
    db.add(gig3)
    db.flush()

    # Umfrage
    survey = Surveys(
        kind_of_survey="Meinungsumfrage",
        rf_survey="Welche neuen Songs sollen wir ins Repertoire aufnehmen?",
        released=True, closed=False,
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
    for field, user, value, comment in [
        (fields[0], alice, "ja",         "Super Song!"),
        (fields[0], bob,   "ja",         ""),
        (fields[0], carol, "vielleicht", "Kenne ich nicht so gut"),
        (fields[1], alice, "ja",         ""),
        (fields[1], bob,   "nein",       "Nicht unser Stil"),
        (fields[1], carol, "ja",         "Toller Song"),
    ]:
        db.add(SurveyFeedback(
            id_sv_field=field.id, id_user=user.id,
            datum=datetime.now(timezone.utc), value=value, comment=comment,
        ))
    db.flush()

    return {
        "users":      {"admin": admin, "alice": alice, "bob": bob, "carol": carol, "dave": dave},
        "songs":      song_objs,
        "rehearsals": [reh1, reh2, reh3],
        "gigs":       [gig1, gig2, gig3],
        "survey":     survey,
    }


@pytest.fixture
def season_data(db_session):
    """
    Legt einen vollständigen Saison-Datensatz in der Test-DB an und gibt
    ein Dict mit allen Objekten zurück.

    Verwendung::

        def test_gig_list(client, season_data):
            gigs = season_data["gigs"]
            response = client.get("/gigs/", headers=...)
            assert len(response.json()) >= 3
    """
    data = create_season_data(db_session)
    db_session.commit()
    return data


@pytest.fixture
def season_client(db_session, season_data):
    """
    Kombinations-Fixture: TestClient + vollständiger Saison-Datensatz.
    Der Admin-User aus dem Saison-Datensatz bekommt direkt ein Auth-Token.

    Verwendung::

        def test_something(season_client):
            client, headers, data = season_client
            response = client.get("/gigs/", headers=headers)
            assert response.status_code == 200
    """
    admin = season_data["users"]["admin"]
    token = auth.create_access_token({"sub": admin.user_name, "role": admin.user_group})
    headers = {"Authorization": f"Bearer {token}"}

    def override_get_db():
        yield db_session

    test_id = str(uuid.uuid4())
    original_key_func = limiter._key_func
    limiter._key_func = lambda request: test_id

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[auth.get_db] = override_get_db

    try:
        with TestClient(app) as test_client:
            yield test_client, headers, season_data
    finally:
        app.dependency_overrides.clear()
        limiter._key_func = original_key_func
