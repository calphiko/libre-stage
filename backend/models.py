"""
SQLAlchemy ORM models for libreStage.

Defines all database tables as Python classes. Every model that maps to
a table inherits from :data:`Base`.

Helper:
    :func:`time_to_str` – converts :class:`datetime.time` /
    :class:`datetime.date` objects to ISO strings for serialisation.
"""

from sqlalchemy import Column, Integer, String, Date, Time, ForeignKey, DateTime, Text, Boolean, UniqueConstraint
from sqlalchemy.ext.hybrid import hybrid_property
from sqlalchemy.orm import declarative_base, Mapped, mapped_column, relationship
from datetime import date, time, datetime, timezone

Base = declarative_base()

def time_to_str(t):
    # Hilfsfunktion für Time/Date Objekte
    return t.strftime('%H:%M:%S') if isinstance(t, time) else (t.strftime('%Y-%m-%d') if isinstance(t, date) else None)

class User(Base):
    """
    Registered application user.

    Attributes:
        id (int): Primary key.
        user_name (str): Unique login name.
        user_pw (str): bcrypt password hash.
        user_group (str): Role – ``admin``, ``editor`` or ``user``.
        email (str): E-mail address.
        clear_name (str): Display name.
        musician (bool): Whether the user is a band member.
        is_singer (bool): Whether the user is a singer.
        mm_username (str): Optional Mattermost username.
    """
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    user_name = Column(String(128), unique=True, index=True)
    user_pw = Column(String(512))     # bcrypt Hash, nicht das Klartext-Passwort
    user_group = Column(String(128))
    email = Column(String(512))
    clear_name = Column(String(1024))
    musician = Column(Boolean)
    is_singer = Column(Boolean)
    mm_username = Column(String(512))
    status = Column(String(32), nullable=False, default="active", server_default="active")


class UsedPasswordResetToken(Base):
    """
    Record of password-reset tokens that have already been consumed.

    Attributes:
        id (int): Primary key.
        token_hash (str): SHA-256 hash of the used token.
        used_at (datetime): Timestamp when the token was used.
    """
    __tablename__ = "used_password_reset_tokens"

    id = Column(Integer, primary_key=True, index=True)
    token_hash = Column(String, unique=True, index=True)
    used_at = Column(DateTime, default=datetime.now(timezone.utc))


class RefreshToken(Base):
    """
    Persistent refresh token linked to a user.

    Attributes:
        id (int): Primary key.
        token_hash (str): SHA-256 hash of the raw token.
        user_id (int): Foreign key to :class:`User`.
        expires_at (datetime): Expiry timestamp (UTC).
        created_at (datetime): Creation timestamp (UTC).
        revoked (bool): ``True`` if the token has been invalidated.
        user (User): Relationship to the owning user.
    """
    __tablename__ = "refresh_tokens"

    id = Column(Integer, primary_key=True, index=True)
    token_hash = Column(String(64), unique=True, index=True, nullable=False)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=False)
    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    revoked = Column(Boolean, default=False, nullable=False)

    user = relationship("User", backref="refresh_tokens")


class TokenBlacklist(Base):
    """
    Blacklisted access tokens (e.g. after explicit logout).

    Attributes:
        id (int): Primary key.
        token_hash (str): SHA-256 hash of the blacklisted JWT.
        blacklisted_at (datetime): Timestamp of blacklisting (UTC).
        expires_at (datetime): Original token expiry – used for cleanup.
    """
    __tablename__ = "token_blacklist"

    id = Column(Integer, primary_key=True, index=True)
    token_hash = Column(String(64), unique=True, index=True, nullable=False)
    blacklisted_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    expires_at = Column(DateTime, nullable=False)

