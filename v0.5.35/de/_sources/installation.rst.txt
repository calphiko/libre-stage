.. _installation:

Installation
============

Dieses Kapitel beschreibt die vollständige Installation von libreStage auf einem eigenen
Server oder auf einem lokalen Rechner für die Entwicklung.

Voraussetzungen
---------------

Folgende Software muss auf dem Zielsystem installiert sein:

.. list-table::
   :header-rows: 1
   :widths: 30 20 50

   * - Software
     - Mindestversion
     - Hinweis
   * - Python
     - 3.11
     - Empfohlen: 3.12+
   * - Node.js
     - 18
     - Für das Frontend (SvelteKit)
   * - npm
     - 9
     - Wird mit Node.js installiert
   * - Git
     - beliebig
     - Für das Klonen des Repositories

Repository klonen
-----------------

.. code-block:: bash

   git clone <repository-url>
   cd libre-stage

Backend einrichten
------------------

libreStage verwendet `uv <https://github.com/astral-sh/uv>`_ als Python-Paketmanager.

.. code-block:: bash

   pip install uv
   uv sync --all-groups

Umgebungsvariablen konfigurieren
---------------------------------

Kopiere die Beispiel-Konfiguration und passe sie an:

.. code-block:: bash

   cp .env.example .env

Öffne anschließend ``.env`` in einem Texteditor und setze mindestens den ``SECRET_KEY``
(langer, zufälliger String). Alle verfügbaren Variablen sind in :ref:`configuration` beschrieben.

Datenbank initialisieren
------------------------

.. code-block:: bash

   uv run alembic upgrade head

Optional: Demo-Datenbank laden
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

   uv run python backend/migrations/init_demo_db.py

Frontend einrichten
--------------------

.. code-block:: bash

   cd frontend && npm install && cd ..

Anwendung starten
-----------------

**Terminal 1 – Backend:**

.. code-block:: bash

   uv run uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload

**Terminal 2 – Frontend:**

.. code-block:: bash

   cd frontend && npm run dev

Die Anwendung ist danach unter folgenden Adressen erreichbar:

* **Frontend:** http://localhost:5173
* **API-Dokumentation (Swagger):** http://localhost:8000/docs

Erster Login
------------

.. note::
   Screenshot folgt – bitte ``docs/manual/_static/screenshots/login.png`` ablegen.

Beim ersten Start mit der Demo-Datenbank stehen folgende Accounts zur Verfügung:

.. list-table::
   :header-rows: 1
   :widths: 20 20 20 40

   * - Benutzername
     - Passwort
     - Rolle
     - Beschreibung
   * - ``admin``
     - ``Admin1234!``
     - admin
     - Vollständige Verwaltungsrechte
   * - ``alice``
     - ``Demo1234!``
     - editor
     - Sängerin, kann Inhalte bearbeiten
   * - ``bob``
     - ``Demo1234!``
     - editor
     - Sänger, kann Inhalte bearbeiten
   * - ``carol``
     - ``Demo1234!``
     - musician
     - Musikerin, Lesezugriff + eigene Todos
   * - ``dave``
     - ``Demo1234!``
     - musician
     - Musiker, Lesezugriff + eigene Todos

.. warning::
   Ändere vor dem produktiven Einsatz unbedingt alle Demo-Passwörter und setze
   einen sicheren ``SECRET_KEY`` in der ``.env``-Datei!

Produktion
----------

Für den produktiven Betrieb empfiehlt sich:

* Frontend mit ``npm run build`` bauen – statische Dateien liegen in ``frontend/build/``
* Backend hinter einem Reverse-Proxy (nginx, Caddy) betreiben
* ``ENVIRONMENT=production`` in ``.env`` setzen (aktiviert Secure-Cookie-Flag)
* PostgreSQL statt SQLite für Mehrbenutzerbetrieb unter Last
* Regelmäßige Datenbank-Backups einrichten
