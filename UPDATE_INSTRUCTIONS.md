# Automail Docker Update Instructions

This document provides step-by-step instructions for updating the Automail application to the latest version from the GitHub repository.

## Important Architecture Note

The Automail application is built into the Docker image during the build process. The repository is cloned from GitHub during `docker build` and the files are copied to `/www/html`. This directory is **not** a git repository inside the container, so updates must be performed by rebuilding the Docker image.

## Prerequisites

Before updating, ensure:
- Docker and Docker Compose are installed and running
- Valid GitHub credentials are configured in `.env` file
- You have backed up any important data

## Update Methods

### Method 1: Standard Update (Recommended)

This method rebuilds the container with the latest code from the repository.

```bash
# 1. Stop the running containers
docker compose down

# 2. Rebuild the application container with fresh code
docker compose build --no-cache automail-app

# 3. Start the updated containers
docker compose up -d

# 4. Check logs to ensure successful startup
docker compose logs -f automail-app
```

**Expected Duration:** 5-10 minutes
**Data Loss:** None (preserves database and persistent files)

### Method 2: Quick Update with Specific Version

Update to a specific Automail version:

```bash
# 1. Stop containers
docker compose down

# 2. Build with specific version
docker compose build \
  --build-arg AUTOMAIL_VERSION=1.8.191 \
  --no-cache automail-app

# 3. Start containers
docker compose up -d
```

### Method 3: Complete Fresh Installation

⚠️ **WARNING:** This removes all data including database. Only use if you want a complete reset.

```bash
# 1. Stop and remove everything
docker-compose down -v

# 2. Remove existing images
docker rmi $(docker images | grep automail | awk '{print $3}')

# 3. Remove data directories (CAUTION: Data loss!)
rm -rf ./data ./db ./dbbackup ./logs

# 4. Rebuild everything from scratch
docker-compose build --pull --no-cache

# 5. Start fresh installation
docker-compose up -d
```

**Expected Duration:** 10-15 minutes
**Data Loss:** Complete (all data will be lost)

### Method 4: Manual In-Container Update (Not Recommended)

⚠️ **Note:** The `/www/html` directory is not a git repository. Updates must be done through container rebuild.

The application files in `/www/html` are copied during the build process and are not connected to git. To properly update, you must rebuild the container using Methods 1-3 above.

If you absolutely need to manually update files:

```bash
# 1. Enter the running container
docker exec -it automail-app bash

# 2. Manually download and extract new version
cd /tmp
wget https://github.com/your-repo/archive/master.zip
unzip master.zip
cp -r automail-master/* /www/html/

# 3. Update dependencies
cd /www/html
composer install --ignore-platform-reqs

# 4. Build application assets
php artisan freescout:build

# 5. Clear caches
php artisan cache:clear
php artisan config:clear
php artisan view:clear

# 6. Exit container
exit

# 7. Restart application container
docker-compose restart automail-app
```

**This method is NOT recommended** as it:
- Doesn't track version changes
- May cause permission issues
- Bypasses the proper build process
- Changes are lost when container is recreated

## Verification Steps

After updating, verify the installation:

1. **Check container status:**
   ```bash
   docker-compose ps
   ```
   All containers should show as "Up"

2. **Check application logs:**
   ```bash
   docker-compose logs --tail=50 automail-app
   ```
   Look for any error messages

3. **Test web interface:**
   - Open browser to http://localhost:8080 (or your configured URL)
   - Log in with admin credentials
   - Check version in admin settings

4. **Verify database connectivity:**
   ```bash
   docker exec automail-app php artisan tinker --execute="DB::connection()->getPdo();"
   ```

## Rollback Procedure

If update fails, rollback to previous version:

```bash
# 1. Stop containers
docker-compose down

# 2. Restore from backup (if available)
docker-compose up -d automail-db
docker exec -i automail-db mysql -u root -ppassword automail < ./dbbackup/latest-backup.sql

# 3. Rebuild with previous version
docker-compose build \
  --build-arg AUTOMAIL_VERSION=1.8.190 \
  --no-cache automail-app

# 4. Start containers
docker-compose up -d
```

## Troubleshooting

### Problem: Build fails with authentication error
**Solution:** Check GitHub credentials in `.env` file:
```bash
cat .env | grep GITHUB
```
Ensure token has repository access permissions.

### Problem: Container won't start after update
**Solution:** Check logs and permissions:
```bash
docker-compose logs automail-app
docker exec automail-app chown -R www-data:www-data /www/html
```

### Problem: Database migration errors
**Solution:** Run migrations manually:
```bash
docker exec automail-app php artisan migrate --force
```

### Problem: Assets not loading correctly
**Solution:** Rebuild assets:
```bash
docker exec automail-app php artisan freescout:build
docker exec automail-app php artisan cache:clear
```

## Backup Recommendations

Before any update:

1. **Database backup:**
   ```bash
   docker exec automail-db-backup backup-now
   ```

2. **Application files backup:**
   ```bash
   tar -czf automail-backup-$(date +%Y%m%d).tar.gz ./data ./db
   ```

3. **Configuration backup:**
   ```bash
   cp .env .env.backup
   cp docker-compose.yml docker-compose.yml.backup
   ```

## Automation Script

Create an update script `update-automail.sh`:

```bash
#!/bin/bash
set -e

echo "Starting Automail update process..."

# Backup
echo "Creating backup..."
docker exec automail-db-backup backup-now || true
tar -czf backups/automail-$(date +%Y%m%d-%H%M%S).tar.gz ./data ./db

# Update
echo "Stopping containers..."
docker-compose down

echo "Rebuilding with latest code..."
docker-compose build --no-cache automail-app

echo "Starting containers..."
docker-compose up -d

echo "Waiting for services to start..."
sleep 30

# Verify
echo "Verifying installation..."
docker-compose ps
docker-compose logs --tail=20 automail-app

echo "Update complete!"
```

Make it executable:
```bash
chmod +x update-automail.sh
./update-automail.sh
```

## Important Notes

- First boot after update may take 2-5 minutes for database migrations
- Always test updates in a development environment first
- Keep GitHub token secure and never commit it to version control
- Regular backups are essential before any update
- Monitor logs during and after update for any issues

## Support

For issues specific to:
- Docker setup: Check container logs with `docker-compose logs`
- Automail application: Refer to https://automail.net/
- This Docker image: https://github.com/cerebello/docker-automail/