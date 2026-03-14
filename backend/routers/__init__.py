"""
API routers package.

Each sub-module registers an :class:`fastapi.APIRouter` that is mounted
in :mod:`backend.main`.  All routers that require authentication use
:func:`backend.auth.get_current_user_dep` as a router-level dependency.

Routers:
    - :mod:`backend.routers.admin` – admin-only user and system management
    - :mod:`backend.routers.cal` – iCal feed endpoints
    - :mod:`backend.routers.gigs` – gig and setlist management
    - :mod:`backend.routers.gigs_livemode` – live-mode controls during performances
    - :mod:`backend.routers.password_reset` – self-service password reset flow
    - :mod:`backend.routers.public` – unauthenticated public endpoints
    - :mod:`backend.routers.rehearsals` – rehearsal scheduling and management
    - :mod:`backend.routers.songs` – song catalogue and candidate proposals
    - :mod:`backend.routers.surveys` – member feedback surveys
"""

