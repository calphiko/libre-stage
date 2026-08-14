.. _changelog:

Änderungsprotokoll
==================

0.5.32 (2026-08-14)
-------------------

Added
~~~~~

* **Proben-Historie – API für vergangene Proben**: Neuer Endpoint
  ``GET /reh/past`` mit ``q``, ``skip`` und ``limit``. Die Antwort enthält
  ``items``, ``total`` und ``has_more`` für paginierte Historienansichten.

Changed
~~~~~~~

* **Vergangene Proben vollständig durchsuchbar**: Die Suche im Tab
  **Vergangene Proben** läuft jetzt serverseitig und durchsucht die komplette
  Historie (u. a. Probenkommentar, Songtitel, Interpret sowie Proben-/Todo-
  Kommentare) statt nur lokal geladener Einträge.

* **Pagination für Protokoll-Historie**: Im Proben-Frontend werden vergangene
  Proben seitenweise geladen (Button **Mehr laden**), damit auch große
  Historien performant bedienbar bleiben.

* **Proben-Stammdaten editierbar für Bearbeiter/Admins**: In der
  Proben-Detailansicht können Nutzer mit Rolle **editor** oder **admin**
  nun **Beginn** und **Ende** einer Probe direkt im Bereich **Stammdaten**
  bearbeiten.

* **Demo-Daten für Historientests erweitert**: ``init_demo_db.py`` erzeugt nun
  24 Proben (davon >20 vergangen) mit zusätzlichen Protokoll- und Todo-Daten,
  sodass Suche und Pagination realistisch getestet werden können.

Fixed
~~~~~

* Chore: Projektversion auf ``0.5.32`` erhöht (``version.json``,
  ``pyproject.toml``, ``uv.lock``, ``frontend/package.json`` und
  ``README.md`` Badge).
* Manual: Benutzerhandbuch **Proben** und Changelog für Release ``0.5.32``
  ergänzt.

0.5.31 (2026-08-07)
-------------------

Added
~~~~~

* **Neuer Gig - Stammdatenvorlage**: Im ``NewGigForm`` kann jetzt ein
  bestehender Gig als Vorlage gewählt werden. Per Dropdown + Button
  **"Übernehmen"** werden Stammdaten in das Formular kopiert; ``Name`` und
  ``Datum`` bleiben dabei bewusst unberührt.

Changed
~~~~~~~

* **Vorlagenauswahl erweitert**: Die Vorlagenliste im ``NewGigForm`` ist nicht
  mehr auf vergangene Gigs beschränkt, sondern zeigt alle Gigs.

* **New-Gig-Modal UX**: Das Modal besitzt nun ein ``✕`` oben rechts im Header
  für ein schnelles Schließen.

* **Vorlagenbereich einklappbar**: Die Übernahme von Stammdaten ist in einen
  aufklappbaren Bereich ausgelagert, um das Formular kompakter zu halten.

Fixed
~~~~~

* **Checklisten-Detail im Gig-Details-Modal**: Beim Bearbeiten eines
  Checklisten-Items führt der Header-Button jetzt korrekt als ``←`` zurück in
  die Checklisten-Übersicht statt das komplette Modal zu schließen.

* **Verschachtelte Modals**: ``modalState`` unterstützt nun einen Stack, sodass
  Unter-Modals sauber zum übergeordneten Modal zurückkehren.

* Chore: Projektversion auf ``0.5.31`` erhöht (``version.json``,
  ``pyproject.toml``, ``frontend/package.json``, ``frontend/package-lock.json``,
  ``README.md`` Badge).
* Manual: Changelog für Release ``0.5.31`` ergänzt.

0.5.30 (2026-07-31)
-------------------

Added
~~~~~

* **Setlisten-Export (alle Gigs) als JSON**: Neue Export-Funktion über
  ``GET /gigs/export/setlists``. Im Frontend kann die vollständige Setlisten-
  Historie nun als Datei heruntergeladen werden (Dateiname aus
  ``Content-Disposition`` mit Fallback).

* **Live-Mode – Sets verschieben**: Neuer Endpoint
  ``POST /gigs_lm/{gig_id}/move-set`` inkl. Frontend-Integration, um Sets im
  laufenden Live-Mode gezielt nach oben/unten zu verschieben.

* **Touch-Unterstützung für Setlist-Drag&Drop**: ``SetList`` und ``SongList``
  unterstützen Touch-Geräte jetzt robuster (u. a. Handle-basiertes Dragging),
  damit die Reihenfolge auch mobil zuverlässig angepasst werden kann.

Changed
~~~~~~~

* **Sängerfarben bereits vor Setlist-Befüllung verfügbar**:
  ``GET /gigs/{gig_id}/singer_colors`` liefert die Farbzuordnung jetzt auf
  Basis des gesamten Song-Repertoires statt nur der aktuell befüllten
  Gig-Setliste. Dadurch sind Farben im Setlist-Editor sofort konsistent
  verfügbar.

* **Session-Limit erhöht**: ``MAX_ACTIVE_SESSIONS`` wurde von 5 auf **10**
  angehoben.

* **Set-Import aus vergangenen Gigs verbessert**: Filterlogik und
  Beschriftungen im Setlist-Editor wurden für den Import aus vergangenen Gigs
  präzisiert.

* **README-Kontaktdaten aktualisiert**.

Fixed
~~~~~

* **New Song Modal (Svelte 5 Bindings)**: Beim Öffnen von ``NewSongModal``
  konnte ein ``props_invalid_value`` auftreten, wenn ``multi_select``-Felder
  initial ``undefined`` waren. Die Initialisierung erfolgt nun bereits vor dem
  ersten Render als Array, sodass ``bind:selected`` stabil funktioniert.

* Chore: Projektversion auf ``0.5.30`` erhöht (``version.json``,
  ``pyproject.toml``, ``frontend/package.json``, ``README.md`` Badge).
* Manual: Changelog für Release ``0.5.30`` ergänzt.

0.5.29 (2026-07-17)
-------------------

Fixed
~~~~~

* **Gespielte Songs – Übersprungene Songs werden abgezogen**: Die Statistik-
  Kachel „Gespielte Songs" im Dashboard und im Saison-Statistik-Modal zeigte
  bisher alle Song-Einträge in Setlisten – unabhängig davon, ob ein Song
  tatsächlich gespielt oder übersprungen wurde. Ab sofort wird
  ``played_songs = total_songs − skipped_count`` berechnet und angezeigt.
  Das Feld ``played_songs`` wurde dem Schema ``SeasonStatistics`` hinzugefügt;
  ``total_songs`` (Gesamtzahl inkl. übersprungener Songs) bleibt weiterhin
  intern vorhanden.

Changed
~~~~~~~

* **Setlist-Editor – Sänger-Farbgebung überarbeitet**: Die farbigen
  Hintergrundgradienten der Song-Kacheln im Setlist-Editor und in der
  Song-Liste wurden durch eine subtilere Variante ersetzt. Die Sängerfarbe
  wird nun ausschließlich als Textfarbe des Songtitels angezeigt; die
  Kacheln selbst bleiben einfarbig im Surface-Ton der jeweiligen Theme-
  Variante. Dadurch ist der Editor bei dunklem Theme besser lesbar und
  wirkt insgesamt ruhiger.

* **Setlist-Editor – Sänger-Farben werden dynamisch vom Backend geladen**:
  Statt die Farben ausschließlich clientseitig zu berechnen, lädt der
  Setlist-Editor die Sänger-Farb-Zuordnung jetzt über den Endpoint
  ``GET /gigs/{gig_id}/singer_colors``. Die Farben werden bei jeder
  Änderung der Setlist-Version (``setlist_version``-Reaktivität) automatisch
  neu abgerufen, sodass externe Änderungen (z. B. durch andere Tabs oder
  Nutzer) sofort berücksichtigt werden.

Removed
~~~~~~~

* **Playlist- und Streaming-Funktionalität entfernt**: Die kurzzeitig
  implementierte Playlist-Verwaltung (inkl. Streaming-Zugangsdaten-
  Administration) wurde vollständig aus dem Projekt entfernt. Betroffen sind
  der Backend-Router ``playlist.py``, der ``playlist_service.py``, die
  zugehörigen Datenbankmodelle und Alembic-Migrationen sowie die
  Frontend-Seiten ``/playlist`` und ``/admin/streaming``.

* Chore: Projektversion auf ``0.5.29`` erhöht (``version.json``,
  ``pyproject.toml``, ``frontend/package.json``).
* Manual: Changelog für Release ``0.5.29`` ergänzt.

0.5.28 (2026-07-16)
-------------------

