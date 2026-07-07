#!/usr/bin/env bash
# Toggle the branded maintenance page.
# It is a standalone Traefik backend with routers at priority 1000, so
# turning it "on" takes over frontend/admin/api traffic immediately —
# those containers can be left running, restarted, or stopped underneath it.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

COMPOSE=(docker compose -f docker-compose-prod.yml -f docker-compose-maintenance.yml --env-file .env.prod)

usage() {
  echo "Usage: $0 {on|off|status}" >&2
  exit 1
}

case "${1:-}" in
  on)
    echo "==> Enabling maintenance page"
    "${COMPOSE[@]}" up -d maintenance
    echo "==> Maintenance page is live at all three domains"
    ;;
  off)
    echo "==> Disabling maintenance page"
    "${COMPOSE[@]}" stop maintenance
    "${COMPOSE[@]}" rm -f maintenance
    echo "==> Normal routing restored"
    ;;
  status)
    "${COMPOSE[@]}" ps maintenance
    ;;
  *)
    usage
    ;;
esac
