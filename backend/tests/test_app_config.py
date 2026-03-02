import pytest
from fastapi.testclient import TestClient
from backend.main import app

client = TestClient(app)

def test_app_config_endpoint():
    """Test that /public/app_config returns correct data with caching header."""
    r = client.get('/public/app_config')
    assert r.status_code == 200
    assert r.headers.get('cache-control') == 'public, max-age=300'
    data = r.json()
    assert 'genres' in data
    assert 'gigTypes' in data
    assert 'songStatuses' in data
    assert 'gigStatuses' in data
    assert 'tonekeys' in data
    assert 'rehearsalSongStatuses' in data
    # Ensure no backend-only keys leak
    assert 'ical_domain' not in data
    assert 'timezone' not in data

