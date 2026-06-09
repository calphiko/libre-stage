# libreStage

**A comprehensive internal management platform for bands and music ensembles**

![Version](https://img.shields.io/badge/version-v0.5.11-blue)
![Python](https://img.shields.io/badge/python-3.11+-green)
![FastAPI](https://img.shields.io/badge/FastAPI-0.135.0-teal)
![Svelte](https://img.shields.io/badge/Svelte-5.29.0-orange)
![Skeleton](https://img.shields.io/badge/Skeleton-4.12.1-orange)

See `docs/manual/changelog.rst` for release notes.

## 📖 Overview

libreStage is a self-hosted web application designed to manage band operations including:

- **Gig Management**: Organize concerts, setlists, and schedules
- **Setlist Editor**: Drag-and-drop interface for creating and editing setlists
- **Live Mode**: Real-time setlist tracking during performances with song rating
- **Song Database**: Manage repertoire with detailed metadata (genre, key, duration, status, etc.)
- **Rehearsal Planning**: Schedule rehearsals, track progress, and assign tasks
- **Survey System**: Gather feedback from band members on song candidates
- **Calendar Integration**: iCal export for gigs and rehearsals
- **User Management**: Role-based access control (admin, editor, musician)
- **PDF Generation**: Professional setlist PDFs plus modern schedule PDFs (portrait, auto line-wrap, logo-adaptive dark theme, watermark)
- **Mattermost Integration**: Optional notifications for new songs, gigs, rehearsals

## 🏗️ Architecture

### Backend (FastAPI + SQLAlchemy)
- **Framework**: FastAPI 0.135.0
- **Database**: SQLite with SQLAlchemy ORM
- **Authentication**: JWT-based with refresh tokens and httpOnly cookies
- **API Documentation**: Auto-generated OpenAPI/Swagger docs
- **Rate Limiting**: SlowAPI for DDoS protection
- **Testing**: Pytest with 72%+ coverage

### Frontend (SvelteKit + Skeleton UI)
- **Framework**: SvelteKit 2.0
- **Svelte**: 5.x (Runes API)
- **UI Library**: Skeleton UI 4.x (@skeletonlabs/skeleton-svelte) with Tailwind CSS 4.x
- **Charts**: ECharts for data visualization
- **Drag & Drop**: svelte-dnd-action for setlist editing
- **Responsive**: Full mobile and tablet support


## 🚀 Quick Start

### Prerequisites

- Python 3.11+
- Node.js 18+
- npm or yarn

### Installation

1. **Clone the repository**
```bash
git clone https://codeberg.org/calphiko/libre-stage.git
cd libre-stage
```

2. **Backend Setup**
```bash
# Install uv (modern Python package installer)
pip install uv

# Sync all dependencies including dev tools
uv sync --all-groups
```

3. **Frontend Setup**
```bash
cd frontend
npm install
cd ..
```

4. **Environment Configuration**

Copy the example environment file and adjust:
```bash
cp .env.example .env
```

Edit `.env` with your values. See [Configuration](#-configuration) for details.

5. **Customize your instance**

Edit `app.config.json` to set your band name, genres, gig types, and other options.
Edit `frontend/src/lib/appConfig.js` to match for the frontend.

### Running the Application

**Backend:**
```bash
python -m uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload
```

**Frontend** (in another terminal):
```bash
cd frontend
npm run dev
```

### Access

- **Frontend**: http://localhost:5173
- **API Documentation**: http://localhost:8000/docs

### First Login

On first run, create an admin user through the API docs (`/docs`) or use the included demo database:

```bash
# Create a fresh demo database with example data
python backend/migrations/init_demo_db.py

# Or specify a custom path
python backend/migrations/init_demo_db.py /path/to/my.db
```

**Demo accounts (password in parentheses):**

| Username | Password | Role |
|----------|----------|------|
| `admin` | `Admin1234!` | admin |
| `alice` | `Demo1234!` | editor (singer) |
| `bob` | `Demo1234!` | editor (singer) |
| `carol` | `Demo1234!` | user (musician) |
| `dave` | `Demo1234!` | user (musician) |

The demo database contains 20 songs, 3 rehearsals, 3 gigs, and 1 survey with example data.

## ⚙️ Configuration

### Environment Variables (`.env`)

| Variable | Description | Default |
|----------|-------------|---------|
| `SECRET_KEY` | JWT signing key (**change this!**) | - |
| `CORS_ORIGINS` | Allowed frontend origins | `http://localhost:5173` |
| `FRONTEND_URL` | Frontend URL (for emails) | `http://localhost:5173` |
| `DATABASE_URL` | SQLAlchemy database URL | `sqlite:///./backend/db/app.db` |
| `TIMEZONE` | Application timezone | `Europe/Berlin` |
| `DOCS_URL` | Swagger docs path (empty to disable) | `/docs` |
| `OPENAPI_URL` | OpenAPI schema path | `/openapi.json` |
| `SMTP_HOST` | SMTP server for emails | - |
| `SMTP_PORT` | SMTP port | `587` |
| `SMTP_USER` | SMTP username | - |
| `SMTP_PASSWORD` | SMTP password | - |
| `MATTERMOST_WEBHOOK_URL` | Mattermost webhook (optional) | - |
| `MM_CHANNEL_SONG_VOTES` | Channel for song notifications | - |
| `MM_CHANNEL_GIGS` | Channel for gig notifications | - |
| `MM_CHANNEL_REH` | Channel for rehearsal notifications | - |

### Application Config (`app.config.json`)

Customize band-specific values without touching code:

```json
{
  "app_name": "My Band Internal",
  "ical_domain": "myband.com",
  "ical_calendar_name": "My Band Schedule",
  "genres": ["Rock", "Pop", "Jazz"],
  "gig_types": ["Festival", "Club", "Private Event"],
  "song_statuses": ["vorschlag", "angenommen", "proben", "spielbar"],
  "timezone": "Europe/Berlin"
}
```

### Frontend Config (`frontend/src/lib/appConfig.js`)

Mirror the same options for the frontend (genres, gig types, statuses, tone keys).

## 📁 Project Structure

```
libre-stage/
├── app.config.json          # Band-specific configuration
├── .env.example             # Environment template
├── version.json             # Version info (shown in footer)
├── pyproject.toml           # Python project config with uv
├── uv.lock                  # Locked dependency versions
├── backend/
│   ├── main.py              # FastAPI entry point
│   ├── auth.py              # JWT authentication
│   ├── database.py          # Database connection
│   ├── models.py            # SQLAlchemy ORM models
│   ├── schemas.py           # Pydantic validation schemas
│   ├── routers/             # API route handlers
│   │   ├── admin.py         # User management
│   │   ├── gigs.py          # Gig & setlist management
│   │   ├── gigs_livemode.py # Live mode during performances
│   │   ├── songs.py         # Song database
│   │   ├── rehearsals.py    # Rehearsal planning
│   │   ├── surveys.py       # Survey system
│   │   ├── cal.py           # iCal export
│   │   └── public.py        # Public endpoints
│   ├── services/            # Business logic
│   ├── utils/               # Helpers (email, mattermost, etc.)
│   ├── pdf/                 # PDF generation
│   ├── migrations/          # Database migration scripts
│   └── tests/               # Pytest test suite
├── frontend/
│   ├── src/
│   │   ├── lib/
│   │   │   ├── api.js       # API client
│   │   │   ├── appConfig.js # Frontend configuration
│   │   │   ├── songFields.js# Field definitions
│   │   │   └── common.js    # Utilities
│   │   └── routes/          # SvelteKit pages
│   │       ├── +layout.svelte
│   │       ├── +page.svelte # Login page
│   │       ├── dashboard/
│   │       ├── gigs/
│   │       ├── songs/
│   │       ├── proben/      # Rehearsals
│   │       └── setlist_editor/
│   ├── static/              # Logo, fonts, favicon
│   └── package.json         # Frontend dependencies
└── docs/                    # Sphinx documentation
    └── manual/              # User manual (DE + EN)
```

## 🔑 Key Features

### Setlist Editor
- Drag-and-drop song arrangement across multiple sets
- Color-coded lead singers (dynamically assigned)
- Automatic timing calculations with break management
- Keyboard shortcuts (Enter to add songs)
- Mobile-responsive

### Live Mode
- Step through songs during a performance
- Rate songs (😞 😐 😊) after playing
- Skip or insert songs on the fly
- Resume from last position on reconnect
- Swipe navigation on mobile

### Song Statistics
- Rehearsal count and timeline
- Gig history with ratings
- Feedback distribution charts
- Most frequent set companions

### GEMA Reports
- Auto-generated Excel exports in official GEMA format
- Skipped songs are automatically excluded

## 📚 Documentation

libreStage includes a comprehensive **Sphinx-based user manual** in both German and English:

- **Access online**: https://calphiko.codeberg.page/ (auto-deployed from main branch)
- **Build locally**:
  ```bash
  # Install docs dependencies
  uv sync --group docs
  
  # Build German version
  uv run sphinx-build -b html -D language=de docs/manual docs/manual/_build/html/de
  
  # Build English version
  uv run sphinx-build -b html -D language=en docs/manual docs/manual/_build/html/en
  ```

The manual covers:
- Installation and initial setup
- User roles and permissions
- Song management workflow
- Gig and setlist creation
- Live mode usage
- Rehearsal planning
- Survey system
- Configuration options

## 🧪 Testing

```bash
# Run all tests (requires uv sync --all-groups first)
uv run pytest

# With coverage report
uv run pytest --cov=backend --cov-report=html

# Single test file
uv run pytest backend/tests/test_gigs.py -v
```

## 🔒 Security

- JWT authentication with refresh tokens in httpOnly cookies
- Token blacklist for secure logout
- bcrypt password hashing with strength validation
- Rate limiting on sensitive endpoints
- Configurable CORS
- Global exception handler (no stack traces leaked)

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| Cannot login on localhost | Set `ENVIRONMENT=development` in `.env` (disables secure cookie flag) |
| CORS errors | Ensure `CORS_ORIGINS` includes your frontend URL |
| Database locked | Expected with SQLite under load; consider PostgreSQL for production |
| Tests fail with DB errors | Delete `backend/db/test_app.db` and re-run |

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Write/update tests
5. Ensure `pytest` passes
6. Submit a pull request

## 📄 License

libreStage is free software: you can redistribute it and/or modify it under the terms of the
[GNU General Public License Version 3](LICENSE).

## 📧 Contact

[Add your contact information here]
