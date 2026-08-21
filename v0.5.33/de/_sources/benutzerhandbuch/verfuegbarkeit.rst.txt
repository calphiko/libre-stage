.. _verfuegbarkeit:

Verfügbarkeitsmanagement
========================

Das Verfügbarkeitsmanagement ermöglicht es jedem Bandmitglied, seine
Teilnahme für anstehende **Gigs** und **Proben** vorab zuzusagen, abzulehnen
oder als unsicher zu kennzeichnen.
Bei einer Absage kann optional eine **Aushilfe** eingetragen werden –
entweder als registriertes Bandmitglied oder als freier Text für externe Personen.

Verfügbarkeit eintragen
-----------------------

Für jeden Gig oder jede Probe stehen drei Status-Schaltflächen zur Verfügung:

.. list-table::
   :header-rows: 1
   :widths: 15 85

   * - Status
     - Bedeutung
   * - ✅ **Dabei**
     - Ich nehme teil.
   * - ❓ **Vielleicht**
     - Ich bin voraussichtlich dabei, kann aber noch nicht sicher zusagen.
   * - ❌ **Nicht dabei**
     - Ich kann nicht teilnehmen.

Ein Klick auf den jeweiligen Button speichert die Auswahl sofort.
Mit dem **✕**-Button wird die eigene Rückmeldung wieder zurückgezogen.

Optionaler Kommentar
~~~~~~~~~~~~~~~~~~~~

Unterhalb der Status-Schaltflächen erscheint ein Kommentarfeld,
in dem ein kurzer Freitext hinterlegt werden kann
(z. B. „Komme etwas später", „Hängt vom Feierabend ab").
Das Feld wird beim Verlassen (``onblur``) automatisch gespeichert.

Aushilfe eintragen
------------------

Wählt ein Mitglied den Status **Nicht dabei**, erscheint ein zusätzliches
Formular zum Eintragen einer Aushilfe.

* **Bandmitglied als Aushilfe**: Dropdown-Auswahl aus allen Musikern der Band.
  Ist eine Person ausgewählt, wird ihr Name automatisch in das Namensfeld übernommen.
* **Externe Aushilfe**: Wird keine interne Person ausgewählt, kann ein freier
  Name eingetippt werden (z. B. „Klaus Müller").

Die Aushilfe ist für alle Bandmitglieder in der Übersicht sichtbar.

Übersicht aller Rückmeldungen
------------------------------

Unterhalb der eigenen Auswahl wird eine tabellarische Übersicht angezeigt:

* **Zähler-Zeile**: Anzahl der Rückmeldungen je Status auf einen Blick
* **Dabei**: Badges aller bestätigten Teilnehmer
* **Vielleicht**: Badges der unsicheren Teilnehmer
* **Nicht dabei**: Name jedes abwesenden Mitglieds, darunter (sofern angegeben) die Aushilfe
* **Keine Rückmeldung**: Alle Bandmitglieder ohne Antwort (nur sichtbar,
  wenn die Musikerliste geladen ist)

Wo ist das Feature zu finden?
------------------------------

Gig-Details
~~~~~~~~~~~

Öffne den Gig-Detail-Dialog (Klick auf einen Gig in der Gigs-Liste).

* **Tab „Übersicht"** – zeigt eine kompakte Schnellübersicht der aktuellen
  Rückmeldungen:
  Zähler, farbige Badges je Status und Aushilfen.
  Über den Link **Details →** gelangt man direkt zum Verfügbarkeits-Tab.

* **Tab „Verfügbarkeit"** – zeigt den vollständigen Widget inkl.
  eigener Statuswahl, Aushilfeformular, Kommentar und vollständiger Teilnehmerliste.

Probe-Details
~~~~~~~~~~~~~

Öffne eine bevorstehende Probe durch Klick in der Probenliste.
Im Modal erscheint oben ein aufklappbarer Bereich **📅 Verfügbarkeit**.
Durch einen Klick auf die Leiste klappt das Widget auf und ermöglicht
Statuswahl, Aushilfe und Kommentar.

.. note::

   Das Widget lädt die Verfügbarkeitsdaten erst beim Aufklappen
   (Proben) bzw. beim Öffnen des Modals (Gigs), um unnötige
   Serveranfragen zu vermeiden.

Technische Details
------------------

* Backend-Endpunkte: ``GET/PUT/DELETE /availability/{event_type}/{event_id}``
* Datenbanktabelle: ``availability`` (Alembic-Migration ``e1f2a3b4c5d6``)
* Pro Benutzer und Ereignis wird genau ein Eintrag gespeichert (Upsert).
* Eine Aushilfe kann entweder als Freitext (``substitute_name``) oder als
  Referenz auf einen registrierten Benutzer (``substitute_user_id``) gespeichert werden.

