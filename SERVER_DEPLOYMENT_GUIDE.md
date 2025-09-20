# 🚀 Niged Ease Backend - Server Deployment Guide

## 🎯 Quick Start

```bash
# 1. Clone repository
git clone <your-repo-url>
cd back-end

# 2. Run automated deployment
./deploy-production.sh --domain yourdomain.com --email admin@yourdomain.com

# 3. Your backend is live! 🎉
```

---

## 📋 Prerequisites

### Server Requirements
- **OS**: Ubuntu 20.04+ / CentOS 8+ / Debian 11+
- **RAM**: Minimum 4GB (8GB+ recommended)
- **CPU**: 2+ cores
- **Storage**: 20GB+ SSD
- **Network**: Public IP with open ports 80, 443

### Software Requirements
- Docker 24.0+
- Docker Compose 2.0+
- Git
- Curl
- OpenSSL

---

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Nginx Proxy   │────│  Core Service   │────│   PostgreSQL    │
│   (Port 80/443) │    │   (Port 8000)   │    │   (Port 5432)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │              ┌─────────────────┐              │
         └──────────────│ Notification    │──────────────┘
                        │  Service (8001) │
                        └─────────────────┘
                                 │
                        ┌─────────────────┐
                        │ User Management │
                        │  Service (8002) │
                        └─────────────────┘
                                 │
                        ┌─────────────────┐
                        │   Redis Cache   │
                        │   (Port 6379)   │
                        └─────────────────┘
```

---

## 🔧 Manual Deployment Steps

### 1. Server Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo apt install docker-compose-plugin -y

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Install additional tools
sudo apt install git curl openssl certbot -y
```

### 2. Clone and Configure

```bash
# Clone repository
git clone <your-repo-url>
cd back-end

# Copy production environment template
cp .env.production .env

# Generate secure secrets
python3 -c "import secrets; print('CORE_SECRET_KEY=' + secrets.token_urlsafe(50))" >> .env
python3 -c "import secrets; print('NOTIFICATION_SECRET_KEY=' + secrets.token_urlsafe(50))" >> .env
python3 -c "import secrets; print('USER_MANAGEMENT_SECRET_KEY=' + secrets.token_urlsafe(50))" >> .env
python3 -c "import secrets; print('JWT_SECRET_KEY=' + secrets.token_urlsafe(50))" >> .env

# Edit configuration
nano .env
```

### 3. SSL Certificate Setup

```bash
# Option 1: Let's Encrypt (Recommended)
sudo certbot certonly --standalone -d yourdomain.com -d www.yourdomain.com
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem ssl/cert.pem
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem ssl/key.pem
sudo chown $USER:$USER ssl/*.pem

# Option 2: Self-signed (Development)
mkdir -p ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ssl/key.pem \
    -out ssl/cert.pem \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=yourdomain.com"
```

### 4. Deploy Services

```bash
# Build and start services
docker compose -f docker-compose.production.yml build
docker compose -f docker-compose.production.yml up -d

# Check service status
docker compose -f docker-compose.production.yml ps
docker compose -f docker-compose.production.yml logs -f
```

---

## ⚙️ Configuration

### Environment Variables (.env)

```env
# Domain & Security
DOMAIN=yourdomain.com
ALLOWED_HOSTS=yourdomain.com,www.yourdomain.com
CORS_ALLOWED_ORIGINS=https://yourdomain.com

# Database
DB_USER=niged_user
DB_PASSWORD=your_secure_password_here
POSTGRES_PASSWORD=your_postgres_password_here

# Email (Gmail App Password recommended)
EMAIL_HOST_USER=admin@yourdomain.com
EMAIL_HOST_PASSWORD=your_gmail_app_password

# Monitoring (optional)
SENTRY_DSN=https://your-sentry-dsn@sentry.io/project
```

### Service Ports

| Service | Internal Port | External Access |
|---------|---------------|-----------------|
| Nginx | 80, 443 | Public |
| Core Service | 8000 | Internal |
| Notification | 8001 | Internal |
| User Management | 8002 | Internal |
| PostgreSQL | 5432 | Internal |
| Redis | 6379 | Internal |
| RabbitMQ | 5672, 15672 | Internal |

---

## 🛡️ Security Features

### Network Security
- ✅ Internal Docker networks isolate services
- ✅ Database network separate from public network
- ✅ Only Nginx exposed to internet
- ✅ SSL/TLS encryption for all external traffic

### Application Security
- ✅ Non-root users in all containers
- ✅ Secret key rotation support
- ✅ Rate limiting on API endpoints
- ✅ CORS protection
- ✅ Security headers enabled

### Infrastructure Security
- ✅ Automated SSL certificate management
- ✅ Container resource limits
- ✅ Health checks and auto-restart
- ✅ Centralized logging

---

## 📊 Monitoring & Maintenance

### Health Checks

