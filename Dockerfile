ARG PHP_VERSION=8.3
ARG DISTRO="alpine"

FROM tiredofit/nginx-php-fpm:${PHP_VERSION}-${DISTRO}-7.7.19
LABEL maintainer="Beaudinn Greve (github.com/cerebello)"

ARG AUTOMAIL_VERSION
ARG GITHUB_USERNAME
ARG GITHUB_TOKEN

ENV AUTOMAIL_VERSION=${AUTOMAIL_VERSION:-"1.8.190"} \
    AUTOMAIL_REPO_URL=https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/Webhoek/automail.git \
    NGINX_WEBROOT=/www/html \
    NGINX_SITE_ENABLED=automail \
    PHP_CREATE_SAMPLE_PHP=FALSE \
    PHP_ENABLE_CURL=TRUE \
    PHP_ENABLE_FILEINFO=TRUE \
    PHP_ENABLE_GNUPG=TRUE \
    PHP_ENABLE_ICONV=TRUE \
    PHP_ENABLE_IGBINARY=TRUE \
    PHP_ENABLE_IMAP=TRUE \
    PHP_ENABLE_INTL=TRUE \
    PHP_ENABLE_LDAP=TRUE \
    PHP_ENABLE_OPENSSL=TRUE \
    PHP_ENABLE_PCNTL=TRUE \
    PHP_ENABLE_PDO_PGSQL=TRUE \
    PHP_ENABLE_POSIX=TRUE \
    PHP_ENABLE_SIMPLEXML=TRUE \
    PHP_ENABLE_TOKENIZER=TRUE \
    PHP_ENABLE_ZIP=TRUE \
    IMAGE_NAME="cerebello/automail" \
    IMAGE_REPO_URL="https://github.com/cerebello/docker-automail/"

ADD build-assets /build-assets
WORKDIR /assets/install

RUN source /assets/functions/00-container && \
    set -x && \
    package update && \
    package upgrade && \
    package install .automail-run-deps expect git gnu-libiconv sed && \
    php-ext prepare && php-ext reset && php-ext enable core && \
    \
    # Clone with token (build-time only)
    clone_git_repo "${AUTOMAIL_REPO_URL}" master /assets/install && \
    \
    # Immediately scrub token from remote but KEEP .git
    git remote set-url origin https://github.com/Webhoek/automail.git && \
    git config --unset-all http.https://github.com/.extraheader || true && \
    \
    mkdir -p vendor/natxet/cssmin/src vendor/rap2hpoutre/laravel-log-viewer/src/controllers && \
    if [ -d "/build-assets/src" ]; then cp -Rp /build-assets/src/* /assets/install ; fi && \
    if [ -d "/build-assets/scripts" ]; then \
      for script in /build-assets/scripts/*.sh; do echo "** Applying $script"; bash "$script"; done ; \
    fi && \
    if [ -d "/build-assets/custom-scripts" ]; then \
      mkdir -p /assets/custom-scripts ; cp -Rp /build-assets/custom-scripts/* /assets/custom-scripts ; \
    fi && \
    composer install --no-dev --optimize-autoloader --ignore-platform-reqs && \
    php artisan freescout:build || true && \
    \
    # Copy WHOLE repo (including .git) to webroot
    mkdir -p /www/html && \
    rsync -a --delete /assets/install/ /www/html/ && \
    chown -R "${NGINX_USER}:${NGINX_GROUP}" /www/html && \
    \
    package cleanup && rm -rf /build-assets /root/.composer /var/tmp/*

# If needed:
# COPY install /www/html
