#!/bin/bash

# Script to update Automail from GitHub without rebuilding the container

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Automail Update Script${NC}"
echo "This will pull the latest changes from GitHub without rebuilding the container"
echo ""

# Check if container is running
if ! docker ps | grep -q automail-app; then
    echo -e "${RED}Error: automail-app container is not running${NC}"
    echo "Please start the container first with: docker compose up -d"
    exit 1
fi

# Read GitHub credentials from .env file
if [ -f .env ]; then
    source .env
else
    echo -e "${YELLOW}Warning: .env file not found. Using environment variables or prompting...${NC}"
fi

# Prompt for GitHub credentials if not set
if [ -z "$GITHUB_USERNAME" ]; then
    read -p "Enter GitHub username: " GITHUB_USERNAME
fi

if [ -z "$GITHUB_TOKEN" ]; then
    read -s -p "Enter GitHub token: " GITHUB_TOKEN
    echo ""
fi

# Construct repo URL
REPO_URL="https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/Webhoek/autommail.git"

echo -e "${YELLOW}Creating backup of current installation...${NC}"
docker exec automail-app bash -c "cp -r /www/html /www/html.backup.$(date +%Y%m%d_%H%M%S)"

echo -e "${YELLOW}Cloning latest repository to temporary location...${NC}"
docker exec automail-app bash -c "rm -rf /tmp/automail-update && git clone --depth=1 --branch=master ${REPO_URL} /tmp/automail-update"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to clone repository${NC}"
    echo "Please check your GitHub credentials and repository access"
    exit 1
fi

echo -e "${YELLOW}Backing up current .env file...${NC}"
docker exec automail-app bash -c "cp /www/html/.env /tmp/env.backup"

echo -e "${YELLOW}Copying new files (preserving storage, .env, and modules)...${NC}"
docker exec automail-app bash -c "
    # Copy new files, excluding things we want to preserve
    rsync -av --delete \
        --exclude='.env' \
        --exclude='storage/' \
        --exclude='Modules/' \
        --exclude='public/modules/' \
        --exclude='bootstrap/cache/' \
        --exclude='.git/' \
        /tmp/automail-update/ /www/html/
"

echo -e "${YELLOW}Restoring .env file...${NC}"
docker exec automail-app bash -c "cp /tmp/env.backup /www/html/.env"

echo -e "${YELLOW}Setting correct permissions...${NC}"
docker exec automail-app bash -c "chown -R nginx:www-data /www/html"

echo -e "${YELLOW}Installing composer dependencies...${NC}"
docker exec automail-app bash -c "cd /www/html && composer install --no-dev --ignore-platform-reqs"

echo -e "${YELLOW}Running Laravel migrations...${NC}"
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan migrate --force"

echo -e "${YELLOW}Clearing caches...${NC}"
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan config:clear"
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan cache:clear"
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan freescout:clear-cache"

echo -e "${YELLOW}Running post-update tasks...${NC}"
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan freescout:after-app-update"

echo -e "${YELLOW}Updating version file...${NC}"
docker exec automail-app bash -c "echo 'Manual update on $(date)' >> /www/html/.automail-version"

echo -e "${YELLOW}Cleaning up...${NC}"
docker exec automail-app bash -c "rm -rf /tmp/automail-update /tmp/env.backup"

echo -e "${GREEN}✓ Update complete!${NC}"
echo ""
echo "The application has been updated to the latest version from GitHub."
echo "Backup created at: /www/html.backup.$(date +%Y%m%d_%H%M%S)"
echo ""
echo -e "${YELLOW}Note: If you encounter any issues, you can restore the backup inside the container${NC}"