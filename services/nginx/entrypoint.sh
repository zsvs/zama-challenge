#!/usr/bin/env bash
set -euo pipefail

# Set defaults if not provided
: "${API_HOST:=127.0.0.1}"
: "${API_PORT:=8080}"

if [[ -z "${API_KEY:-}" ]]; then
  echo "[nginx] WARNING: API_KEY is empty; non-health endpoints will be inaccessible (401/403)."
fi

envsubst '$API_KEY $API_HOST $API_PORT' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf
echo "[nginx] rendered config:"
sed -n '1,120p' /etc/nginx/conf.d/default.conf || true

exec nginx -g 'daemon off;'
