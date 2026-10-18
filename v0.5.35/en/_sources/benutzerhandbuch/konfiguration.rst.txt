.. _admin_konfiguration:

Admin-Konfiguration
===================

Ab Version ``v0.4.0`` koennen Admins die weichen Parameter aus
``appConfig.json`` direkt in der Weboberflaeche bearbeiten.

Aufruf
------

* Menuepunkt: **Konfiguration**
* Route: ``/admin/config``
* Zugriff: nur Benutzer mit Rolle ``admin``

Nicht-Admins werden auf das Dashboard umgeleitet.

Welche Werte koennen geaendert werden?
--------------------------------------

Folgende Soft-Keys sind editierbar:

* ``genres``
* ``gigTypes``
* ``songStatuses``
* ``gigStatuses``
* ``tonekeys``
* ``rehearsalSongStatuses``

Damit lassen sich Auswahlwerte in Formularen zentral pflegen, z. B.
Genre-Listen, Gig-Typen oder Statuswerte.

Bedienung
---------

* Mit **+** wird ein neuer Eintrag hinzugefuegt
* Mit **-** wird ein Eintrag entfernt
* **Verwerfen** setzt alle Aenderungen auf den zuletzt geladenen Stand zurueck
* **Speichern** schreibt die Konfiguration dauerhaft in ``appConfig.json``

Nach erfolgreichem Speichern wird die Frontend-Konfiguration neu geladen,
damit geaenderte Listen sofort in Formularen verfuegbar sind.

Validierung und Speicherung
---------------------------

Beim Speichern prueft das Backend die Daten:

* nur freigegebene Keys sind erlaubt
* Datentypen muessen zum jeweiligen Feld passen
* Strings werden normalisiert (z. B. trimmen, leere Eintraege entfernen)

Die Datei wird atomisch geschrieben, damit keine halbfertige Konfiguration
auf der Platte landet.

API-Hinweis
-----------

Die Admin-Seite nutzt intern folgende Endpunkte:

* ``GET /admin/config/soft``
* ``PUT /admin/config/soft``

Der oeffentliche Read-Endpoint ``GET /public/app_config`` bleibt weiterhin
bestehen und liefert die aktuelle Frontend-Konfiguration.

