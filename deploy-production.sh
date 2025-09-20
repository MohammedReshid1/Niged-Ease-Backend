#!/bin/bash

# ===========================================
# NIGED EASE BACKEND - PRODUCTION DEPLOYMENT
# ===========================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAIN=""
EMAIL=""
ENVIRONMENT="production"
COMPOSE_FILE="docker-compose.production.yml"
ENV_FILE=".env"

# Logging
LOG_DIR="./logs/deployment"
mkdir -p "$LOG_DIR"
DEPLOY_LOG="$LOG_DIR/deploy-$(date +%Y%m%d-%H%M%S).log"

# Function to log messages
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] $level: $message" | tee -a "$DEPLOY_LOG"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "SUCCESS" "$@"; }

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to generate secure secret key
generate_secret_key() {
    python3 -c "import secrets; print(secrets.token_urlsafe(50))"
}

# Function to display banner
show_banner() {
    echo -e "${GREEN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                NIGED EASE BACKEND DEPLOYMENT                 ║
║                   Production Environment                     ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking deployment prerequisites..."
    
    local missing_deps=()
    
    if ! command_exists docker; then
        missing_deps+=("docker")
    fi
    
    if ! command_exists docker-compose || ! command_exists docker compose; then
        missing_deps+=("docker-compose")
    fi
    
    if ! command_exists git; then
        missing_deps+=("git")
    fi
    
    if ! command_exists curl; then
        missing_deps+=("curl")
    fi
    
    if ! command_exists openssl; then
        missing_deps+=("openssl")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install the missing dependencies and retry."
        exit 1
    fi
    
    # Check Docker daemon
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running. Please start Docker and retry."
        exit 1
    fi
    
    log_success "All prerequisites check passed!"
}

