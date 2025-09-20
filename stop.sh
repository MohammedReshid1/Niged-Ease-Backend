#!/bin/bash

# Stop all services

ENVIRONMENT=${1:-development}

echo "Stopping all services..."

if [ "$ENVIRONMENT" == "production" ]; then
    docker-compose -f docker-compose.production.yml down
else
    docker-compose down
fi

echo "All services stopped."