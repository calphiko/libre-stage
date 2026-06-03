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
    ``tonekeys``, ``rehearsalSongStatuses``, ``setlist_timing``
"""

import json
import sys
import logging
import tempfile
from copy import deepcopy
from pathlib import Path
from threading import RLock
from datetime import datetime, timezone

logger = logging.getLogger("uvicorn.error")

_config_path = Path(__file__).parent.parent / "config/appConfig.json"

_REQUIRED_KEYS = [
    "genres",
    "gigTypes",
    "songStatuses",
    "gigStatuses",
    "tonekeys",
    "rehearsalSongStatuses",
    "setlist_timing",
]

SOFT_CONFIG_KEYS = tuple(_REQUIRED_KEYS)
_OBJECT_SOFT_KEYS = {"genres", "gigTypes", "songStatuses", "gigStatuses", "tonekeys"}
_STRING_SOFT_KEYS = {"rehearsalSongStatuses"}
_SETLIST_TIMING_SOFT_KEYS = {"setlist_timing"}
_SETLIST_TIMING_KEYS = (
    "DEFAULT_SONG_DURATION_SECONDS",
    "DEFAULT_INTER_SONG_BREAK_SECONDS",
    "DEFAULT_SET_PAUSE_SECONDS",
)


class ConfigValidationError(ValueError):
    """Raised when admin-provided soft config payload is invalid."""


_config_lock = RLock()
app_config: dict = {}


def _validate_required_keys(config: dict) -> None:
    missing = [k for k in _REQUIRED_KEYS if k not in config]
    if missing:
        raise ConfigValidationError(f"appConfig.json ist unvollstaendig! Fehlende Keys: {', '.join(missing)}")


def _load_config_from_disk() -> dict:
    with open(_config_path, "r", encoding="utf-8") as f:
        config = json.load(f)
    if not isinstance(config, dict):
        raise ConfigValidationError("appConfig.json muss ein JSON-Objekt sein")
    _validate_required_keys(config)
    return config


def load_config() -> dict:
    """Load appConfig.json into the module-global config dict."""
    with _config_lock:
        loaded = _load_config_from_disk()
        app_config.clear()
        app_config.update(loaded)
        logger.info(f"App config loaded from: {_config_path}")
        return deepcopy(app_config)


def get_config() -> dict:
    """Return a deep copy of the full application configuration."""
    with _config_lock:
        return deepcopy(app_config)


def get_soft_config() -> dict:
    """Return only admin-editable soft config keys."""
    with _config_lock:
        return {key: deepcopy(app_config[key]) for key in SOFT_CONFIG_KEYS}


def get_soft_config_updated_at() -> str:
    """Return the last modification time of appConfig.json in ISO8601."""
    try:
        ts = _config_path.stat().st_mtime
        return datetime.fromtimestamp(ts, tz=timezone.utc).isoformat().replace("+00:00", "Z")
    except OSError:
        return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _normalize_object_list_item(key: str, item):
    if isinstance(item, str):
        stripped = item.strip()
        if not stripped:
            return None
        return {"key": stripped, "label": stripped}

    if not isinstance(item, dict):
        raise ConfigValidationError(f"{key}: Eintraege muessen String oder Objekt sein")

    key_val = item.get("key")
    label_val = item.get("label", key_val)

    if isinstance(key_val, str):
        key_val = key_val.strip()
    if isinstance(label_val, str):
        label_val = label_val.strip()

    if key == "tonekeys" and key_val is None:
        if label_val is None:
            label_val = ""
        if not isinstance(label_val, str):
            raise ConfigValidationError("tonekeys: label muss String sein")
        return {"key": None, "label": label_val}

    if not isinstance(key_val, str) or not key_val:
        raise ConfigValidationError(f"{key}: key muss ein nicht-leerer String sein")

    if not isinstance(label_val, str) or not label_val:
        label_val = key_val

    return {"key": key_val, "label": label_val}


def _normalize_string_list_item(key: str, item):
    if isinstance(item, str):
        stripped = item.strip()
        return stripped or None

    if isinstance(item, dict):
        value = item.get("key", item.get("label"))
        if isinstance(value, str):
            stripped = value.strip()
            return stripped or None

    raise ConfigValidationError(f"{key}: Eintraege muessen Strings sein")


def _normalize_setlist_timing_entry(item):
    if not isinstance(item, dict) or len(item) != 1:
        raise ConfigValidationError(
            "setlist_timing: Jeder Eintrag muss ein Objekt mit genau einem Timing-Key sein"
        )

    timing_key, raw_value = next(iter(item.items()))
    if timing_key not in _SETLIST_TIMING_KEYS:
        raise ConfigValidationError(
            f"setlist_timing: Unbekannter Timing-Key '{timing_key}'"
        )

    if isinstance(raw_value, bool):
        raise ConfigValidationError(
            f"setlist_timing: '{timing_key}' muss eine Zahl in Sekunden sein"
        )

    if isinstance(raw_value, str):
        raw_value = raw_value.strip()
        if not raw_value:
            raise ConfigValidationError(
                f"setlist_timing: '{timing_key}' darf nicht leer sein"
            )
        try:
            value = int(raw_value)
        except ValueError as exc:
            raise ConfigValidationError(
                f"setlist_timing: '{timing_key}' muss eine ganze Zahl sein"
            ) from exc
    elif isinstance(raw_value, float):
        if not raw_value.is_integer():
            raise ConfigValidationError(
                f"setlist_timing: '{timing_key}' muss eine ganze Zahl sein"
            )
        value = int(raw_value)
    elif isinstance(raw_value, int):
        value = raw_value
    else:
        raise ConfigValidationError(
            f"setlist_timing: '{timing_key}' muss eine ganze Zahl sein"
        )

    if value < 0:
        raise ConfigValidationError(
            f"setlist_timing: '{timing_key}' darf nicht negativ sein"
        )

    return timing_key, value


def _normalize_soft_list(key: str, value):
    if not isinstance(value, list):
        raise ConfigValidationError(f"{key}: Wert muss eine Liste sein")

    normalized = []
    seen = set()

    if key in _OBJECT_SOFT_KEYS:
        for item in value:
            normalized_item = _normalize_object_list_item(key, item)
            if normalized_item is None:
                continue
            dedupe_token = (normalized_item.get("key"), normalized_item.get("label"))
            if dedupe_token in seen:
                continue
            seen.add(dedupe_token)
            normalized.append(normalized_item)
        return normalized

    if key in _STRING_SOFT_KEYS:
        for item in value:
            normalized_item = _normalize_string_list_item(key, item)
            if normalized_item is None or normalized_item in seen:
                continue
            seen.add(normalized_item)
            normalized.append(normalized_item)
        return normalized

    if key in _SETLIST_TIMING_SOFT_KEYS:
        timing_values = {}
        for item in value:
            timing_key, timing_seconds = _normalize_setlist_timing_entry(item)
            timing_values[timing_key] = timing_seconds

        missing = [timing_key for timing_key in _SETLIST_TIMING_KEYS if timing_key not in timing_values]
        if missing:
            raise ConfigValidationError(
                "setlist_timing: Fehlende Timing-Keys: " + ", ".join(missing)
            )

        return [{timing_key: timing_values[timing_key]} for timing_key in _SETLIST_TIMING_KEYS]

    raise ConfigValidationError(f"Nicht editierbarer Key: {key}")


def _write_config_atomic(config: dict) -> None:
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        dir=_config_path.parent,
        delete=False,
        suffix=".tmp",
    ) as tmp:
        json.dump(config, tmp, ensure_ascii=False, indent=2)
        tmp.write("\n")
        temp_path = Path(tmp.name)

    temp_path.replace(_config_path)


def update_soft_config(payload: dict) -> dict:
    """Validate, persist and reload the editable soft config keys."""
    if not isinstance(payload, dict):
        raise ConfigValidationError("Payload muss ein JSON-Objekt sein")

    keys = set(payload.keys())
    allowed = set(SOFT_CONFIG_KEYS)

    unknown_keys = sorted(keys - allowed)
    if unknown_keys:
        raise ConfigValidationError(f"Unbekannte Keys: {', '.join(unknown_keys)}")

    missing_keys = sorted(allowed - keys)
    if missing_keys:
        raise ConfigValidationError(f"Fehlende Keys: {', '.join(missing_keys)}")

    normalized = {key: _normalize_soft_list(key, payload[key]) for key in SOFT_CONFIG_KEYS}

    with _config_lock:
        current = _load_config_from_disk()
        current.update(normalized)
        _validate_required_keys(current)
        _write_config_atomic(current)
        app_config.clear()
        app_config.update(current)

    return get_soft_config()

try:
    load_config()
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
except ConfigValidationError as e:
    print(
        f"\n{'=' * 60}\n"
        f"FATAL: appConfig.json ist unvollstaendig oder ungueltig!\n"
        f"Fehler: {e}\n"
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
    return get_soft_config()
