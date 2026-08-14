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
   * - **user**
     - Lesezugriff, eigene Todos verwalten, abstimmen, Bewertungen abgeben

Berechtigungssübersicht:

.. list-table::
   :header-rows: 1
   :widths: 40 15 15 15

   * - Funktion
     - admin
     - editor
     - user
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

.. note::
   **Deaktivierte Benutzer** (Status ``deactivated``) können sich nicht einloggen
   und haben in keiner der obigen Funktionen Zugriffsrechte – unabhängig von ihrer Rolle.

Benutzerverwaltung (nur Admin)
-------------------------------

Admins erreichen die Benutzerverwaltung über **Benutzerverwaltung → Alle Benutzer**.
Die Tabelle zeigt alle angelegten Benutzer und erlaubt das direkte Bearbeiten,
Anlegen sowie Deaktivieren und Reaktivieren von Accounts.

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

Status-Spalte
~~~~~~~~~~~~~

Die Spalte **Status** zeigt den aktuellen Zustand jedes Accounts:

* ``✅ aktiv`` – der Benutzer kann sich einloggen und die Anwendung normal nutzen
* ``🚫 deaktiviert`` – der Benutzer ist gesperrt (kein Login, kein Stimmrecht,
  kein Schreibzugriff); alle Daten bleiben erhalten

Passwort zurücksetzen
~~~~~~~~~~~~~~~~~~~~~

Der Button **Reset Password** in der Tabellenspalte sendet dem Benutzer
einen Zurücksetzen-Link – per **Mattermost** (falls ``mm_username`` gesetzt)
oder per **E-Mail**.

Benutzer deaktivieren
~~~~~~~~~~~~~~~~~~~~~

Der Button **🚫 Deaktivieren** in der letzten Tabellenspalte öffnet einen
Bestätigungs-Dialog. Nach Bestätigung wird der Account deaktiviert:

* Alle aktiven Sitzungen des Benutzers werden **sofort beendet** (alle
  Refresh-Tokens werden widerrufen – Logout auf allen Geräten ohne Verzögerung)
* Der Benutzer kann sich **nicht mehr einloggen**
* Der Benutzer hat **kein Stimmrecht** mehr bei Song- oder Meinungsumfragen
* Der Benutzer erhält eine **E-Mail-Benachrichtigung** über die Deaktivierung
* Alle Daten (Todos, Feedbacks, Abstimmungseinträge) bleiben **vollständig erhalten**

.. note::
   Ein Admin kann seinen **eigenen Account nicht deaktivieren** – dies schützt
   vor versehentlicher Aussperrung aller Administratoren.

Benutzer reaktivieren
~~~~~~~~~~~~~~~~~~~~~

Bei deaktivierten Benutzern erscheint stattdessen der Button **✅ Reaktivieren**.
Nach dem Klick wird der Account sofort wieder auf ``active`` gesetzt – ohne
weiteren Bestätigungs-Dialog. Der Benutzer erhält eine E-Mail-Benachrichtigung
und kann sich danach wieder normal einloggen.
