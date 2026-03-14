.. _changelog:

Änderungsprotokoll
==================

v0.3.9 (2026-03-14)
--------------------

* Song-Vorschläge: Abstimmungsanzeige als kompakte Badge-Zeile überarbeitet –
  Ja/Nein/Enthaltung mit absoluten Werten und Prozentzahlen direkt sichtbar
* Song-Vorschläge: Quorum-Kriterium eingeführt – ``max(3, floor(n × 0,75))``
  Stimmberechtigte müssen abgestimmt haben, bevor der Übernahme-Button erscheint
* Song-Vorschläge: Übernahme-Button (✓, grün) erscheint für Admins/Editoren
  sobald Quorum erreicht und ≥ 50 % Ja-Stimmen vorliegen; kein Button solange
  das Quorum fehlt
* Song-Vorschläge: Anzeige „∑ abgegeben / gesamt" mit Hinweis auf fehlende
  Quorum-Stimmen
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
