#!/bin/bash

# One-time script to fix git repository setup in the container

echo "Fixing Git Repository Setup"
echo "==========================="

# Check if container is running
if ! docker ps | grep -q automail-app; then
    echo "Error: automail-app container is not running"
    echo "Please start it with: docker compose up -d"
    exit 1
fi

# Read credentials
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

if [ -z "$GITHUB_USERNAME" ] || [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_USERNAME and GITHUB_TOKEN must be set in .env file"
    exit 1
fi

echo "1. Adding git safe directory exception..."
docker exec automail-app bash -c "git config --global --add safe.directory /www/html"

echo "2. Checking current git status..."
docker exec automail-app bash -c "cd /www/html && git status" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "   No git repository found. Initializing..."
    docker exec automail-app bash -c "cd /www/html && git init"
fi

echo "3. Checking remote configuration..."
docker exec automail-app bash -c "cd /www/html && git remote -v"

echo "4. Removing any existing origin remote..."
docker exec automail-app bash -c "cd /www/html && git remote remove origin" 2>/dev/null

echo "5. Adding correct origin remote..."
docker exec automail-app bash -c "cd /www/html && git remote add origin https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/Webhoek/autommail.git"

echo "6. Verifying remote configuration..."
docker exec automail-app bash -c "cd /www/html && git remote -v"

echo "7. Fetching from remote (this may take a moment)..."
docker exec automail-app bash -c "cd /www/html && git fetch origin master --depth=1"

echo "8. Setting up tracking branch..."
docker exec automail-app bash -c "cd /www/html && git branch --set-upstream-to=origin/master master" 2>/dev/null || \
docker exec automail-app bash -c "cd /www/html && git checkout -b master origin/master" 2>/dev/null || \
echo "   Branch already exists"

echo ""
echo "Git repository fixed! You can now use ./quick-pull.sh to update the code."
echo ""
echo "To test, run:"
echo "  docker exec automail-app bash -c 'cd /www/html && git status'"
echo "  docker exec automail-app bash -c 'cd /www/html && git remote -v'"