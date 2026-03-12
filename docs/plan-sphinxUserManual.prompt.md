# Plan: Sphinx-Benutzerhandbuch (DE+EN) mit Codeberg Pages

Sphinx + `sphinx-rtd-theme` wird unter `docs/manual/` aufgesetzt. Deutsch ist Hauptsprache, Englisch wird als vollständige `gettext`-Übersetzung (`locales/en/`) manuell gepflegt. Screenshots werden als Platzhalter-Direktiven vorbereitet (`.. figure::`). Ein Woodpecker-Job baut beide Sprachversionen, legt sie versioniert ab und pushed in den `pages`-Branch. Die Version wird aus `version.json` ausgelesen.

## Schritte

- [x] **1. Abhängigkeiten** in `pyproject.toml` unter `[dependency-groups]` als neue `docs`-Gruppe ergänzen: `sphinx`, `sphinx-rtd-theme`, `sphinx-intl`, `sphinx-copybutton`.

- [x] **2. `docs/manual/conf.py`** anlegen mit:
  - `html_theme = 'sphinx_rtd_theme'`, `language = 'de'`
  - `gettext_compact = False`, `locale_dirs = ['locales/']`
  - `version` / `release` via Python aus `version.json` gelesen
  - `html_context` mit Versions-Liste für den RTD-Switcher (`latest`, `vX.Y.Z`)
  - `html_static_path = ['_static']`, Extension `sphinx_copybutton`
  - Dazu `Makefile` und `make.bat`

- [x] **3. `_static/screenshots/`-Verzeichnis** anlegen mit:
  - `.gitkeep`
  - `README.md` mit Liste aller erwarteten Screenshots (Dateiname, empfohlene Auflösung, Beschreibung) als Arbeitsanweisung

- [x] **4. Deutsche `.rst`-Inhalte** vollständig anlegen:
  - [x] `index.rst` — Titelseite, `toctree`, Kurzbeschreibung, `.. figure:: /_static/screenshots/overview.png`
  - [x] `installation.rst` — Voraussetzungen (Python 3.11+, Node 18+), Backend/Frontend-Setup, `.env` konfigurieren, Demo-DB starten, erster Login (Tabelle mit Demo-Accounts), Screenshot `login.png`
  - [x] `configuration.rst` — alle `.env`-Variablen als Tabelle, `appConfig.json`-Felder (Genres, Gig-Typen, Song-Status, Tonarten, Pausen), Frontend-Config
  - [x] `benutzerhandbuch/index.rst` — toctree für alle Unterseiten
  - [x] `benutzerhandbuch/dashboard.rst` — Todos-Tabs, Saison-Statistiken-Widget, Kalender-URL (iCal), Screenshot `dashboard.png`
  - [x] `benutzerhandbuch/gigs.rst` — Gig anlegen/bearbeiten (alle Felder: Name, Datum, Typ, Veranstalter, Location, Einlass/Beginn/Ende), Status-Workflow (`anfrage` → `angenommen` → `abgelehnt`), GEMA-Export (Excel-Format, übersprungene Songs werden ausgeschlossen), Setlist-PDF, Screenshot `gigs.png`
  - [x] `benutzerhandbuch/setlist_editor.rst` — Sets anlegen/umbenennen/löschen, Songs per Drag & Drop anordnen, Songsuche/Hinzufügen, Zeitberechnung + Pausen, Sänger-Farb-Kodierung, Screenshot `setlist_editor.png`
  - [x] `benutzerhandbuch/livemode.rst` — Verfügbarkeit (nur Gig-Tag oder Force durch Editor/Admin), Start, Song-Navigation (Pfeile/Swipe/Tastatur), Bewertung (😞😐😊), Songs einfügen/überspringen, Wiederverbinden, Screenshot `livemode.png`
  - [x] `benutzerhandbuch/songs.rst` — Songdatenbank, alle Felder (Titel, Interpret, Komponist, Texter, Bearbeiter, Verlag, Tonart, Dauer, Genre, Status, Sänger), Status-Workflow (`vorschlag` → `angenommen` → `proben` → `spielbar`), Screenshot `songs.png`
  - [x] `benutzerhandbuch/proben.rst` — Proben anlegen, Aufgaben/Todos, Probe-Songs, Screenshot `proben.png`
  - [x] `benutzerhandbuch/abstimmungen.rst` — drei Umfragetypen (Meinungsumfrage, Terminfindung, Auftrittsanfrage), Screenshot `abstimmungen.png`
  - [x] `benutzerhandbuch/benutzer.rst` — Profil, Passwort ändern (Regeln: 8 Zeichen, Groß/Klein, Ziffer, Sonderzeichen), Rollen-Tabelle (admin/editor/musician mit Berechtigungen)
  - [x] `api.rst` — Kurzübersicht REST-API, Verweis auf `/docs` (Swagger/OpenAPI)

