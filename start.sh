#!/usr/bin/env bash
set -e

# ── Load centralized env vars ─────────────────────────────
if [ -f /etc/grafana/env.grafana ]; then
  export $(grep -v '^#' /etc/grafana/env.grafana | xargs)
fi
rm /etc/grafana/env.grafana

grafana cli admin reset-admin-password "${GRAFANA_ADMIN_PASSWORD:-admin}"

# ── Start Grafana in background ────────────────────────────
grafana server \
  --homepath=/usr/share/grafana \
  --config=/etc/grafana/grafana.ini \
  --packaging=docker &

GRAFANA_PID=$!

echo "⏳ Waiting 120 seconds to ensure final container..."
sleep 120

# ── Wait for Grafana to be ready and create API token ─────
# Use background to avoid blocking other services
GF_HOST_URL="${GF_HOST_URL:-localhost:3000}"
GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-admin}"
GF_DASHBOARD_MGR_USER="${GF_DASHBOARD_MGR_USER:-dashboardmgr}"
GF_DASHBOARD_MGR_PASSWORD="${GF_DASHBOARD_MGR_PASSWORD:-admin}"
SA_NAME="api-agent"
SA_ROLE="Admin"
# Wait Grafana API
until curl -s -u "$GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASSWORD" "$GF_HOST_URL/api/health" | grep '"database": "ok"'; do
  echo "Waiting Grafana API..."
  sleep 5
done

# Create service account
SA=$(curl -s -u "$GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASSWORD" \
  -H "Content-Type: application/json" \
  -X POST "$GF_HOST_URL/api/serviceaccounts" \
  -d "{
  \"name\":\"$SA_NAME\",
  \"role\":\"$SA_ROLE\"
  }")
echo "✔ Created Service Account: ${SA}"

# Create dashboard manager user
USER_ID=$(curl -s -u "$GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASSWORD" \
  -H "Content-Type: application/json" \
  -X POST $GF_HOST_URL/api/admin/users \
  -d "{
    \"name\":\"$GF_DASHBOARD_MGR_USER\",
    \"email\":\"$GF_DASHBOARD_MGR_USER@example.com\",
    \"login\":\"$GF_DASHBOARD_MGR_USER\",
    \"password\":\"$GF_DASHBOARD_MGR_PASSWORD\"
    }")
echo "✔ Created User: ${USER_ID}"

# Create API token
# TOKEN=$(curl -s -u "$GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASSWORD" \
#   -H "Content-Type: application/json" \
#   -d "{\"name\":\"default-token\"}" \
#   "$GH_HOST_URL/api/serviceaccounts/$SA_ID/tokens" | jq -r .key)

# echo "SERVICE_ACCOUNT_TOKEN=$TOKEN" > /etc/grafana/sa_token.env
# echo "✔ Service Account and Token created: $TOKEN"

wait $GRAFANA_PID
