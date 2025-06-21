#!/usr/bin/env bash
set -e

# ── Load centralized env vars ─────────────────────────────
if [ -f /etc/env.grafana ]; then
  export $(grep -v '^#' /etc/env.grafana | xargs)
fi

# ── Nginx config with dynamic port ─────────────────────────
export PORT="${PORT:-8080}"
envsubst '$PORT' < /etc/nginx/nginx.conf.template \
           > /etc/nginx/nginx.conf

# ── Start Grafana in background ────────────────────────────
grafana server \
  --homepath=/usr/share/grafana \
  --config=/etc/grafana/grafana.ini \
  --packaging=docker &

# ── Start FastAPI app (Uvicorn) in background ──────────────
uvicorn app.main:app --host 0.0.0.0 --port 8000 &

# ── Start Nginx (main process) ─────────────────────────────
exec nginx -g "daemon off;"
