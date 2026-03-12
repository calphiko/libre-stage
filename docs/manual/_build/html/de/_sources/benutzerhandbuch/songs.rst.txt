.. _songs:

Song-Datenbank
==============

Die Song-Datenbank enthält das gesamte Repertoire der Band.
Admins und Editors können Songs anlegen, bearbeiten und archivieren.

.. note::
   Screenshot folgt – bitte ``docs/manual/_static/screenshots/songs.png`` ablegen.

Song anlegen
------------

Klicke auf **+ Neuer Song**, um das Formular zu öffnen.

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Feld
     - Beschreibung
   * - **Titel**
     - Offizieller Songtitel
   * - **Interpret**
     - Ursprünglicher Interpret
   * - **Komponist**
     - Name(n) der Komponisten (für GEMA-Export)
   * - **Texter**
     - Name(n) der Texter (für GEMA-Export)
   * - **Bearbeiter**
     - Name des Bearbeiters (falls eigenes Arrangement)
   * - **Verlag**
     - Musikverlag (für GEMA-Export)
   * - **Tonart**
     - Tonart des Songs (z. B. „Am“, „G“, „C#“)
   * - **Dauer**
     - Spielzeit in Minuten:Sekunden (z. B. ``3:45``)
   * - **Genre**
     - Genre aus der konfigurierten Liste (siehe :ref:`configuration`)
   * - **Status**
     - Aktueller Status im Workflow (s. u.)
   * - **Sänger**
     - Hauptsänger aus der Sängerliste

Status-Workflow
---------------

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Status
     - Bedeutung
   * - **vorschlag**
     - Song wurde vorgeschlagen, aber noch nicht bewertet
   * - **angenommen**
     - Song ist grundsätzlich akzeptiert
   * - **proben**
     - Song wird aktiv geprobt
   * - **spielbar**
     - Song ist bühnenreif – erscheint im Setlist-Editor
   * - **bedarfsweise_proben**
     - Song ist spielbar, wird aber bei Bedarf nochmals geprobt

.. note::
   Nur Songs mit Status **spielbar** oder **bedarfsweise_proben** erscheinen
   im Setlist-Editor.

Filtern und Suchen
------------------

* Status (Mehrfachauswahl)
* Genre
* Sänger
* Freitextsuche (Titel / Interpret)

Song-Details und Statistiken
-----------------------------

Ein Klick auf einen Song öffnet die Detailansicht mit:

* Alle Felder des Songs
* **Proben-Historie:** Wie oft und wann wurde der Song geprobt?
* **Gig-Historie:** Bei welchen Auftritten wurde der Song gespielt, mit Bewertungen?
* **Feedback-Verteilung:** Balkendiagramm der Bewertungen aus dem Live-Modus
* **Häufige Begleiter:** Welche anderen Songs erscheinen am häufigsten in derselben Setlist?

Bewertungen (Songvoting)
------------------------

Alle Benutzer können Songs bewerten (Daumen hoch / Daumen runter).
Die Bewertungen sind im Dashboard als Aufgabe sichtbar.