```bash
# Check all services
curl https://yourdomain.com/health

# Check individual services
docker compose -f docker-compose.production.yml ps
docker compose -f docker-compose.production.yml logs [service_name]
```

### Database Backup

```bash
# Manual backup
./scripts/backup.sh

# Automated backups (runs daily at 2 AM)
docker compose -f docker-compose.production.yml --profile backup up -d
```

### Log Management

```bash
# View service logs
docker compose logs -f core_service
docker compose logs -f nginx

# Log rotation is automatic (max 10MB per file, 5 files)
```

### Performance Monitoring

```bash
# Enable Prometheus monitoring
docker compose -f docker-compose.production.yml --profile monitoring up -d

# Access Prometheus dashboard
http://yourdomain.com:9090
```

---

## 🚨 Troubleshooting

### Common Issues

#### Services Won't Start
```bash
# Check Docker daemon
sudo systemctl status docker
sudo systemctl start docker

# Check resource usage
docker stats

# View detailed logs
docker compose logs --tail=100
```

#### SSL Certificate Issues
```bash
# Renew Let's Encrypt certificates
sudo certbot renew

# Test SSL configuration
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com
```

#### Database Connection Issues
```bash
# Check PostgreSQL logs
docker compose logs db

# Test database connection
docker compose exec db psql -U niged_user -d core_service_db -c "SELECT 1;"
```

#### High Memory Usage
```bash
# Check container resource usage
docker stats

# Restart specific service
docker compose restart core_service
```

### Performance Optimization

#### Scale Services
```bash
# Scale specific service
docker compose -f docker-compose.production.yml up -d --scale core_service=3
```

#### Database Optimization
```bash
# Access database for tuning
docker compose exec db psql -U niged_user

# Run VACUUM and ANALYZE
VACUUM ANALYZE;

# Check query performance
SELECT * FROM pg_stat_activity;
```

---

## 🔄 Updates & Maintenance

### Application Updates

```bash
# Pull latest code
git pull origin main

# Rebuild and restart services
docker compose -f docker-compose.production.yml build --no-cache
docker compose -f docker-compose.production.yml up -d

# Run migrations if needed
docker compose exec core_service python manage.py migrate
```

### System Updates

```bash
# Update server packages
sudo apt update && sudo apt upgrade -y

# Update Docker images
docker compose pull
docker compose up -d
```

### SSL Certificate Renewal

```bash
# Auto-renewal with cron
echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -

# Manual renewal
sudo certbot renew
sudo systemctl reload nginx
```

---

## 🏭 Production Checklist

### Pre-deployment
- [ ] Domain DNS points to server IP
- [ ] Firewall configured (ports 80, 443 open)
- [ ] SSL certificates generated
- [ ] Environment variables configured
- [ ] Database passwords changed from defaults
- [ ] Email configuration tested

### Post-deployment
- [ ] All services healthy and running
- [ ] HTTPS working correctly
- [ ] API endpoints responding
- [ ] Database migrations completed
- [ ] Backup scripts configured
- [ ] Monitoring enabled
- [ ] Log rotation configured

### Security Hardening
- [ ] Server firewall configured
- [ ] SSH key-based authentication
- [ ] Regular security updates enabled
- [ ] Non-root user for deployment
- [ ] Database access restricted
- [ ] Rate limiting configured

---

## 📞 Support & Maintenance

### Service Management Commands

```bash
# Start services
docker compose -f docker-compose.production.yml up -d

# Stop services
docker compose -f docker-compose.production.yml down

# Restart specific service
docker compose -f docker-compose.production.yml restart core_service

# View logs
docker compose -f docker-compose.production.yml logs -f [service]

# Scale service
docker compose -f docker-compose.production.yml up -d --scale core_service=2

# Update service
docker compose -f docker-compose.production.yml up -d --no-deps core_service
```

### Backup & Restore

```bash
# Create backup
./scripts/backup.sh

# Restore from backup
./scripts/restore.sh core_service_db /backups/core_service_db_20231201_120000.sql.gz

# List backups
ls -la backups/
```

### Emergency Procedures

#### Complete System Restart
```bash
docker compose -f docker-compose.production.yml down
docker system prune -f
docker compose -f docker-compose.production.yml up -d
```

#### Database Recovery
```bash
# Stop services
docker compose stop core_service notification_service user_management_service

# Restore database
./scripts/restore.sh core_service_db /backups/latest_backup.sql.gz

# Start services
docker compose up -d
```

---

## 🎉 Success!

Your Niged Ease backend is now successfully deployed and ready for production use!

### Next Steps
1. Configure your frontend application to point to your API
2. Set up monitoring and alerting
3. Configure automated backups to cloud storage
4. Set up CI/CD pipeline for automated deployments

### Support
- Check logs: `docker compose logs -f`
- Report issues: Create GitHub issue
- Documentation: Review this guide

**Happy deploying! 🚀**