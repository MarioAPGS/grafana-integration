FROM grafana/grafana-oss:latest

USER root

# --- Install Python, uv and SQLite plugin ---
RUN apk update && \
    apk add --no-cache python3 py3-pip && \
    pip3 install --no-cache-dir --break-system-packages uv && \
    \
    grafana-cli --pluginsDir "/var/lib/grafana/plugins" plugins install frser-sqlite-datasource && \
    chown -R 472:472 /var/lib/grafana/plugins && \
    mkdir -p /var/lib/grafana/sqlite_databases /app

# --- Copy files ---
COPY pyproject.toml /app/pyproject.toml
COPY app /app/app
COPY start.sh /start.sh
COPY provisioning /etc/grafana/provisioning
COPY grafana.ini /etc/grafana/grafana.ini

RUN chmod +x /start.sh

WORKDIR /app

# --- Install Python dependencies ---
RUN uv pip install --system --break-system-packages fastapi uvicorn[standard] aiofiles python-multipart

# --- Feature toggles ---
ENV \
  GF_FEATURE_TOGGLES_PROVISIONING=true \
  GF_FEATURE_TOGGLES_KUBERNETESCLIENTDASHBOARDSFOLDERS=true \
  GF_FEATURE_TOGGLES_KUBERNETESDASHBOARDS=true \
  GF_FEATURE_TOGGLES_GRAFANAAPISERVERENSUREKUBECTLACCESS=true

EXPOSE 3000 8000

ENTRYPOINT ["/start.sh"]
