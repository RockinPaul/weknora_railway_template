#!/bin/sh
# Railway wrapper around upstream's /app/scripts/docker-entrypoint.sh.
set -eu
for key in JWT_SECRET SYSTEM_AES_KEY DB_HOST DB_USER DB_PASSWORD DB_NAME REDIS_ADDR DOCREADER_ADDR; do
  eval "v=\${$key:-}"
  [ -n "$v" ] || { echo "$key is empty; refusing to start" >&2; exit 1; }
done
# Upstream silently disables credential encryption when the key is not exactly 32 bytes.
[ "${#SYSTEM_AES_KEY}" -eq 32 ] || { echo "SYSTEM_AES_KEY must be exactly 32 characters, got ${#SYSTEM_AES_KEY}" >&2; exit 1; }
# The server exits when Postgres is unreachable; on a first deploy the database may still be
# initialising, so wait for its port instead of burning Railway restart attempts.
i=0
until bash -c 'exec 3<>"/dev/tcp/$0/$1"' "$DB_HOST" "${DB_PORT:-5432}" 2>/dev/null; do
  i=$((i+1)); [ "$i" -le 60 ] || { echo "Postgres at ${DB_HOST}:${DB_PORT:-5432} not reachable after 120s" >&2; exit 1; }
  [ $((i % 5)) -eq 1 ] && echo "waiting for Postgres at ${DB_HOST}:${DB_PORT:-5432}..."
  sleep 2
done
# server.host/server.port come from config.yaml; viper maps SERVER_HOST/SERVER_PORT over them.
# "[::]" makes Go listen on IPv4 and IPv6 (the app formats host:port itself, so brackets are needed).
export SERVER_HOST="${SERVER_HOST:-[::]}"
export SERVER_PORT="${PORT:-8080}"
exec /app/scripts/docker-entrypoint.sh "$@"
