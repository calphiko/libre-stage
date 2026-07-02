"""
Pydantic schemas for request validation and response serialisation.

Every schema is a :class:`pydantic.BaseModel` subclass.  Schemas are
grouped by domain:

- **Auth** – :class:`LoginRequest`, :class:`RefreshRequest`,
  :class:`LogoutRequest`
- **User** – :class:`UserOut`, :class:`UserCreate`, :class:`UserUpdate`,
  :class:`UserListElem`, :class:`UserTodo`, :class:`UserTodoList`
- **Song** – :class:`SongIn`, :class:`SongOut`, :class:`SongCandidateOut`,
  :class:`SongFeedbackBase`, :class:`SongFeedbackIn`,
  :class:`SongStatistics`
- **Rehearsal** – :class:`RehListElem`, :class:`NewRehDict`,
  :class:`RehTodoOut`
- **Gig** – :class:`GigIn`, :class:`GigOut`, :class:`GigSetlistOut`,
  :class:`GigStatistics`, :class:`SeasonStatistics`
- **Survey** – :class:`SurveyIn`, :class:`SurveyList`,
  :class:`SurveyQuestionOut`, :class:`SurveyFeedbackOut`
- **Password** – :class:`PasswordUpdateRequest`,
  :class:`PasswordResetRequest`
"""

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

from pydantic import BaseModel, Field, field_validator, computed_field, model_validator, EmailStr
from typing import Optional, Union, List, Dict
from enum import Enum
from datetime import time, date, datetime

class LoginRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=8, max_length=128)

    @field_validator('username', mode='before')
    @classmethod
    def strip_username(cls, v):
        if isinstance(v, str):
            return v.strip()
        return v


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class RefreshRequest(BaseModel):
    refresh_token: str


class LogoutRequest(BaseModel):
    refresh_token: Optional[str] = None


class UserGroup(str, Enum):
    admin = "admin"
    editor = "editor"
    user = "user"

class UserStatus(str, Enum):
    active = "active"
    deactivated = "deactivated"

class UserCreate(BaseModel):
    user_name: str = Field(..., min_length=3, max_length=30, pattern=r'^[a-zA-Z0-9_-]+$')
    clear_name: Optional[str] = None
    email: EmailStr
    user_pw: str
    user_group: UserGroup
    musician: bool = False
    is_singer: bool = False
    status: UserStatus = UserStatus.active

class UserOut(BaseModel):
    id: int
    user_name: str
    user_group: UserGroup
    email: EmailStr
    clear_name: str
    musician: bool
    is_singer: bool
    mm_username: Optional[str] = ""
    status: UserStatus = UserStatus.active
    model_config = {"from_attributes": True}  # <--- das ist essenziell!


class UserTodo(BaseModel):
    id: int
    todo: str
    user_name: str
    song_title: str
    song_interpret: str
    done: bool
    dt: Optional[datetime]

class SongForFeedback(BaseModel):
    id: int
    title: str
    interpret: str
    status: str

class SurveyForFeedback(BaseModel):
    id: int
    kind_of_survey: str
    rf_survey: str
    release_date: Optional[str] = None

class UserTodoList(BaseModel):
    todo: List[UserTodo] = Field(default_factory=list)
    songs_to_feedback: List[SongForFeedback] = Field(default_factory=list)
    surveys_to_feedback: List[SurveyForFeedback] = Field(default_factory=list)

class PasswordUpdateRequest(BaseModel):
    user_id: int
    old_password: str
    new_password: str

class PasswordResetRequest(BaseModel):
    new_password: str = Field(..., min_length=8, max_length=128)


class SoftConfigOption(BaseModel):
    key: Optional[str] = None
    label: str

    model_config = {"extra": "forbid"}


class SoftConfigUpdateIn(BaseModel):
    genres: List[Union[str, SoftConfigOption]]
    gigTypes: List[Union[str, SoftConfigOption]]
    songStatuses: List[Union[str, SoftConfigOption]]
    gigStatuses: List[Union[str, SoftConfigOption]]
    tonekeys: List[Union[str, SoftConfigOption]]
    rehearsalSongStatuses: List[Union[str, SoftConfigOption]]
    setlist_timing: List[Dict[str, int]]
    danceStyles: List[Union[str, SoftConfigOption]]

    model_config = {"extra": "forbid"}


