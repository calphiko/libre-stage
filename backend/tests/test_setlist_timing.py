from datetime import date, time, timedelta
from types import SimpleNamespace

from backend.utils import setlist_timing


def test_timing_defaults_are_read_from_app_config(monkeypatch):
    monkeypatch.setattr(
        setlist_timing,
        "get_config",
        lambda: {
            "setlist_timing": [
                {"DEFAULT_SONG_DURATION_SECONDS": 300},
                {"DEFAULT_INTER_SONG_BREAK_SECONDS": 45},
                {"DEFAULT_SET_PAUSE_SECONDS": 720},
            ]
        },
    )

    assert setlist_timing.song_duration_to_timedelta(None) == timedelta(seconds=300)
    assert setlist_timing.pause_to_timedelta(None) == timedelta(seconds=720)


def test_timing_defaults_fallback_when_missing_config(monkeypatch):
    monkeypatch.setattr(setlist_timing, "get_config", lambda: {})

    assert setlist_timing.song_duration_to_timedelta(None) == timedelta(seconds=240)
    assert setlist_timing.pause_to_timedelta(None) == timedelta(seconds=600)


def test_calculate_setlist_timing_uses_configured_inter_song_break(monkeypatch):
    monkeypatch.setattr(
        setlist_timing,
        "get_config",
        lambda: {
            "setlist_timing": [
                {"DEFAULT_SONG_DURATION_SECONDS": 300},
                {"DEFAULT_INTER_SONG_BREAK_SECONDS": 45},
                {"DEFAULT_SET_PAUSE_SECONDS": 600},
            ]
        },
    )

    set_obj = SimpleNamespace(
        songs=[
            SimpleNamespace(position=1, song=SimpleNamespace(duration=None)),
            SimpleNamespace(position=2, song=SimpleNamespace(duration=None)),
        ],
        pause=None,
    )
    gig = SimpleNamespace(
        datum=date(2026, 1, 1),
        begin=time(19, 0),
        sets=[SimpleNamespace(position=1, set=set_obj)],
    )

    timing = setlist_timing.calculate_setlist_timing(gig)
    starts = timing["schedule"][1]

    assert len(starts) == 2
    assert (starts[1] - starts[0]) == timedelta(seconds=345)
    assert timing["set_end"][1] == starts[1] + timedelta(seconds=300)

