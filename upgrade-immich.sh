#!/usr/bin/env bash
set -euo pipefail

# Refresh the release-specific Compose file, keeping Immich private behind Caddy.
APP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
COMPOSE_URL='https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml'
BACKUP_DIR="$APP_DIR/.upgrade-backups"
HEALTH_CONTAINERS=(immich_server immich_machine_learning immich_redis immich_postgres)

if [[ "${EUID}" -ne 0 ]] && ! docker info >/dev/null 2>&1; then
  exec sudo --preserve-env=PATH "$0" "$@"
fi

for command in curl docker; do
  command -v "$command" >/dev/null || {
    echo "Required command not found: $command" >&2
    exit 1
  }
done

cd "$APP_DIR"
docker info >/dev/null

temporary_compose="$(mktemp "$APP_DIR/.docker-compose.yml.XXXXXX")"
cleanup() { rm -f "$temporary_compose"; }
trap cleanup EXIT

curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
  "$COMPOSE_URL" -o "$temporary_compose"

# The upstream file publishes this port publicly; this host is proxied by Caddy.
if ! grep -Fqx "      - '2283:2283'" "$temporary_compose"; then
  echo 'Unexpected upstream port definition; leaving the current Compose file unchanged.' >&2
  exit 1
fi
sed -i \
  -e "s#      - '2283:2283'#      - \"127.0.0.1:2283:2283\"#" \
  -e "s#POSTGRES_INITDB_ARGS: '--data-checksums'#POSTGRES_INITDB_ARGS: \"--data-checksums\"#" \
  "$temporary_compose"

docker compose -f "$temporary_compose" --env-file .env config -q

mkdir -p "$BACKUP_DIR"
backup_file="$BACKUP_DIR/docker-compose.$(date -u +%Y%m%dT%H%M%SZ).yml"
cp -- "$COMPOSE_FILE" "$backup_file"
# Running through sudo must not make the app's tracked config root-owned.
if [[ "${EUID}" -eq 0 ]]; then
  chown --reference="$COMPOSE_FILE" "$temporary_compose"
fi
chmod --reference="$COMPOSE_FILE" "$temporary_compose"
mv -- "$temporary_compose" "$COMPOSE_FILE"

echo "Compose backup: $backup_file"
docker compose pull
docker compose up -d --remove-orphans

for attempt in {1..60}; do
  healthy=true
  for container in "${HEALTH_CONTAINERS[@]}"; do
    status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container" 2>/dev/null || true)"
    if [[ "$status" != 'healthy' && "$status" != 'running' ]]; then
      healthy=false
      break
    fi
  done
  if [[ "$healthy" == true ]]; then
    docker compose ps
    echo 'Immich upgrade complete.'
    exit 0
  fi
  sleep 2
done

docker compose ps >&2
echo 'Timed out waiting for Immich containers to become healthy.' >&2
exit 1