class SoftConfigOut(BaseModel):
    genres: List[SoftConfigOption]
    gigTypes: List[SoftConfigOption]
    songStatuses: List[SoftConfigOption]
    gigStatuses: List[SoftConfigOption]
    tonekeys: List[SoftConfigOption]
    rehearsalSongStatuses: List[str]
    setlist_timing: List[Dict[str, int]]
    danceStyles: List[SoftConfigOption]


class SoftConfigMeta(BaseModel):
    editableKeys: List[str]
    updatedAt: str


class SoftConfigAdminResponse(BaseModel):
    data: SoftConfigOut
    meta: SoftConfigMeta


class SoftConfigUpdateResponse(BaseModel):
    message: str
    updatedKeys: List[str]
    data: SoftConfigOut

class SongIn(BaseModel):
    title: str = Field(..., max_length=200)
    interpret: str =  Field(..., max_length=200)
    genre: str= Field(..., max_length=100)
    singer_background: Optional[str] = Field(None, max_length=200)
    singer_lead: Optional[str] = Field(None, max_length=200)
    dance_styles: Optional[str] = Field(None, max_length=512)
    composer: Optional[str] = Field(None, max_length=500)
    texter: Optional[str] = Field(None, max_length=500)
    publisher: Optional[str] = Field(None, max_length=500)
    arrangement: Optional[str] = Field(None, max_length=500)
    tone_key: Optional[str] = Field(None, max_length=20)
    status: str
    comment: Optional[str] = Field(None, max_length=5000)
    ytlink: Optional[str] = None
    brass: Optional[Union[int,str]] = None  # erlaubt beides
    text: Optional[str] = None                 # falls in Model vorhanden
    id: int = None

    duration: Optional[Union[time, str]] = None

    @field_validator("duration", mode="before")
    @classmethod
    def parse_duration(cls, v):
        if v in (None, "", "None"):
            return None
        if isinstance(v, time):
            return v # pragma: no cover
        h, m, s = map(int, v.split(":"))
        return time(hour=h, minute=m, second=s)

class SongFeedbackIn(BaseModel):
    song_id: int
    user_id: int
    feedback: str

class SongFeedbackBase(BaseModel):
    song_id: int
    user_id: int
    feedback: str

    model_config = {"from_attributes": True}


class SongFeedbackSummary(BaseModel):
    song_id: int
    total_votes: int = 0
    yes_votes: int = 0
    no_votes: int = 0
    abstain_votes: int = 0
    unknown_votes: int = 0

class SongCandidateOut(BaseModel):
    id: int
    title: str
    interpret: str
    genre: Optional[str] = None
    singer_lead: Optional[str] = None
    singer_background: Optional[str] = None
    dance_styles: Optional[str] = None
    composer: Optional[str] = None
    tone_key: Optional[str] = None
    status: Optional[str] = None
    ytlink: Optional[str] = None
    brass: Optional[int] = None
    duration: Optional[time] = None
    feedbacks: list[SongFeedbackBase] = Field(default_factory=list)

    model_config = {"from_attributes": True}

class SongOut(BaseModel):
    title: Optional[str] = None
    interpret: Optional[str] = None
    genre: Optional[str] = None
    singer_background: Optional[str] = None
    singer_lead: Optional[str] = None
    dance_styles: Optional[str] = None
    composer: Optional[str] = None
    texter: Optional[str] = None
    publisher: Optional[str] = None
    arrangement: Optional[str] = None
    tone_key: Optional[str] = None
    status: Optional[str] = None
    comment: Optional[str] = None
    ytlink: Optional[str] = None
    duration: Optional[time] = None
    brass: Optional[int] = None
    id: int = None

    @computed_field
    @property
    def singer_lead_short(self) -> str:
        # Die Logik aus deinem dict
        return self.singer_lead.strip().split("+")[0].split(" ")[0].split(",")[0].strip() if self.singer_lead else ""

    @computed_field
    @property
    def duration_formatted(self) -> str:
        if isinstance(self.duration, time):
            return self.duration.strftime("%M:%S")
        return "00:00"

    model_config = {"from_attributes": True}  # <--- das ist essenziell!


