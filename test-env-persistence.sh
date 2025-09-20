#!/bin/bash

echo "Testing .env file persistence across container restarts..."
echo ""

# Add a test variable to .env file
echo "Adding test variable to .env file..."
docker exec automail-app bash -c "echo 'TEST_CUSTOM_VAR=my_custom_value' >> /www/html/.env"
docker exec automail-app bash -c "echo 'ANOTHER_TEST=another_value' >> /www/html/.env"

echo "Current .env content (showing test variables):"
docker exec automail-app bash -c "grep TEST /www/html/.env"
echo ""

# Restart the container
echo "Restarting container..."
docker-compose restart automail-app
sleep 10  # Wait for container to fully start

echo ""
echo "After restart, checking if custom variables persist:"
docker exec automail-app bash -c "grep TEST /www/html/.env" 2>/dev/null || echo "Custom variables were lost!"
echo ""

echo "Checking if database credentials are still present:"
docker exec automail-app bash -c "grep -E '^DB_(HOST|DATABASE|USERNAME)=' /www/html/.env | head -3"
echo ""

echo "Test complete!"