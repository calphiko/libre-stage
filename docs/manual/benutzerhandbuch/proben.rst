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

Vergangene Proben – Protokoll-Ansicht
--------------------------------------

Proben deren Datum in der Vergangenheit liegt, werden im Tab **Vergangene Proben**
als schreibgeschütztes Protokoll angezeigt. Eine Bearbeitung ist nicht mehr möglich.

Das Protokoll zeigt:

* Den **Probenkommentar** als Freitext
* Alle **Songs** mit Status-Badge, Todo, Probenkommentar und persönlichen Todos
* Todo-Status: ✔ = erledigt, ⏳ = offen, mit Namensnennung des Zugewiesenen

Suche in vergangenen Proben
-----------------------------

Es gibt zwei Suchebenen:

**Außen – Proben-Suche** (oberhalb der Probe-Liste):
  Filtert welche Proben-Karten angezeigt werden. Durchsucht gleichzeitig
  Datum, Song-Titel, Interpret und Probenkommentar.

**Innen – Song-Suche** (innerhalb einer aufgeklappten Probe):
  Filtert die Song-Liste der aufgeklappten Probe nach Titel, Interpret
  und Probenkommentar. Ein Trefferzähler „x von y Songs" erscheint
  sobald der Filter aktiv ist.

iCal-Export
-----------

Proben erscheinen automatisch im persönlichen Kalender-Feed jedes Benutzers
(siehe :ref:`dashboard` – Kalender-Export).
