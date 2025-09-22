#!/bin/bash

# Quick script to pull latest changes if repo already exists in container

echo "Quick Git Pull for Automail"
echo "=========================="

# Check if container is running
if ! docker ps | grep -q automail-app; then
    echo "Error: automail-app container is not running"
    exit 1
fi

# Read credentials
if [ -f .env ]; then
    source .env
fi

if [ -z "$GITHUB_USERNAME" ] || [ -z "$GITHUB_TOKEN" ]; then
    echo "Please set GITHUB_USERNAME and GITHUB_TOKEN in .env file"
    exit 1
fi

# Add safe directory first
echo "Setting git safe directory..."
docker exec automail-app bash -c "git config --global --add safe.directory /www/html"

# Check if git repo exists AND has correct remote
docker exec automail-app bash -c "cd /www/html && git remote get-url origin" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Git repository not properly configured. Setting up..."
    
    # Check if .git exists but no remote
    docker exec automail-app bash -c "[ -d /www/html/.git ]" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "Found existing .git directory, adding remote..."
        docker exec automail-app bash -c "cd /www/html && git remote add origin https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/Webhoek/autommail.git" 2>/dev/null || \
        docker exec automail-app bash -c "cd /www/html && git remote set-url origin https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/Webhoek/autommail.git"
    else
        echo "Initializing new git repository..."
        docker exec automail-app bash -c "cd /www/html && git init"
        docker exec automail-app bash -c "cd /www/html && git remote add origin https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/Webhoek/autommail.git"
    fi
    
    echo "Fetching from remote..."
    docker exec automail-app bash -c "cd /www/html && git fetch --depth=1"
    
    echo "Resetting to origin/master..."
    docker exec automail-app bash -c "cd /www/html && git reset --hard origin/master"
else
    echo "Checking for uncommitted changes..."
    docker exec automail-app bash -c "cd /www/html && git status --short"
    
    echo "Stashing any local changes..."
    docker exec automail-app bash -c "cd /www/html && git stash save 'Auto-stash before pull'" 2>/dev/null
    
    echo "Pulling latest changes..."
    docker exec automail-app bash -c "cd /www/html && git pull origin master" 2>/dev/null
    
    if [ $? -ne 0 ]; then
        echo "Pull failed due to conflicts. Forcing update..."
        docker exec automail-app bash -c "cd /www/html && git fetch origin master"
        docker exec automail-app bash -c "cd /www/html && git reset --hard origin/master"
    fi
    
    # Try to reapply stashed changes
    docker exec automail-app bash -c "cd /www/html && git stash pop" 2>/dev/null || echo "Note: No stashed changes to reapply or conflicts occurred"
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