class SongScrawlOut(BaseModel):
    recording_id: Optional[str] = None
    work_id: Optional[str] = None
    duration: Optional[str] = None
    ytlink: Optional[str] = None
    composers: List[str] = Field(default_factory=list)
    lyricists: List[str] = Field(default_factory=list)
    composer: Optional[str] = None
    texter: Optional[str] = None

class GigIn(BaseModel):
    name: str
    datum: date
    venue: Optional[str] = None
    kind_of_gig: str
    doors: Optional[Union[time,str]] = None
    begin: Optional[Union[time,str]] = None
    end: Optional[Union[time,str]] = None
    organizer: Optional[str] = None
    status: Optional[str] = None
    id: int = None
    publish: Optional[int] = None
    notes: Optional[str] = None

    @field_validator("datum", mode="before")
    @classmethod
    def parse_date(cls, v):
        print (f"Parse: {v}")
        if v in (None, "", "None"):
            return None # pragma: no cover
        if isinstance(v, date):
            return v # pragma: no cover
        try:
            y, m, d = map(int, v.split("-")) # pragma: no cover
            print(date(year=y, month=m, day=d)) # pragma: no cover
            return date(year=y, month=m, day=d) # pragma: no cover
        except Exception as exc: # pragma: no cover
            raise ValueError("date muss im Format YYYY-MM-DD sein") from exc # pragma: no cover

    @field_validator("doors", "begin", "end", mode="before")
    @classmethod
    def parse_time_field(cls, v):
        if v in (None, "", "None"): # pragma: no cover
            return None # pragma: no cover
        if isinstance(v, time): # pragma: no cover
            return v # pragma: no cover
        try: # pragma: no cover
            h, m, s = map(int, v.split(":")) # pragma: no cover
            return time(hour=h, minute=m, second=s) # pragma: no cover
        except Exception as exc: # pragma: no cover
            raise ValueError("doors, begin, end müssen im Format HH:MM:SS (z.B. 09:30:00) sein") from exc # pragma: no cover


