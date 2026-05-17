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

"""Shared timing calculation for setlist views and PDF rendering."""

from __future__ import annotations

from collections import defaultdict
from datetime import datetime, time, timedelta
from typing import Any

DEFAULT_SONG_DURATION = timedelta(minutes=4)
DEFAULT_INTER_SONG_BREAK = timedelta(seconds=30)
DEFAULT_SET_PAUSE = timedelta(minutes=10)


def _time_like_to_timedelta(value: Any, fallback: timedelta) -> timedelta:
    if value is None:
        return fallback
    if isinstance(value, timedelta):
        return value
    if isinstance(value, time):
        return timedelta(hours=value.hour, minutes=value.minute, seconds=value.second)
    if isinstance(value, str):
        parts = value.split(":")
        try:
            if len(parts) == 2:
                hours, minutes = map(int, parts)
                seconds = 0
            elif len(parts) == 3:
                hours, minutes, seconds = map(int, parts)
            else:
                return fallback
            return timedelta(hours=hours, minutes=minutes, seconds=seconds)
        except ValueError:
            return fallback
    return fallback


def song_duration_to_timedelta(duration: Any) -> timedelta:
    return _time_like_to_timedelta(duration, DEFAULT_SONG_DURATION)


def pause_to_timedelta(pause: Any) -> timedelta:
    return _time_like_to_timedelta(pause, DEFAULT_SET_PAUSE)


def get_pause_before_set(previous_gigset: Any, current_gigset: Any, schedule: dict[int, list[datetime]]) -> int | None:
    """Return pause minutes between two sets based on the schedule used by the PDF."""
    if not previous_gigset or not current_gigset:
        return None

    prev_times = schedule.get(previous_gigset.position, [])
    curr_times = schedule.get(current_gigset.position, [])
    if not prev_times or not curr_times:
        return None

    prev_setsongs = sorted(previous_gigset.set.songs, key=lambda ss: ss.position)
    if prev_setsongs:
        prev_last_duration = song_duration_to_timedelta(prev_setsongs[-1].song.duration)
    else:
        prev_last_duration = timedelta(0)

    prev_end = prev_times[-1] + prev_last_duration
    curr_start = curr_times[0]
    pause = int(round((curr_start - prev_end).total_seconds() / 60))
    return pause if pause > 0 else None


def calculate_setlist_timing(gig: Any) -> dict[str, Any]:
    """Calculate start times per song and per-set pause values."""
    gig_start = datetime.combine(gig.datum, gig.begin or time(19, 0))
    schedule: dict[int, list[datetime]] = defaultdict(list)
    set_end: dict[int, datetime] = {}
    current_time = gig_start

    gig_sets_sorted = sorted(gig.sets, key=lambda gs: gs.position)
    for idx, gigset in enumerate(gig_sets_sorted):
        set_obj = gigset.set
        set_songs = sorted(set_obj.songs, key=lambda ss: ss.position)
        for setsong in set_songs:
            schedule[gigset.position].append(current_time)
            duration = song_duration_to_timedelta(setsong.song.duration)
            current_time = current_time + duration + DEFAULT_INTER_SONG_BREAK

        if set_songs and schedule[gigset.position]:
            last_song_start = schedule[gigset.position][-1]
            last_song_duration = song_duration_to_timedelta(set_songs[-1].song.duration)
            set_end[gigset.position] = last_song_start + last_song_duration

        if idx < len(gig_sets_sorted) - 1:
            current_time = current_time + pause_to_timedelta(set_obj.pause)

    pause_before: dict[int, int] = {}
    for idx in range(1, len(gig_sets_sorted)):
        pause = get_pause_before_set(gig_sets_sorted[idx - 1], gig_sets_sorted[idx], schedule)
        if pause is not None:
            pause_before[gig_sets_sorted[idx].position] = pause

    return {
        "schedule": dict(schedule),
        "pause_before": pause_before,
        "set_end": set_end,
    }


def serialize_timing_for_api(timing: dict[str, Any]) -> dict[str, dict[str, Any]]:
    """Convert timing data to JSON-serialisable payload for API responses."""
    schedule = timing.get("schedule", {})
    pause_before = timing.get("pause_before", {})
    set_end = timing.get("set_end", {})

    return {
        "schedule": {
            str(set_position): [start.strftime("%H:%M") for start in starts]
            for set_position, starts in schedule.items()
        },
        "pause_before": {str(set_position): minutes for set_position, minutes in pause_before.items()},
        "set_end": {
            str(set_position): end.strftime("%H:%M")
            for set_position, end in set_end.items()
        },
    }



