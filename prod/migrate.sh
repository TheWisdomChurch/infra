#!/bin/bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

COMPOSE_FILE="docker-compose-prod.yml"

echo -e "${BLUE}=== WisdomChurch Database Migration ===${NC}\n"

# Check if services are running
if ! docker compose -f "$COMPOSE_FILE" ps migrate > /dev/null 2>&1; then
    echo -e "${RED}✗ Services not running${NC}"
    echo "Start services first with: make start"
    exit 1
fi

# Get database URL from environment
if [[ ! -f ".env" ]]; then
    echo -e "${RED}✗ .env file not found${NC}"
    exit 1
fi

echo -e "${BLUE}Testing database connectivity...${NC}"

# Test connection
db_url=$(grep "^DATABASE_URL=" .env | cut -d= -f2-)

if [[ -z "$db_url" ]]; then
    echo -e "${RED}✗ DATABASE_URL not set in .env${NC}"
    exit 1
fi

# Try to connect from local machine (if psql available)
if command -v psql &> /dev/null; then
    echo -e "${YELLOW}Testing local connection...${NC}"
    if psql "$db_url" -c "SELECT version();" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Database is reachable${NC}\n"
    else
        echo -e "${RED}✗ Cannot reach database from local${NC}"
        echo "Possible issues:"
        echo "  1. Wrong DATABASE_URL credentials"
        echo "  2. Server IP not whitelisted in Supabase"
        echo "  3. Network connectivity issue"
        echo ""
        echo "Fix: Update .env with correct Supabase credentials"
        exit 1
    fi
fi

echo -e "${BLUE}Running migration...${NC}"
docker compose -f "$COMPOSE_FILE" exec -T api /root/wisdom-house migrate up

if [[ $? -eq 0 ]]; then
    echo -e "\n${GREEN}✓ Migration completed successfully${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Migration failed${NC}"
    echo "Check logs with: make logs migrate"
    exit 1
fi
