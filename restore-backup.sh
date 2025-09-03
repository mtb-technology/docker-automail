#!/bin/bash

# Automail Backup Restoration Script
# This script restores Automail application files and database from another instance

set -e

# Configuration
BACKUP_SQL="automail-server-2-dump.sql"
BACKUP_HTML_DIR="automail-server-2-html"
DOCKER_PROJECT="docker-automail"

echo "=== Automail Backup Restoration ==="
echo

# Step 1: Verify backup files exist
echo "Step 1: Verifying backup files..."
if [ ! -f "$BACKUP_SQL" ]; then
    echo "Error: Database backup file '$BACKUP_SQL' not found!"
    echo "Please ensure you have run:"
    echo "  rsync sebnmis@106.108.29.71:automail-server-2-dump.sql automail-server-2-dump.sql"
    exit 1
fi

if [ ! -d "$BACKUP_HTML_DIR" ]; then
    echo "Error: Application backup directory '$BACKUP_HTML_DIR' not found!"
    echo "Please ensure you have run:"
    echo "  rsync --recursive --delete --rsync-path=/usr/bin/rsync --times sebnmis@106.108.29.71:/var/www/automail-production automail-server-2-html"
    exit 1
fi

echo "✓ Backup files verified"
echo

# Step 2: Stop current containers
echo "Step 2: Stopping Docker containers..."
docker compose down
echo "✓ Containers stopped"
echo

# Step 3: Backup current data (optional safety measure)
echo "Step 3: Creating safety backup of current data..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
if [ -d "./data" ]; then
    mv ./data "./data.backup.$TIMESTAMP"
    echo "✓ Current data backed up to ./data.backup.$TIMESTAMP"
fi
if [ -d "./db" ]; then
    mv ./db "./db.backup.$TIMESTAMP"
    echo "✓ Current database backed up to ./db.backup.$TIMESTAMP"
fi
echo

# Step 4: Prepare directories
echo "Step 4: Preparing directories..."
mkdir -p ./data
mkdir -p ./db
echo "✓ Directories prepared"
echo

# Step 5: Start only database container
echo "Step 5: Starting database container..."
docker compose up -d automail-db
echo "Waiting for database to be ready..."
sleep 10

# Wait for database to be fully ready
until docker exec automail-db mysql -u root -ppassword -e "SELECT 1" &>/dev/null; do
    echo "Waiting for database..."
    sleep 2
done
echo "✓ Database container ready"
echo

# Step 6: Import database dump
echo "Step 6: Importing database dump..."
echo "This may take a few minutes for large databases..."

# Get file size for progress reporting
FILE_SIZE=$(du -h "$BACKUP_SQL" | cut -f1)
echo "Database dump size: $FILE_SIZE"

# First, configure MySQL for large imports
echo "Configuring MySQL for large import..."
docker exec automail-db mysql -u root -ppassword -e "SET GLOBAL max_allowed_packet=1073741824;"
docker exec automail-db mysql -u root -ppassword -e "SET GLOBAL wait_timeout=28800;"
docker exec automail-db mysql -u root -ppassword -e "SET GLOBAL interactive_timeout=28800;"
docker exec automail-db mysql -u root -ppassword -e "SET GLOBAL net_read_timeout=600;"
docker exec automail-db mysql -u root -ppassword -e "SET GLOBAL net_write_timeout=600;"

# Create database
echo "Creating database..."
docker exec automail-db sh -c "mysql -u root -ppassword -e 'DROP DATABASE IF EXISTS automail; CREATE DATABASE automail CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'"

# Import using a more robust method
echo "Starting import (this will take time for large databases)..."
echo "Import method: Direct piped import to avoid copying large file to container"

# Use pv for progress if available, otherwise use cat
if command -v pv &> /dev/null; then
    echo "Using pv for progress monitoring..."
    pv "$BACKUP_SQL" | docker exec -i automail-db mysql -u root -ppassword \
        --max_allowed_packet=1G \
        --connect-timeout=600 \
        --wait-timeout=28800 \
        --interactive-timeout=28800 \
        --net-read-timeout=600 \
        --net-write-timeout=600 \
        automail
else
    echo "Importing without progress bar (install pv for progress monitoring)..."
    cat "$BACKUP_SQL" | docker exec -i automail-db mysql -u root -ppassword \
        --max_allowed_packet=1G \
        --connect-timeout=600 \
        --wait-timeout=28800 \
        --interactive-timeout=28800 \
        --net-read-timeout=600 \
        --net-write-timeout=600 \
        automail
fi

echo "✓ Database imported successfully"
echo

# Step 7: Start application container
echo "Step 7: Starting application container..."
docker compose up -d automail-app
echo "Waiting for application container to initialize..."
sleep 10
echo "✓ Application container started"
echo

# Step 8: Copy application files
echo "Step 8: Copying application files to container..."

# Copy the application files to the container's web root
docker cp "$BACKUP_HTML_DIR/." automail-app:/www/html/

# Set proper permissions
docker exec automail-app chown -R nginx:www-data /www/html
docker exec automail-app chmod -R 755 /www/html
docker exec automail-app find /www/html -type f -exec chmod 644 {} \;

# Ensure storage directories are writable
docker exec automail-app chmod -R 775 /www/html/storage || true
docker exec automail-app chmod -R 775 /www/html/bootstrap/cache || true

echo "✓ Application files copied and permissions set"
echo

# Step 9: Update configuration
echo "Step 9: Updating configuration..."

# Check if .env file exists in the backup
if [ -f "$BACKUP_HTML_DIR/.env" ]; then
    echo "Found .env file in backup. You may need to update database credentials:"
    echo "  DB_HOST=automail-db"
    echo "  DB_DATABASE=automail"
    echo "  DB_USERNAME=automail"
    echo "  DB_PASSWORD=automail"
    echo
    echo "Would you like to automatically update the database configuration? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        # Update database configuration in container
        docker exec automail-app sed -i 's/^DB_HOST=.*/DB_HOST=automail-db/' /www/html/.env || true
        docker exec automail-app sed -i 's/^DB_DATABASE=.*/DB_DATABASE=automail/' /www/html/.env || true
        docker exec automail-app sed -i 's/^DB_USERNAME=.*/DB_USERNAME=automail/' /www/html/.env || true
        docker exec automail-app sed -i 's/^DB_PASSWORD=.*/DB_PASSWORD=automail/' /www/html/.env || true
        echo "✓ Database configuration updated"
    fi
fi

# Clear application cache
docker exec automail-app sh -c "cd /www/html && php artisan cache:clear" || true
docker exec automail-app sh -c "cd /www/html && php artisan config:clear" || true
docker exec automail-app sh -c "cd /www/html && php artisan view:clear" || true

echo "✓ Configuration updated"
echo

# Step 10: Start remaining services
echo "Step 10: Starting all services..."
docker compose up -d
echo "✓ All services started"
echo

# Step 11: Verify restoration
echo "Step 11: Verifying restoration..."
echo

# Check container status
docker compose ps

echo
echo "=== Restoration Complete ==="
echo
echo "Your Automail instance has been restored from backup!"
echo "Please verify:"
echo "  1. Access the application at: http://106.108.30.64"
echo "  2. Check logs for any errors: docker compose logs -f automail-app"
echo "  3. Test login with your existing credentials"
echo
echo "If you encounter issues:"
echo "  - Check logs: docker compose logs automail-app"
echo "  - Verify database connection: docker exec automail-app cat /www/html/.env | grep DB_"
echo "  - Your original data is backed up with timestamp: $TIMESTAMP"
echo