import json

import pytest

import backend.app_config as app_config_module


@pytest.fixture
def temp_app_config_file(monkeypatch, tmp_path):
    original_path = app_config_module._config_path
    source_config = app_config_module.get_config()

    tmp_config_path = tmp_path / "appConfig.json"
    tmp_config_path.write_text(json.dumps(source_config, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    monkeypatch.setattr(app_config_module, "_config_path", tmp_config_path)
    app_config_module.load_config()

    try:
        yield tmp_config_path
    finally:
        monkeypatch.setattr(app_config_module, "_config_path", original_path)
        app_config_module.load_config()


def test_admin_can_get_soft_config(client, test_user, auth_headers, temp_app_config_file):
    response = client.get("/admin/config/soft", headers=auth_headers)

    assert response.status_code == 200
    body = response.json()
    assert "data" in body
    assert "meta" in body
    assert set(body["meta"]["editableKeys"]) == set(app_config_module.SOFT_CONFIG_KEYS)
    assert "updatedAt" in body["meta"]


def test_non_admin_get_soft_config_forbidden(client, test_user2, auth_headers2, temp_app_config_file):
    response = client.get("/admin/config/soft", headers=auth_headers2)
    assert response.status_code == 403


def test_admin_can_update_soft_config(client, test_user, auth_headers, temp_app_config_file):
    payload = {
        "genres": [{"key": "Rock", "label": "Rock"}, "Pop"],
        "gigTypes": [{"key": "Club", "label": "Club"}],
        "songStatuses": [{"key": "neu", "label": "Neu"}],
        "gigStatuses": [{"key": "angefragt", "label": "Angefragt"}],
        "tonekeys": [{"key": None, "label": ""}, {"key": "C", "label": "C"}],
        "rehearsalSongStatuses": ["neu", "in arbeit", "fertig"],
        "danceStyles": [{"key": "Walzer", "label": "Walzer"}],
        "setlist_timing": [
            {"DEFAULT_SONG_DURATION_SECONDS": 250},
            {"DEFAULT_INTER_SONG_BREAK_SECONDS": 35},
            {"DEFAULT_SET_PAUSE_SECONDS": 620},
        ],
    }

    response = client.put("/admin/config/soft", headers=auth_headers, json=payload)

    assert response.status_code == 200
    body = response.json()
    assert body["message"] == "Soft config updated"
    assert body["data"]["genres"][1] == {"key": "Pop", "label": "Pop"}

    stored = json.loads(temp_app_config_file.read_text(encoding="utf-8"))
    assert stored["gigTypes"] == [{"key": "Club", "label": "Club"}]
    assert stored["rehearsalSongStatuses"] == ["neu", "in arbeit", "fertig"]
    assert stored["setlist_timing"] == [
        {"DEFAULT_SONG_DURATION_SECONDS": 250},
        {"DEFAULT_INTER_SONG_BREAK_SECONDS": 35},
        {"DEFAULT_SET_PAUSE_SECONDS": 620},
    ]


def test_admin_update_soft_config_validation_error(client, test_user, auth_headers, temp_app_config_file):
    payload = {
        "genres": [{"key": "", "label": "Leer"}],
        "gigTypes": [],
        "songStatuses": [],
        "gigStatuses": [],
        "tonekeys": [],
        "rehearsalSongStatuses": [],
        "danceStyles": [],
        "setlist_timing": [
            {"DEFAULT_SONG_DURATION_SECONDS": 240},
            {"DEFAULT_INTER_SONG_BREAK_SECONDS": 30},
            {"DEFAULT_SET_PAUSE_SECONDS": 600},
        ],
    }

    response = client.put("/admin/config/soft", headers=auth_headers, json=payload)

    assert response.status_code == 400
    assert "genres" in response.json()["detail"]


def test_public_app_config_reflects_admin_update(client, test_user, auth_headers, temp_app_config_file):
    payload = {
        "genres": [{"key": "Synthpop", "label": "Synthpop"}],
        "gigTypes": [{"key": "Open Air", "label": "Open Air"}],
        "songStatuses": [{"key": "bereit", "label": "Bereit"}],
        "gigStatuses": [{"key": "fix", "label": "Fix"}],
        "tonekeys": [{"key": None, "label": ""}, {"key": "Dm", "label": "Dm"}],
        "rehearsalSongStatuses": ["neu"],
        "danceStyles": [{"key": "Tango", "label": "Tango"}],
        "setlist_timing": [
            {"DEFAULT_SONG_DURATION_SECONDS": 300},
            {"DEFAULT_INTER_SONG_BREAK_SECONDS": 25},
            {"DEFAULT_SET_PAUSE_SECONDS": 700},
        ],
    }

    put_response = client.put("/admin/config/soft", headers=auth_headers, json=payload)
    assert put_response.status_code == 200

    get_response = client.get("/public/app_config")
    assert get_response.status_code == 200
    data = get_response.json()
    assert data["genres"] == [{"key": "Synthpop", "label": "Synthpop"}]
    assert data["rehearsalSongStatuses"] == ["neu"]
    assert data["setlist_timing"] == [
        {"DEFAULT_SONG_DURATION_SECONDS": 300},
        {"DEFAULT_INTER_SONG_BREAK_SECONDS": 25},
        {"DEFAULT_SET_PAUSE_SECONDS": 700},
    ]

