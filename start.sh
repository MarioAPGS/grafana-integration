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

# ── Wait for Grafana to be ready and create API token ─────
# Use background to avoid blocking other services
GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_GRAFANA_ADMIN_PASSWORD:-admin}"
SA_NAME="api-agent"
SA_ROLE="Admin"

# Wait Grafana API
until curl -s -u "$GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASSWORD" "$GH_HOST_URL/api/health" | grep '"database": "ok"'; do
  echo "Waiting Grafana API..."
  sleep 5
done

# Create service account
SA_ID=$(curl -s -u "$GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$SA_NAME\",\"role\":\"$SA_ROLE\"}" \
  "$GH_HOST_URL/api/serviceaccounts" | jq -r .id)

# Create API token
TOKEN=$(curl -s -u "$GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"default-token\"}" \
  "$GH_HOST_URL/api/serviceaccounts/$SA_ID/tokens" | jq -r .key)

echo "SERVICE_ACCOUNT_TOKEN=$TOKEN" > /etc/grafana/sa_token.env
echo "✔ Service Account and Token created: $TOKEN"

# ── Start FastAPI app (Uvicorn) in background ──────────────
uvicorn app.main:app --host 0.0.0.0 --port 8000 &

# ── Start Nginx (main process) ─────────────────────────────
exec nginx -g "daemon off;"
