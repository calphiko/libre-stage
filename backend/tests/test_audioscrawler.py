import backend.utils.audioscrawler as audioscrawler


class _MockResponse:
    def __init__(self, payload):
        self._payload = payload

    def raise_for_status(self):
        return None

    def json(self):
        return self._payload


def test_search_track_musicbrainz_with_mocked_api(monkeypatch):
    calls = []

    def fake_get(url, params=None, headers=None, timeout=None):
        calls.append((url, params))

        if url == "https://musicbrainz.org/ws/2/recording":
            return _MockResponse(
                {
                    "recordings": [
                        {
                            "id": "rec-1",
                            "title": "Always",
                            "length": 188000,
                            "score": "100",
                            "artist-credit": [{"artist": {"name": "Bon Jovi"}}],
                        }
                    ]
                }
            )

        if url == "https://musicbrainz.org/ws/2/recording/rec-1":
            return _MockResponse(
                {
                    "relations": [
                        {"type": "performance", "work": {"id": "work-1"}},
                        {"type": "streaming music", "url": {"resource": "https://www.youtube.com/watch?v=test123"}},
                    ]
                }
            )

        if url == "https://musicbrainz.org/ws/2/work/work-1":
            return _MockResponse(
                {
                    "relations": [
                        {
                            "type": "writer",
                            "artist": {
                                "name": "Texter und Komponist(in): Richard Z. Kruspe, Paul Landers, Till Lindemann, Christian Lorenz (keyboardist), Oliver Riedel und Christoph Schneider (Rammstein drummer)"
                            },
                        }
                    ]
                }
            )

        raise AssertionError(f"Unexpected URL called: {url}")

    monkeypatch.setattr(audioscrawler, "get", fake_get)
    monkeypatch.setattr(audioscrawler, "sleep", lambda _: None)

    result = audioscrawler.search_track_musicbrainz("Bon Jovi", "Always")

    assert result == {
        "recording_id": "rec-1",
        "duration": "00:03:08",
        "work_id": "work-1",
        "ytlink": "https://www.youtube.com/watch?v=test123",
        "composers": [
            "Christian Lorenz",
            "Christoph Schneider",
            "Oliver Riedel",
            "Paul Landers",
            "Richard Z. Kruspe",
            "Till Lindemann",
        ],
        "lyricists": [
            "Christian Lorenz",
            "Christoph Schneider",
            "Oliver Riedel",
            "Paul Landers",
            "Richard Z. Kruspe",
            "Till Lindemann",
        ],
    }

    assert len(calls) == 3


def test_search_track_musicbrainz_returns_none_on_request_exception(monkeypatch):
    def fake_get(*args, **kwargs):
        raise audioscrawler.RequestException("network down")

    monkeypatch.setattr(audioscrawler, "get", fake_get)

    assert audioscrawler.search_track_musicbrainz("Bon Jovi", "Always") is None


def test_search_track_musicbrainz_extracts_ytlink_from_related_release(monkeypatch):
    def fake_get(url, params=None, headers=None, timeout=None):
        if url == "https://musicbrainz.org/ws/2/recording":
            return _MockResponse(
                {
                    "recordings": [
                        {
                            "id": "rec-2",
                            "title": "Always",
                            "length": 188000,
                            "artist-credit": [{"artist": {"name": "Bon Jovi"}}],
                        }
                    ]
                }
            )

        if url == "https://musicbrainz.org/ws/2/recording/rec-2":
            return _MockResponse(
                {
                    "relations": [{"type": "performance", "work": {"id": "work-2"}}],
                    "releases": [{"id": "rel-1"}],
                }
            )

        if url == "https://musicbrainz.org/ws/2/release/rel-1":
            return _MockResponse(
                {
                    "relations": [
                        {
                            "type": "streaming music",
                            "url": {"resource": "https://youtu.be/relatedRelease"},
                        }
                    ],
                    "release-group": {"id": "rg-1"},
                }
            )

        if url == "https://musicbrainz.org/ws/2/work/work-2":
            return _MockResponse({"relations": []})

        raise AssertionError(f"Unexpected URL called: {url}")

    monkeypatch.setattr(audioscrawler, "get", fake_get)
    monkeypatch.setattr(audioscrawler, "sleep", lambda _: None)

    result = audioscrawler.search_track_musicbrainz("Bon Jovi", "Always")

    assert result["ytlink"] == "https://youtu.be/relatedRelease"



