#!/usr/bin/env bash
set -e

# Start Grafana in the background
/run.sh &

# Start FastAPI
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
