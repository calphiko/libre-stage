#!/bin/bash

DB_PATH=/app/backend/db/app.db

if [ ! -f "$DB_PATH" ]; then
    echo "Database not found at $DB_FILE – creating demo database..."
    cd /app/backend/migrations
    uv run init_demo_db.py || exit 1
fi

cd /app

echo "Running database migrations..."
uv run alembic upgrade head
echo "Database migrations completed."

echo "Starting backend..."
uv run uvicorn backend.main:app --host 0.0.0.0 --port 8000 --log-level debug --log-config ./backend/log_conf.json &

cd /app/frontend/

echo "Starting frontend"
node build
