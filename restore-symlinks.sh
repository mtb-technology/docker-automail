#!/bin/bash

# Restore symlinks between /www/html and /data volume
# This fixes issues when git operations remove the symlinks

echo "Restoring Data Volume Symlinks"
echo "==============================="

# Check if container is running
if ! docker ps | grep -q automail-app; then
    echo "Error: automail-app container is not running"
    echo "Please start it with: docker compose up -d"
    exit 1
fi

echo "Checking current symlink status..."
echo ""

echo "Storage directory status:"
docker exec automail-app bash -c "ls -la /www/html/storage 2>/dev/null || echo '  /www/html/storage does not exist'"
docker exec automail-app bash -c "ls -la /data/storage 2>/dev/null || echo '  /data/storage does not exist'"
echo ""

echo ".env file status:"
docker exec automail-app bash -c "ls -la /www/html/.env 2>/dev/null || echo '  /www/html/.env does not exist'"
docker exec automail-app bash -c "ls -la /data/config 2>/dev/null || echo '  /data/config does not exist'"
echo ""

echo "Restoring symlinks..."

# Check and restore storage symlink
docker exec automail-app bash -c "
if [ -d /data/storage ]; then
    if [ ! -L /www/html/storage ] || [ ! -e /www/html/storage ]; then
        echo '  Restoring storage symlink...'
        rm -rf /www/html/storage
        ln -s /data/storage /www/html/storage
        echo '  ✓ Storage symlink restored'
    else
        echo '  ✓ Storage symlink is already correct'
    fi
else
    echo '  ⚠ /data/storage does not exist - cannot create symlink'
fi
"

# Check and restore .env symlink
docker exec automail-app bash -c "
if [ -f /data/config ]; then
    if [ ! -L /www/html/.env ] || [ ! -e /www/html/.env ]; then
        echo '  Restoring .env symlink...'
        rm -f /www/html/.env
        ln -sf /data/config /www/html/.env
        echo '  ✓ .env symlink restored'
    else
        echo '  ✓ .env symlink is already correct'
    fi
else
    echo '  ⚠ /data/config does not exist - cannot create symlink'
fi
"

echo ""
echo "Setting correct permissions..."
docker exec automail-app bash -c "chown -R nginx:www-data /www/html"
docker exec automail-app bash -c "[ -d /data ] && chown -R nginx:www-data /data"

echo ""
echo "Final symlink status:"
echo "Storage: $(docker exec automail-app bash -c 'ls -la /www/html/storage')"
echo ".env: $(docker exec automail-app bash -c 'ls -la /www/html/.env')"
echo ""
echo "Symlinks restoration complete!"