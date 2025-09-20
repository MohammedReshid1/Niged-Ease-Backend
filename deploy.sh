#!/bin/bash

# Niged Ease Backend Deployment Script
# Usage: ./deploy.sh [development|production]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default to development if no argument provided
ENVIRONMENT=${1:-development}

echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}  Niged Ease Backend Deployment Script${NC}"
echo -e "${GREEN}  Environment: ${YELLOW}$ENVIRONMENT${NC}"
echo -e "${GREEN}===========================================${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

if ! command_exists docker; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

if ! command_exists docker-compose; then
    echo -e "${RED}Error: Docker Compose is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites met${NC}"

# Function to generate secret key
generate_secret_key() {
    python3 -c 'import secrets; print(secrets.token_urlsafe(50))'
}

# Setup environment files
setup_environment() {
    echo -e "\n${YELLOW}Setting up environment...${NC}"
    
    if [ "$ENVIRONMENT" == "production" ]; then
        if [ ! -f .env ]; then
            echo -e "${YELLOW}Creating production .env file...${NC}"
            cp .env.production .env
            
            # Generate secure secret keys
            echo -e "${YELLOW}Generating secure secret keys...${NC}"
            CORE_KEY=$(generate_secret_key)
            NOTIFICATION_KEY=$(generate_secret_key)
            USER_MANAGEMENT_KEY=$(generate_secret_key)
            JWT_KEY=$(generate_secret_key)
            
            # Update .env with generated keys (on macOS use -i '' for in-place editing)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s/your-production-core-secret-key-here/$CORE_KEY/" .env
                sed -i '' "s/your-production-notification-secret-key-here/$NOTIFICATION_KEY/" .env
                sed -i '' "s/your-production-user-management-secret-key-here/$USER_MANAGEMENT_KEY/" .env
                sed -i '' "s/your-production-jwt-secret-key-here/$JWT_KEY/" .env
            else
                sed -i "s/your-production-core-secret-key-here/$CORE_KEY/" .env
                sed -i "s/your-production-notification-secret-key-here/$NOTIFICATION_KEY/" .env
                sed -i "s/your-production-user-management-secret-key-here/$USER_MANAGEMENT_KEY/" .env
                sed -i "s/your-production-jwt-secret-key-here/$JWT_KEY/" .env
            fi
            
            echo -e "${RED}IMPORTANT: Please update the .env file with your production values:${NC}"
            echo -e "  - Database credentials"
            echo -e "  - Email configuration"
            echo -e "  - Domain name"
            echo -e "  - SSL certificates"
            read -p "Press enter to continue after updating .env file..."
        fi
        
        # Check for SSL certificates
        if [ ! -d "ssl" ]; then
            mkdir -p ssl
            echo -e "${YELLOW}SSL directory created. Please add your SSL certificates:${NC}"
            echo -e "  - ssl/cert.pem"
            echo -e "  - ssl/key.pem"
            read -p "Press enter to continue after adding SSL certificates..."
        fi
    fi
    
    echo -e "${GREEN}✓ Environment setup complete${NC}"
}

# Build Docker images
build_images() {
    echo -e "\n${YELLOW}Building Docker images...${NC}"
    
    if [ "$ENVIRONMENT" == "production" ]; then
        docker-compose -f docker-compose.production.yml build --no-cache
    else
        docker-compose build --no-cache
    fi
    
    echo -e "${GREEN}✓ Docker images built successfully${NC}"
}

# Start services
start_services() {
    echo -e "\n${YELLOW}Starting services...${NC}"
    
    if [ "$ENVIRONMENT" == "production" ]; then
        docker-compose -f docker-compose.production.yml up -d
    else
        docker-compose up -d
    fi
    
    echo -e "${GREEN}✓ Services started successfully${NC}"
}

# Wait for services to be healthy
wait_for_services() {
    echo -e "\n${YELLOW}Waiting for services to be healthy...${NC}"
    
    # Wait for database
    echo -n "Waiting for database..."
    for i in {1..30}; do
        if docker-compose exec -T db pg_isready -U postgres >/dev/null 2>&1; then
            echo -e " ${GREEN}✓${NC}"
            break
        fi
        echo -n "."
        sleep 2
    done
    
    # Wait for services to be ready
    echo -n "Waiting for services to be ready..."
    sleep 10
    echo -e " ${GREEN}✓${NC}"
}

# Create superuser for each service
create_superusers() {
    echo -e "\n${YELLOW}Creating superusers...${NC}"
    
    read -p "Do you want to create superusers? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Creating superuser for Core Service...${NC}"
        if [ "$ENVIRONMENT" == "production" ]; then
            docker-compose -f docker-compose.production.yml exec core_service python manage.py createsuperuser
        else
            docker-compose exec core_service python manage.py createsuperuser
        fi
        
        echo -e "${YELLOW}Creating superuser for User Management Service...${NC}"
        if [ "$ENVIRONMENT" == "production" ]; then
            docker-compose -f docker-compose.production.yml exec user_management_service python manage.py createsuperuser
        else
            docker-compose exec user_management_service python manage.py createsuperuser
        fi
    fi
}

# Show service status
show_status() {
    echo -e "\n${GREEN}===========================================${NC}"
    echo -e "${GREEN}  Deployment Complete!${NC}"
    echo -e "${GREEN}===========================================${NC}"
    
    if [ "$ENVIRONMENT" == "production" ]; then
        docker-compose -f docker-compose.production.yml ps
    else
        docker-compose ps
    fi
    
    echo -e "\n${GREEN}Service URLs:${NC}"
    if [ "$ENVIRONMENT" == "production" ]; then
        echo -e "  Main API: ${YELLOW}https://yourdomain.com/api/${NC}"
        echo -e "  Core Admin: ${YELLOW}https://yourdomain.com/admin/core/${NC}"
        echo -e "  User Admin: ${YELLOW}https://yourdomain.com/admin/users/${NC}"
        echo -e "  API Docs: ${YELLOW}https://yourdomain.com/docs/${NC}"
    else
        echo -e "  Core Service: ${YELLOW}http://localhost:8000${NC}"
        echo -e "  Notification Service: ${YELLOW}http://localhost:8001${NC}"
        echo -e "  User Management Service: ${YELLOW}http://localhost:8002${NC}"
        echo -e "  RabbitMQ Management: ${YELLOW}http://localhost:15672${NC}"
    fi
    
    echo -e "\n${GREEN}Useful commands:${NC}"
    echo -e "  View logs: ${YELLOW}docker-compose logs -f [service_name]${NC}"
    echo -e "  Stop services: ${YELLOW}docker-compose down${NC}"
    echo -e "  Restart service: ${YELLOW}docker-compose restart [service_name]${NC}"
    echo -e "  Execute command: ${YELLOW}docker-compose exec [service_name] [command]${NC}"
}

# Main deployment flow
main() {
    setup_environment
    build_images
    start_services
    wait_for_services
    create_superusers
    show_status
}

# Run main function
main