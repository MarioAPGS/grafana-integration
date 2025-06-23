FROM grafana/grafana-oss:latest
USER root

# ── System & Python deps ──────────────────────────────
RUN apk add --no-cache python3 py3-pip bash nginx gettext jq \
    && pip3 install --no-cache-dir --break-system-packages uv \
    && chown -R 472:472 /var/lib/grafana/plugins \
    && mkdir -p /var/lib/grafana/sqlite_databases /app

RUN grafana-cli --pluginsDir "/var/lib/grafana/plugins" plugins install frser-sqlite-datasource

# ── Project files ─────────────────────────────────────
COPY env.grafana          /etc/grafana/env.grafana
COPY provisioning         /etc/grafana/provisioning
COPY grafana.ini          /etc/grafana/grafana.ini
COPY start.sh             /start.sh
COPY mapdevs-fileuploader-app/dist /var/lib/grafana/plugins/mapdevs-fileuploader-app
# Grant permissions to the Go backend
RUN chown -R 472:472 /var/lib/grafana/plugins/mapdevs-fileuploader-app
RUN if [ -f /var/lib/grafana/plugins/mapdevs-fileuploader-app/mapdevs-fileuploader-app ]; then \
    chmod +x /var/lib/grafana/plugins/mapdevs-fileuploader-app/mapdevs-fileuploader-app; \
    fi

RUN  chmod +x /start.sh

EXPOSE 3000

ENTRYPOINT ["/start.sh"]
