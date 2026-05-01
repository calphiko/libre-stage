.. _proben:

Proben
======

Im Bereich **Proben** werden Bandproben geplant, vorbereitet und im Nachgang
als Protokoll dokumentiert.

.. note::
   Screenshot folgt - bitte ``docs/manual/_static/screenshots/proben.png`` ablegen.

Probe anlegen
-------------

Klicke auf das **+** neben der Ueberschrift **Proben**, um das Formular zu oeffnen.

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - Feld
     - Beschreibung
   * - **Start (Datum & Zeit)**
     - Pflichtfeld fuer den Beginn der Probe
   * - **Ende (optional)**
     - Optionales Enddatum mit Uhrzeit; muss nach dem Start liegen
   * - **Kommentar**
     - Freitext fuer interne Notizen

**Wichtig:** Wird keine Endzeit eingetragen, setzt das System automatisch
**Startzeit + 2 Stunden**.

Zeitraum in der Listenansicht
-----------------------------

Jede Probe wird als Zeitbereich angezeigt (z. B. ``18:00-20:30 Uhr``).
Wenn Start und Ende auf verschiedenen Tagen liegen, zeigt die Karte beide Daten.

Beim Loeschen einer Probe enthaelt der Bestaetigungsdialog ebenfalls den
vollstaendigen Zeitraum, damit es keine Verwechslungen gibt.

Songs und Todos in Proben
-------------------------

In einer aufgeklappten Probe koennen Songs hinzugefuegt und pro Song Todos,
Status und Kommentare gepflegt werden.

* Song zur Probe hinzufuegen (inkl. optionalem Todo)
* Song-Status direkt in der Probe aendern
* Persoenliche Todos pro Mitglied vergeben
* Song und Probenkommentare dokumentieren

Vergangene Proben - Protokoll-Ansicht
-------------------------------------

Vergangene Proben werden im Tab **Vergangene Proben** als schreibgeschuetztes
Protokoll angezeigt.

Das Protokoll zeigt:

* den Probenkommentar als Freitext
* alle Songs inkl. Status, Todo und Kommentaren
* persoenliche Todos mit Statussymbolen (``✔`` erledigt, ``⏳`` offen)

Suche in vergangenen Proben
---------------------------

Das Suchfeld oberhalb der Liste filtert vergangene Proben nach:

* Datum
* Song-Titel
* Interpret
* Probenkommentar

Treffer werden in der aufgeklappten Protokollansicht farblich hervorgehoben.

iCal-Export
-----------

Proben erscheinen automatisch im oeffentlichen iCal-Feed unter ``/ical/``.
Der Kalendereintrag enthaelt den Zeitbereich (Start-Ende) im Titel und in der
Beschreibung.