class RehTodo(Base):
    """
    A to-do item assigned to a specific user for a song in a rehearsal.

    Attributes:
        id (int): Primary key.
        id_song (int): Foreign key to :class:`Song`.
        id_reh (int): Foreign key to :class:`RehSong` (rehearsal).
        id_user (int): Foreign key to :class:`User`.
        todo (str): Description of the task.
        dt (datetime | None): Optional due date/time.
        done (bool): Whether the task has been completed.
    """
    __tablename__ = "todos"

    id = Column(Integer, primary_key=True)
    id_song = Column(Integer, ForeignKey('songs.id'), nullable=False)
    id_reh = Column(Integer, ForeignKey('rehearsal_song.id_rehearsal'),nullable=False)
    id_user = Column(Integer, ForeignKey('users.id'), nullable=False)
    todo = Column(Text, nullable=False)
    dt = Column(DateTime, nullable=True)
    done = Column(Boolean, nullable=False, default=False)


class RehSong(Base):
    """
    Association between a :class:`Rehearsal` and a :class:`Song`.

    Stores per-song rehearsal metadata (comment, to-do text, done flag)
    and exposes several hybrid properties that proxy attributes of the
    related :class:`Song`.

    Attributes:
        id (int): Primary key.
        id_rehearsal (int): Foreign key to :class:`Rehearsal`.
        id_song (int): Foreign key to :class:`Song`.
        comment (str | None): Free-text comment for this rehearsal slot.
        todo (str | None): Short to-do description.
        done (bool | None): Whether the rehearsal slot is marked as done.
        rehearsal (Rehearsal): Owning rehearsal.
        song (Song): The rehearsed song.
        todos (list[RehTodo]): Individual to-do items for this slot.
    """
    __tablename__ = "rehearsal_song"
    __table_args__ = (
        UniqueConstraint('id_rehearsal', 'id_song', name='_reh_song_uc'),
    )

    id = Column(Integer, primary_key=True)
    id_rehearsal = Column(Integer, ForeignKey('rehearsal.id'), nullable=False)
    id_song = Column(Integer, ForeignKey('songs.id'), nullable=False)
    comment = Column(Text, nullable=True)
    todo = Column(Text, nullable=True)
    done = Column(Boolean, nullable=True, default=False)

    @hybrid_property
    def title(self):
        return self.song.title

    @hybrid_property
    def interpret(self):
        return self.song.interpret

    @hybrid_property
    def status(self):
        return self.song.status

    @hybrid_property
    def setlist_comment(self):
        return self.song.comment

    @hybrid_property
    def song_todos(self):
        return [todo for todo in self.todos]

    # Beziehung: gehört zu Rehearsal
    rehearsal = relationship('Rehearsal', back_populates='songs')
    # Beziehung: gehört zu Song
    song = relationship('Song', back_populates='rehearsal_links')
    # Beziehung: Aufgaben (Todos) dieser Probe/Song-Kombi
    todos = relationship(
        "RehTodo",
        primaryjoin=(
            "and_(RehSong.id_song==foreign(RehTodo.id_song), "
            "RehSong.id_rehearsal==foreign(RehTodo.id_reh))"
        ),
        overlaps="song"
    )

class Rehearsal(Base):
    """
    A single band rehearsal session.

    Attributes:
        id (int): Primary key.
        comment (str): Free-text notes about the rehearsal.
        begin (datetime): Start time.
        end (datetime): End time.
        ical (str): iCal UID or event string.
        songs (list[RehSong]): Songs scheduled for this rehearsal.
    """
    __tablename__ = "rehearsal"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    comment: Mapped[str] = mapped_column()
    begin: Mapped[datetime] = mapped_column()
    end: Mapped[datetime] = mapped_column()
    ical: Mapped[str] = mapped_column(String(1024))
    # Beziehung: Eine Probe enthält viele Zwischentabellen-Einträge
    songs = relationship('RehSong', back_populates='rehearsal')