Added
~~~~~

* **Session-Limit pro Benutzer**: Jeder Benutzer darf maximal **5 gleichzeitig
  aktive Sessions** haben. Beim Login oder Token-Refresh wird geprüft, ob
  bereits 5 nicht-widerrufene, nicht abgelaufene Refresh-Tokens existieren.
  Ist die Grenze erreicht, wird die **älteste aktive Session automatisch
  widerrufen**, bevor die neue angelegt wird. Die Konstante
  ``MAX_ACTIVE_SESSIONS = 5`` in ``auth.py`` steuert den Schwellwert zentral.

* **Cross-Tab-Koordination für Token-Refresh (Frontend)**: Mehrere Browser-
  Tabs derselben App koordinieren sich nun über ``BroadcastChannel`` und
  ``localStorage``, damit nur ein Tab gleichzeitig einen ``/refresh``-Request
  stellt. Bisher konnten zwei Tabs denselben Refresh-Token gleichzeitig
  verwenden, was die Replay-Detection triggerte und alle Sessions sperrte.

  * ``BroadcastChannel('libre_stage_auth')`` informiert andere Tabs nach
    erfolgreichem Refresh (``token_refreshed``) und nach Logout (``auth_logout``).
  * ``localStorage['libre_stage_last_token_refresh']`` speichert den Zeitstempel
    des letzten Refreshes. Innerhalb von 8 Sekunden starten andere Tabs
    keinen eigenen Refresh-Request (``anotherTabRefreshedRecently()``).

* **iCal-Token: Ablaufdatum** (``exp``-Claim): iCal-Tokens haben nun eine
  Laufzeit von **365 Tagen** (``ICAL_TOKEN_EXPIRE_DAYS = 365``). Ablauf wird
  standardmäßig durch die JWT-Library beim Decode geprüft – kein manueller
  Timestamp-Vergleich mehr.

Changed
~~~~~~~

* **Refresh-Token-Laufzeit verlängert**: ``REFRESH_TOKEN_EXPIRE_DAYS`` von
  30 auf **90 Tage** erhöht. Benutzer müssen sich damit nur noch ca. alle
  3 Monate neu einloggen, sofern sie die App regelmäßig nutzen.

* **Password-Reset-Token: Standard-``exp``-Claim**: ``create_password_reset_token``
  setzt nun einen echten JWT-``exp``-Claim statt des bisherigen manuellen
  ``ts``-Timestamps. ``verify_password_reset_token`` entfernt die redundante
  Ablaufprüfung – die JWT-Library wirft automatisch eine ``ExpiredSignatureError``
  bei abgelaufenen Tokens.

* **Legacy-SHA1-Passwort-Hash-Unterstützung entfernt**: Die
  ``LEGACY_HASH_DEADLINE`` (2026-04-30) ist abgelaufen. Der gesamte SHA-1-
  Pfad in ``verify_password`` sowie der Auto-Upgrade-Code in
  ``authenticate_user`` wurden entfernt. ``verify_password`` prüft
  ausschließlich bcrypt-Hashes (``$2b$``, ``$2a$``, ``$2y$``).
  Der nicht mehr benötigte ``import base64`` wurde ebenfalls entfernt.

* **iCal-Token-Verifikation bereinigt**: ``verify_ical_token`` nutzt nun den
  Standard-``exp``-Claim statt manuellem ``ts``-Check. Ein Format-String-Bug
  (``"iCal token verified!".format(...)`` ohne Platzhalter) wurde behoben
  (``logger.info("...", user.user_name)``).

Fixed
~~~~~

* **Parallele Sessions**: Ein neuer Login von einem Gerät/Tab entzieht anderen
  aktiven Sessions nicht mehr die Authentifizierung. Jede Session hält einen
  eigenen Refresh-Token; die Cross-Tab-Koordination verhindert race-condition-
  bedingte Logout-Kaskaden.

* Chore: Projektversion auf ``0.5.28`` erhöht (``version.json``,
  ``pyproject.toml``, ``frontend/package.json``).
* Manual: Changelog für Release ``0.5.28`` ergänzt.

0.5.27 (2026-07-09)
-------------------

Added
~~~~~

* **Kanban-Ansicht für die Gig-Checkliste**: Die Checkliste im Tab
  **✅ Checkliste** des Gig-Detaildialogs bietet nun wahlweise eine
  **Kanban-Board-Ansicht** neben der bestehenden Listenansicht.
  Ein Toggle-Schalter (☰ Liste / ⬛ Kanban) im Header wechselt zwischen
  beiden Modi. Das Board zeigt zwei Spalten – **Offen** (gelb) und
  **Erledigt** (grün) – mit kompakten Karten pro Aufgabe (Titel, Kategorie-
  Badge, Fälligkeit, Zuständiger, Kommentar). Editors können Aufgaben
  direkt per Schaltfläche zwischen den Spalten verschieben.

* **Vergangenheitssperre – Gig-Checkliste (Frontend)**: Für vergangene Gigs
  wird der **+ Eintrag**-Button ausgeblendet und durch einen 🔒-Hinweis
  ersetzt. Das Formular lässt sich auch programmatisch nicht mehr öffnen.

