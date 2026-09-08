#!/bin/sh
# Render Railway specifics into the nginx template, then hand over to upstream's entrypoint
# (it writes config.js, runs envsubst for APP_HOST/APP_PORT/APP_SCHEME/MAX_* and starts nginx).
set -eu
ns="$(awk '/^nameserver/ {print $2; exit}' /etc/resolv.conf 2>/dev/null || true)"
[ -n "$ns" ] || { echo "no nameserver in /etc/resolv.conf; cannot resolve the app" >&2; exit 1; }
case "$ns" in *:*) ns="[$ns]" ;; esac
sed -i -e "s|__RESOLVER__|$ns|" -e "s|__PORT__|${PORT:-80}|g" /etc/nginx/templates/default.conf.template
exec /docker-entrypoint.sh
