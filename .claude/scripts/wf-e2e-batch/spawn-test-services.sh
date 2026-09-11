#!/usr/bin/env bash
# spawn-test-services.sh — Start N replicas cho parallel batch test
# Usage: ./spawn-test-services.sh <n-replicas> [up|down]
set -euo pipefail

N="${1:-3}"
ACTION="${2:-up}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.test-parallel.yml}"

[ ! -f "$COMPOSE_FILE" ] && echo "docker-compose.test-parallel.yml not found — skip" && exit 0

case "$ACTION" in
  up)
    echo "Starting $N BE + $N FE replicas..."
    BACKEND_REPLICAS=$N FRONTEND_REPLICAS=$N \
      docker-compose -f "$COMPOSE_FILE" up -d --scale backend=$N --scale frontend=$N 2>&1

    # Wait for health
    echo "Waiting for services..."
    for i in $(seq 1 30); do
      healthy=$(docker-compose -f "$COMPOSE_FILE" ps | grep -c "healthy" || echo "0")
      [ "$healthy" -ge 2 ] && echo "Services ready ($healthy healthy)" && break
      sleep 5
    done
    ;;
  down)
    docker-compose -f "$COMPOSE_FILE" down 2>&1
    echo "Services stopped"
    ;;
  *)
    echo "Usage: $0 <n-replicas> [up|down]" && exit 1
    ;;
esac