# Function to setup environment
setup_environment() {
    log_info "Setting up production environment..."
    
    # Prompt for domain if not set
    if [ -z "$DOMAIN" ]; then
        echo -n "Enter your domain name (e.g., yourdomain.com): "
        read -r DOMAIN
    fi
    
    if [ -z "$DOMAIN" ]; then
        log_error "Domain name is required for production deployment"
        exit 1
    fi
    
    # Prompt for email if not set
    if [ -z "$EMAIL" ]; then
        echo -n "Enter your email for SSL certificates: "
        read -r EMAIL
    fi
    
    if [ -z "$EMAIL" ]; then
        log_error "Email is required for SSL certificate generation"
        exit 1
    fi
    
    # Create .env file from template
    if [ ! -f "$ENV_FILE" ]; then
        log_info "Creating production environment file..."
        cp .env.production "$ENV_FILE"
        
        # Generate secure secrets
        local core_secret=$(generate_secret_key)
        local notification_secret=$(generate_secret_key)
        local user_secret=$(generate_secret_key)
        local jwt_secret=$(generate_secret_key)
        local db_password=$(generate_secret_key | head -c 32)
        local rabbitmq_password=$(generate_secret_key | head -c 32)
        local redis_password=$(generate_secret_key | head -c 32)
        
        # Update .env with generated values and user input
        sed -i.bak \
            -e "s/yourdomain.com/$DOMAIN/g" \
            -e "s/CHANGE_ME_CORE_SECRET_KEY_50_CHARS_MINIMUM/$core_secret/" \
            -e "s/CHANGE_ME_NOTIFICATION_SECRET_KEY_50_CHARS_MINIMUM/$notification_secret/" \
            -e "s/CHANGE_ME_USER_MANAGEMENT_SECRET_KEY_50_CHARS_MINIMUM/$user_secret/" \
            -e "s/CHANGE_ME_JWT_SECRET_KEY_50_CHARS_MINIMUM/$jwt_secret/" \
            -e "s/CHANGE_ME_STRONG_PASSWORD_HERE/$db_password/" \
            -e "s/CHANGE_ME_RABBITMQ_PASSWORD/$rabbitmq_password/" \
            -e "s/your-production-email@yourdomain.com/admin@$DOMAIN/" \
            "$ENV_FILE"
        
        # Add Redis password
        echo "" >> "$ENV_FILE"
        echo "REDIS_PASSWORD=$redis_password" >> "$ENV_FILE"
        
        log_success "Environment file created with secure generated secrets"
        log_warn "Please review and update $ENV_FILE with your specific values:"
        log_warn "- EMAIL_HOST_PASSWORD (Gmail app password)"
        log_warn "- AWS credentials (if using S3 backups)"
        log_warn "- SENTRY_DSN (if using error monitoring)"
    fi
    
    # Create necessary directories
    local directories=(
        "ssl"
        "logs"
        "backups"
        "scripts"
        "nginx"
        "monitoring"
        "rabbitmq"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        log_info "Created directory: $dir"
    done
}

# Function to setup SSL certificates
setup_ssl() {
    log_info "Setting up SSL certificates..."
    
    if [ ! -f "ssl/cert.pem" ] || [ ! -f "ssl/key.pem" ]; then
        log_info "SSL certificates not found. Setting up Let's Encrypt..."
        
        # Install certbot if not available
        if ! command_exists certbot; then
            log_warn "Certbot not found. Please install it manually:"
            log_warn "Ubuntu/Debian: sudo apt install certbot"
            log_warn "CentOS/RHEL: sudo yum install certbot"
            log_warn "macOS: brew install certbot"
            echo -n "Press Enter after installing certbot..."
            read -r
        fi
        
        # Stop nginx if running to free port 80
        docker-compose -f "$COMPOSE_FILE" stop nginx 2>/dev/null || true
        
        # Generate certificate
        log_info "Generating SSL certificate for $DOMAIN..."
        sudo certbot certonly \
            --standalone \
            --agree-tos \
            --no-eff-email \
            --email "$EMAIL" \
            -d "$DOMAIN" \
            -d "www.$DOMAIN" || {
                log_error "Failed to generate SSL certificate"
                log_info "Creating self-signed certificate for testing..."
                openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                    -keyout ssl/key.pem \
                    -out ssl/cert.pem \
                    -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"
        }
        
        # Copy certificates if Let's Encrypt succeeded
        if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
            sudo cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ssl/cert.pem
            sudo cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ssl/key.pem
            sudo chown "$USER:$USER" ssl/cert.pem ssl/key.pem
            log_success "SSL certificates installed successfully"
        fi
    else
        log_success "SSL certificates already exist"
    fi
}

# Function to create Nginx configuration
create_nginx_config() {
    log_info "Creating production Nginx configuration..."
    
    cat > nginx/nginx.production.conf << EOF
# Nginx Production Configuration for Niged Ease Backend
worker_processes \${NGINX_WORKER_PROCESSES};
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 2048;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging format
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for" '
                    'rt=\$request_time uct="\$upstream_connect_time" '
                    'uht="\$upstream_header_time" urt="\$upstream_response_time"';

    access_log /var/log/nginx/access.log main;

    # Performance settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/rss+xml
        application/atom+xml
        image/svg+xml;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone \$binary_remote_addr zone=auth:10m rate=5r/s;

    # Upstream definitions
    upstream core_service {
        least_conn;
        server core_service:8000 max_fails=3 fail_timeout=30s;
        keepalive 32;
    }

    upstream notification_service {
        least_conn;
        server notification_service:8001 max_fails=3 fail_timeout=30s;
        keepalive 32;
    }

    upstream user_management_service {
        least_conn;
        server user_management_service:8002 max_fails=3 fail_timeout=30s;
        keepalive 32;
    }

    # HTTP to HTTPS redirect
    server {
        listen 80;
        server_name $DOMAIN www.$DOMAIN;
        return 301 https://\$server_name\$request_uri;
    }

    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name $DOMAIN www.$DOMAIN;

        # SSL configuration
        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;

        # Static files with caching
        location /static/ {
            alias /static/;
            expires 30d;
            add_header Cache-Control "public, immutable";
            add_header X-Content-Type-Options nosniff;
            access_log off;
        }

        location /media/ {
            alias /media/;
            expires 7d;
            add_header Cache-Control "public";
            access_log off;
        }

        # Health check endpoint
        location /health {
            access_log off;
            return 200 "healthy\\n";
            add_header Content-Type text/plain;
        }

        # Core service API
        location /api/core/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://core_service/api/;
            include proxy_params;
        }

        # Notification service API
        location /api/notifications/ {
            limit_req zone=api burst=10 nodelay;
            proxy_pass http://notification_service/api/;
            include proxy_params;
        }

        # User management service API
        location /api/users/ {
            limit_req zone=api burst=15 nodelay;
            proxy_pass http://user_management_service/api/;
            include proxy_params;
        }

        # Authentication endpoints with strict rate limiting
        location /api/auth/ {
            limit_req zone=auth burst=5 nodelay;
            proxy_pass http://user_management_service/api/auth/;
            include proxy_params;
        }

        # Admin interfaces (restrict in production)
        location /admin/ {
            # Uncomment to restrict by IP
            # allow 192.168.1.0/24;
            # deny all;
            
            location /admin/core/ {
                proxy_pass http://core_service/admin/;
                include proxy_params;
            }

            location /admin/users/ {
                proxy_pass http://user_management_service/admin/;
                include proxy_params;
            }
        }

        # API documentation
        location /docs/ {
            proxy_pass http://core_service/docs/;
            include proxy_params;
        }

        # Default location
        location / {
            return 404;
        }
    }
}
EOF

    # Create proxy_params file
    cat > nginx/proxy_params << 'EOF'
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_set_header Host $http_host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-Host $server_name;
proxy_connect_timeout 60s;
proxy_send_timeout 60s;
proxy_read_timeout 60s;
proxy_buffering on;
proxy_buffer_size 8k;
proxy_buffers 8 8k;
proxy_busy_buffers_size 16k;
EOF

    log_success "Nginx configuration created"
}

