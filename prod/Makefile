# WisdomChurch — production stack.
#
# make deploy   git pull -> maintenance page up -> pull fresh images ->
#               migrate -> roll out -> wait for health -> maintenance page
#               down -> prune old images.
#
# If any step fails, the pipeline stops right there and the maintenance
# page stays up — visitors never see a crash, a blank screen, or a bare
# 404, only the branded "under maintenance" page, until you fix it and
# re-run `make deploy`.
#
# Cleanup is scoped to this project only: `make clean` removes dangling
# images left behind by old deploys. It deliberately never runs a
# host-wide `docker system prune` / `docker volume prune` — this host
# also runs Traefik with its Let's Encrypt certificate storage, and a
# blanket prune could take that out. redis_data and the traefik-public
# network are likewise never touched by any target here.

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

ENV_FILE := .env.prod
COMPOSE  := docker compose -f docker-compose-prod.yml --env-file $(ENV_FILE)
MAINT    := docker compose -f docker-compose-prod.yml -f docker-compose-maintenance.yml --env-file $(ENV_FILE)

HEALTH_TIMEOUT := 180
HEALTH_INTERVAL := 5

.PHONY: help deploy repo-pull pull migrate up down ps logs clean \
        maintenance-on maintenance-off maintenance-status wait-healthy

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

deploy: ## Full release: pull repo + images, migrate, roll out, then drop maintenance page once healthy
	@$(MAKE) repo-pull
	@$(MAKE) maintenance-on
	@$(MAKE) pull
	@$(MAKE) migrate
	@$(MAKE) up
	@$(MAKE) wait-healthy
	@$(MAKE) maintenance-off
	@$(MAKE) clean
	@echo "==> Deploy complete"

repo-pull: ## Fast-forward this infra checkout from git (fails rather than clobbering local changes)
	@echo "==> Pulling infra repository changes"
	git -C .. pull --ff-only

pull: ## Pull latest api/frontend/admin images
	@echo "==> Pulling latest images"
	$(COMPOSE) pull api frontend admin

migrate: ## Run database migrations (aborts here if they fail)
	@echo "==> Running database migrations"
	$(COMPOSE) up migrate --exit-code-from migrate --abort-on-container-exit

up: ## Start/recreate redis, api, frontend, admin
	@echo "==> Rolling out redis, api, frontend, admin"
	$(COMPOSE) up -d redis api frontend admin

wait-healthy: ## Block until api, frontend, admin all report healthy (or time out)
	@echo "==> Waiting for api/frontend/admin to report healthy (timeout: $(HEALTH_TIMEOUT)s)"
	@elapsed=0; \
	while :; do \
		api=$$(docker inspect -f '{{.State.Health.Status}}' wisdom_api 2>/dev/null || echo missing); \
		frontend=$$(docker inspect -f '{{.State.Health.Status}}' wisdom_frontend 2>/dev/null || echo missing); \
		admin=$$(docker inspect -f '{{.State.Health.Status}}' wisdom_admin 2>/dev/null || echo missing); \
		if [ "$$api" = "healthy" ] && [ "$$frontend" = "healthy" ] && [ "$$admin" = "healthy" ]; then \
			echo "==> All services healthy"; \
			break; \
		fi; \
		if [ $$elapsed -ge $(HEALTH_TIMEOUT) ]; then \
			echo "==> Timed out waiting for health (api=$$api frontend=$$frontend admin=$$admin)"; \
			echo "==> Maintenance page stays up. Check: make logs"; \
			exit 1; \
		fi; \
		sleep $(HEALTH_INTERVAL); elapsed=$$((elapsed + HEALTH_INTERVAL)); \
		echo "==> still waiting... ($${elapsed}s) api=$$api frontend=$$frontend admin=$$admin"; \
	done

down: ## Stop the stack (volumes are untouched)
	$(COMPOSE) down

ps: ## Show container status
	$(COMPOSE) ps

logs: ## Tail logs for the whole stack
	$(COMPOSE) logs -f --tail=200

clean: ## Remove dangling images left behind by old deploys (no volumes, no system-wide prune)
	@echo "==> Removing dangling images"
	docker image prune -f

maintenance-on: ## Show the maintenance page now
	@echo "==> Enabling maintenance page"
	$(MAINT) up -d maintenance

maintenance-off: ## Restore normal routing
	@echo "==> Disabling maintenance page"
	$(MAINT) stop maintenance
	$(MAINT) rm -f maintenance

maintenance-status: ## Check whether the maintenance page is currently active
	@$(MAINT) ps maintenance
