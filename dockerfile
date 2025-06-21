FROM grafana/grafana-oss:latest
USER root

# ── System & Python deps ──────────────────────────────
RUN apk add --no-cache python3 py3-pip bash nginx gettext \
    && pip3 install --no-cache-dir --break-system-packages uv \
    && grafana-cli --pluginsDir "/var/lib/grafana/plugins" plugins install frser-sqlite-datasource \
    && chown -R 472:472 /var/lib/grafana/plugins \
    && mkdir -p /var/lib/grafana/sqlite_databases /app

# ── Project files ─────────────────────────────────────
COPY env.grafana          /etc/env.grafana
COPY pyproject.toml       /app/pyproject.toml
COPY app                  /app/app
COPY provisioning         /etc/grafana/provisioning
COPY grafana.ini          /etc/grafana/grafana.ini
COPY nginx.conf.template  /etc/nginx/nginx.conf.template
COPY start.sh             /start.sh
RUN  chmod +x /start.sh

WORKDIR /app

RUN uv pip install --system --break-system-packages \
    fastapi uvicorn[standard] aiofiles python-multipart httpx

EXPOSE 8080

ENTRYPOINT ["/start.sh"]