* **Vergangenheitssperre – Gig-Checkliste (Backend)**: Der Endpoint
  ``POST /gigs/{gig_id}/checklist`` lehnt neue Einträge für vergangene Gigs
  mit **HTTP 403** ab
  (*„Für vergangene Gigs können keine neuen Checklisten-Einträge angelegt werden."*).

* **Vergangenheitssperre – Verfügbarkeit (Frontend)**: Das
  ``AvailabilityWidget`` erhält einen neuen Prop ``readonly``. Bei
  vergangenen Gigs werden die Statusbuttons (Dabei / Vielleicht / Nicht
  dabei) sowie das Aushilfe-Formular und das Kommentarfeld ausgeblendet;
  stattdessen erscheint der Hinweis
  *„🔒 Vergangenes Event – keine Rückmeldung mehr möglich."*
  Die bereits abgegebene eigene Rückmeldung bleibt als Badge sichtbar;
  die Gesamtübersicht aller Rückmeldungen ist weiterhin lesbar.
  Der ``GigDetailsModal`` berechnet ``gigIsPast`` und übergibt es als
  ``readonly`` an das Widget.

* **Vergangenheitssperre – Verfügbarkeit (Backend)**: Die Endpoints
  ``PUT /availability/gig/{id}`` und ``DELETE /availability/gig/{id}``
  lehnen Schreibzugriffe auf vergangene Gigs mit **HTTP 403** ab.
  Proben (``event_type=rehearsal``) sind nicht betroffen. Lesezugriffe
  (``GET``) bleiben für alle Events uneingeschränkt.

* **Tests – Verfügbarkeit (vergangene Gigs)**: Fünf neue Tests in
  ``test_availability.py`` decken die Vergangenheitssperre ab:
  PUT → 403, DELETE → 403, Fehlermeldung enthält „vergangen",
  Proben nicht betroffen, GET weiterhin lesbar.

* **Tests – Gig-Checkliste** (neue Datei ``test_gig_checklist.py``):
  12 Tests für GET (leer, 404, Lesezugriff auf vergangene Gigs) und POST
  (Erfolgsfall, vollständige Rückgabe, 404, fehlende Berechtigung,
  vergangener Gig → 403 mit Fehlermeldung, kein DB-Eintrag nach Ablehnung).

Changed
~~~~~~~

* **+ Eintrag-Button**: Verwendet nun ``variant-filled-primary`` (ohne
  ``border``) – konsistent mit anderen Hinzufügen-Buttons (z. B. im
  Ablaufplan).
* Chore: Projektversion auf ``0.5.27`` erhöht (``version.json``,
  ``pyproject.toml``, ``frontend/package.json``).
* Manual: Changelog für Release ``0.5.27`` ergänzt.

0.5.26 (2026-07-07)
-------------------

Added
~~~~~

* **Kommentarfeld in der Gig-Checkliste**: Jede Aufgabe erhält ein optionales
  Feld **Kommentar / Ergebnis**, um das Ergebnis oder Rückstände zu protokollieren.
  Vorhandene Kommentare werden in der Listenansicht mit 💬-Symbol angezeigt.

  * Datenbank: neue Spalte ``comment TEXT`` in ``gig_checklist_items`` via
    Alembic-Migration ``c3d4e5f6a1b2_add_comment_to_checklist_items``.
  * Schema: ``GigChecklistItemIn`` / ``GigChecklistItemOut`` um ``comment`` ergänzt.

* **Checklisten-Detailmodal**: Klick auf eine Aufgabe in der Checkliste öffnet
  ein Modal mit allen Details (Titel, Status, Gig, Kategorie, Zuständiger,
  Fälligkeit, Kommentar). Admins und Editors können darin die Aufgabe direkt
  erledigen oder über ein Inline-Formular bearbeiten.
  Das Modal ist sowohl in der Gig-Checkliste als auch im Dashboard erreichbar.

* **Dashboard – Tab „✅ Checkliste"**: Zeigt offene Gig-Checklisten-Aufgaben,
  die dem eingeloggten Mitglied zugewiesen sind. Klick auf einen Eintrag öffnet
  das Detailmodal; Admins/Editors können Aufgaben direkt als erledigt markieren.

* **Dashboard – Tab „👥 Gig-Rückmeldungen"**: Zeigt bevorstehende Gigs, für die
  noch keine Verfügbarkeitsrückmeldung abgegeben wurde. Link führt zur
  Gig-Übersicht.

* **Dashboard – Todos aus ``GET /user_todos``**: Der bestehende Backend-Endpunkt
  liefert nun zwei zusätzliche Felder:

  * ``gig_checklist_todos`` – offene, dem User zugewiesene Checklisten-Aufgaben
  * ``pending_gigs`` – Gigs ohne Verfügbarkeitseintrag des Users

  Beide Felder werden in einem einzigen API-Call mitgeliefert; kein separater
  Request mehr nötig.

* Zusätzlicher Backend-Endpunkt ``GET /availability/pending_gigs`` bleibt
  weiterhin verfügbar (für externe Nutzung).

Changed
~~~~~~~

* Dashboard-Hilfetext aktualisiert: beschreibt jetzt alle sechs Todo-Tabs.
* :ref:`checkliste`: Neue Abschnitte *Kommentarfeld*, *Aufgaben-Detailansicht*
  und *Dashboard-Integration*.
* :ref:`dashboard`: vollständig überarbeitet; beschreibt alle sechs Tabs,
  Nächste Termine, Saison-Statistiken und Kalender-Abo.
* Chore: Projektversion auf ``0.5.26`` erhöht.

0.5.25 (2026-07-07)
-------------------

Added
~~~~~

* **Gig-Checkliste**: Jeder Gig erhält einen neuen Tab **✅ Checkliste** (Tab 6)
  mit einer strukturierten Aufgabenliste für die Gig-Vorbereitung.
  Aufgaben besitzen Titel, Kategorie, optional einen Verantwortlichen (Mitglied
  oder Freitext) sowie ein optionales Fälligkeitsdatum.
  Admins und Editors können Aufgaben anlegen, bearbeiten, löschen und als erledigt
  markieren; normale Mitglieder sehen die Liste in Lese-Ansicht.
* Gig-Details / Tab **Übersicht**: Neue Karte **✅ Checkliste** zeigt sofort
  einen Fortschrittsbalken (erledigte / offene Punkte) sowie bis zu vier offene
  Aufgaben als Schnellvorschau. Der Link **Details →** wechselt direkt in den
  Checklisten-Tab.
* Backend: Neuer Router ``/gigs/{gig_id}/checklist`` mit Endpunkten
  ``GET``, ``POST``, ``PUT /{item_id}``, ``PATCH /{item_id}/done``,
  ``DELETE /{item_id}``. Das Abhaken (``PATCH done``) setzt ``check_editor``
  voraus.
* Datenbank: Neue Tabelle ``gig_checklist_items`` über Alembic-Migration
  ``f1a2b3c4d5e6_add_gig_checklist_items``; ``upgrade``/``downgrade`` vollständig
  implementiert.
* Frontend-API: Neue Hilfsfunktionen ``getGigChecklist``, ``createChecklistItem``,
  ``updateChecklistItem``, ``toggleChecklistItemDone``, ``deleteChecklistItem``
  in ``api.js``.
* Manual: Neues Kapitel :ref:`checkliste` im Benutzerhandbuch;
  Querverweise in :ref:`gigs` ergänzt.

* **Setlisten-Sperre**: Setliste und Ablaufplan eines Gigs sind nach mehr als
  sieben Tagen seit dem Gig-Datum für Editors gesperrt. Admins können weiterhin
  Änderungen vornehmen.

  * Backend: Hilfsfunktion ``_is_setlist_locked`` prüft das Gig-Datum; alle
    schreibenden Endpunkte (``PUT /update_setlist/``, ``POST/PUT/DELETE
    /schedule/``) geben bei überschrittener Frist und fehlendem Admin-Recht
    ``403 SETLIST_LOCKED`` zurück.
  * Frontend: Berechneter Zustand ``setlistLocked`` und ``canEditSetlist``;
    Button **Setliste bearbeiten** wird deaktiviert (🔒-Präfix, Tooltip).
    Im Ablaufplan-Tab erhalten Admins einen gelben Hinweis.

* **Mobiles Tab-Layout**: Im Gig-Detail-Dialog werden die sieben Tabs auf
  kleinen Bildschirmen (< ``sm``) durch ein natives ``<select>``-Dropdown
  ersetzt; auf größeren Bildschirmen bleiben die Tab-Buttons unverändert.

Changed
~~~~~~~

* Chore: Projektversion auf ``0.5.25`` erhöht (``version.json``, ``frontend/package.json``).
* Manual: Changelog für Release ``0.5.25`` ergänzt.

0.5.24 (2026-07-07)
-------------------

Added
~~~~~

* **Verfügbarkeitsmanagement**: Bandmitglieder können für jeden Gig und jede
  Probe ihren Teilnahmestatus hinterlegen (✅ Dabei / ❓ Vielleicht / ❌ Nicht dabei).
  Bei Absagen kann optional eine Aushilfe eingetragen werden – entweder als
  registriertes Bandmitglied (Dropdown) oder als freier Text für externe Personen.
* Gig-Details / Tab **Übersicht**: Neue Karte **📅 Verfügbarkeit** zeigt sofort
  beim Öffnen des Modals eine kompakte Schnellübersicht (Zähler je Status,
  farbige Name-Badges, eingetragene Aushilfen). Link **Details →** wechselt
  direkt in den Verfügbarkeits-Tab.
* Gig-Details: Neuer Tab **Verfügbarkeit** (Tab 5) mit dem vollständigen
  ``AvailabilityWidget``: eigene Statuswahl, Aushilfeformular, Kommentar und
  vollständige Teilnehmerliste inkl. „Keine Rückmeldung"-Sektion.
  Die Musikerliste wird beim ersten Öffnen des Tabs nachgeladen.
* Proben-Details: Aufklappbarer Bereich **📅 Verfügbarkeit** oben im Modal
  mit demselben Widget; Status- und Aushilfeänderungen werden sofort gespeichert.
* Backend: Neuer Router ``/availability`` mit Endpunkten
  ``GET/PUT/DELETE /availability/{event_type}/{event_id}``
  (``event_type`` = ``rehearsal`` oder ``gig``).
* Datenbank: Neue Tabelle ``availability`` über Alembic-Migration
  ``e1f2a3b4c5d6_add_availability_table``; ``upgrade``/``downgrade`` vollständig implementiert.
* Frontend-API: Neue Hilfsfunktionen ``getAvailability``, ``setAvailability``,
  ``deleteAvailability`` in ``api.js``.
* Demo-Datenbank: ``init_demo_db.py`` erzeugt realistische Availability-Einträge
  für alle drei Gigs und die zukünftige Probe (alle Status-Varianten, externe und
  interne Aushilfen).
* Manual: Neues Kapitel :ref:`verfuegbarkeit` im Benutzerhandbuch;
  Querverweise in :ref:`gigs` und :ref:`proben` ergänzt.

Changed
~~~~~~~

* Chore: Projektversion auf ``0.5.24`` erhöht (``version.json``, ``frontend/package.json``).
* Manual: Changelog für Release ``0.5.24`` ergänzt.

0.5.23 (2026-07-03)
-------------------


Added
~~~~~

* Abstimmungen / Meinungsumfrage: User können zu ihrer gewählten Option einen **Kommentar** hinterlassen.
  Eine Inline-Textarea erscheint direkt unter der ausgewählten Option; der Kommentar wird beim Verlassen des Feldes (``onblur``) gespeichert.
  Bestehende Kommentare anderer User werden weiterhin in der aufklappbaren Feedback-Liste angezeigt.
* Abstimmungen / Terminumfrage: Neuer **Kommentarbereich unterhalb der Matrix** – für jeden Termin, bei dem der User abgestimmt hat,
  steht ein Kommentarfeld bereit. Speichern erfolgt ebenfalls ``onblur`` oder per ``Enter``.
* Abstimmungen / Terminumfrage: Grid-Zellen zeigen ein zentriertes **💬**-Symbol, sobald ein Kommentar vorliegt
  (Desktop: in der leeren Zelle; Mobile: unterhalb des Farbfeldes).
* Abstimmungen / Terminumfrage: Beim Hover über eine Zelle wird der gespeicherte Kommentar als **Tooltip** angezeigt
  (Desktop und Mobile über ``title``-Attribut sowie ``aria-label``).
* Abstimmungen / Terminumfrage: Im Kommentarbereich zeigt die zweite Spalte ein **farbiges Vote-Symbol**
  (grün/gelb/rot gemäß Abstimmung), konsistent mit der Matrix-Darstellung.
* Backend-Tests: Alle ``test_admin_config``-Testpayloads um ``danceStyles`` ergaenzt,
  das als Pflichtfeld in ``SoftConfigUpdateIn`` hinzugekommen war.

Changed
~~~~~~~

* Admin-Konfiguration: Das Frontend leitet ``objectKeys`` und ``stringKeys`` jetzt **dynamisch aus der API-Antwort** ab,
  statt sie hart zu kodieren. Neue Objekt-Keys im Backend erscheinen automatisch als editierbare Sektion;
  nur der Typ-Hinweis ``STRING_KEYS`` bleibt im Frontend gepflegt.
  ``form`` startet als leeres ``{}`` und wird vollständig vom Backend befüllt.
* Abstimmungen / Terminumfrage: Mobile-Layout zeigt in den Vote-Feldern **nur noch die Hintergrundfarbe**
  (kein ✓/~/✗-Symbol mehr); ein vorhandener Kommentar wird durch 💬 signalisiert.
* Abstimmungen / Terminumfrage: ``buildAllFeedbacks()`` als zentrale Hilfsfunktion extrahiert –
  eigene Kommentar-Drafts werden konsistent bei jedem API-Call mitgesendet.
* Chore: Projektversion auf ``0.5.23`` erhoeht (Backend/Frontend/Lockfile/Release-Metadaten/README-Badge).
* Manual: Changelog fuer Release ``0.5.23`` ergaenzt; Abstimmungs-Dokumentation aktualisiert.

0.5.22 (2026-07-02)
-------------------

Added
~~~~~

* Konfiguration: ``app_config.py`` prüft beim Start, ob alle erwarteten Pflicht-Keys in der ``appConfig.json`` vorhanden sind.
  Fehlende Keys werden automatisch mit leeren Listen (``[]``) bzw. – für ``setlist_timing`` – mit sinnvollen Standard-Werten befüllt.
  Die ergänzte Konfiguration wird atomar zurückgeschrieben, sodass die Datei dauerhaft konsistent bleibt.
  Ein ``WARNING``-Log nennt alle automatisch ergänzten Keys.
* Sicherheit: ``DOMPurify`` (``dompurify ^3.4.11``) integriert – Markdown-gerenderter HTML-Inhalt der Gig-Protokoll-Notizen wird vor der Darstellung
  bereinigt (erlaubte Tags: Überschriften, Textformatierung, Listen, Code, Links; erlaubte Attribute: ``href``, ``title``, ``target``, ``rel``).
* Abhängigkeiten: ``@types/dompurify ^3.0.5`` als Dev-Dependency hinzugefügt.
* Styling: ``@tailwindcss/typography ^0.5.20`` als Dev-Dependency hinzugefügt und über ``@plugin "@tailwindcss/typography"`` in ``app.css`` aktiviert –
  ermöglicht sauberes typografisches Rendering von Markdown-Inhalten.

Changed
~~~~~~~

* Gig-Protokoll: Edit-Toggle im ``GigDetailsModal`` auf **Checkbox** umgestellt.
  Statt separater Bearbeiten/Abbrechen-Buttons im Tab-Bereich steuert eine ``Edit-Mode``-Checkbox den Editiermodus;
  Speichern- und Abbrechen-Buttons wurden in die modale **Footer-Leiste** verschoben, konsistent mit den übrigen Modal-Aktionen.
* Konfiguration: ``_load_config_from_disk`` ruft statt ``_validate_required_keys`` die neue Funktion ``_ensure_required_keys`` auf,
  die bei fehlenden Keys nicht mehr abbricht, sondern Standardwerte einsetzt und persistiert.
  ``_validate_required_keys`` bleibt für den Admin-Update-Pfad (``update_soft_config``) unverändert erhalten.
* Chore: Projektversion auf ``0.5.22`` erhoeht (Backend/Frontend/Lockfile/Release-Metadaten/README-Badge).
* Manual: Changelog fuer Release ``0.5.22`` ergaenzt; Konfigurationsdokumentation um Selbstheilungs-Verhalten aktualisiert.

0.5.21 (2026-06-30)
-------------------

Added
~~~~~

* Gig-Protokoll: Neuer Tab **Protokoll** im ``GigDetailsModal`` ermöglicht das Erfassen und Bearbeiten von Nachbesprechungsnotizen pro Gig.
  Inhalte werden als Markdown gespeichert und gerendert (``**fett**``, *kursiv*, Überschriften, Listen, ``code``).
* Gig-Protokoll: Neuer Backend-Endpoint ``PUT /gigs/{gig_id}/notes`` mit Authentifizierung und Berechtigungsprüfung.
* Gig-Protokoll: Neues Schema-Feld ``notes`` in ``GigUpdate`` und ``GigOut``; Hilfsfunktion ``updateGigNotes`` in der Frontend-API ergaenzt.
* Gig-Protokoll: Neue Alembic-Migration ``0ba4c6c97dad_add_notes_to_gigs`` fuegt Spalte ``gigs.notes TEXT`` hinzu.
* Gig-Protokoll: Backend-Tests fuer den neuen Notes-Endpoint ergaenzt (Speichern, Berechtigungspruefung, leerer Inhalt).
* Gig-Statistik: Neue Komponente ``gigSetStatusPlot.svelte`` – gestapeltes Balkendiagramm **Songs je Set** im Statistik-Tab des ``GigDetailsModal``.
  X-Achse: Set-Namen; Y-Achse: Anzahl Songs farblich unterteilt in Gespielt (blau), Eingeschoben (gruen) und Uebersprungen (gelb, negativ unterhalb der X-Achse).
  Unterstuetzt kompakte Zentrierung bei ≤ 8 Sets, DataZoom ab > 12 Sets sowie Dark-Mode.

Changed
~~~~~~~

* Gig-Statistik: Uebersprungene Songs werden als negativer Balken **unterhalb der X-Achse** dargestellt (divergierendes Balkendiagramm).
* Gig-Statistik: Chart-Design an den Genre-Verteilungs-Plot angeglichen (gleiche Grid-Abstände, ``barMaxWidth: 26``, Achsen-Styling, Legende oben, kompakte Zentrierung bei ≤ 8 Sets).
* Gig-Statistik: Sektion ``Songs je Set`` wird immer angezeigt, sobald Statistikdaten geladen sind – bei fehlender Setliste erscheint ein Hinweistext statt eines leeren Bereichs.
* Gig-Ablaufplan: Deutschsprachige Bezeichnungen in der ``GigSchedule``-Komponente korrigiert.
* Chore: Projektversion auf ``0.5.21`` erhoeht (Backend/Frontend/Lockfile/Release-Metadaten/README-Badge).
* Manual: Changelog fuer Release ``0.5.21`` ergaenzt.

Fixed
~~~~~

* Public-Endpoint: Im Song-Histogramm-Endpoint (``/public/song_histogram``) wurde ``kind_of_gig`` faelschlicherweise gegen das globale statt das jahresspezifische Histogramm-Dict geprueft, was zu einem ``KeyError`` fuehren konnte. Korrektur: Pruefung erfolgt jetzt korrekt gegen ``histogram[year]``.

0.5.20 (2026-06-23)
-------------------

Added
~~~~~

* Gig-Ablaufplan: Pro Eintrag kann jetzt ein optionaler Kommentar erfasst und gespeichert werden.
* Datenbank: Neue Spalte ``gig_schedule_items.comment`` inkl. Alembic-Migration ``a1b2c3d4e5f6_add_comment_to_gig_schedule_items``.

Changed
~~~~~~~

* Ablaufplan-Ansicht: Kommentare werden im Ueberblick direkt unter dem Titel (``Was``) dargestellt.
* Ablaufplan-PDF: Kommentare werden in der zweiten Spalte unter dem Titel gerendert; Zeilenumbrueche im Kommentar werden dabei beibehalten.
* PDF-Downloadname: Unicode-faehige Normalisierung fuer Gig-Namen verbessert, ungueltige Dateinamenzeichen werden robust ersetzt.
* Chore: Projektversion auf ``0.5.20`` erhoeht (Backend/Frontend/Lockfile/Release-Metadaten/README-Badge).
* Manual: Changelog fuer Release ``0.5.20`` ergaenzt.

Fixed
~~~~~

* Frontend: ``Ablaufplan drucken`` nutzt konsistent den ``Blob`` aus ``getGigSchedulePDF`` (statt Objekt), wodurch der Fehler ``Failed to execute 'createObjectURL' on 'URL'`` behoben ist.

0.5.19 (2026-06-23)
-------------------

Added
~~~~~

* Setup: Das Backend startet nicht mit dem standard-SECRET_KEY. Es muss einer vom Administrator definiert werden.

Changed
~~~~~~~

* Setlist-Editor: Sets aus anderen Gigs koennen direkt in die aktuelle Setliste kopiert werden.
* Frontend: Persistenter Store behandelt ``localStorage``-Fehler im Browser robust (z. B. bei deaktiviertem Storage).
* Abhaengigkeiten: ``pyproject.toml`` und ``requirements.txt`` aktualisiert fuer verbesserte Kompatibilitaet und Performance.
* Frontend: ``adapter-node`` auf Version ``5.5.4`` fixiert, um einen Upgrade-Fehler zu verhindern, der das Ausliefern statischer Dateien unterbunden hatte.
* Chore: Projektversion auf ``0.5.19`` erhoeht (Backend/Frontend/Lockfile/Release-Metadaten/README-Badge).
* Manual: Changelog fuer Release ``0.5.19`` ergaenzt.

Fixed
~~~~~

* Tests: Testkette fuer den neuen Auth-Flow korrigiert.
* Datenbank: ``published``-Feld als ``int`` statt ``bool`` gespeichert (Datenbankkompatibilitaet).

0.5.18 (2026-06-18)
-------------------

Added
~~~~~

* Proben/Songs: Zusätzliche Berechtigungspruefungen fuer Bearbeitungen eingefuehrt, damit Editor-Rechte konsistent durchgesetzt werden.
* Setlisten-Editor: Hinzufügen von Sets von verganenen Gigs ermöglicht

Changed
~~~~~~~

* Proben-Details und Song-Management: Bearbeitungsrechte im UI ueberarbeitet und klarer gesteuert.
* Gig-Set-Management: Validierung beim Hinzufuegen/Bearbeiten von Songs erweitert und Fehlerbehandlung robuster gemacht.
* UI/UX: Modale Dialoge nutzen nun ein Fullscreen-Layout fuer eine bessere Bedienbarkeit auf kleineren Ansichten.
* Sicherheit/Config: Startup-Validierung fuer Umgebungsparameter ergaenzt, um Fehlkonfigurationen frueh zu erkennen.
* Chore: Projektversion auf ``0.5.18`` erhoeht (Backend/Frontend/Lockfile/Release-Metadaten/README-Badge).
* Manual: Changelog fuer Release ``0.5.18`` ergaenzt.

Fixed
~~~~~

* Songs: Fehlende Funktion ``getSongDetails`` fuer das Nachladen von Song-Details ergaenzt.

0.5.17 (2026-06-16)
-------------------

Added
~~~~~

* Song-Details: Neuer Edit-Mode im ``SongDetailsModal`` mit Speichern/Abbrechen direkt im Modal.
* Song-Details: Manueller Button ``Metadaten abrufen`` im Edit-Mode; uebernimmt Dauer, Komponist, Texter und YouTube-Link ueber den bestehenden Scraper.
* Proben: Neues ``RehearsalDetailsModal`` fuer eine detailreiche Probe-Ansicht; ``RehearsalCard`` oeffnet Details nun modal.
* Umfragen: Neues ``SurveyDetailsModal`` fuer die kompakte Detailansicht einzelner Umfragen.
* Umfragen: Bestehende Umfragen koennen um neue Antwortoptionen erweitert werden.

Changed
~~~~~~~

* Live-Mode: Songs koennen gezielt vor einer bestehenden Position in die Setliste eingefuegt werden.
* Live-Mode: Unlock-Handling und zugehoerige UI-Rueckmeldungen verbessert.
* Umfragen/Terminfindung: Layout und Responsiveness in ``SurveyDetailsModal`` und ``TerminfindungView`` optimiert.
* Umfragen: Deutsche Texte im ``SurveyDetailsModal`` sprachlich bereinigt.
* Gigs: Modal-Handling in der Gig-Verwaltung vereinfacht und ungenutzte Funktionen entfernt.
* Chore: Projektversion auf ``0.5.17`` erhoeht (Backend/Frontend/Lockfile/Release-Metadaten/README-Badge).

0.5.16 (2026-06-14)
-------------------

Added
~~~~~

* Backend: Neuer Endpoint ``GET /csrf`` gibt fuer authentifizierte Clients ein CSRF-Token zurueck und erneuert das CSRF-Cookie.
* Setlist-Timing: Rueckgabe um ``slot_durations`` erweitert, um effektive Slotlaengen pro Song (inkl. Inter-Song-Pausen) explizit bereitzustellen.
* Tests: Neue Abdeckung in ``backend/tests/test_setlist_service.py`` fuer die Ausgabe von Slot-Dauern inkl. ``00:00:00`` bei uebersprungenen Songs.
* Backend: Neue Abhaengigkeit ``pathvalidate`` aufgenommen.

Changed
~~~~~~~

* Security/Auth: ``/login`` und ``/refresh`` liefern nun zusaetzlich ``csrf_token`` im Response-Payload fuer robustes CSRF-Handling im Frontend.
* Frontend-API: CSRF-Handling robustifiziert (Token-Cache, automatisches Nachladen ueber ``/csrf``, Retry bei ``CSRF validation failed``, konsistente Header-Setzung fuer mutierende Requests).
* Setlist-Timing: Uebersprungene Songs verursachen keine Inter-Song-Pause mehr; der betreffende Slot wird als ``0`` Sekunden gefuehrt.
* PDF-Export: Setlisten-PDF nutzt ``slot_durations`` fuer die angezeigten Songzeiten und verbessert die Durchstreichung uebersprungener Songs (kontraststark in Screen/Print).
* Setlist-Service: ``dump_gig_struct`` zeigt effektive Slot-Dauern im Format ``HH:MM:SS`` statt roher Songdauer.
* Frontend-UI: Layout und Responsiveness fuer Sidebar, Header/Footer, Login-Seite und globale Komponentenabstaende/-groessen ueberarbeitet.
* Terminfindung (Frontend): Mobile-Ansicht von Karten auf eine kompakte, tabellarische Matrix umgestellt (inkl. klarer Trennung der eigenen bearbeitbaren Zeile, read-only Darstellung anderer Teilnehmer und uebersichtlicher Header-/Zeilenstruktur bei vielen Alternativen).

0.5.15 (2026-06-11)
-------------------

Changed
~~~~~~~

* Sicherheit: Logout-Blacklist-Decoding robustifiziert (korrekter ``algorithms``-Parameter, Logging bei Decode-Fehlern).
* Sicherheit: Authentifizierung auf HttpOnly-Cookies umgestellt, inkl. CSRF-Schutz (Double-Submit + Origin/Referer-Pruefung).
* Sicherheit: Refresh-Token-Rotation mit Reuse-Detection eingefuehrt; bei Replay werden aktive Refresh-Tokens des Nutzers widerrufen.
* Frontend: Rehearsal-Highlighting ohne ``{@html}`` umgesetzt, um den Stored-XSS-Angriffsweg zu schliessen.
* Tests: Auth-Testfixturen stabilisiert, indem Rate-Limits in Test-Clients deaktiviert und pro Test sauber zurueckgesetzt werden.
* Chore: Projektversion auf ``0.5.15`` erhoeht (Backend/Frontend/Lockfile/Release-Metadaten/README-Badge).

0.5.14 (2026-06-11)
-------------------

Changed
~~~~~~~

* Setlist-Editor: Loading Spinner hinzugefügt
* Top-Layout: Volles Logo in Kopfzeile

0.5.13 (2026-06-10)
-------------------

Changed
~~~~~~~

* Setlist-Editor: Optimistic Concurrency fuer Setlisten-Updates eingefuehrt. Vor dem Speichern wird jetzt die ``setlist_version`` geprueft.
* Setlist-Editor: Bei Konflikten (``409 SETLIST_CONFLICT``) wird der veraltete Update-Versuch abgelehnt, eine Toast-Meldung gezeigt und die Ansicht auf den aktuellen DB-Stand aktualisiert.
* Setlist-Editor: Undo/Redo mit Versionspruefung kompatibel gemacht, indem bei Undo/Redo immer die aktuelle Basis-Version verwendet wird.
* Setlist-Editor: Regelmaessiger Hintergrund-Check auf neuere ``setlist_version`` in der Datenbank ergaenzt; bei externer Aenderung wird die Browser-Ansicht automatisch aktualisiert und per Toast darauf hingewiesen.
* Chore: Projektversion auf ``0.5.13`` erhoeht (Backend/Frontend/Lockfile/Release-Metadaten/README-Badge).
* Manual: Changelog fuer Release ``0.5.13`` ergaenzt.

0.5.12 (2026-06-10)
-------------------

Changed
~~~~~~~

* Setlist-Editor: Undo/Redo im Editor ergaenzt (Buttons sowie Shortcuts ``Strg/Cmd+Z`` und ``Strg/Cmd+Y``).
* Setlist-Editor: Fehler-Feedback ueber Toast-Meldungen bei fehlgeschlagenem Speichern sowie Undo/Redo ergaenzt.
* Setlist-Editor: Stabilitaet beim Loeschen und bei Drag-and-Drop verbessert, damit Songs nach dem Entfernen wieder sauber zusammenrutschen und Verschiebe-Aktionen als Undo-Schritt erfasst werden.
* Chore: Projektversion auf ``0.5.12`` erhoeht (Backend/Frontend/Lockfile/Release-Metadaten/README-Badge).

0.5.11 (2026-06-09)
-------------------

Changed
~~~~~~~

* Setlist-Editor: Nach dem Schliessen des Song-Details-Modals werden geaenderte Songdaten lokal uebernommen; Saengerfarben werden ohne kompletten Seiten-Reload neu gerendert.
* Chore: Projektversion auf ``0.5.11`` erhoeht (Backend/Frontend/Lockfile/Release-Metadaten/README-Badge).

0.5.10 (2026-06-08)
-------------------

Changed
~~~~~~~

* Setlist-Editor: Song details Modal in Songlist.

0.5.9 (2026-06-08)
-------------------

Changed
~~~~~~~

* Song-Details: Die Saenger-Vorschlagsliste wurde visuell verstaerkt (deutlicher Kontrast, nahezu deckender Hintergrund), damit Eintraege im Modal besser lesbar sind.
* Songs-Liste: Laufzeitfehler beim Grid-Layout behoben (``gridApi.doLayout is not a function``); Layout-Aufrufe sind jetzt API-kompatibel abgesichert.
* Chore: Projektversion auf ``0.5.9`` erhoeht (Backend/Frontend/Lockfile/Release-Metadaten/README-Badge).

0.5.8 (2026-06-05)
-------------------

Changed
~~~~~

* Setlist-Editor: Neue Abstände für bessere Übersicht

* Chore: Projektversion auf ``0.5.8`` erhoeht (Backend/Frontend/Release-Metadaten/README-Badge).
* Manual: Fuer ``0.5.7`` sind noch keine neuen Screenshots im Handbuch enthalten; diese werden zeitnah nachgereicht.


0.5.7 (2026-06-04)
-------------------

Changed
~~~~~~~

* Frontend-UI: Seitenuebergreifend modernisierte und vereinheitlichte Komponentenstile (Cards, Buttons, Inputs, Tabs, Tabellen) inkl. konsistenter Light-/Dark-Mode-Darstellung.
* Frontend-UI: Globale Hintergrundverlaeufe fuer die App sowie abgestimmte Verlaufsflaechen in zentralen Dashboard-Bereichen ergaenzt.
* Setlist-Editor: Song-Elemente in der Songliste zeigen die Saengerfarben wieder sichtbar an und sind im Darkmode kontrastreicher dargestellt.
* Chore: Projektversion auf ``0.5.7`` erhoeht (Backend/Frontend/Release-Metadaten/README-Badge).
* Manual: Fuer ``0.5.7`` sind noch keine neuen Screenshots im Handbuch enthalten; diese werden zeitnah nachgereicht.

0.5.6 (2026-06-03)
-------------------

Changed
~~~~~~~

* Setlist-Timing: Uebersprungene Songs (``uebersprungen = true``) werden in der Zeitkalkulation nun mit ``0`` Sekunden beruecksichtigt.
* Setlist-Timing: Berechnung von ``schedule``, ``set_end`` und set-uebergreifenden Pausen ist auf die neue Skip-Logik abgestimmt.
* Tests: Neue Abdeckung fuer den Fall, dass ein uebersprungener Song keine Laufzeit zur Setliste addiert.
* Chore: Projektversion auf ``0.5.6`` erhoeht (Backend/Frontend/Lockfile/Release-Metadaten/README-Badge).

0.5.5 (2026-06-03)
-------------------

Added
~~~~~

* Admin-Konfiguration: ``setlist_timing`` ist jetzt im Soft-Config-Editor direkt bearbeitbar.
* Admin-Konfiguration: Timing-Werte werden im Editor ueber besser lesbare Time-Picker (``HH:MM:SS``) erfasst.

Changed
~~~~~~~

* Soft-Config-Backend validiert und normalisiert ``setlist_timing`` inklusive Pflicht-Keys und nicht-negativer Ganzzahlen.
* Setlist-Timing nutzt keine hartkodierten Defaults mehr, sondern liest die Standardwerte aus ``appConfig.json`` (mit sicheren Fallbacks).
* Chore: Projektversion auf ``0.5.5`` erhoeht (Backend/Frontend/Lockfile/Release-Metadaten/README-Badge).

0.5.4 (2026-06-02)
-------------------

Added
~~~~~

* Proben/Songkarte: Neue Aktion ``Letzte Probe`` oeffnet ein Modal mit dem letzten verfuegbaren Protokoll des Songs vor der aktuellen Probe.

Changed
~~~~~~~

* Protokollansicht vergangener Proben: Lesbarkeit verbessert durch hoeheren Textkontrast, entspanntere Zeilenhoehe und klar getrennte Song-Bloecke.
* Status-Buttons in der Songkarte: nicht aktive Stati werden als Outline dargestellt; ``retired`` bleibt rot hervorgehoben.
* Songkarte uebergibt nun ``rehearsalId`` und ``rehearsalBegin`` an Kindkomponenten fuer kontextbezogene Protokollabfragen.
* Song-Details: Tab ``Abstimmung`` zeigt Abstimmungen jetzt anonymisiert nur noch als Summen (Ja/Nein/Enthaltung) ohne Einzelstimmen.
* Chore: Projektversion auf ``0.5.4`` erhoeht (Backend/Frontend/Lockfile/Release-Metadaten/README-Badge).

0.5.3 (2026-05-28)
-------------------

Added
~~~~~

* Song Tabelle im Webfrontend flexibler und Platzökonomischer gemacht
* Songs API: Neuer Endpoint ``GET /songs/crawler/metadata`` liefert Song-Metadaten (Dauer, Komponist/Texter, YouTube-Link) fuer ``interpret`` + ``title``.
* Song anlegen: Formular laedt Metadaten nun automatisch nach dem Ausfuellen von Interpret und Titel (inkl. Debounce/Cooldown und Ladeindikator).
* Backend-Tests: Neue Testfaelle fuer den Metadata-Endpoint (200/404) und erweiterte ``audioscrawler``-Tests inklusive YouTube-Link-Aufloesung ueber Release-Kette.

Changed
~~~~~~~

* ``backend/utils/audioscrawler.py`` wurde deutlich robustifiziert: besseres Matching/Scoring fuer Recordings/Works, Normalisierung von Personennamen, Fallbacks auf TheAudioDB bei MusicBrainz-Fehlern sowie YouTube-Link-Suche in Recording-, Release- und Release-Group-Relationen.
* Setlist-Editor: Loeschen von Songs nutzt eine ruhige zweistufige Exit-Animation (erst visuell ausblenden/nach rechts schieben, dann entfernen), um hektische Layout-Spruenge zu reduzieren.
* Songs-Schema erweitert um ``SongScrawlOut`` fuer die strukturierte Rueckgabe der Crawler-Metadaten.
* Chore: Projektversion auf ``0.5.3`` erhoeht (Backend/Frontend/Lockfile/Release-Metadaten/README-Badge).

0.5.2 (2026-05-27)
-------------------

Added
~~~~~

* Dashboard: Neue Karten fuer ``naechste Probe`` und ``naechsten Auftritt`` mit Datum/Details und Direktlinks zu ``/proben`` bzw. ``/gigs``.

Changed
~~~~~~~

* Bugfix: Im Setlist Editor wurde die Zeitberechnung für Datumsüberlauf sensibilisiert.
* Dashboard: Saisonstatistik-Block auf eCharts umgestellt (Gigs-Fortschritt, Song-Mix, Feedback-Gauge, Genre-Top-Liste).
* Chore: Projektversion auf ``0.5.2`` erhoeht (Backend/Frontend/Lockfiles/Release-Metadaten/README-Badge).

0.5.1 (2026-05-26)
-------------------

Added
~~~~~

* Neuer Gig-Endpoint ``GET /gigs/genre_palette`` liefert eine globale, deterministische Genre-Farbpalette fuer konsistente Farben ueber alle Statistiken hinweg.

Changed
~~~~~~~

* Genre-Farben in den Gig-/Saison-Statistikplots werden nun backend-seitig vereinheitlicht und nicht mehr pro einzelnem Datensatz lokal abgeleitet.
* Genre-Palette auf bis zu 25 eindeutige Farben erweitert, bevor Farben zyklisch wiederverwendet werden.
* Chore: Projektversion auf ``0.5.1`` erhoeht (Backend/Frontend/Lockfile/Release-Metadaten/README-Badge).

0.5.0 (2026-05-26)
-------------------

Added
~~~~~

* Gig- und Saison-Statistik: Neuer Feedback-Verteilungsplot (Donut) für Live-Bewertungen.
* Gig- und Saison-Statistik: Genre-Visualisierung mit relativer Verteilung und normalisiertem Stacked-Bar-Verlauf.
* Genre-Plot: Filter nach Veranstaltungsart in der Saisonstatistik.

Changed
~~~~~~~

* Stats-Plots visuell überarbeitet: kompaktere Diagrammbereiche, bessere Achsenbeschriftung, weniger Label-Überlappungen.
* Chore: Projektversion auf ``0.5.0`` erhöht (Backend/Frontend/Lockfile/Release-Metadaten/README-Badge).
* Manual: Changelog um die neuen Feedback- und Genre-Auswertungen ergänzt.

0.4.6a (2026-05-23)
--------------------

Fixed
~~~~~

* Setlisteneditor: Beim Drag-and-Drop aus der Songliste in ein Set wurde der neue Song in bestimmten Fällen nicht persistiert. Der Speichern-Flow setzt nun die ``song_id`` robust, sodass der Eintrag zuverlässig gespeichert wird.

Changed
~~~~~~~

* Projektversion auf ``0.4.6a`` erhöht (Backend/Frontend/Release-Metadaten).

0.4.6 (2026-05-23)
-------------------

Changed
~~~~~~~

* Live-Modus Layout wurde für bessere Bedienbarkeit auf Bühne/Tablet überarbeitet (stabileres Höhenlayout, größere Bewertungsschaltflächen, bessere Kontraste im Light/Dark-Mode).
* Song-Einfügen und Hilfe werden als Overlay dargestellt, damit die Hauptansicht ohne störendes Vertikal-Scrollen nutzbar bleibt.
* Setlisteneditor: Songliste unterstützt jetzt Drag-and-Drop direkt in Sets; neue Einträge werden dabei robust als neue Set-Songs verarbeitet.
* Setlisteneditor: Beim Hinzufügen aus der Songliste kann das Ziel-Set direkt gewählt werden (statt immer nur ans Ende der Setliste).
* Setlisteneditor: Layout und Bedienelemente wurden für Tablet/Touch verbessert (größere Buttons, optimierte Grid-Aufteilung, bessere Sichtbarkeit von Set-/Song-Infos).


0.4.5 (2026-05-22)
-------------------

Added
~~~~~

* New backend export endpoint ``GET /gigs/{gig_id}/forscore-setlist`` generates forScore-compatible ``.4ss`` setlists (PLIST XML).
* Gig detail view in the iOS app now includes a dedicated action to download/share ``forScore-Setliste (.4ss)`` directly from ``GigDetailView``.
* Backend tests now cover forScore setlist export success and ``404`` handling for unknown gigs.

Changed
~~~~~~~

* Project version metadata bumped to ``0.4.5`` across backend/frontend release files and README badge.

0.4.4 (2026-05-19)
-------------------

Added
~~~~~

* Shared utility ``backend/utils/pdf_palette.py`` now centralizes logo-based palette extraction for schedule and setlist PDFs.
* Setlist palette resolver now supports ``druckfreundlich`` as explicit mode switch (print-friendly light palette).

Changed
~~~~~~~

* Setlist PDF and schedule PDF now use the same shared palette extraction pipeline.
* Palette resolvers now return robust default schemes when no logo is available.
* Project, frontend and lockfile versions bumped to ``0.4.4``.

0.4.3 (2026-05-18)
--------------------

Added
~~~~~

* Gig edit forms now use a second-precision time picker (``HH:MM:SS``) in desktop and mobile views.

Changed
~~~~~~~

* Gig time values are normalized to ``HH:MM:SS`` during edit and save flows.
* Gig schedule fixed points (doors, begin, end) now support midnight rollover correctly.
* Project and frontend versions bumped to ``0.4.3``.

0.4.2 (2026-05-17)
--------------------

Added
~~~~~

* Setlist PDF supports a second, print-friendly style via ``design=print``.
* Gig UI offers a dedicated download action for the print-friendly setlist PDF.
* Setlist PDF now includes a subtle logo watermark.
* New backend test for print-style setlist PDF export.

Changed
~~~~~~~

* Setlist PDF visual design was aligned with the schedule PDF style.
* Setlist PDF header was reduced in height to free more content space.
* Setlist PDF accent colors were adjusted to orange tones matching the schedule style.
* Setlist PDF footer now includes ``Generated by libreStage | pakleds-patentoffice.de``.
* Pause display in setlists moved from "before next set" to "after current set".
* Project and frontend versions bumped to ``0.4.2``.


v0.4.1 (2026-05-15)
--------------------
* Fix: Setlist-Generator - Direkter Import von timedelta am Anfang.
* Setlist-Editor: Neue Shortcuts fuer schnelleres Arbeiten (u. a.
  ``Strg/Cmd + Shift + Enter`` fuer neues Set am Ende)
* Setlist-Editor: ``Enter`` im Suchfeld fuegt nur noch ohne Zusatz-Tasten hinzu
  und scrollt anschliessend automatisch ans Ende der Setlist
* Setlist-Editor: Shortcut zum Entfernen des letzten Songs aus dem Stack
  ergaenzt (``Strg/Cmd + Shift + Backspace/Entf``)
* Setlist-Editor: Direkte Schnellwahl fuer Suchtreffer 1-4 ueber
  ``Strg/Cmd + Opt/Alt + Shift + 1-4`` im Suchfeld
* Benutzerhandbuch: Setlist-Editor-Dokumentation an die neuen Shortcuts und
  das aktualisierte Suchfeld-Verhalten angepasst

v0.4.0 (2026-05-12)
--------------------

* Admin: Neue Seite **Konfiguration** unter ``/admin/config`` zum Bearbeiten
  der weichen ``appConfig.json``-Parameter direkt in der Anwendung
* Admin: Neue API-Endpunkte ``GET /admin/config/soft`` und
  ``PUT /admin/config/soft`` mit strikter Rollenpruefung (nur ``admin``)
* Konfiguration: ``appConfig``-Verarbeitung im Backend erweitert um
  Validierung, Normalisierung, atomisches Schreiben und Reload ohne Neustart
* Frontend: Soft-Config-Editor nutzt jetzt das zentrale Toast-System fuer
  Erfolg/Fehler-Hinweise statt lokaler Inline-Alerts
* Frontend: Zeitstempel **Stand** in der Admin-Konfiguration wird im
  deutschen Datums-/Zeitformat angezeigt (``formatGermanDateTime``)
* Frontend: Plus/Minus-Aktionen im Config-Editor auf die ueblichen
  Icon-Button-Stile vereinheitlicht
* Tests: Neue Backend-Tests fuer Admin-Config-Endpunkte inkl. Auth,
  Validierung und Persistenz
* Benutzerhandbuch: Neues Kapitel zur Admin-Konfiguration ergaenzt

v0.3.16 (2026-05-04)
---------------------

* Song-Vorschläge: Spalten **Mein Feedback** und **Gesamtfeedback** zur
  gemeinsamen Spalte **Abstimmung** zusammengefuehrt
* Song-Vorschläge: Stimmanzeigen (Ja/Nein/Enthaltung) als klickbare Buttons
  umgesetzt; Musiker koennen direkt ueber die Badge-Buttons abstimmen
* Song-Vorschläge: Aktive eigene Stimme wird visuell hervorgehoben
* Song-Vorschläge: Mobile Darstellung der Abstimmungs-Elemente verbessert
  (unterhalb ``md`` untereinander, ab ``md`` wieder nebeneinander)
* Song-Details: In der normalen Detailansicht kann ein Song per Dropdown einer
  geplanten zukuenftigen Probe zugewiesen werden
* Song-Details: Das Dropdown enthaelt eine leere Option (**Keine Zuordnung**),
  um den Song keiner Probe zuzuweisen

v0.3.15 (2026-04-18)
---------------------

* Songs: Beim Anlegen eines Songs prueft das Formular jetzt live die Kombination
  aus **Titel** und **Interpret** gegen bestehende Eintraege (inkl. kleiner
  Schreibabweichungen)
* Songs: Bei wahrscheinlicher Dublette erscheint direkt unter **Interpret** ein
  Warning-Hinweis mit dem Status des bereits vorhandenen Songs
* Songs: Das Speichern bleibt trotz Hinweis weiterhin moeglich
* Benutzerhandbuch: Abschnitt ``Song anlegen`` um die neue Dublettenwarnung
  ergaenzt

v0.3.13 (2026-03-16)
---------------------

* Proben: Beim Erstellen einer Probe kann jetzt optional eine **Endzeit** gesetzt werden
* Proben: Wird keine Endzeit angegeben, setzt das Backend automatisch **Startzeit + 2 Stunden**
* Proben: Validierung für Zeitbereiche ergänzt (Endzeit muss nach der Startzeit liegen)
* Proben: Kartenansicht und Lösch-Bestätigung zeigen den **Zeitraum** (Start-Ende) statt nur Datum/Startzeit
* Benachrichtigungen: Erstellungs-Text (Mattermost) zeigt den vollständigen Proben-Zeitraum
* iCal: Öffentlicher Kalender-Export zeigt bei Proben den Zeitraum im Summary und in der Beschreibung
* Benutzerhandbuch: Proben-Dokumentation auf das neue Zeitbereichs-Verhalten aktualisiert

v0.3.12 (2026-03-15)
---------------------

* Benutzerverwaltung: Benutzer können nicht mehr endgültig gelöscht werden –
  stattdessen wird ein **Status** (``active`` / ``deactivated``) eingeführt
* Benutzerverwaltung: Neuer **🚫 Deaktivieren**-Button pro Tabellenzeile deaktiviert
  einen Benutzer nach Bestätigung; deaktivierte Benutzer können sofort über
  **✅ Reaktivieren** wieder freigeschaltet werden
* Benutzerverwaltung: Neue **Status-Spalte** in der Benutzertabelle zeigt
  ``✅ aktiv`` / ``🚫 deaktiviert`` farbig an
* Sicherheit: Beim Deaktivieren werden **alle aktiven Refresh-Tokens** des Benutzers
  sofort widerrufen → Logout aller Geräte ohne Verzögerung
* Sicherheit: Jeder API-Request prüft den Benutzerstatus direkt in der Datenbank –
  deaktivierte Benutzer erhalten **sofort HTTP 401** (kein Warten auf Token-Ablauf)
* Sicherheit: Deaktivierte Benutzer können sich **nicht einloggen** und haben
  **kein Stimmrecht** bei Song- und Meinungsumfragen
* Sicherheit: Admins können **ihren eigenen Account nicht deaktivieren** (Schutz
  vor versehentlicher Aussperrung)
* Erinnerungen & Benutzerliste: Deaktivierte Musiker erhalten **keine Erinnerungs-
  Benachrichtigungen** mehr und erscheinen nicht in Auswahllisten
* Datenbank: Migration ``2d3e2798b7a5`` fügt Spalte ``status VARCHAR(32) NOT NULL
  DEFAULT 'active'`` zur Tabelle ``users`` hinzu; alle bestehenden Einträge
  werden automatisch auf ``active`` gesetzt
* Backend: ``DELETE /admin/users/{id}`` setzt nun ``status = deactivated`` statt
  den Datensatz zu entfernen; neuer Endpoint ``PUT /admin/users/{id}/activate``

v0.3.11 (2026-03-15)
---------------------

* Benutzerverwaltung: Admins können Benutzer direkt über ein **+**-Formular
  anlegen (Username, Klarname, E-Mail, Passwort, Rolle, Musiker, Sänger)
* Benutzerverwaltung: Neuer **🗑️-Button** pro Tabellenzeile löscht einen
  Benutzer nach Bestätigung über das Standard-Bestätigungs-Modal
* Benutzerverwaltung: Tabelle wird nach Anlegen und Löschen automatisch
  aktualisiert
* Backend: neuer ``DELETE /admin/users/{id}`` Endpoint
* Benutzerhandbuch: Abschnitt „Benutzerverwaltung" vollständig neu dokumentiert

v0.3.10 (2026-03-15)
---------------------

* Live-Modus: Vorwärts-Sprung über die Setlisten-Übersicht (Shortcut ``L``)
  markiert den aktuellen Song und alle übersprungenen Songs zwischen aktuellem
  und Ziel-Song automatisch als **übersprungen**; Rückwärts-Sprünge bleiben
  ohne Seiteneffekte
* Proben: Vergangene Proben werden als schreibgeschütztes **Protokoll** angezeigt –
  Probenkommentar, Songs mit Status, Todos und Kommentaren, keine Bearbeitungs-Controls
* Proben: Protokoll-Ansicht verschlankt – Markdown-ähnliche Textdarstellung ohne
  Badges, Rahmen oder verschachtelte Listen
* Proben: Suchbegriff aus der übergeordneten Suche wird im aufgeklappten Protokoll
  **farbig hervorgehoben**; separates inneres Suchfeld entfernt
* Proben: **Suche über alle vergangenen Proben** – filtert nach Datum, Song-Titel,
  Interpret und Probenkommentar
* Proben: Eine Probe bleibt den **ganzen Probentag und den Folgetag** editierbar
  und unter „Bevorstehende Proben" sichtbar; erst danach wechselt sie ins Protokoll
* Proben: Schaltfläche „Neue Probe" als kompaktes **+**-Icon direkt neben der
  Seitenüberschrift platziert (nur für Admins/Editoren sichtbar)

v0.3.9 (2026-03-14)
--------------------

* Song-Vorschläge: Abstimmungsanzeige als kompakte **Badge-Zeile** überarbeitet –
  Ja/Nein/Enthaltung mit absoluten Werten und Prozentzahlen direkt sichtbar,
  kein Hover mehr erforderlich
* Song-Vorschläge: **Quorum-Kriterium** eingeführt – ``max(3, floor(n × 0,75))``
  Stimmberechtigte müssen abgestimmt haben, bevor der Übernahme-Button erscheint
* Song-Vorschläge: Übernahme-Button (✓, grün) erscheint für Admins/Editoren
  sobald Quorum erreicht und ≥ 50 % Ja-Stimmen vorliegen; kein Button solange
  das Quorum nicht erfüllt ist
* Song-Vorschläge: Anzeige „**∑ abgegeben / gesamt**" zeigt Abstimmungsfortschritt;
  Quorum-Detail im Tooltip
* Song-Vorschläge: „(n f. Quorum)"-Texthinweis entfernt – Layout schlanker
* Benutzerhandbuch: Abschnitt „Song-Vorschläge & Abstimmung" vollständig neu dokumentiert

v0.3.5 (2026-03-10)
--------------------

* Setlist-Editor: Bug-Fix beim Hinzufügen mehrerer Sets ohne Seitenreload
* Setlist-Editor: Rename-Funktion für Sets stabilisiert
* Frontend auf Svelte 5 / Skeleton 4.12.1 migriert
* Zeitraum-Generierung im Gig-Formular korrigiert

v0.3.0
------

* Live-Modus: Swipe-Navigation auf Mobilgeräten
* Live-Modus: Song-Bewertung (😞 / 😐 / 😊)
* Song-Statistiken: Proben- und Gig-Historie
* GEMA-Export: übersprungene Songs werden ausgeschlossen

v0.2.0
------

* Saison-Statistiken im Dashboard
* Abstimmungs-System (Meinungsumfrage, Terminfindung, Auftrittsanfrage)
* Passwort-Stärke-Validierung
* Rate-Limiting auf sicherheitskritischen Endpoints

v0.1.0
------

* Initiale Veröffentlichung
* Gig-Verwaltung mit Setlist-Editor
* Song-Datenbank, Proben-Planung
* Benutzerverwaltung mit Rollen (admin / editor / musician)
* iCal-Export, PDF-Generierung
