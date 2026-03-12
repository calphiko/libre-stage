.. _dashboard:

Dashboard
=========

Das Dashboard ist die erste Seite nach dem Login. Es zeigt auf einen Blick alle
persönlichen Aufgaben, offene Abstimmungen und die Saison-Statistiken der Band.

.. note::
   Screenshot folgt – bitte ``docs/manual/_static/screenshots/dashboard.png`` ablegen.

Todos
-----

Der Reiter **Offene Aufgaben** listet alle Todos auf, die dem eingeloggten Benutzer
zugewiesen sind. Todos entstehen automatisch, wenn:

* Eine neue Probe mit Aufgaben erstellt wird
* Ein Song zur Bewertung freigegeben wurde
* Eine Abstimmung gestartet wurde

Todos können mit einem Klick auf das Häkchen als erledigt markiert werden.
Erledigte Todos werden im Reiter **Erledigte Aufgaben** archiviert.

Songbewertungen
~~~~~~~~~~~~~~~

Im Reiter **Songbewertungen** erscheinen Songs, für die noch keine persönliche
Bewertung abgegeben wurde. Hier kann direkt eine Bewertung (Daumen hoch / Daumen runter)
eingetragen werden.

Abstimmungen
~~~~~~~~~~~~~

Offene Abstimmungen erscheinen im Reiter **Offene Abstimmungen**.
Ein Klick öffnet die jeweilige Abstimmung.

Saison-Statistiken
------------------

Das Widget **Saison-Statistiken** (nur für admins und editors sichtbar) zeigt:

* Anzahl Gigs, Proben und Songs
* Häufigste Genres im Repertoire
* Aktivste Sänger in Setlists

Kalender-Export (iCal)
-----------------------

Unter **Mein Kalender** findet jeder Benutzer seine persönliche iCal-URL.
Diese URL kann in Google Calendar, Apple Kalender, Thunderbird etc. eingebunden werden.

.. code-block:: text

   https://<deine-domain>/cal/ical/<token>

Die URL enthält einen persönlichen Token und sollte nicht öffentlich geteilt werden.