# Function to create backup scripts
create_backup_scripts() {
    log_info "Creating backup scripts..."
    
    cat > scripts/backup.sh << 'EOF'
#!/bin/bash

# Database backup script
set -e

BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup all databases
DATABASES=("core_service_db" "notification_service_db" "user_management_db")

for db in "${DATABASES[@]}"; do
    echo "Backing up database: $db"
    pg_dump -h db -U "$DB_USER" -d "$db" | gzip > "$BACKUP_DIR/${db}_${DATE}.sql.gz"
done

# Create combined backup
echo "Creating combined backup..."
pg_dumpall -h db -U "$DB_USER" | gzip > "$BACKUP_DIR/all_databases_${DATE}.sql.gz"

# Upload to S3 if configured
if [ -n "${AWS_ACCESS_KEY_ID:-}" ] && [ -n "${BACKUP_S3_BUCKET:-}" ]; then
    echo "Uploading backups to S3..."
    aws s3 cp "$BACKUP_DIR" "s3://$BACKUP_S3_BUCKET/$(date +%Y/%m/%d)/" --recursive --storage-class STANDARD_IA
fi

# Cleanup old backups
echo "Cleaning up old backups..."
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete

echo "Backup completed successfully at $(date)"
EOF

    chmod +x scripts/backup.sh

    # Create restore script
    cat > scripts/restore.sh << 'EOF'
#!/bin/bash

# Database restore script
set -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <database_name> <backup_file>"
    exit 1
fi

DB_NAME="$1"
BACKUP_FILE="$2"

echo "Restoring database: $DB_NAME from $BACKUP_FILE"

# Stop services that use the database
docker-compose -f docker-compose.production.yml stop core_service notification_service user_management_service

# Drop and recreate database
psql -h db -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;"
psql -h db -U "$DB_USER" -d postgres -c "CREATE DATABASE $DB_NAME;"

# Restore database
if [[ "$BACKUP_FILE" == *.gz ]]; then
    gunzip -c "$BACKUP_FILE" | psql -h db -U "$DB_USER" -d "$DB_NAME"
else
    psql -h db -U "$DB_USER" -d "$DB_NAME" < "$BACKUP_FILE"
fi

# Restart services
docker-compose -f docker-compose.production.yml up -d

echo "Restore completed successfully"
EOF

    chmod +x scripts/restore.sh
    log_success "Backup scripts created"
}

# Function to create monitoring configuration
create_monitoring() {
    log_info "Creating monitoring configuration..."
    
    cat > monitoring/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files: []

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx:80']
    metrics_path: /metrics
    scrape_interval: 30s

  - job_name: 'postgres'
    static_configs:
      - targets: ['db:5432']
    scrape_interval: 30s

  - job_name: 'rabbitmq'
    static_configs:
      - targets: ['rabbitmq:15692']
    scrape_interval: 30s
EOF

    log_success "Monitoring configuration created"
}