- [x] **5. Englische Übersetzung** anlegen:
  - [x] `make gettext` → `.pot`-Dateien in `_build/gettext/`
  - [x] `sphinx-intl update -p _build/gettext -l en` → `locales/en/LC_MESSAGES/*.po`
  - [x] Alle `.po`-Dateien vollständig auf Englisch übersetzen (manuell)
  - [x] Build-Test: `sphinx-build -b html -D language=en . _build/html/en`

- [x] **6. `.woodpecker.yml`** um einen `docs`-Step erweitern (läuft nur auf `main`-Branch):
  - [x] `uv sync --group docs` → Sphinx-Abhängigkeiten installieren
  - [x] DE bauen → `public/de/`
  - [x] EN bauen → `public/en/`
  - [x] Version aus `version.json` lesen → `public/vX.Y.Z/de/`, `public/vX.Y.Z/en/`
  - [x] Root-`index.html` mit Sprachauswahl (DE/EN) + Versions-Links generieren
  - [x] `pages`-Branch auschecken, Inhalte kopieren, `git push origin pages` via SSH-Deploy-Key (Secret: `PAGES_SSH_KEY`)
  - [x] Anleitung zur Einrichtung des Deploy-Keys in `docs/CODEBERG_PAGES_SETUP.md` dokumentieren

- [x] **7. `taskfile.yaml`** um lokale Docs-Tasks ergänzen:
  - [x] `docs:build-de` — baut HTML auf Deutsch
  - [x] `docs:build-en` — baut HTML auf Englisch
  - [x] `docs:gettext` — generiert `.pot`-Dateien für Übersetzung
  - [x] `docs:serve` — startet lokalen HTTP-Server auf `_build/html/de/`

## Weitere Entscheidungen (getroffen)

- **Screenshots**: Alle `.. figure::`-Direktiven werden mit `:alt:`-Text und einer `.. note:: Screenshot folgt`-Notiz vorbereitet — so baut die Doku fehlerfrei, auch bevor die Bilder vorliegen.
- **Deploy-Key**: Die `CODEBERG_PAGES_SETUP.md` erklärt Schritt für Schritt: SSH-Key generieren, Public Key als Deploy Key im Codeberg-Repo hinterlegen, Private Key als `PAGES_SSH_KEY`-Secret in Woodpecker eintragen.
- **Versions-Switcher**: Im RTD-Theme wird `html_context['versions']` mit `[('latest', '/'), ('vX.Y.Z', '/vX.Y.Z/de/')]` befüllt, sodass Nutzer in der Doku zwischen Versionen wechseln können.
- **Übersetzungspflege**: `.po`-Dateien werden manuell gepflegt (kein DeepL/Weblate).
- **Hosting**: Codeberg Pages, Woodpecker-Job pushed in den `pages`-Branch.
- **Sprachen**: Deutsch vollständig als Hauptsprache, Englisch vollständig übersetzt.

