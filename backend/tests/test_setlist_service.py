from datetime import date, time
from types import SimpleNamespace
from unittest.mock import Mock

from sqlalchemy.orm import Session

from backend.services.setlist import SetlistService
from backend.utils import setlist_timing


def test_dump_gig_struct_prints_slot_duration_and_zero_for_skipped(monkeypatch, capsys):
    monkeypatch.setattr(
        setlist_timing,
        "get_config",
        lambda: {
            "setlist_timing": [
                {"DEFAULT_SONG_DURATION_SECONDS": 240},
                {"DEFAULT_INTER_SONG_BREAK_SECONDS": 30},
                {"DEFAULT_SET_PAUSE_SECONDS": 600},
            ]
        },
    )

    set_obj = SimpleNamespace(
        id=1,
        setlist_name="Test-Set",
        pause=None,
        songs=[
            SimpleNamespace(
                position=1,
                song=SimpleNamespace(title="Song A", singer_lead="Vox", duration="00:04:00"),
                uebersprungen=False,
                eingeschoben=False,
                feedback=0,
            ),
            SimpleNamespace(
                position=2,
                song=SimpleNamespace(title="Song B", singer_lead="Vox", duration="00:05:00"),
                uebersprungen=True,
                eingeschoben=False,
                feedback=0,
            ),
        ],
    )
    gig = SimpleNamespace(
        id=1,
        name="Testgig",
        datum=date(2026, 1, 1),
        begin=time(19, 0),
        sets=[SimpleNamespace(position=1, set=set_obj)],
    )

    service = SetlistService(session=Mock(spec=Session))
    service.dump_gig_struct(gig)

    output = capsys.readouterr().out
    assert "Song A / Vox / 00:04:30" in output
    assert "Song B / Vox / 00:00:00" in output



