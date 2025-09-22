#!/bin/bash

# Force pull - discards all local changes and resets to remote master

echo "Force Pull for Automail"
echo "======================="
echo "WARNING: This will discard ALL local changes!"
echo ""

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
    echo "Error: GITHUB_USERNAME and GITHUB_TOKEN must be set in .env file"
    exit 1
fi

read -p "This will DISCARD all local changes. Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo "Setting git safe directory..."
docker exec automail-app bash -c "git config --global --add safe.directory /www/html"

echo "Backing up current .env file..."
docker exec automail-app bash -c "cp /www/html/.env /tmp/env.backup" 2>/dev/null

echo "Fetching latest from remote..."
docker exec automail-app bash -c "cd /www/html && git fetch origin master"

echo "Resetting to remote master (discarding local changes)..."
docker exec automail-app bash -c "cd /www/html && git reset --hard origin/master"

echo "Cleaning untracked files..."
docker exec automail-app bash -c "cd /www/html && git clean -fd"

echo "Restoring .env file..."
docker exec automail-app bash -c "cp /tmp/env.backup /www/html/.env" 2>/dev/null

echo "Setting correct permissions..."
docker exec automail-app bash -c "chown -R nginx:www-data /www/html"

echo "Running composer install..."
docker exec automail-app bash -c "cd /www/html && composer install --no-dev --ignore-platform-reqs"

echo "Running migrations..."
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan migrate --force"

echo "Clearing caches..."
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan config:clear"
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan cache:clear"
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan freescout:clear-cache"

echo "Running post-update tasks..."
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan freescout:after-app-update"

echo ""
echo "Force pull complete! All files reset to match remote master."