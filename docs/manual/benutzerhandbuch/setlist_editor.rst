.. _setlist_editor:

Setlist-Editor
==============

Der Setlist-Editor ermöglicht es, Setlists für Gigs zu erstellen und zu bearbeiten.
Er unterstützt mehrere Sets, Drag & Drop sowie automatische Zeitberechnung.

.. image:: ../_static/screenshots/gigs_setlist_editor.png
   :alt: Gigs Detail Screenshot
   :width: 500px
   :align: center

Sets anlegen
------------

Über den Button **+ Set** wird ein neues Set an die Setlist angehängt.
Jedes Set bekommt automatisch einen Namen (z. B. „Set 1“, „Set 2“, …).

Set umbenennen
~~~~~~~~~~~~~~

Klicke auf den Set-Namen, um ihn inline zu bearbeiten.
Drücke **Enter** oder klicke außerhalb des Feldes, um den Namen zu speichern.

Set löschen
~~~~~~~~~~~

Über den Button **-** am Set-Header kann das gesamte Set gelöscht werden.


Songs hinzufügen
----------------

Im unteren Bereich des Editors befindet sich eine Songliste mit allen Songs,
deren Status ``spielbar`` ist.

* Klicke auf einen Song, um ihn am Ende der Setlist hinzuzufügen.
* Im Suchfeld kann nach Titel oder Interpret gesucht werden.
* Mit **Enter** (ohne Zusatz-Tasten wie ``Shift``/``Ctrl``/``Cmd``) wird der erste Suchtreffer direkt am Ende der Setlist hinzugefügt.
* Nach dem Hinzufügen per **Enter** scrollt die Ansicht automatisch ans Ende der Setlist.

Set aus vergangenem Gig importieren
-----------------------------------

Über den Button **Set aus vergangenem Gig** kann ein komplettes Set aus einem bereits vergangenen Gig
in die aktuelle Setlist übernommen werden.

Ablauf:

* Vergangenen Gig auswählen
* Set aus diesem Gig auswählen
* Mit **Als neues Set einfügen** importieren

Beim Import werden bewusst nur die musikalischen Set-Daten kopiert:

* **Setname**
* **Songs** in der vorhandenen Reihenfolge

Nicht übernommen werden Live-/Nachbereitungsdaten:

* Song-Bewertungen (``feedback``)
* Übersprungen-Markierungen (``uebersprungen``)
* Eingeschoben-Markierungen (``eingeschoben``)

Nach erfolgreichem Import zeigt die Oberfläche eine Toast-Bestätigung an.

Drag & Drop
-----------

* **Innerhalb eines Sets:** Ziehe einen Song an die gewünschte Position.
* **Zwischen Sets:** Ziehe einen Song auf ein anderes Set.

Zeitberechnung
--------------

libreStage berechnet die Spielzeit automatisch aus den hinterlegten Song-Dauern.
Die Gesamtdauer und geplante Endzeit werden in Echtzeit aktualisiert.

Pausen
~~~~~~

Zwischen Sets wird automatisch eine Pause eingeplant. Die Standard-Pausenlänge wird
in ``appConfig.json`` über das Feld ``default_break_seconds`` konfiguriert.
Die Pausenlänge kann für jeden Übergang im Editor angepasst werden.

Sänger-Farb-Kodierung
----------------------

Jeder Sänger erhält automatisch eine eigene Farbe als farbiger Balken
links neben dem Song-Titel.

Tastaturkürzel
--------------

.. list-table::
   :header-rows: 1
   :widths: 20 80

   * - Taste
     - Funktion
   * - **Enter**
     - Ersten Suchtreffer am Ende der Setlist hinzufügen (nur ohne ``Shift``/``Ctrl``/``Cmd``/``Alt``)
   * - **Strg/Cmd + Opt/Alt + Shift + 1-4**
     - Suchtreffer 1-4 direkt am Ende der Setlist hinzufügen (im Suchfeld)
   * - **Strg/Cmd + Shift + Enter**
     - Neues Set am Ende hinzufügen
   * - **Strg/Cmd + Shift + Backspace/Entf**
     - Letzten Song des Stacks entfernen (funktioniert auch bei Fokus in Eingabefeldern)