class Gig(Base):
    """
    A band performance (gig / concert).

    Attributes:
        id (int): Primary key.
        name (str): Display name of the gig.
        datum (date): Performance date.
        organizer (str | None): Name of the organiser.
        kind_of_gig (str | None): Type, e.g. *Schützenfest*.
        venue (str | None): Location name.
        doors (time | None): Doors-open time.
        begin (time | None): Start time of the performance.
        end (time | None): End time of the performance.
        status (str | None): Workflow status.
        publish (str | None): Whether the gig is published publicly.
        sets (list[GigSet]): Ordered set list for this gig.
    """

    __tablename__ = "gigs"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(512), nullable=False)
    datum:Mapped[date] = mapped_column("date")      # oder Column(Date), je nach Datentyp in deiner Datenbank
    organizer = Column(String(512))
    kind_of_gig = Column(String(128))
    venue = Column(String(512))
    doors = Column(Time)
    begin = Column(Time)
    end = Column(Time)
    status = Column(String)
    publish = Column(String)
    notes = Column(Text, nullable=True)

    sets: Mapped[list["GigSet"]] = relationship(
        "GigSet", back_populates="gig", order_by="GigSet.position"
    )
    schedule_items: Mapped[list["GigScheduleItem"]] = relationship(
        "GigScheduleItem",
        back_populates="gig",
        order_by="GigScheduleItem.item_datetime",
        cascade="all, delete-orphan",
    )

    def debug_dump(self, schedule=None):
        """
        Print a human-readable overview of the gig structure to stdout.

        Args:
            schedule (dict | None): Optional timing schedule as returned
                by :meth:`services.setlist.SetlistService.calc_schedule`.
        """
        print(f"\n=== Gig {self.id}: {self.name} am {self.datum} ===\n")
        print(f"  Beginn: {self.begin}")
        for gigset in sorted(self.sets, key=lambda x: x.position):
            set_obj = gigset.set
            print(f"  -> Set {gigset.position}: {set_obj.setlist_name or set_obj.name} Id: {set_obj.id} (Pause: {set_obj.pause})")
            setsonglist = sorted(set_obj.songs, key=lambda ss: ss.position)
            for idx, setsong in enumerate(setsonglist, start=1):
                song = setsong.song
                zeit_str = (
                    schedule[gigset.position][idx - 1].strftime('%H:%M')
                    if schedule and gigset.position in schedule and idx - 1 < len(schedule[gigset.position])
                    else "-"
                )
                print(f"     [{zeit_str}] {setsong.position}. {song.title} / {song.singer_lead} / {song.duration}")

    def to_dict(self, include_song_details=True):
        """
        Serialise the gig and its full set list to a plain dictionary.

        Args:
            include_song_details (bool): Reserved for future use; currently
                always includes song details.

        Returns:
            dict: A JSON-serialisable representation of the gig including
            all sets and songs.
        """
        return {
            "id": self.id,
            "name": self.name,
            "datum": time_to_str(self.datum),
            "organizer": self.organizer,
            "kind_of_gig": self.kind_of_gig,
            "venue": self.venue,
            "doors": time_to_str(self.doors),
            "begin": time_to_str(self.begin),
            "end": time_to_str(self.end),
            "sets": [
                {
                    "id": gigset.id,
                    "gigset_id": gigset.id,
                    "set_id": gigset.set.id,
                    "set_name": gigset.set.name,
                    "pause": time_to_str(gigset.set.pause),
                    "setlist_name": gigset.set.setlist_name,
                    "songs": [
                        setsong.to_setlist_dict()
                        for setsong in gigset.set.songs
                    ]
                }
                for gigset in sorted(self.sets, key=lambda x: x.position)
            ]
        }

