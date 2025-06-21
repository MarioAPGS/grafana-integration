FROM grafana/grafana-oss:latest
USER root

ENV DS_POSTGRES_HOST=dpg-d1b8se15pdvs73dk6580-a.oregon-postgres.render.com \
    DS_POSTGRES_PORT=5432 \
    DS_POSTGRES_USER=core_lz4l_user \
    DS_POSTGRES_PASSWORD=my_password \
    DS_POSTGRES_DB=core_lz4l

# ── System & Python deps ──────────────────────────────
RUN apk add --no-cache python3 py3-pip bash nginx gettext \
    && pip3 install --no-cache-dir --break-system-packages uv \
    && grafana-cli --pluginsDir "/var/lib/grafana/plugins" plugins install frser-sqlite-datasource \
    && chown -R 472:472 /var/lib/grafana/plugins \
    && mkdir -p /var/lib/grafana/sqlite_databases /app

# ── Project files ─────────────────────────────────────
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

ENV GF_SERVER_ROOT_URL='%(protocol)s://%(domain)s/grafana' \
    GF_SERVER_SERVE_FROM_SUB_PATH=true \
    GF_SERVER_HTTP_PORT=8001

# Solo informativo
EXPOSE 8080

ENTRYPOINT ["/start.sh"]
