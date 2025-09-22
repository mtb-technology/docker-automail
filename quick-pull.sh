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
    
    echo "Restoring data volume symlinks..."
    # Restore storage symlink to /data/storage
    docker exec automail-app bash -c "[ -d /data/storage ] && [ ! -L /www/html/storage ] && rm -rf /www/html/storage && ln -s /data/storage /www/html/storage"
    # Restore .env symlink to /data/config  
    docker exec automail-app bash -c "[ -f /data/config ] && [ ! -L /www/html/.env ] && rm -f /www/html/.env && ln -sf /data/config /www/html/.env"
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
        
        echo "Restoring data volume symlinks after force reset..."
        # Restore storage symlink to /data/storage
        docker exec automail-app bash -c "[ -d /data/storage ] && [ ! -L /www/html/storage ] && rm -rf /www/html/storage && ln -s /data/storage /www/html/storage"
        # Restore .env symlink to /data/config  
        docker exec automail-app bash -c "[ -f /data/config ] && [ ! -L /www/html/.env ] && rm -f /www/html/.env && ln -sf /data/config /www/html/.env"
    fi
    
    # Try to reapply stashed changes
    docker exec automail-app bash -c "cd /www/html && git stash pop" 2>/dev/null || echo "Note: No stashed changes to reapply or conflicts occurred"
fi

echo "Setting initial permissions..."
docker exec automail-app bash -c "chown -R nginx:www-data /www/html"

echo "Running composer update..."
docker exec automail-app bash -c "cd /www/html && composer install --no-dev --ignore-platform-reqs"

echo "Creating required directories..."
docker exec automail-app bash -c "mkdir -p /www/html/vendor/natxet/cssmin/src"
docker exec automail-app bash -c "mkdir -p /www/html/vendor/rap2hpoutre/laravel-log-viewer/src/controllers"
docker exec automail-app bash -c "mkdir -p /www/html/public/modules/"

echo "Running migrations..."
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan migrate --force"

echo "Creating storage link..."
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan storage:link" 2>/dev/null

echo "Clearing caches..."
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan config:clear"
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan cache:clear" 
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan freescout:clear-cache"

echo "Running post-update tasks..."
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan freescout:after-app-update"

echo "Installing modules..."
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan freescout:module-install" 2>/dev/null

echo "Setting final permissions (following setup-permissions.sh pattern)..."
# Set ownership for storage directory
docker exec automail-app bash -c "chown -R nginx:www-data /www/html/storage/"
docker exec automail-app bash -c "chmod -R ug+rwx /www/html/storage/"

# Set ownership for Modules directory
docker exec automail-app bash -c "chown -R nginx:www-data /www/html/Modules/"

# Set ownership for public modules directory
docker exec automail-app bash -c "chown -R nginx:www-data /www/html/public/modules/"

# Set ownership for bootstrap cache
docker exec automail-app bash -c "chown -R nginx:www-data /www/html/bootstrap/cache"
docker exec automail-app bash -c "chmod -R ug+rwx /www/html/bootstrap/cache"

# Set ownership for public builds
docker exec automail-app bash -c "chown -R nginx:www-data /www/html/public/css/builds /www/html/public/js/builds" 2>/dev/null
docker exec automail-app bash -c "chmod -R ug+rwx /www/html/public/css/builds /www/html/public/js/builds" 2>/dev/null

# Set ownership for entire webroot (as in setup-permissions.sh)
docker exec automail-app bash -c "chown -R nginx:www-data /www/html"

# Set specific ownership for cache data if using /data volume
docker exec automail-app bash -c "[ -d /data/storage/framework/cache/data ] && chown -R 80:82 /data/storage/framework/cache/data" 2>/dev/null

echo "Done! Latest changes pulled and applied with correct permissions."