class Song(Base):
    """
    A song in the band's repertoire.

    Attributes:
        id (int): Primary key.
        title (str): Song title.
        interpret (str): Artist / band name.
        genre (str | None): Musical genre.
        singer_background (str | None): Background singer(s).
        singer_lead (str | None): Lead singer.
        composer (str | None): Composer name(s).
        texter (str | None): Lyricist name(s).
        publisher (str | None): Publisher.
        arrangement (str | None): Arranger.
        text (str | None): Full lyrics.
        tone_key (str | None): Musical key, e.g. ``Bb``.
        status (str | None): Workflow status (e.g. ``angenommen``).
        comment (str | None): Internal notes.
        ytlink (str | None): YouTube link.
        duration (time | None): Song duration.
        brass (int | None): Brass instrument flag.
        rehearsal_links (list[RehSong]): Rehearsal associations.
        feedbacks (list[SongCandidateFeedback]): Candidate feedback entries.
    """
    __tablename__ = "songs"
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(1024))
    interpret = Column(String(1024))
    genre = Column(String(512))
    singer_background = Column(String(512))
    singer_lead = Column(String(512))
    dance_styles = Column(String(512))
    composer = Column(String(1024))
    texter = Column(String(1024))
    publisher = Column(String(1024))
    arrangement = Column(String(512))
    text = Column(String)
    tone_key = Column(String(10))
    status = Column(String(128))
    comment = Column(String(1024))
    ytlink = Column(String(20248))
    duration = Column(Time)
    brass = Column(Integer)

    rehearsal_links = relationship('RehSong', back_populates='song')
    feedbacks = relationship('SongCandidateFeedback', back_populates='song', cascade="all, delete-orphan")

    def to_setlist_dict(self):
        """
        Serialise the song to a dictionary suitable for setlist display.

        Returns:
            dict: Song fields used in setlist views (title, interpret,
            genre, singers, duration, brass, tone_key, status, comment).
        """
        return {
            "id": self.id,
            "title": self.title,
            "interpret": self.interpret,
            "genre": self.genre.strip() if self.genre else "",
            "singer_lead": self.singer_lead if self.singer_lead else "",
            "singer_background": self.singer_background if self.singer_background else "",
            "dance_styles": self.dance_styles if self.dance_styles else "",
            "duration": self.duration.strftime("%H:%M:%S") if type(self.duration) == time else "00:00:00",
            "brass": self.brass,
            "tone_key": self.tone_key,
            "status": self.status,
            "comment": self.comment,
        }

    def to_setlist_element(self):
        """
        Like :meth:`to_setlist_dict` but adds ``song_id`` and a
        placeholder ``setsong_id`` of ``-1``.

        Returns:
            dict: Extended setlist dictionary with ``song_id`` and
            ``setsong_id``.
        """
        output_dict = self.to_setlist_dict()
        output_dict["song_id"] = output_dict["id"]
        output_dict["setsong_id"] = -1
        return output_dict

class SongCandidateFeedback(Base):
    """
    User feedback on a song candidate (proposal).

    Attributes:
        id (int): Primary key.
        song_id (int): Foreign key to :class:`Song`.
        user_id (int): Foreign key to :class:`User`.
        date (datetime): Timestamp of the feedback.
        feedback (str): Feedback text.
        song (Song): The song this feedback belongs to.
    """
    __tablename__ = "song_feedback"
    id = Column(Integer, primary_key=True, index=True)
    song_id = Column(Integer, ForeignKey('songs.id'), nullable=False)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=False)
    date = Column(DateTime, nullable=False, default=datetime)
    feedback = Column(Text, nullable=False)


    song = relationship('Song', back_populates='feedbacks')