class NewGig(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    datum: date
    venue: Optional[str] =  Field(None, max_length=300)
    kind_of_gig: str = Field(..., max_length=300)
    begin: Union[time, str]  # Pflichtfeld
    doors: Optional[Union[time, str]] = None
    end: Optional[Union[time, str]] = None
    organizer: Optional[str] = None
    status: Optional[str] = None
    publish: Optional[int] = 0

    @model_validator(mode="before")
    @classmethod
    def set_default_times(cls, values):
        begin = values.get("begin")

        # begin zu time konvertieren falls String
        if isinstance(begin, str) and begin:
            parts = begin.split(":")
            h = int(parts[0])
            m = int(parts[1])
            s = int(parts[2]) if len(parts) == 3 else 0  # Sekunden optional
            begin_time = time(hour=h, minute=m, second=s)
            values["begin"] = begin_time
        elif isinstance(begin, time):
            begin_time = begin
        else:
            return values

        # doors: 1 Stunde vor begin
        if not values.get("doors"):
            doors_hour = (begin_time.hour - 1) % 24
            values["doors"] = time(hour=doors_hour, minute=begin_time.minute, second=begin_time.second)
        else:
            if isinstance(values["doors"], str):
                parts = values["doors"].split(":")
                h = int(parts[0])
                m = int(parts[1])
                s = int(parts[2]) if len(parts) == 3 else 0  # Sekunden optional
                values["doors"] = time(hour=h, minute=m, second=s)

        # end: 2 Stunden nach begin
        if not values.get("end"):
            end_hour = (begin_time.hour + 2) % 24
            values["end"] = time(hour=end_hour, minute=begin_time.minute, second=begin_time.second)
        else:
            if isinstance(values["end"], str):
                parts = values["end"].split(":")
                h = int(parts[0])
                m = int(parts[1])
                s = int(parts[2]) if len(parts) == 3 else 0  # Sekunden optional
                values["end"] = time(hour=h, minute=m, second=s)

        return values


class GigOut(BaseModel):
    name: str = None
    datum: date = None
    venue: Optional[str] = None
    organizer: Optional[str] = None
    kind_of_gig: Optional[str] = None
    doors: Optional[time] = None
    begin: Optional[time] = None
    end: Optional[time] = None
    status: Optional[str] = None
    id: int = None
    publish: int = None
    notes: Optional[str] = None

    model_config = {"from_attributes": True}  # <--- das ist essenziell!


class GigScheduleItemIn(BaseModel):
    item_datetime: datetime
    was: str = Field(..., max_length=512)
    wer: str = Field(..., max_length=512)
    wo: str = Field(..., max_length=512)
    comment: Optional[str] = Field(None, max_length=2000)


class GigScheduleItemOut(BaseModel):
    id: Optional[int] = None
    gig_id: int
    item_datetime: datetime
    was: str
    wer: str
    wo: str
    comment: Optional[str] = None
    is_fixed: bool = False

    model_config = {"from_attributes": True}


class GigScheduleOut(BaseModel):
    items: List[GigScheduleItemOut] = Field(default_factory=list)


class GigScheduleBulkItemIn(BaseModel):
    id: Optional[int] = None
    item_datetime: datetime
    was: str = Field(..., max_length=512)
    wer: str = Field(..., max_length=512)
    wo: str = Field(..., max_length=512)
    comment: Optional[str] = Field(None, max_length=2000)


class GigScheduleBulkUpdateIn(BaseModel):
    items: List[GigScheduleBulkItemIn] = Field(default_factory=list)


class GigNotesIn(BaseModel):
    notes: Optional[str] = None

class SetOut(BaseModel):
    id: int
    position: int
    pause: time | None
    setlist_name: str | None
    songs: list[SongOut]
    model_config = {"from_attributes": True}


class SongInSetOut(BaseModel):
    id: int
    setsong_id: Optional[int] = None
    song_id: int
    position: Optional[int] = None
    title: str
    duration: Optional[str]
    singer_lead: Optional[str]
    singer_background: Optional[str]
    interpret: Optional[str]
    genre: Optional[str] = None
    tone_key: Optional[str] = None
    ytlink: Optional[str] = None
    comment: Optional[str] = None
    brass: Optional[int]
    status: Optional[str] = None

class SetInGigOut(BaseModel):
    id: Optional[int] = None
    gigset_id: Optional[int] = None
    set_id: Optional[int] = None
    set_name: Optional[str] = ''
    pause: Optional[str] = None
    setlist_name: Optional[str] = ''
    songs: List[SongInSetOut]

class GigSetlistTimingOut(BaseModel):
    schedule: Dict[str, List[str]] = Field(default_factory=dict)
    pause_before: Dict[str, int] = Field(default_factory=dict)
    set_end: Dict[str, str] = Field(default_factory=dict)


class GigSetlistOut(BaseModel):
    id: int
    name: str
    datum: Optional[str]
    organizer: Optional[str] = None
    kind_of_gig: Optional[str] = None
    venue: Optional[str] = None
    doors: Optional[str] = None
    begin: Optional[str] = None
    end: Optional[str] = None
    status: Optional[str] = None
    publish: Optional[str] = None
    setlist_version: Optional[str] = None
    notes: Optional[str] = None
    sets: List[SetInGigOut]
    timing: Optional[GigSetlistTimingOut] = None

    model_config = {"from_attributes": True}

class SongInSetLM(BaseModel):
    id: int
    title: str
    interpret: str
    position: int
    tone_key: Optional[str] = None
    comment: Optional[str] = None
    uebersprungen: Optional[bool] = None
    eingeschoben: Optional[bool] = None
    feedback: Optional[int] = None

    model_config = {"from_attributes": True}

class SongInSetLMUpdate(BaseModel):
    id: int
    uebersprungen: Optional[bool] = None
    eingeschoben: Optional[bool] = None
    feedback: Optional[int] = None

    model_config = {"from_attributes": True}

class SetInGigLM(BaseModel):
    id: int
    position: int
    pause: Optional[str] = None
    setlist_name: Optional[str] = None
    songs: List[SongInSetLM]

    model_config = {"from_attributes": True}



class GigSetListLiveMode(BaseModel):
    id: int
    name: str
    datum: Optional[str]
    doors: Optional[str] = None
    begin: Optional[str] = None
    end: Optional[str] = None
    sets: List[SetInGigLM]

    model_config = {"from_attributes": True}  # <--- das ist essenziell!

class GetSetlistIn(BaseModel):
    id: int
    name: str
    datum: Optional[str]
    organizer: Optional[str] = None
    kind_of_gig: Optional[str] = None
    venue: Optional[str] = None
    doors: Optional[str] = None
    begin: Optional[str] = None
    end: Optional[str] = None
    status: Optional[str] = None
    publish: Optional[str] = None
    setlist_version: Optional[str] = None
    sets: List[SetInGigOut]

    model_config = {"from_attributes": True}  # <--- das ist essenziell!

class SongToSetIn:
    gigId: int
    songId: int
    setId: int
    position: int


class TodoInSong(BaseModel):
    id: Optional[int]
    id_song: int
    id_reh: int
    id_user: int

    todo: str
    dt: Optional[datetime]
    done: bool

    model_config = {"from_attributes": True}

class SongInReh(BaseModel):
    id: Optional[int] = None
    id_rehearsal: int
    id_song: int
    interpret: str
    title: str
    status: str
    comment: Optional[str]
    setlist_comment: Optional[str]
    todo: Optional[str]
    song_todos: Optional[List[TodoInSong]] = Field(default_factory=list)
    done: bool

    model_config = {"from_attributes": True}


class SongRehearsalHistoryTodo(BaseModel):
    id: int
    id_user: int
    todo: str
    done: bool

    model_config = {"from_attributes": True}


class SongRehearsalHistoryEntry(BaseModel):
    rehearsal_id: int
    rehearsal_date: datetime
    comment: Optional[str] = None
    todo: Optional[str] = None
    done: bool = False
    rehearsal_comment: Optional[str] = None
    todos: List[SongRehearsalHistoryTodo] = Field(default_factory=list)

    model_config = {"from_attributes": True}


class GigPlayedEntry(BaseModel):
    gig_id: int
    gig_name: str
    gig_date: str
    feedback: Optional[int] = None
    uebersprungen: Optional[bool] = None
    eingeschoben: Optional[bool] = None

class CompanionSong(BaseModel):
    song_id: int
    title: str
    interpret: str
    count: int

class SongStatistics(BaseModel):
    # Proben
    rehearsal_count: int = 0
    first_rehearsal: Optional[str] = None
    last_rehearsal: Optional[str] = None

    # Gigs
    gig_count: int = 0
    gigs_played: List[GigPlayedEntry] = Field(default_factory=list)

    # Live-Mode Bewertungen
    feedback_count: int = 0
    feedback_avg: Optional[float] = None
    feedback_distribution: dict = Field(default_factory=dict)  # {1: x, 2: y, 3: z}
    skipped_count: int = 0
    inserted_count: int = 0

    # Häufige Set-Begleiter
    companion_songs: List[CompanionSong] = Field(default_factory=list)


class GigOverviewEntry(BaseModel):
    gig_id: int
    gig_name: str
    gig_date: str
    song_count: int
    skipped_count: int
    inserted_count: int
    feedback_avg: Optional[float] = None

class TopSongEntry(BaseModel):
    song_id: int
    title: str
    interpret: str
    count: int  # Wie oft in Setlisten dieser Saison


class TopSkippedSongEntry(BaseModel):
    song_id: int
    title: str
    interpret: str
    skipped_count: int  # Wie oft in der Saison uebersprungen


class GenreTimelinePoint(BaseModel):
    label: str
    date: Optional[str] = None
    kind_of_gig: Optional[str] = None
    genre_counts: dict = Field(default_factory=dict)  # {genre: count}
    total: int = 0


class GenrePaletteOut(BaseModel):
    palette: dict = Field(default_factory=dict)  # {genre: "#RRGGBB"}

class SeasonStatistics(BaseModel):
    jahr: Optional[int] = None
    gig_count: int = 0
    played_gig_count: int = 0     # Anzahl gespielter (vergangener) Gigs
    total_songs: int = 0          # Gesamtzahl Song-Einträge in allen Sets
    unique_songs: int = 0         # Anzahl unique Songs
    skipped_count: int = 0
    inserted_count: int = 0
    feedback_count: int = 0
    feedback_avg: Optional[float] = None
    feedback_distribution: dict = Field(default_factory=dict)  # {1: x, 2: y, 3: z}
    genre_distribution: dict = Field(default_factory=dict)  # {genre: count}
    genre_timeline: List[GenreTimelinePoint] = Field(default_factory=list)
    top_songs: List[TopSongEntry] = Field(default_factory=list)
    top_skipped_songs: List[TopSkippedSongEntry] = Field(default_factory=list)
    gigs_overview: List[GigOverviewEntry] = Field(default_factory=list)


class GigStatsSongEntry(BaseModel):
    song_id: int
    title: str
    interpret: str
    position: int
    feedback: Optional[int] = None
    uebersprungen: Optional[bool] = None
    eingeschoben: Optional[bool] = None

class GigStatsSetEntry(BaseModel):
    set_name: str
    feedback_avg: Optional[float] = None
    songs: List[GigStatsSongEntry] = Field(default_factory=list)

class GigStatistics(BaseModel):
    gig_id: int
    gig_name: str
    gig_date: str
    song_count: int = 0
    skipped_count: int = 0
    inserted_count: int = 0
    feedback_count: int = 0
    feedback_avg: Optional[float] = None
    feedback_distribution: dict = Field(default_factory=dict)  # {1: x, 2: y, 3: z}
    genre_distribution: dict = Field(default_factory=dict)  # {genre: count}
    genre_timeline: List[GenreTimelinePoint] = Field(default_factory=list)
    sets: List[GigStatsSetEntry] = Field(default_factory=list)


class RehListElem(BaseModel):
    id: int
    begin: datetime
    end: Optional[datetime] = None
    comment: Optional[str] = None
    ical: Optional[str] = ""
    songs: Optional[List[SongInReh]] = Field(default_factory=list)

    model_config = {"from_attributes": True}

class NewRehDict(BaseModel):
    begin: datetime
    end: Optional[datetime] = None
    comment: Optional[str]

    @model_validator(mode="after")
    def validate_time_range(self):
        if self.end is not None and self.end <= self.begin:
            raise ValueError("end must be after begin")
        return self

    model_config = {"from_attributes": True}

class UserListElem(BaseModel):
    id: int
    user_name: str
    clear_name: str
    email: str


class SurveyFeedbackOut(BaseModel):
    id: Optional[int] = -1
    id_sv_field: int
    id_user: int
    value: Optional[str] = None
    comment: Optional[str] = ""

    model_config = {"from_attributes": True}


class SurveyFieldsOut(BaseModel):
    id: int
    id_survey: int
    field_text: str
    feedbacks: List[SurveyFeedbackOut] = Field(default_factory=list)

    model_config = {"from_attributes": True}


class SurveyQuestionOut(BaseModel):
    id: int
    kind_of_survey: str
    rf_survey: str
    released: bool
    release_date: datetime
    closed: bool
    fields: List[SurveyFieldsOut]
    user_created: int
    model_config = {"from_attributes": True}
    #
class SurveyList(BaseModel):
    id: int
    kind_of_survey: str
    rf_survey: str
    released: bool
    closed: bool
    release_date: datetime
    user_created: int

    model_config = {"from_attributes": True}

class SurveyFieldIn(BaseModel):
    field_text: str

class SurveyIn(BaseModel):
    kind_of_survey: str
    rf_survey: str
    released: bool
    closed: bool
    fields: List[SurveyFieldIn]  # Nur die Feldtexte beim Anlegen


class SurveyFieldAppendIn(BaseModel):
    field_text: str = Field(..., min_length=1)

    @field_validator("field_text", mode="before")
    @classmethod
    def strip_field_text(cls, value):
        if not isinstance(value, str):
            return value
        stripped = value.strip()
        if not stripped:
            raise ValueError("field_text must not be empty")
        return stripped


class SurveyFieldsAppendIn(BaseModel):
    fields: List[SurveyFieldAppendIn] = Field(..., min_length=1)


class PublicSongHistogram(BaseModel):
    genre: str
    count: int

class PublicDate(BaseModel):
    Datum: str
    Name: str
    Ort: str
    Einlass: Optional[str] = None
    Beginn: Optional[str] = None
    Ende: Optional[str] = None
    Veranstalter: Optional[str] = None
    Art: Optional[str] = None

    @classmethod
    def from_gig(cls, gig):
        return cls(
            Datum=gig.datum.strftime('%Y-%m-%d') if gig.datum else None,
            Name=gig.name,
            Ort=gig.venue or "",
            Einlass=gig.doors.strftime('%H:%M') if gig.doors else None,
            Beginn=gig.begin.strftime('%H:%M') if gig.begin else None,
            Ende=gig.end.strftime('%H:%M') if gig.end else None,
            Veranstalter=gig.organizer or "",
            Art=gig.kind_of_gig or ""
        )



