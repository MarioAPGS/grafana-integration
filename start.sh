#!/usr/bin/env bash
set -e

export PORT="${PORT:-8080}"
envsubst '$PORT' < /etc/nginx/nginx.conf.template \
           > /etc/nginx/nginx.conf

grafana server \
  --homepath=/usr/share/grafana \
  --config=/etc/grafana/grafana.ini \
  --packaging=docker &

uvicorn app.main:app --host 0.0.0.0 --port 8000 &

exec nginx -g "daemon off;"
