.. _api:

REST-API
========

libreStage stellt eine vollständige REST-API bereit, die vom Frontend genutzt wird
und auch direkt angesprochen werden kann.

API-Dokumentation (Swagger)
----------------------------

Die interaktive API-Dokumentation ist unter folgendem Pfad erreichbar
(sofern nicht in ``.env`` deaktiviert):

.. code-block:: text

   http://<dein-server>:8000/docs

Authentifizierung
-----------------

Die API verwendet JWT-Tokens in **httpOnly-Cookies**.

* **Login:** ``POST /login``
* **Token erneuern:** ``POST /refresh``
* **Logout:** ``POST /logout``

Endpunkt-Übersicht
------------------

.. list-table::
   :header-rows: 1
   :widths: 10 35 55

   * - Methode
     - Pfad
     - Beschreibung
   * - POST
     - ``/login``
     - Benutzer einloggen
   * - POST
     - ``/logout``
     - Benutzer ausloggen
   * - GET
     - ``/gigs``
     - Alle Gigs abrufen
   * - POST
     - ``/gigs``
     - Neuen Gig anlegen
   * - GET
      - ``/gigs/{id}/setlist.pdf``
      - Setlist-PDF generieren
   * - GET
      - ``/gigs/{id}/schedule.pdf``
      - Ablaufplan-PDF generieren (Querformat, Stammdaten, adaptive Farben, Logo-Wasserzeichen)
   * - GET
     - ``/gigs/{id}/gema``
     - GEMA-Excel-Export
   * - GET
     - ``/gigs_lm/{id}``
     - Gig-Daten für Live-Modus laden
   * - PUT
     - ``/gigs_lm/{id}/``
     - Song-Status im Live-Modus aktualisieren
   * - GET
     - ``/songs``
     - Alle Songs abrufen
   * - GET
     - ``/rehearsals``
     - Alle Proben abrufen
   * - GET
     - ``/surveys``
     - Alle Abstimmungen abrufen
   * - GET
     - ``/cal/ical/{token}``
     - Persönlicher iCal-Kalender-Feed
   * - GET
     - ``/public/app_config``
     - App-Konfiguration (öffentlich, ohne Login)

Rate Limiting
-------------

.. list-table::
   :header-rows: 1
   :widths: 40 60

   * - Endpunkt
     - Limit
   * - ``/login``
     - 10 Anfragen / Minute
   * - ``/refresh``
     - 10 Anfragen / Minute
   * - ``/change_password``
     - 5 Anfragen / Minute
   * - ``/update_user``
     - 10 Anfragen / Minute
