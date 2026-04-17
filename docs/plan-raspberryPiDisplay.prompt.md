# Plan: Raspberry Pi Musiker-Display (Python GUI + Polling)

**TL;DR:** Finaler Plan mit zwei klaren Branches. `dev` → später Merge in `main`. `rPi` bleibt dauerhaft eigenständig. Gig-Auswahl zeigt Gigs ab 12h vor aktuellem Zeitpunkt. CI im `rPi`-Branch ist eine schlanke, eigenständige Woodpecker-Config ohne Docs-Deploy.

---

## Branch: `dev` → merge in `main`

### 1. DB-Modell & Migration
`current_setsong_id` (Integer, nullable, FK → `set_songs.id`) und `setlist_revision` (Integer, default 0) zur Klasse `Gig` in `backend/models.py` ergänzen. Neue Alembic-Migration in `backend/alembic/versions/` erstellen.

### 2. Neue Endpoints in `backend/routers/gigs_livemode.py`
- `PUT /{gig_id}/current` (editor-only): setzt `current_setsong_id` am Gig. Schema `SetCurrentSongIn` in `backend/schemas.py`.
- `GET /{gig_id}/status` (alle authentifizierten User, **kein** `check_editor`): gibt `{ revision, current_setsong_id, current_title, current_interpret, current_tone_key, next_title, next_interpret }` zurück. Schema `GigLiveStatus` in `backend/schemas.py`. Die bestehenden Schreibvorgänge `update_songs_lm` und `insert_song_after` inkrementieren zusätzlich `setlist_revision`.

### 3. Frontend anpassen
`setCurrentSong(gigId, setsongId)` in `frontend/src/lib/api.js` ergänzen. In `frontend/src/lib/components/LiveModeModal.svelte` bei `goNext()`, `goPrev()` und `jumpToSong()` fire-and-forget aufrufen.

### 4. Backend-Tests in `backend/tests/`
- `GET /{gig_id}/status`: unauthentifiziert → 401, `user`-Rolle → 200, korrekter `next`-Song-Inhalt.
- `PUT /{gig_id}/current`: editor → 200, user → 403.

Laufen automatisch im bestehenden CI-Step `test-and-coverage` in `.woodpecker.yml`.

---

## Branch: `rPi` – dauerhaft eigenständig

### 5. Repo-Struktur `pi-display/`
Eigenständiges Paket mit eigenem `pyproject.toml`:
- Laufzeit-Abhängigkeiten: `requests`
- Test-Gruppe: `pytest`, `pytest-cov`, `responses`

Eigenes `uv.lock`. Eigene `.woodpecker.yml` im `rPi`-Branch – **nur** ein einziger Step:

```yaml
steps:
  - name: test-pi-display
    image: python:3.14
    commands:
      - pip install uv
      - cd pi-display
      - uv sync --all-groups
      - uv run pytest --cov=pi_display --cov-report=term
```

Der `build-and-deploy-docs`-Step aus `main` wird **nicht** übernommen. Woodpecker führt immer die `.woodpecker.yml` des jeweiligen Branches aus – kein Konflikt.

### 6. Auth-Client `pi-display/auth_client.py`
- `login(url, user, pw)` → speichert `access_token` + `refresh_token`.
- Wrapper-Methoden `get(path)` / `put(path, data)`: bei 401 automatisch `POST /refresh` aufrufen, neues `access_token` speichern, Request einmalig wiederholen. Schlägt der zweite Versuch ebenfalls fehl → Exception weitergeben.
- Refresh-Token läuft 30 Tage – für einen Abend absolut stabil.

### 7. tkinter GUI `pi-display/main.py` – drei Screens via `tk.Frame`-Stack

**Login-Screen:**
- Felder für Server-URL, Username, Passwort.
- Bei Erfolg in `config.ini` persistiert (nächster Start überspringt diesen Screen automatisch).

**Gig-Auswahl-Screen:**
- `GET /gigs` → clientseitig filtern: `datetime.combine(gig.datum, time(0,0)) >= now - timedelta(hours=12)`.
- Deckt laufende Abendgigs ab; Gigs von vorgestern nicht mehr sichtbar.
- Scrollbare Klickliste, sortiert aufsteigend nach Datum.

**Display-Screen:**
- Fullscreen-Modus.
- Aktueller Song groß (Titel + Tonart), nächster Song kleiner darunter.
- Polling alle 3s via `root.after(3000, poll)` → `GET /gigs_lm/{gig_id}/status`.
- Bei geänderter `revision` → 5s gelber Hintergrund als visuelle Warnung vor Setlisten-Änderung.
- Bei Verbindungsfehler → `⚠ Offline`-Label in der Ecke, letzter bekannter Song bleibt sichtbar.

### 8. Tests `pi-display/tests/`
- `auth_client.py`: 401-Retry-Flow, Token-Refresh erfolgreich, gescheiterter zweiter Retry löst Exception aus.
- Poll-Logik: gemockte HTTP-Responses via `responses`-Library, `revision`-Änderung löst Highlight aus, Verbindungsfehler setzt Offline-Status.

### 9. Setup-Doku `pi-display/README.md`
- Clone `rPi`-Branch, `uv sync`, `config.ini.example` kopieren und anpassen.
- Autostart-Beispiel via `systemd`-User-Service.

---

## Hinweise & Randbedingungen

1. **Gig-Filterung `datum >= heute - 12h`:** `GET /gigs` liefert das Datum (`YYYY-MM-DD`) ohne Uhrzeit. Der Pi vergleicht `datetime.combine(gig.datum, time(0,0)) >= now - timedelta(hours=12)`. Gigs, die gestern Abend starteten und jetzt noch laufen, sind damit eingeschlossen – Gigs von vorgestern nicht mehr.

2. **Branch-Merge-Strategie:** `rPi` wird nie in `dev` oder `main` gemergt. Die `.woodpecker.yml` im `rPi`-Branch wird vollständig durch die schlanke Pi-CI-Config ersetzt – da Woodpecker immer die Datei des jeweiligen Branches ausführt, entsteht kein Konflikt mit dem `build-and-deploy-docs`-Step in `main`.

3. **`check_editor`-Guard beim Status-Endpoint:** Der bestehende `GET /{gig_id}` erfordert `editor`-Rechte. Der neue `GET /{gig_id}/status` ist für normale `user`-Accounts erreichbar, damit Pi-Konten keine Editor-Rechte benötigen.

4. **Jedes Gerät mit eigenem User-Account:** Jeder Pi authentifiziert sich mit dem User-Account des jeweiligen Musikers. Kein geteilter Service-Account notwendig.

