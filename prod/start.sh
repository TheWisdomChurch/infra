#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check prerequisites
check_docker() {
  if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker is not installed${NC}"
    exit 1
  fi
  echo -e "${GREEN}✓ Docker found${NC}"
}

check_env_file() {
  if [[ ! -f ".env" ]]; then
    echo -e "${RED}✗ .env file not found${NC}"
    exit 1
  fi
  echo -e "${GREEN}✓ .env file found${NC}"
}

check_networks() {
  if ! docker network inspect traefik-public &> /dev/null; then
    echo -e "${YELLOW}⚠ traefik-public network not found, creating...${NC}"
    docker network create traefik-public
    echo -e "${GREEN}✓ Created traefik-public network${NC}"
  else
    echo -e "${GREEN}✓ traefik-public network exists${NC}"
  fi
}

# Main commands
case "${1:-help}" in
  start)
    echo -e "${BLUE}Starting WisdomChurch infrastructure...${NC}"
    check_docker
    check_env_file
    check_networks

    echo -e "\n${BLUE}Pulling latest images...${NC}"
    docker compose pull

    echo -e "\n${BLUE}Starting services...${NC}"
    docker compose up -d

    echo -e "\n${BLUE}Waiting for services to be healthy...${NC}"
    sleep 5
    docker compose ps

    echo -e "\n${GREEN}✓ Services started!${NC}"
    echo -e "${BLUE}Check logs with: docker compose logs -f${NC}"
    ;;

  stop)
    echo -e "${BLUE}Stopping services...${NC}"
    docker compose down
    echo -e "${GREEN}✓ Services stopped${NC}"
    ;;

  restart)
    echo -e "${BLUE}Restarting services...${NC}"
    docker compose restart
    echo -e "${GREEN}✓ Services restarted${NC}"
    ;;

  logs)
    docker compose logs -f "${2:-}"
    ;;

  status)
    check_docker
    check_env_file
    echo -e "\n${BLUE}Service Status:${NC}"
    docker compose ps

    echo -e "\n${BLUE}Service Health:${NC}"
    docker compose ps --format "table {{.Names}}\t{{.Status}}"
    ;;

  health)
    echo -e "${BLUE}Checking service health...${NC}"
    for service in redis migrate api frontend admin; do
      container="wisdom_${service}"
      if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
        health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "N/A")
        echo -e "  ${service}: ${status} (health: ${health})"
      fi
    done
    ;;

  clean)
    echo -e "${RED}WARNING: This will remove all containers and volumes!${NC}"
    read -p "Are you sure? (yes/no) " -n 3 -r
    echo
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
      docker compose down -v
      echo -e "${GREEN}✓ Cleaned up${NC}"
    fi
    ;;

  help|*)
    cat << EOF
${BLUE}WisdomChurch Infrastructure Management${NC}

Usage: ./start.sh [COMMAND]

Commands:
  start       - Start all services
  stop        - Stop all services
  restart     - Restart all services
  logs        - Show service logs (add service name for specific logs)
  status      - Show service status
  health      - Check service health
  clean       - Remove all containers and volumes (destructive!)
  help        - Show this help message

Examples:
  ./start.sh start
  ./start.sh logs api
  ./start.sh status
  ./start.sh health

Environment:
  Make sure .env file exists in the current directory.
  Variables like API_TAG, REDIS_PASSWORD must be set.

EOF
    ;;
esac
