.PHONY: help start stop restart logs status health clean setup
COMPOSE_FILE := docker-compose-prod.yml
COMPOSE := docker compose -f $(COMPOSE_FILE)

help:
	@echo "WisdomChurch Infrastructure Management"
	@echo ""
	@echo "Available commands:"
	@echo "  make start       - Start all services"
	@echo "  make stop        - Stop all services"
	@echo "  make restart     - Restart all services"
	@echo "  make logs        - Show all service logs"
	@echo "  make logs-api    - Show API logs"
	@echo "  make logs-frontend - Show frontend logs"
	@echo "  make logs-admin  - Show admin logs"
	@echo "  make logs-redis  - Show Redis logs"
	@echo "  make status      - Show service status"
	@echo "  make health      - Check service health"
	@echo "  make clean       - Remove all containers/volumes (destructive)"
	@echo "  make setup       - Setup environment and networks"
	@echo "  make shell-api   - Open shell in API container"
	@echo "  make shell-db    - Connect to database"

setup:
	@echo "Setting up environment..."
	@if [ ! -f ".env" ]; then \
		if [ -f ".env.prod" ]; then \
			ln -sf .env.prod .env; \
			echo "Created .env symlink to .env.prod"; \
		fi \
	fi
	@docker network inspect traefik-public > /dev/null 2>&1 || \
		(docker network create traefik-public && echo "Created traefik-public network")
	@echo "Setup complete!"

start: setup
	@echo "Starting services..."
	@$(COMPOSE) pull --quiet
	@$(COMPOSE) up -d
	@sleep 5
	@make status
	@echo ""
	@echo "✓ Services started!"
	@echo ""
	@echo "⚠ Note: If migration failed (check 'make logs migrate'), run:"
	@echo "  make migrate-retry"
	@echo ""
	@echo "Monitor startup with: make logs"

stop:
	@echo "Stopping services..."
	@$(COMPOSE) down
	@echo "✓ Services stopped"

restart: stop start

logs:
	$(COMPOSE) logs -f

logs-api:
	$(COMPOSE) logs -f api

logs-frontend:
	$(COMPOSE) logs -f frontend

logs-admin:
	$(COMPOSE) logs -f admin

logs-redis:
	$(COMPOSE) logs -f redis

status:
	@$(COMPOSE) ps

health:
	@echo "Service Health Status:"
	@$(COMPOSE) ps --format "table {{.Names}}\t{{.Status}}"

clean:
	@echo "WARNING: This will remove all containers and volumes!"
	@read -p "Are you sure? (yes/no) " confirm && \
		if [ "$$confirm" = "yes" ]; then \
			$(COMPOSE) down -v && \
			echo "✓ Cleaned up"; \
		fi

pull:
	@echo "Pulling latest images..."
	@$(COMPOSE) pull

validate:
	@echo "Validating docker-compose configuration..."
	@$(COMPOSE) config > /dev/null && echo "✓ Configuration is valid"

version:
	@docker compose --version

migrate-status:
	@echo "Migration Status:"
	@$(COMPOSE) ps migrate

migrate-logs:
	@$(COMPOSE) logs migrate

migrate-retry:
	@echo "Retrying database migration..."
	@$(COMPOSE) restart migrate
	@sleep 5
	@$(COMPOSE) logs migrate

migrate-manual:
	@echo "Running manual migration..."
	@chmod +x migrate.sh
	@./migrate.sh
