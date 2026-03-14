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

Song-Vorschläge & Abstimmung
-----------------------------

Neu eingereichte Songs erhalten zunächst den Status **vorschlag** und erscheinen
im Tab **Vorschläge** der Song-Seite. Dort können alle stimmberechtigten
Bandmitglieder (Musiker) ihr Votum abgeben, bevor ein Song offiziell übernommen wird.

Abstimmen
~~~~~~~~~

Jedes Mitglied mit dem Flag **Musiker** kann pro Song eine von drei Stimmen abgeben:

.. list-table::
   :widths: 15 85

   * - 👍
     - **Ja** – ich möchte den Song ins Repertoire aufnehmen
   * - 👎
     - **Nein** – ich bin gegen die Aufnahme
   * - 🤷
     - **Enthaltung** – ich habe keine Meinung / möchte mich enthalten

Dieselbe Schaltfläche nochmals klicken zieht die Stimme zurück.

Abstimmungsergebnis auf einen Blick
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Das Ergebnis wird je Song als kompakte Badge-Zeile angezeigt:

* **∑ x / y** – abgegebene Stimmen (Ja + Nein + Enthaltung) von benötigten
  Quorum-Stimmen *y* (= 90 % aller Stimmberechtigten, aufgerundet)
* **(n fehlen)** – Hinweis, wie viele Stimmen noch für das Quorum fehlen
* 👍 **n (xx %)** – absolute und relative Anzahl der Ja-Stimmen
* 👎 **n (xx %)** – absolute und relative Anzahl der Nein-Stimmen
* 🤷 **n** – Enthaltungen (werden nur angezeigt, wenn mindestens eine vorliegt)
* **✅ Freigegeben** – erscheint, sobald alle drei Freigabe-Kriterien erfüllt sind

Freigabe-Kriterien
~~~~~~~~~~~~~~~~~~

Ein Song gilt als **freigegeben**, wenn gleichzeitig gilt:

1. Der Ja-Anteil unter den gültigen Stimmen (Ja + Nein) beträgt **≥ 50 %**.
2. Es wurden **mindestens 4** gültige Stimmen (Ja + Nein) abgegeben.
3. **Mindestens 90 % aller Stimmberechtigten** (Musiker) haben abgestimmt
   (Enthaltungen zählen für das Quorum mit).

.. note::
   Das Quorum wird berechnet als ``ceil(Anzahl Musiker × 0,9)``. Bei einer
   Band mit 10 Musikern müssen also mindestens 9 Stimmen vorliegen, bevor
   der Freigabe-Button aktiv wird.

Song übernehmen
~~~~~~~~~~~~~~~

Für **Admins und Editoren** erscheint in der Aktionsspalte die Schaltfläche **✓**,
sobald mindestens eine Ja-Stimme vorliegt. Die Farbe signalisiert den Status:

.. list-table::
   :widths: 15 85

   * - **Grün ✓**
     - Alle Kriterien erfüllt – Übernahme empfohlen
   * - **Gelb ✓**
     - Quorum noch nicht erreicht – Übernahme möglich, aber Begründung erforderlich

Abweichungen vom Abstimmungsergebnis (z. B. wegen Dringlichkeit oder persönlicher
Abstimmung in der Probe) müssen kurz begründet werden.

Persönliche Abstimmung
~~~~~~~~~~~~~~~~~~~~~~

Wurde in einer Probe direkt per Handzeichen abgestimmt, kann ein Admin/Editor
den Song ohne digitale Abstimmung direkt als **angenommen** eintragen –
vorausgesetzt, die anwesenden Stimmberechtigten haben mehrheitlich zugestimmt
(Enthaltungen zählen nicht).
