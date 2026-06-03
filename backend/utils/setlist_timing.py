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

from backend.app_config import get_config

_DEFAULT_SONG_DURATION_SECONDS = 240
_DEFAULT_INTER_SONG_BREAK_SECONDS = 30
_DEFAULT_SET_PAUSE_SECONDS = 600

_SETLIST_DEFAULT_KEYS = {
    "DEFAULT_SONG_DURATION_SECONDS": _DEFAULT_SONG_DURATION_SECONDS,
    "DEFAULT_INTER_SONG_BREAK_SECONDS": _DEFAULT_INTER_SONG_BREAK_SECONDS,
    "DEFAULT_SET_PAUSE_SECONDS": _DEFAULT_SET_PAUSE_SECONDS,
}


def _normalize_seconds(value: Any, fallback: int) -> int:
    if isinstance(value, bool):
        return fallback
    if isinstance(value, int):
        return value if value >= 0 else fallback
    if isinstance(value, float):
        if value.is_integer() and value >= 0:
            return int(value)
        return fallback
    if isinstance(value, str):
        stripped = value.strip()
        if not stripped:
            return fallback
        try:
            parsed = int(stripped)
        except ValueError:
            return fallback
        return parsed if parsed >= 0 else fallback
    return fallback


def _timing_seconds_from_config(config: dict[str, Any]) -> dict[str, int]:
    resolved = dict(_SETLIST_DEFAULT_KEYS)
    entries = config.get("setlist_timing")
    if not isinstance(entries, list):
        return resolved

    for item in entries:
        if not isinstance(item, dict):
            continue
        for key, fallback in _SETLIST_DEFAULT_KEYS.items():
            if key in item:
                resolved[key] = _normalize_seconds(item[key], fallback)

    return resolved


def _get_setlist_timing_defaults() -> tuple[timedelta, timedelta, timedelta]:
    config = get_config()
    timing_seconds = _timing_seconds_from_config(config)

    return (
        timedelta(seconds=timing_seconds["DEFAULT_SONG_DURATION_SECONDS"]),
        timedelta(seconds=timing_seconds["DEFAULT_INTER_SONG_BREAK_SECONDS"]),
        timedelta(seconds=timing_seconds["DEFAULT_SET_PAUSE_SECONDS"]),
    )


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


def song_duration_to_timedelta(duration: Any, fallback: timedelta | None = None) -> timedelta:
    if fallback is None:
        fallback, _, _ = _get_setlist_timing_defaults()
    return _time_like_to_timedelta(duration, fallback)


def pause_to_timedelta(pause: Any, fallback: timedelta | None = None) -> timedelta:
    if fallback is None:
        _, _, fallback = _get_setlist_timing_defaults()
    return _time_like_to_timedelta(pause, fallback)


def _setsong_duration_to_timedelta(setsong: Any, fallback: timedelta) -> timedelta:
    # Skipped songs should not consume runtime in schedule calculations.
    if getattr(setsong, "uebersprungen", False):
        return timedelta(0)
    return song_duration_to_timedelta(setsong.song.duration, fallback)


def get_pause_before_set(
    previous_gigset: Any,
    current_gigset: Any,
    schedule: dict[int, list[datetime]],
    default_song_duration: timedelta | None = None,
) -> int | None:
    """Return pause minutes between two sets based on the schedule used by the PDF."""
    if not previous_gigset or not current_gigset:
        return None

    prev_times = schedule.get(previous_gigset.position, [])
    curr_times = schedule.get(current_gigset.position, [])
    if not prev_times or not curr_times:
        return None

    prev_setsongs = sorted(previous_gigset.set.songs, key=lambda ss: ss.position)
    if prev_setsongs:
        prev_last_duration = _setsong_duration_to_timedelta(
            prev_setsongs[-1],
            default_song_duration,
        )
    else:
        prev_last_duration = timedelta(0)

    prev_end = prev_times[-1] + prev_last_duration
    curr_start = curr_times[0]
    pause = int(round((curr_start - prev_end).total_seconds() / 60))
    return pause if pause > 0 else None


def calculate_setlist_timing(gig: Any) -> dict[str, Any]:
    """Calculate start times per song and per-set pause values."""
    default_song_duration, default_inter_song_break, default_set_pause = _get_setlist_timing_defaults()
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
            duration = _setsong_duration_to_timedelta(setsong, default_song_duration)
            current_time = current_time + duration + default_inter_song_break

        if set_songs and schedule[gigset.position]:
            last_song_start = schedule[gigset.position][-1]
            last_song_duration = _setsong_duration_to_timedelta(
                set_songs[-1],
                default_song_duration,
            )
            set_end[gigset.position] = last_song_start + last_song_duration

        if idx < len(gig_sets_sorted) - 1:
            current_time = current_time + pause_to_timedelta(set_obj.pause, default_set_pause)

    pause_before: dict[int, int] = {}
    for idx in range(1, len(gig_sets_sorted)):
        pause = get_pause_before_set(
            gig_sets_sorted[idx - 1],
            gig_sets_sorted[idx],
            schedule,
            default_song_duration,
        )
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



