#!/bin/bash

cd /app

uv run uvicorn backend.main:app --host 0.0.0.0 --port 8000 --log-level debug --log-config ./backend/log_conf.json &

cd /app/frontend/

node build 
