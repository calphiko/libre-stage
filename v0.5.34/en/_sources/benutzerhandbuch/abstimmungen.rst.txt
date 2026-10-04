.. _abstimmungen:

Abstimmungen
============

Im Bereich **Abstimmungen** können drei Typen von Umfragen erstellt werden.

.. image:: ../_static/screenshots/abstimmungen.png
   :alt: Abstimmungen Screenshot
   :width: 500px
   :align: center

Abstimmung anlegen
------------------

Admins und Editors können über **+ Neue Abstimmung** eine neue Umfrage anlegen.
Im Formular wird zunächst der **Typ** der Abstimmung gewählt.

Umfragetypen
------------

Meinungsumfrage
~~~~~~~~~~~~~~~

Eine klassische Umfrage mit einer Frage und vordefinierten Antwortmöglichkeiten.
Ergebnisse sind in Echtzeit als Balkendiagramm sichtbar.

Jede Antwortmöglichkeit kann durch einen **Klick** ausgewählt oder abgewählt werden.
Sobald eine Option gewählt ist, erscheint direkt darunter ein optionales **Kommentarfeld**.
Der Kommentar wird beim Verlassen des Felds automatisch gespeichert.
Kommentare anderer Mitglieder sind in der aufklappbaren Feedback-Liste der jeweiligen Option sichtbar.

Terminfindung
~~~~~~~~~~~~~

Ermittelt einen gemeinsamen Termin für z. B. eine Sonderprobe.

* Der Ersteller gibt mehrere mögliche Termine vor.
* Jedes Mitglied markiert die Termine mit **Ja (✓)**, **Vielleicht (~)** oder **Nein (✗)**;
  ein weiterer Klick setzt den Status zurück.
* Das Ergebnis zeigt in einer Heatmap, welcher Termin die meisten Zusagen hat.

**Kommentare in der Terminumfrage**

Unterhalb der Matrix erscheint ein **Kommentarbereich** für alle Termine, bei denen bereits
abgestimmt wurde. Neben dem Datum zeigt ein farbiges Symbol die eigene Wahl an.
Der Kommentar wird beim Verlassen des Felds oder mit ``Enter`` gespeichert.

Haben andere Mitglieder einen Kommentar hinterlassen, ist dies in der Zelle durch **💬**
erkennbar. Beim Hovern über eine Zelle wird der Kommentar als Tooltip eingeblendet.

Auftrittsanfrage
~~~~~~~~~~~~~~~~

Wird eingesetzt, wenn eine Anfrage für einen Auftritt eingegangen ist.

* Der Ersteller beschreibt den geplanten Auftritt.
* Alle Mitglieder stimmen ab: **Ja / Nein / Vielleicht**.

Abstimmung schließen
--------------------

Nach dem Schließen können keine weiteren Stimmen abgegeben werden.
Die Ergebnisse bleiben dauerhaft einsehbar.

Benachrichtigungen
------------------

Wenn Mattermost konfiguriert ist (siehe :ref:`configuration`), erhalten Bandmitglieder
eine Benachrichtigung, sobald eine neue Abstimmung gestartet wird.
