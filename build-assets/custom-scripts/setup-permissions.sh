#!/bin/bash
# Setup permissions and modules for Automail

# Set ownership for storage directory
chown -R "${NGINX_USER}":"${NGINX_GROUP}" "${NGINX_WEBROOT}"/storage/

# Set ownership for Modules directory
chown -R "${NGINX_USER}":"${NGINX_GROUP}" "${NGINX_WEBROOT}"/Modules/

# Create public modules directory
mkdir -p "${NGINX_WEBROOT}"/public/modules/

# Set ownership for public modules directory
chown -R "${NGINX_USER}":"${NGINX_GROUP}" "${NGINX_WEBROOT}"/public/modules/

# Install FreeScout modules
php artisan freescout:module-install

# Set ownership for entire webroot
chown -R "${NGINX_USER}":"${NGINX_GROUP}" /www/html

# Set specific ownership for cache data
chown -R 80:82 /data/storage/framework/cache/data/