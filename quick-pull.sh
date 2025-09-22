#!/bin/bash

# Quick script to pull latest changes if repo already exists in container

echo "Quick Git Pull for Automail"
echo "=========================="

# Check if container is running
if ! docker ps | grep -q automail-app; then
    echo "Error: automail-app container is not running"
    exit 1
fi

# Check if git repo exists in container
docker exec automail-app bash -c "[ -d /www/html/.git ]" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "No git repository found in /www/html"
    echo "Initializing git repository..."
    
    # Read credentials
    if [ -f .env ]; then
        source .env
    fi
    
    if [ -z "$GITHUB_USERNAME" ] || [ -z "$GITHUB_TOKEN" ]; then
        echo "Please set GITHUB_USERNAME and GITHUB_TOKEN in .env file"
        exit 1
    fi
    
    # Initialize git repo
    docker exec automail-app bash -c "cd /www/html && git init"
    docker exec automail-app bash -c "cd /www/html && git config --global --add safe.directory /www/html"
    docker exec automail-app bash -c "cd /www/html && git remote add origin https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/Webhoek/autommail.git"
    docker exec automail-app bash -c "cd /www/html && git fetch --depth=1"
    docker exec automail-app bash -c "cd /www/html && git reset --hard origin/master"
else
    echo "Adding safe directory exception..."
    docker exec automail-app bash -c "git config --global --add safe.directory /www/html"
    
    echo "Pulling latest changes..."
    docker exec automail-app bash -c "cd /www/html && git pull origin master"
fi

echo "Running composer update..."
docker exec automail-app bash -c "cd /www/html && composer install --no-dev --ignore-platform-reqs"

echo "Running migrations..."
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan migrate --force"

echo "Clearing caches..."
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan config:clear && sudo -u nginx php artisan cache:clear"

echo "Running post-update tasks..."
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan freescout:after-app-update"

echo "Done! Latest changes pulled and applied."