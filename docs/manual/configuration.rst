.. _configuration:

Konfiguration
=============

libreStage wird über zwei Konfigurationsdateien gesteuert: die ``.env``-Datei für
serverseitige Einstellungen und ``appConfig.json`` für anwendungsspezifische Anpassungen.

Umgebungsvariablen (``.env``)
------------------------------

Kopiere zunächst die Vorlage:

.. code-block:: bash

   cp .env.example .env

Anschließend alle relevanten Werte eintragen:

.. list-table::
   :header-rows: 1
   :widths: 30 15 55

   * - Variable
     - Standard
     - Beschreibung
   * - ``SECRET_KEY``
     - –
     - **Pflichtfeld.** Langer, zufälliger String zum Signieren von JWTs. Niemals öffentlich!
   * - ``ENVIRONMENT``
     - ``production``
     - ``development`` deaktiviert das Secure-Flag für Cookies (nötig auf ``localhost``)
   * - ``CORS_ORIGINS``
     - ``http://localhost:5173``
     - Erlaubte Frontend-Ursprünge (kommagetrennt)
   * - ``FRONTEND_URL``
     - ``http://localhost:5173``
     - Basis-URL des Frontends (wird in E-Mails verwendet)
   * - ``DATABASE_URL``
     - ``sqlite:///./backend/db/app.db``
     - SQLAlchemy-Datenbank-URL (SQLite oder PostgreSQL)
   * - ``TIMEZONE``
     - ``Europe/Berlin``
     - Zeitzone der Anwendung (IANA-Format)
   * - ``SMTP_HOST``
     - –
     - SMTP-Server für E-Mail-Versand (optional)
   * - ``SMTP_PORT``
     - ``587``
     - SMTP-Port
   * - ``SMTP_USER``
     - –
     - SMTP-Benutzername
   * - ``SMTP_PASSWORD``
     - –
     - SMTP-Passwort
   * - ``MATTERMOST_WEBHOOK_URL``
     - –
     - Webhook-URL für Mattermost-Benachrichtigungen (optional)

Anwendungskonfiguration (``appConfig.json``)
---------------------------------------------

Die Datei ``appConfig.json`` im Projekt-Root enthält alle band-spezifischen Einstellungen,
die **ohne erneutes Bauen** des Frontends geändert werden können.

Ab ``v0.4.0`` koennen Admins die weichen Parameter auch direkt in der
Weboberflaeche unter :ref:`admin_konfiguration` pflegen.

.. code-block:: json

   {
     "app_name": "libreStage",
     "app_name_short": "LS",
     "timezone": "Europe/Berlin",
     "default_break_seconds": 30
   }

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - Feld
     - Beschreibung
   * - ``app_name``
     - Vollständiger Anwendungsname (erscheint im Header)
   * - ``app_name_short``
     - Kurzname / Kürzel der Band
   * - ``app_title``
     - Untertitel der Anwendung
   * - ``timezone``
     - Zeitzone (IANA-Format, muss mit ``.env`` übereinstimmen)
   * - ``default_break_seconds``
     - Standard-Pausenlänge zwischen Sets in Sekunden (Standard: 30)
   * - ``genres``
     - Liste verfügbarer Genres für Songs
   * - ``gigTypes``
     - Auswahlliste für den Veranstaltungstyp
   * - ``tonekeys``
     - Verfügbare Tonarten
   * - ``rehearsalSongStatuses``
     - Song-Statuswerte für Proben-Ansichten

Song-Status
~~~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Status
     - Bedeutung
   * - ``vorschlag``
     - Song wurde vorgeschlagen, aber noch nicht bewertet
   * - ``angenommen``
     - Song ist grundsätzlich akzeptiert
   * - ``proben``
     - Song wird aktiv geprobt
   * - ``spielbar``
     - Song ist bühnenreif und kann in Setlists eingesetzt werden
   * - ``bedarfsweise_proben``
     - Song ist spielbar, wird aber bei Bedarf nochmals geprobt

Gig-Status
~~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Status
     - Bedeutung
   * - ``anfrage``
     - Auftrittsanfrage eingegangen, noch keine Zusage
   * - ``angenommen``
     - Auftritt wurde bestätigt
   * - ``abgelehnt``
     - Auftrittsanfrage wurde abgelehnt

Frontend-Konfiguration
-----------------------

Das Frontend lädt die Konfiguration zur Laufzeit vom Backend-Endpoint ``/public/app_config``.
Für den Entwicklungsmodus wird die API-URL über ``VITE_API_URL`` gesteuert:

.. code-block:: bash

   # frontend/.env (für lokale Entwicklung)
   VITE_API_URL=http://localhost:8000
