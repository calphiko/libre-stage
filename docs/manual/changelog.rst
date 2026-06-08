.. _changelog:

Änderungsprotokoll
==================

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
