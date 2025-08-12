#!/bin/bash
set -euo pipefail
CONF="${NIFI_HOME:-/opt/nifi}/conf/nifi.properties"
sed -i 's|^nifi.web.https.host=.*|# nifi.web.https.host=|' "$CONF" || true
sed -i 's|^nifi.web.https.port=.*|# nifi.web.https.port=|' "$CONF" || true
HTTP_PORT="${NIFI_WEB_HTTP_PORT:-8080}"
sed -i "s|^nifi.web.http.host=.*|nifi.web.http.host=0.0.0.0|" "$CONF" || true
sed -i "s|^nifi.web.http.port=.*|nifi.web.http.port=${HTTP_PORT}|" "$CONF" || true
exec /opt/nifi/bin/nifi.sh run
