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

Admins erreichen die Benutzerverwaltung über **Admin → Benutzer**.
Dort können neue Benutzer angelegt, Rollen zugewiesen, Sänger-Status gesetzt
und Benutzer deaktiviert werden.
