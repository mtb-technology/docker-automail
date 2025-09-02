# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Docker-based deployment of Automail (https://automail.net/), a helpdesk system. The project containerizes the Automail application with automated installation and configuration.

## Core Architecture

### Container Stack
- **automail-app**: Main application container running Nginx + PHP-FPM on Alpine Linux
  - Based on `tiredofit/nginx-php-fpm` image
  - Runs Automail application from private GitHub repository
  - Webroot: `/www/html`
  
- **automail-db**: MariaDB database container
  - Based on `tiredofit/mariadb` image
  - Database name: `automail`
  
- **automail-db-backup**: Automated database backup container
  - Based on `tiredofit/db-backup` image
  - Backups stored in `./dbbackup`

### Key Directories
- `./data`: Persistent application data (sessions, cache)
- `./db`: MariaDB data files
- `./dbbackup`: Database backups
- `./logs`: Nginx and PHP logs
- `./build-assets`: Custom scripts and source modifications
- `./install`: Container initialization scripts

## Development Commands

### Container Management
```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f automail-app

# Access application shell
docker exec -it automail-app bash

# Restart services
docker-compose restart

# Stop all services
docker-compose down
```

### Building and Deployment
```bash
# Build image locally
docker build -t automail-app \
  --build-arg GITHUB_USERNAME=${GITHUB_USERNAME} \
  --build-arg GITHUB_TOKEN=${GITHUB_TOKEN} \
  --build-arg SITE_URL=${SITE_URL} .

# Pull and run prebuilt image
docker pull tiredofit/automail:latest
```

### Database Operations
```bash
# Access database
docker exec -it automail-db mysql -u automail -pautomail automail

# Manual backup
docker exec automail-db-backup backup-now
```

## Configuration Details

### Environment Variables Required
- `GITHUB_USERNAME`: GitHub username for private repo access
- `GITHUB_TOKEN`: GitHub Personal Access Token
- `SITE_URL`: Full URL where application will be accessed
- `ADMIN_EMAIL`: Administrator email for initial setup
- `ADMIN_PASS`: Administrator password (should be rotated after bootstrap)

### Important Configuration Notes
- Application runs on port 80 inside container, mapped to 127.0.0.1:8080
- Database credentials: username `automail`, password `automail` (development only)
- SSL termination expected to be handled by reverse proxy
- First boot can take 2-5 minutes for schema setup
- Auto-update is disabled in current configuration (`ENABLE_AUTO_UPDATE=false`)

## Critical Files

- `docker-compose.yml`: Main orchestration file defining all services
- `Dockerfile`: Application container build definition
- `.env`: Environment variables (contains sensitive credentials - never commit)

## Security Considerations

- The `.env` file contains GitHub credentials and should never be committed
- Database passwords in docker-compose.yml should be changed for production
- `APP_TRUSTED_PROXIES` should be configured appropriately for production
- Admin password should be rotated immediately after initial setup