class Set(Base):
    """
    A named set of songs within a gig.

    Attributes:
        id (int): Primary key.
        name (str): Internal set name.
        pause (time): Duration of the break after this set (default 10 min).
        setlist_name (str | None): Optional public-facing name shown on
            printed setlists.
        gig_links (list[GigSet]): Associations to gigs.
        songs (list[SetSong]): Ordered songs in this set.
    """
    __tablename__ = "sets"

    id: Mapped[int]              = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str]            = mapped_column(String(512), nullable=False)
    pause: Mapped[time] = mapped_column(
        Time,
        nullable=False,
        default=lambda: time(hour=0, minute=10, second=0),  # Python-seitig
        server_default="00:10:00"  # DB-seitig für neuen Datensatz ohne Wert
    )
    setlist_name: Mapped[str | None] = mapped_column(String(1024))

    gig_links: Mapped[list["GigSet"]] = relationship("GigSet", back_populates="set")

    songs: Mapped[list["SetSong"]] = relationship(
        "SetSong",
        back_populates="set",
        order_by="SetSong.position",
        cascade="all, delete-orphan"
    )

    def to_setlist_dict(self):
        """
        Minimal serialisation of the set (currently only ``id``).

        Returns:
            dict: ``{"id": self.id}``
        """
        return {
            "id": self.id,
        }

class SetSong(Base):
    """
    Association between a :class:`Set` and a :class:`Song`, including
    position and live-mode state.

    Attributes:
        id (int): Primary key.
        id_set (int): Foreign key to :class:`Set`.
        id_song (int): Foreign key to :class:`Song`.
        position (int): 1-based position of the song within the set.
        eingeschoben (bool | None): Marked as inserted ad-hoc during live mode.
        uebersprungen (bool | None): Marked as skipped during live mode.
        feedback (int | None): Post-performance rating (1–3).
        song (Song): The associated song.
        set (Set): The owning set.
    """
    __tablename__ = "set_songs"

    id: Mapped[int]           = mapped_column(Integer, primary_key=True, autoincrement=True)
    id_set: Mapped[int]       = mapped_column(ForeignKey("sets.id"), nullable=False)
    id_song: Mapped[int]      = mapped_column(ForeignKey("songs.id"), nullable=False)
    position: Mapped[int]     = mapped_column(Integer, nullable=False)  # Position im Set

    # Live-Mode Spalten
    eingeschoben: Mapped[bool | None] = mapped_column(Boolean, nullable=True, default=None)
    uebersprungen: Mapped[bool | None] = mapped_column(Boolean, nullable=True, default=None)
    feedback: Mapped[int | None] = mapped_column(Integer, nullable=True, default=None)

    song: Mapped["Song"]      = relationship("Song")
    set: Mapped["Set"] = relationship(
        "Set",
        back_populates="songs"
        # primaryjoin NICHT setzen!
    )

    # In models.py, Methode to_setlist_dict der SetSong-Klasse
    def to_setlist_dict(self):
        """
        Serialise the set–song association for setlist views.

        Returns a fallback entry with a warning title if the linked song
        has been deleted.

        Returns:
            dict: Song fields plus ``song_id``, ``setsong_id``,
            ``position``, ``eingeschoben``, ``uebersprungen`` and
            ``feedback``.
        """
        if not self.song:
            # Fallback für fehlende Songs
            return {
                "id": self.id,  # SetSong ID als Fallback
                "song_id": 0,  # Dummy-ID statt None
                "setsong_id": self.id,
                "title": "⚠️ Song gelöscht",
                "position": self.position,
                "interpret": "",
                "genre": "",
                "singer_lead": "",
                "duration": "00:00:00",
                "brass": 0,
                "tone_key": "",
                "status": "",
                "comment": "",
                "eingeschoben": self.eingeschoben,
                "uebersprungen": self.uebersprungen,
                "feedback": self.feedback
            }

        output_dict = self.song.to_setlist_dict()
        output_dict["song_id"] = self.song.id
        output_dict["setsong_id"] = self.id
        output_dict["position"] = self.position
        output_dict["eingeschoben"] = self.eingeschoben
        output_dict["uebersprungen"] = self.uebersprungen
        output_dict["feedback"] = self.feedback
        return output_dict


