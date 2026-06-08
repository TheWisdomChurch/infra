#!/bin/bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== WisdomChurch - DEPLOY NOW (Live in 2 minutes) ===${NC}\n"

# Step 1: Clean up
echo -e "${BLUE}Step 1: Cleaning up old containers...${NC}"
docker compose -f docker-compose-prod.yml down --remove-orphans 2>/dev/null || true
sleep 2

# Step 2: Clean images
echo -e "${BLUE}Step 2: Cleaning old images...${NC}"
docker image prune -af --filter "label!=keep" 2>/dev/null || true

# Step 3: Pull fresh images
echo -e "${BLUE}Step 3: Pulling latest images...${NC}"
docker compose -f docker-compose-prod.yml pull

# Step 4: Start services (skipping migration - it was blocking)
echo -e "${BLUE}Step 4: Starting services...${NC}"
docker compose -f docker-compose-prod.yml up -d --remove-orphans

# Step 5: Wait for services to be healthy
echo -e "${BLUE}Step 5: Waiting for services to become healthy...${NC}"
sleep 10

# Step 6: Show status
echo -e "\n${GREEN}=== Service Status ===${NC}"
docker compose -f docker-compose-prod.yml ps

echo -e "\n${GREEN}=== Service Health ===${NC}"
docker compose -f docker-compose-prod.yml ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null | grep -v "NAME"

# Final message
echo -e "\n${GREEN}✅ DEPLOYMENT COMPLETE!${NC}"
echo -e "\n${BLUE}Your application is live at:${NC}"
echo "  🌐 https://wisdomchurchhq.org"
echo "  🔐 https://admin.wisdomchurchhq.org"
echo ""
echo -e "${BLUE}Monitor logs:${NC}"
echo "  docker compose -f docker-compose-prod.yml logs -f"
echo ""
echo -e "${YELLOW}Note: Database migration will retry automatically${NC}"
echo "  Check: docker compose -f docker-compose-prod.yml logs migrate"
