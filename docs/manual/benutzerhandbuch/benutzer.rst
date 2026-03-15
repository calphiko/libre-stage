.. _benutzer:

Benutzerverwaltung & Profil
===========================

.. note::
   Screenshot folgt – bitte ``docs/manual/_static/screenshots/benutzer.png`` ablegen.

Eigenes Profil
--------------

Jeder Benutzer kann sein eigenes Profil über den Menüpunkt **Mein Profil** aufrufen.
Dort können folgende Angaben geändert werden:

* **Anzeigename**
* **E-Mail-Adresse**
* **Passwort** (siehe unten)
* **Sänger-Markierung:** Setzt den Benutzer als Sänger für den Setlist-Editor

Passwort ändern
---------------

Passwort-Anforderungen:

* Mindestens **8 Zeichen**
* Mindestens ein **Großbuchstabe**
* Mindestens ein **Kleinbuchstabe**
* Mindestens eine **Ziffer**
* Mindestens ein **Sonderzeichen** (z. B. ``!``, ``@``, ``#``, ``$``)

Passwort vergessen
------------------

Auf der Login-Seite gibt es den Link **Passwort vergessen**.
Eine E-Mail mit Zurücksetzen-Link wird an die hinterlegte Adresse gesendet.

.. note::
   Die E-Mail-Funktion erfordert eine konfigurierte SMTP-Verbindung (siehe :ref:`configuration`).

Rollen und Berechtigungen
--------------------------

libreStage kennt drei Benutzerrollen:

.. list-table::
   :header-rows: 1
   :widths: 15 85

   * - Rolle
     - Beschreibung
   * - **admin**
     - Voller Zugriff auf alle Funktionen, inkl. Benutzerverwaltung
   * - **editor**
     - Kann Inhalte erstellen und bearbeiten (Gigs, Songs, Proben, Abstimmungen)
   * - **musician**
     - Lesezugriff, eigene Todos verwalten, abstimmen, Bewertungen abgeben

Berechtigungssübersicht:

.. list-table::
   :header-rows: 1
   :widths: 40 15 15 15

   * - Funktion
     - admin
     - editor
     - musician
   * - Gigs anlegen / bearbeiten
     - ✓
     - ✓
     - ✗
   * - Setlist bearbeiten
     - ✓
     - ✓
     - ✗
   * - Live-Modus starten (Gig-Tag)
     - ✓
     - ✓
     - ✓
   * - Live-Modus erzwingen (außerhalb Gig-Tag)
     - ✓
     - ✓
     - ✗
   * - Songs anlegen / bearbeiten
     - ✓
     - ✓
     - ✗
   * - Songs bewerten
     - ✓
     - ✓
     - ✓
   * - Proben anlegen / bearbeiten
     - ✓
     - ✓
     - ✗
   * - Abstimmungen anlegen
     - ✓
     - ✓
     - ✗
   * - An Abstimmungen teilnehmen
     - ✓
     - ✓
     - ✓
   * - Benutzer verwalten
     - ✓
     - ✗
     - ✗

Benutzerverwaltung (nur Admin)
-------------------------------

Admins erreichen die Benutzerverwaltung über **Benutzerverwaltung → Alle Benutzer**.
Die Tabelle zeigt alle angelegten Benutzer und erlaubt das direkte Bearbeiten,
Anlegen und Löschen.

Benutzer anlegen
~~~~~~~~~~~~~~~~

Klicke auf das **+**-Icon oberhalb der Tabelle, um das Formular einzublenden:

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Feld
     - Beschreibung
   * - **Username** ✱
     - Eindeutiger Login-Name (3–30 Zeichen, nur Buchstaben, Zahlen, ``_``, ``-``)
   * - **Klarname**
     - Anzeigename in der Anwendung
   * - **E-Mail** ✱
     - Gültige E-Mail-Adresse (für Passwort-Reset und Benachrichtigungen)
   * - **Passwort** ✱
     - Initiales Passwort – der Benutzer kann es später selbst ändern
   * - **Rolle**
     - ``user``, ``editor`` oder ``admin``
   * - **Ist Musiker**
     - Stimmrecht bei Song-Abstimmungen
   * - **Ist Sänger**
     - Erscheint als Sänger-Auswahl im Setlist-Editor

✱ Pflichtfeld

Benutzer bearbeiten
~~~~~~~~~~~~~~~~~~~

Felder in der Tabelle können direkt angeklickt und bearbeitet werden –
Änderungen werden nach Verlassen des Feldes automatisch gespeichert.
Toggle-Schalter für **Ist Musiker** und **Ist Sänger** wirken sofort.

Passwort zurücksetzen
~~~~~~~~~~~~~~~~~~~~~

Der Button **Reset Password** in der Tabellenspalte sendet dem Benutzer
einen Zurücksetzen-Link – per **Mattermost** (falls ``mm_username`` gesetzt)
oder per **E-Mail**.

Benutzer löschen
~~~~~~~~~~~~~~~~

Der 🗑️-Button in der letzten Tabellenspalte öffnet einen Bestätigungs-Dialog.
Nach Bestätigung wird der Benutzer unwiderruflich gelöscht.

.. warning::
   Das Löschen eines Benutzers entfernt alle zugehörigen Daten (Todos, Feedbacks etc.).
   Diese Aktion kann nicht rückgängig gemacht werden.
