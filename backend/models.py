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

from sqlalchemy import Column, Integer, String, Date, Time, ForeignKey, DateTime, Text, Boolean, UniqueConstraint
from sqlalchemy.ext.hybrid import hybrid_property
from sqlalchemy.orm import declarative_base, Mapped, mapped_column, relationship
from datetime import date, time, datetime, timezone

Base = declarative_base()

def time_to_str(t):
    # Hilfsfunktion für Time/Date Objekte
    return t.strftime('%H:%M:%S') if isinstance(t, time) else (t.strftime('%Y-%m-%d') if isinstance(t, date) else None)

class User(Base):
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


class UsedPasswordResetToken(Base):
    __tablename__ = "used_password_reset_tokens"

    id = Column(Integer, primary_key=True, index=True)
    token_hash = Column(String, unique=True, index=True)
    used_at = Column(DateTime, default=datetime.now(timezone.utc))


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id = Column(Integer, primary_key=True, index=True)
    token_hash = Column(String(64), unique=True, index=True, nullable=False)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=False)
    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    revoked = Column(Boolean, default=False, nullable=False)

    user = relationship("User", backref="refresh_tokens")


class TokenBlacklist(Base):
    __tablename__ = "token_blacklist"

    id = Column(Integer, primary_key=True, index=True)
    token_hash = Column(String(64), unique=True, index=True, nullable=False)
    blacklisted_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    expires_at = Column(DateTime, nullable=False)

class RehTodo(Base):
    __tablename__ = "todos"

    id = Column(Integer, primary_key=True)
    id_song = Column(Integer, ForeignKey('songs.id'), nullable=False)
    id_reh = Column(Integer, ForeignKey('rehearsal_song.id_rehearsal'),nullable=False)
    id_user = Column(Integer, ForeignKey('users.id'), nullable=False)
    todo = Column(Text, nullable=False)
    dt = Column(DateTime, nullable=True)
    done = Column(Boolean, nullable=False, default=False)


class RehSong(Base):
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
    __tablename__ = "rehearsal"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    comment: Mapped[str] = mapped_column()
    begin: Mapped[datetime] = mapped_column()
    end: Mapped[datetime] = mapped_column()
    ical: Mapped[str] = mapped_column(String(1024))
    # Beziehung: Eine Probe enthält viele Zwischentabellen-Einträge
    songs = relationship('RehSong', back_populates='rehearsal')


class Gig(Base):
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

    sets: Mapped[list["GigSet"]] = relationship(
        "GigSet", back_populates="gig", order_by="GigSet.position"
    )

    def debug_dump(self, schedule=None):
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

    def to_dict (self, include_song_details=True):
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
    __tablename__ = "songs"
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(1024))
    interpret = Column(String(1024))
    genre = Column(String(512))
    singer_background = Column(String(512))
    singer_lead = Column(String(512))
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
        return {
            "id": self.id,
            "title": self.title,
            "interpret": self.interpret,
            "genre": self.genre.strip() if self.genre else "",
            "singer_lead": self.singer_lead if self.singer_lead else "",
            "singer_background": self.singer_background if self.singer_background else "",
            "duration": self.duration.strftime("%H:%M:%S") if type(self.duration) == time else "00:00:00",
            "brass": self.brass,
            "tone_key": self.tone_key,
            "status": self.status,
            "comment": self.comment,
        }

    def to_setlist_element(self):
        output_dict = self.to_setlist_dict()
        output_dict["song_id"] = output_dict["id"]
        output_dict["setsong_id"] = -1
        return output_dict

class SongCandidateFeedback(Base):
    __tablename__ = "song_feedback"
    id = Column(Integer, primary_key=True, index=True)
    song_id = Column(Integer, ForeignKey('songs.id'), nullable=False)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=False)
    date = Column(DateTime, nullable=False, default=datetime)
    feedback = Column(Text, nullable=False)


    song = relationship('Song', back_populates='feedbacks')


class Set(Base):
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
        return {
            "id": self.id,
        }

class SetSong(Base):
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
    __tablename__ = "gig_sets"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    id_gig: Mapped[int] = mapped_column(ForeignKey("gigs.id"), nullable=False)
    id_set: Mapped[int] = mapped_column(ForeignKey("sets.id"), nullable=False)
    position: Mapped[int] = mapped_column(Integer, nullable=False)

    gig: Mapped["Gig"] = relationship("Gig", back_populates="sets")
    set: Mapped["Set"] = relationship("Set", back_populates="gig_links")


class Surveys(Base):
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
    __tablename__ = "survey_field"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    id_survey = Column(Integer, ForeignKey('surveys.id'), nullable=False)
    field_text = Column(Text, nullable=False)
    feedbacks = relationship("SurveyFeedback", backref="survey_field", cascade="all, delete-orphan")

class SurveyFeedback(Base):
    __tablename__ = "survey_feedback"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    id_sv_field = Column(Integer, ForeignKey('survey_field.id'), nullable=False)
    id_user = Column(Integer, ForeignKey('users.id'), nullable=False)
    datum = Column(DateTime, nullable=False, default=datetime)
    value = Column(Text, nullable=False)
    comment= Column(Text, nullable=True)