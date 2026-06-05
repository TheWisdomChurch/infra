#!/bin/bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== WisdomChurch Infrastructure Setup ===${NC}\n"

# Check if .env.prod exists
if [[ ! -f ".env.prod" ]]; then
  echo -e "${RED}Error: .env.prod not found${NC}"
  echo "Please create .env.prod first, you can copy from .env.example"
  exit 1
fi

# Generate secure random values
generate_secret() {
  openssl rand -hex 32
}

generate_token() {
  openssl rand -hex 64
}

echo -e "${YELLOW}Checking for empty/missing critical variables...${NC}\n"

# Check REDIS_PASSWORD
REDIS_PASSWORD=$(grep "^REDIS_PASSWORD=" .env.prod | cut -d= -f2 || echo "")
if [[ -z "$REDIS_PASSWORD" ]]; then
  echo -e "${YELLOW}⚠ REDIS_PASSWORD is empty${NC}"
  REDIS_PASSWORD=$(generate_secret)
  echo -e "${GREEN}Generated: ${REDIS_PASSWORD}${NC}"
  sed -i "s/^REDIS_PASSWORD=.*/REDIS_PASSWORD=$REDIS_PASSWORD/" .env.prod
  echo -e "${GREEN}✓ Updated REDIS_PASSWORD${NC}\n"
fi

# Check JWT_SECRET
JWT_SECRET=$(grep "^JWT_SECRET=" .env.prod | cut -d= -f2 || echo "")
if [[ -z "$JWT_SECRET" ]]; then
  echo -e "${YELLOW}⚠ JWT_SECRET is empty${NC}"
  JWT_SECRET=$(generate_token)
  echo -e "${GREEN}Generated: ${JWT_SECRET}${NC}"
  sed -i "s/^JWT_SECRET=.*/JWT_SECRET=$JWT_SECRET/" .env.prod
  echo -e "${GREEN}✓ Updated JWT_SECRET${NC}\n"
fi

# Check AUTH_SECRET_KEY
AUTH_SECRET_KEY=$(grep "^AUTH_SECRET_KEY=" .env.prod | cut -d= -f2 || echo "")
if [[ -z "$AUTH_SECRET_KEY" ]]; then
  echo -e "${YELLOW}⚠ AUTH_SECRET_KEY is empty${NC}"
  AUTH_SECRET_KEY=$(generate_token)
  echo -e "${GREEN}Generated: ${AUTH_SECRET_KEY}${NC}"
  sed -i "s/^AUTH_SECRET_KEY=.*/AUTH_SECRET_KEY=$AUTH_SECRET_KEY/" .env.prod
  echo -e "${GREEN}✓ Updated AUTH_SECRET_KEY${NC}\n"
fi

# Create .env symlink
if [[ ! -L ".env" ]]; then
  rm -f .env  # Remove if it's a regular file
  ln -sf .env.prod .env
  echo -e "${GREEN}✓ Created .env symlink${NC}\n"
fi

# Create traefik-public network
echo -e "${BLUE}Setting up Docker networks...${NC}"
if ! docker network inspect traefik-public &>/dev/null; then
  echo -e "${YELLOW}⚠ traefik-public network not found${NC}"
  docker network create traefik-public
  echo -e "${GREEN}✓ Created traefik-public network${NC}\n"
else
  echo -e "${GREEN}✓ traefik-public network exists${NC}\n"
fi

# Validate configuration
echo -e "${BLUE}Validating docker-compose configuration...${NC}"
if docker compose -f docker-compose-prod.yml config > /dev/null 2>&1; then
  echo -e "${GREEN}✓ Configuration is valid${NC}\n"
else
  echo -e "${RED}✗ Configuration validation failed${NC}"
  docker compose -f docker-compose-prod.yml config 2>&1 | head -20
  echo -e "\n${YELLOW}Please fix the issues above and try again.${NC}"
  exit 1
fi

echo -e "${GREEN}=== Setup Complete ===${NC}"
echo -e "\n${BLUE}Next steps:${NC}"
echo "1. Review .env.prod for any custom values that need adjustment"
echo "2. Ensure DATABASE_URL is set correctly (Supabase, etc.)"
echo "3. Configure external API keys (YouTube, S3, etc.)"
echo "4. Run: ${BLUE}make start${NC}"
echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo "  make start       - Start all services"
echo "  make status      - Check service status"
echo "  make logs        - View service logs"
echo "  make health      - Check service health"
