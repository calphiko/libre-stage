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
Application configuration loader.

Reads and validates ``appConfig.json`` from the project root on import.
If the file is missing, malformed or incomplete the application exits
immediately with a descriptive error message.

Required top-level keys in ``appConfig.json``:
    ``genres``, ``gigTypes``, ``songStatuses``, ``gigStatuses``,
    ``tonekeys``, ``rehearsalSongStatuses``
"""

import json
import sys
import logging
from pathlib import Path

logger = logging.getLogger("uvicorn.error")

_config_path = Path(__file__).parent.parent / "appConfig.json"

_REQUIRED_KEYS = [
    "genres",
    "gigTypes",
    "songStatuses",
    "gigStatuses",
    "tonekeys",
    "rehearsalSongStatuses",
]

try:
    with open(_config_path, "r", encoding="utf-8") as f:
        app_config: dict = json.load(f)
    logger.info(f"App config loaded from: {_config_path}")
except FileNotFoundError:
    print(
        f"\n{'=' * 60}\n"
        f"FATAL: appConfig.json nicht gefunden!\n"
        f"Erwarteter Pfad: {_config_path}\n\n"
        f"Bitte erstelle die Datei im Projekt-Root.\n"
        f"Eine Vorlage findest du in der Dokumentation.\n"
        f"{'=' * 60}\n",
        file=sys.stderr,
    )
    sys.exit(1)
except json.JSONDecodeError as e:
    print(
        f"\n{'=' * 60}\n"
        f"FATAL: appConfig.json enthält ungültiges JSON!\n"
        f"Pfad: {_config_path}\n"
        f"Fehler: {e}\n"
        f"{'=' * 60}\n",
        file=sys.stderr,
    )
    sys.exit(1)

# Prüfe ob alle erforderlichen Keys vorhanden sind
_missing = [k for k in _REQUIRED_KEYS if k not in app_config]
if _missing:
    print(
        f"\n{'=' * 60}\n"
        f"FATAL: appConfig.json ist unvollständig!\n"
        f"Fehlende Keys: {', '.join(_missing)}\n"
        f"Pfad: {_config_path}\n"
        f"{'=' * 60}\n",
        file=sys.stderr,
    )
    sys.exit(1)


def get_frontend_config() -> dict:
    """
    Return only the configuration keys relevant to the frontend.

    Returns:
        dict: A dictionary containing ``genres``, ``gigTypes``,
        ``songStatuses``, ``gigStatuses``, ``tonekeys`` and
        ``rehearsalSongStatuses``.
    """
    return {
        "genres": app_config["genres"],
        "gigTypes": app_config["gigTypes"],
        "songStatuses": app_config["songStatuses"],
        "gigStatuses": app_config["gigStatuses"],
        "tonekeys": app_config["tonekeys"],
        "rehearsalSongStatuses": app_config["rehearsalSongStatuses"],
    }
