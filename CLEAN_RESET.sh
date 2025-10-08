#!/bin/bash

echo "🧹 GIDEON STUDIO COMPLETE RESET & CLEAN DEPLOYMENT"
echo "================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Stop and remove ALL containers and volumes
echo -e "${YELLOW}1. Stopping all containers and removing volumes...${NC}"
docker compose down --volumes --remove-orphans --timeout 0

# System cleanup
echo -e "${YELLOW}2. Cleaning Docker system...${NC}"
docker system prune -af --volumes
docker volume prune -f
docker image prune -f

# Remove old containers explicitly
echo -e "${YELLOW}3. Removing any remaining containers...${NC}"
docker rm -f $(docker ps -aq) 2>/dev/null || true

# Remove old images related to our project
echo -e "${YELLOW}4. Removing old Gideon Studio images...${NC}"
docker images | grep -E "(ai-studio-server|gideon)" | awk '{print $3}' | xargs docker rmi -f 2>/dev/null || true

# Remove project-specific volumes (the key one you found!)
echo -e "${YELLOW}5. Removing project volumes...${NC}"
docker volume ls | grep "^local.*ai-studio-server" | awk '{print $2}' | xargs docker volume rm -f 2>/dev/null || true

echo -e "${YELLOW}6. Clean verified - checking state...${NC}"
echo "Active containers:"
docker ps -a
echo ""
echo "Active volumes:"
docker volume ls
echo ""
echo "Recent images:"
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | head -10

echo -e "${GREEN}✅ CLEAN COMPLETE - READY FOR DEPLOYMENT${NC}"
echo ""
echo -e "${YELLOW}NEXT STEPS:${NC}"
echo "1. Pull latest changes: git pull origin main"
echo "2. Verify .env file has OAuth credentials"
echo "3. Deploy: docker compose up -d"
echo "4. Monitor: docker compose logs -f gideon-studio"
echo "5. Test: open https://studio.euctools.ai"
echo ""
echo -e "${GREEN}THIS WILL BE A WORKING OAUTH + KNOWLEDGE BASE SYSTEM! 🎯${NC}"
