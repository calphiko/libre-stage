.. _changelog:

Änderungsprotokoll
==================

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

* Song-Vorschlaege: Spalten **Mein Feedback** und **Gesamtfeedback** zur
  gemeinsamen Spalte **Abstimmung** zusammengefuehrt
* Song-Vorschlaege: Stimmanzeigen (Ja/Nein/Enthaltung) als klickbare Buttons
  umgesetzt; Musiker koennen direkt ueber die Badge-Buttons abstimmen
* Song-Vorschlaege: Aktive eigene Stimme wird visuell hervorgehoben
* Song-Vorschlaege: Mobile Darstellung der Abstimmungs-Elemente verbessert
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
