.. _proben:

Proben
======

Im Bereich **Proben** werden alle Bandproben geplant und dokumentiert.

.. note::
   Screenshot folgt – bitte ``docs/manual/_static/screenshots/proben.png`` ablegen.

Probe anlegen
-------------

Klicke auf **+ Neue Probe**, um das Formular zu öffnen:

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Feld
     - Beschreibung
   * - **Datum**
     - Datum der Probe
   * - **Uhrzeit**
     - Beginn der Probe
   * - **Ort**
     - Probenraum / Adresse
   * - **Kommentar**
     - Interne Anmerkungen zur Probe
   * - **Songs**
     - Liste der Songs, die in dieser Probe geübt werden sollen

Songs einer Probe zuweisen
--------------------------

Im Probe-Formular können Songs aus der Datenbank ausgewählt werden.
Die Song-Liste kann nach Status gefiltert werden
(konfigurierbar über ``rehearsalSongStatuses`` in ``appConfig.json``).

Aufgaben (Todos)
----------------

Admins und Editors können Aufgaben anlegen, die Mitgliedern zugewiesen werden:

* **Titel** der Aufgabe
* **Zugewiesener Benutzer** (oder alle Mitglieder)
* **Fälligkeit** (optional)

Zugewiesene Aufgaben erscheinen im Dashboard unter **Offene Aufgaben**.

Probe-Fortschritt
-----------------

In der Probe-Karte wird angezeigt, wie viele Aufgaben bereits erledigt wurden.

iCal-Export
-----------

Proben erscheinen automatisch im persönlichen Kalender-Feed jedes Benutzers
(siehe :ref:`dashboard` – Kalender-Export).
