.. _livemode:

Live-Modus
==========

Der Live-Modus begleitet die Band während eines Auftritts. Er zeigt den aktuellen Song
prominent an, ermöglicht Navigation und erfasst Bewertungen für spätere Auswertungen.

.. note::
   Screenshot folgt – bitte ``docs/manual/_static/screenshots/livemode.png`` ablegen.

Verfügbarkeit
-------------

Der Live-Modus kann gestartet werden, wenn:

* **Es der Gig-Tag ist** (das Datum des Gigs entspricht dem heutigen Datum), *oder*
* ein **Editor oder Admin** den Modus manuell erzwingt.

Musician-Benutzer können den Live-Modus nur am Gig-Tag starten.

Song-Navigation
---------------

Desktop
~~~~~~~

* **Pfeil rechts / Weiter-Button:** Nächster Song
* **Tastatur →:** Nächster Song
* **Pfeil links / Zurück-Button:** Vorheriger Song
* **Tastatur ←:** Vorheriger Song

Mobile (Touch)
~~~~~~~~~~~~~~

* **Wischen nach links:** Nächster Song
* **Wischen nach rechts:** Vorheriger Song

Fortschrittsanzeige
~~~~~~~~~~~~~~~~~~~

Eine Progress-Bar zeigt die aktuelle Position innerhalb der Setlist.
Darunter wird der aktuelle Set und die Position im Set angezeigt
(z. B. „Set 2 – Song 3 / 8“).

Songbewertung
-------------

Nach dem Spielen eines Songs kann eine Bewertung abgegeben werden:

.. list-table::
   :header-rows: 1
   :widths: 15 85

   * - Symbol
     - Bedeutung
   * - 😞
     - Hat nicht gut funktioniert
   * - 😐
     - War in Ordnung
   * - 😊
     - Hat sehr gut funktioniert

Die Bewertungen fließen in die Song-Statistiken ein.

Song überspringen
-----------------

Über den Button **Überspringen** wird der aktuelle Song als übersprungen markiert.
Übersprungene Songs werden im GEMA-Export ausgeschlossen (siehe :ref:`gigs`).

Song einfügen
-------------

Über **Song einfügen** kann ein Song aus der Datenbank spontan in die laufende Setlist
eingefügt werden.

Session wiederverbinden
-----------------------

Wird die Seite neu geladen oder das Gerät gewechselt, öffnet sich der Live-Modus
automatisch an der zuletzt gespeicherten Position.