class GigSet(Base):
    """
    Ordered association between a :class:`Gig` and a :class:`Set`.

    Attributes:
        id (int): Primary key.
        id_gig (int): Foreign key to :class:`Gig`.
        id_set (int): Foreign key to :class:`Set`.
        position (int): 1-based display order within the gig.
        gig (Gig): The owning gig.
        set (Set): The associated set.
    """
    __tablename__ = "gig_sets"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    id_gig: Mapped[int] = mapped_column(ForeignKey("gigs.id"), nullable=False)
    id_set: Mapped[int] = mapped_column(ForeignKey("sets.id"), nullable=False)
    position: Mapped[int] = mapped_column(Integer, nullable=False)

    gig: Mapped["Gig"] = relationship("Gig", back_populates="sets")
    set: Mapped["Set"] = relationship("Set", back_populates="gig_links")


class GigScheduleItem(Base):
    """Additional freely editable timeline items for a gig."""

    __tablename__ = "gig_schedule_items"
    __table_args__ = (
        UniqueConstraint("gig_id", "item_datetime", name="_gig_schedule_uc"),
    )

    id = Column(Integer, primary_key=True, index=True)
    gig_id = Column(Integer, ForeignKey("gigs.id"), nullable=False)
    item_datetime = Column(DateTime, nullable=False)
    was = Column(String(512), nullable=False)
    wer = Column(String(512), nullable=False)
    wo = Column(String(512), nullable=False)
    comment = Column(Text, nullable=True)

    gig: Mapped["Gig"] = relationship("Gig", back_populates="schedule_items")


class Surveys(Base):
    """
    A feedback survey created by an admin or editor.

    Attributes:
        id (int): Primary key.
        kind_of_survey (str): Survey category / type label.
        rf_survey (str): Request-for-feedback description.
        released (bool): Whether the survey is visible to members.
        closed (bool): Whether the survey is closed for new responses.
        user_created (int): Foreign key to the creating :class:`User`.
        release_date (datetime): Date/time the survey was released.
        datum (datetime): Creation date.
        fields (list[SurveyFields]): Individual questions / fields.
    """
    __tablename__ = "surveys"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    kind_of_survey = Column(String(1024), nullable=False)
    rf_survey = Column(Text, nullable=False)
    released = Column(Boolean, default=False)
    closed = Column(Boolean, default=False)
    user_created = Column(Integer, ForeignKey('users.id'), nullable=False)
    release_date = Column(DateTime, nullable=False)
    fields = relationship("SurveyFields", backref="survey", cascade="all, delete-orphan")
    datum = Column(DateTime, nullable=False, default=datetime)

class SurveyFields(Base):
    """
    A single question or rating field within a :class:`Surveys`.

    Attributes:
        id (int): Primary key.
        id_survey (int): Foreign key to :class:`Surveys`.
        field_text (str): The question or label text.
        feedbacks (list[SurveyFeedback]): Responses to this field.
    """
    __tablename__ = "survey_field"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    id_survey = Column(Integer, ForeignKey('surveys.id'), nullable=False)
    field_text = Column(Text, nullable=False)
    feedbacks = relationship("SurveyFeedback", backref="survey_field", cascade="all, delete-orphan")

class SurveyFeedback(Base):
    """
    A user's response to a single :class:`SurveyFields` entry.

    Attributes:
        id (int): Primary key.
        id_sv_field (int): Foreign key to :class:`SurveyFields`.
        id_user (int): Foreign key to :class:`User`.
        datum (datetime): Timestamp of the response.
        value (str): The submitted value (e.g. a rating string).
        comment (str | None): Optional free-text comment.
    """
    __tablename__ = "survey_feedback"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    id_sv_field = Column(Integer, ForeignKey('survey_field.id'), nullable=False)
    id_user = Column(Integer, ForeignKey('users.id'), nullable=False)
    datum = Column(DateTime, nullable=False, default=datetime)
    value = Column(Text, nullable=False)
    comment= Column(Text, nullable=True)

