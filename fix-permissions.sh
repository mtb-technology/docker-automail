#!/bin/bash

# Fix file permissions for Automail
# Based on setup-permissions.sh and Dockerfile configuration

echo "Fixing Automail File Permissions"
echo "================================="

# Check if container is running
if ! docker ps | grep -q automail-app; then
    echo "Error: automail-app container is not running"
    echo "Please start it with: docker compose up -d"
    exit 1
fi

echo "Setting ownership for storage directory..."
docker exec automail-app bash -c "chown -R nginx:www-data /www/html/storage/"
docker exec automail-app bash -c "chmod -R ug+rwx /www/html/storage/"

echo "Setting ownership for Modules directory..."
docker exec automail-app bash -c "chown -R nginx:www-data /www/html/Modules/"

echo "Creating and setting permissions for public modules directory..."
docker exec automail-app bash -c "mkdir -p /www/html/public/modules/"
docker exec automail-app bash -c "chown -R nginx:www-data /www/html/public/modules/"

echo "Setting ownership for bootstrap cache..."
docker exec automail-app bash -c "chown -R nginx:www-data /www/html/bootstrap/cache"
docker exec automail-app bash -c "chmod -R ug+rwx /www/html/bootstrap/cache"

echo "Setting ownership for public builds..."
docker exec automail-app bash -c "mkdir -p /www/html/public/css/builds /www/html/public/js/builds"
docker exec automail-app bash -c "chown -R nginx:www-data /www/html/public/css/builds /www/html/public/js/builds"
docker exec automail-app bash -c "chmod -R ug+rwx /www/html/public/css/builds /www/html/public/js/builds"

echo "Creating required vendor directories..."
docker exec automail-app bash -c "mkdir -p /www/html/vendor/natxet/cssmin/src"
docker exec automail-app bash -c "mkdir -p /www/html/vendor/rap2hpoutre/laravel-log-viewer/src/controllers"

echo "Setting ownership for entire webroot..."
docker exec automail-app bash -c "chown -R nginx:www-data /www/html"

echo "Setting specific ownership for cache data (if using /data volume)..."
docker exec automail-app bash -c "[ -d /data ] && chown -R nginx:www-data /data" 2>/dev/null
docker exec automail-app bash -c "[ -d /data/storage/framework/cache/data ] && chown -R 80:82 /data/storage/framework/cache/data" 2>/dev/null

echo "Running freescout:after-app-update..."
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan freescout:after-app-update"

echo "Installing module symlinks..."
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan freescout:module-install" 2>/dev/null

echo "Creating storage link..."
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan storage:link" 2>/dev/null

echo "Clearing caches..."
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan config:clear"
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan cache:clear"
docker exec automail-app bash -c "cd /www/html && sudo -u nginx php artisan freescout:clear-cache"

echo ""
echo "Permissions fixed successfully!"
echo ""
echo "If you still have issues, try:"
echo "  1. docker compose restart automail-app"
echo "  2. Check logs: docker compose logs automail-app"