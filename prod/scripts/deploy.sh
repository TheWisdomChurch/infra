#!/usr/bin/env bash
# Pull the latest images and roll out a new release.
# Migrations run to completion, and the deploy aborts if they fail —
# api/frontend/admin are never started against a schema that didn't apply.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

COMPOSE=(docker compose -f docker-compose-prod.yml --env-file .env.prod)

echo "==> Pulling latest images"
"${COMPOSE[@]}" pull api frontend admin

echo "==> Running database migrations"
"${COMPOSE[@]}" up migrate --exit-code-from migrate --abort-on-container-exit

echo "==> Rolling out redis, api, frontend, admin"
"${COMPOSE[@]}" up -d redis api frontend admin

echo "==> Waiting for health checks"
"${COMPOSE[@]}" ps

echo "==> Pruning dangling images"
docker image prune -f >/dev/null

echo "==> Deploy complete"
