"""
libreStage Backend
==================

Main package of the libreStage backend. Contains all modules for the
FastAPI application, database models, authentication and API routers.

Modules:
    - :mod:`backend.main` – FastAPI application and core endpoints
    - :mod:`backend.models` – SQLAlchemy database models
    - :mod:`backend.schemas` – Pydantic schemas for request/response validation
    - :mod:`backend.auth` – Authentication and JWT token management
    - :mod:`backend.database` – Database connection and session management
    - :mod:`backend.app_config` – Application configuration from ``appConfig.json``
    - :mod:`backend.routers` – API routers for all resources
    - :mod:`backend.services` – Business logic services
    - :mod:`backend.utils` – Helper functions and utilities
"""