# Function to build and deploy
deploy() {
    log_info "Starting production deployment..."
    
    # Pull latest changes
    if [ -d ".git" ]; then
        log_info "Pulling latest changes from git..."
        git pull origin main || log_warn "Git pull failed, continuing with local version"
    fi
    
    # Build images
    log_info "Building production Docker images..."
    docker-compose -f "$COMPOSE_FILE" build --no-cache || {
        log_error "Failed to build Docker images"
        exit 1
    }
    
    # Start services
    log_info "Starting production services..."
    docker-compose -f "$COMPOSE_FILE" up -d || {
        log_error "Failed to start services"
        exit 1
    }
    
    # Wait for services to be healthy
    log_info "Waiting for services to be healthy..."
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        local healthy_services=0
        local total_services=4  # db, nginx, core_service, notification_service, user_management_service
        
        if docker-compose -f "$COMPOSE_FILE" ps | grep -q "healthy"; then
            healthy_services=$(docker-compose -f "$COMPOSE_FILE" ps | grep -c "healthy" || echo "0")
        fi
        
        if [ "$healthy_services" -ge 3 ]; then  # Allow some services to not have health checks
            log_success "Services are healthy!"
            break
        fi
        
        log_info "Attempt $attempt/$max_attempts: $healthy_services/$total_services services healthy"
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_warn "Some services may not be fully healthy, checking logs..."
        docker-compose -f "$COMPOSE_FILE" logs --tail=20
    fi
}

# Function to create systemd service
create_systemd_service() {
    if command_exists systemctl; then
        log_info "Creating systemd service..."
        
        local service_file="/etc/systemd/system/niged-ease.service"
        local working_dir=$(pwd)
        
        sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=Niged Ease Backend Services
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$working_dir
ExecStart=/usr/bin/docker-compose -f $COMPOSE_FILE up -d
ExecStop=/usr/bin/docker-compose -f $COMPOSE_FILE down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
        
        sudo systemctl daemon-reload
        sudo systemctl enable niged-ease.service
        
        log_success "Systemd service created and enabled"
        log_info "Use 'sudo systemctl start niged-ease' to start services"
        log_info "Use 'sudo systemctl stop niged-ease' to stop services"
    fi
}

# Function to show deployment summary
show_summary() {
    local nginx_status=$(docker-compose -f "$COMPOSE_FILE" ps nginx | grep -c "Up" || echo "0")
    
    echo -e "${GREEN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                   DEPLOYMENT SUCCESSFUL!                    ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    log_success "Niged Ease Backend deployed successfully!"
    echo
    log_info "Service URLs:"
    if [ "$nginx_status" -gt 0 ]; then
        log_info "  Main API: https://$DOMAIN"
        log_info "  Core Service Admin: https://$DOMAIN/admin/core/"
        log_info "  User Management Admin: https://$DOMAIN/admin/users/"
        log_info "  API Documentation: https://$DOMAIN/docs/"
    else
        log_warn "  Nginx not running, check individual service ports"
        log_info "  Core Service: http://localhost:8000"
        log_info "  Notification Service: http://localhost:8001"
        log_info "  User Management: http://localhost:8002"
    fi
    
    echo
    log_info "Management Commands:"
    log_info "  View logs: docker-compose -f $COMPOSE_FILE logs -f [service]"
    log_info "  Restart service: docker-compose -f $COMPOSE_FILE restart [service]"
    log_info "  Stop all: docker-compose -f $COMPOSE_FILE down"
    log_info "  Backup database: ./scripts/backup.sh"
    
    echo
    log_info "Important Files:"
    log_info "  Environment: $ENV_FILE"
    log_info "  SSL Certificates: ssl/"
    log_info "  Logs: logs/"
    log_info "  Backups: backups/"
    log_info "  Deployment Log: $DEPLOY_LOG"
    
    echo
    log_warn "Next Steps:"
    log_warn "1. Review and update $ENV_FILE with your specific values"
    log_warn "2. Set up SSL certificate auto-renewal"
    log_warn "3. Configure monitoring and alerting"
    log_warn "4. Set up regular backups"
    log_warn "5. Configure firewall rules"
}

# Main execution
main() {
    show_banner
    log_info "Starting production deployment process..."
    
    check_prerequisites
    setup_environment
    setup_ssl
    create_nginx_config
    create_backup_scripts
    create_monitoring
    deploy
    create_systemd_service
    show_summary
    
    log_success "Deployment completed successfully!"
}

# Handle script arguments
case "${1:-}" in
    --domain)
        DOMAIN="$2"
        shift 2
        ;;
    --email)
        EMAIL="$2"
        shift 2
        ;;
    --help)
        echo "Usage: $0 [--domain DOMAIN] [--email EMAIL]"
        echo "  --domain DOMAIN    Set domain name for deployment"
        echo "  --email EMAIL      Set email for SSL certificates"
        echo "  --help            Show this help message"
        exit 0
        ;;
esac

# Run main function
main "$@"