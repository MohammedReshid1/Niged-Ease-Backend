# Niged Ease Backend Deployment Guide

## Quick Start

### Development Deployment
```bash
# 1. Run the deployment script
./deploy.sh development

# 2. Access services at:
# - Core Service: http://localhost:8000
# - Notification Service: http://localhost:8001
# - User Management Service: http://localhost:8002
# - RabbitMQ Management: http://localhost:15672 (guest/guest)
```

### Production Deployment
```bash
# 1. Configure environment
cp .env.production .env
# Edit .env with your production values

# 2. Add SSL certificates
mkdir ssl
# Add cert.pem and key.pem to ssl directory

# 3. Run deployment
./deploy.sh production
```

## Prerequisites

- Docker & Docker Compose installed
- PostgreSQL (via Docker)
- Python 3.10+ (for local development)
- SSL certificates (for production)

## Project Structure

```
├── core_service/           # Main business logic service
├── notification_service/   # Email/SMS notification service
├── user_management_service/# Authentication & user management
├── docker-compose.yml      # Development configuration
├── docker-compose.production.yml # Production configuration
├── nginx.conf             # Development nginx config
├── nginx.production.conf  # Production nginx config with SSL
├── deploy.sh             # Automated deployment script
├── stop.sh              # Stop all services
└── .env files           # Environment configurations
```

## Environment Configuration

### Development (.env files created automatically)
- Each service has its own .env file with default development settings
- Uses local PostgreSQL database
- Debug mode enabled
- CORS configured for localhost:3000

### Production (.env.production)
Required configurations:
```bash
# Security Keys (auto-generated if using deploy.sh)
CORE_SECRET_KEY=<generated>
NOTIFICATION_SECRET_KEY=<generated>
USER_MANAGEMENT_SECRET_KEY=<generated>
JWT_SECRET_KEY=<generated>

# Database
DB_HOST=your-db-host
DB_USER=your-db-user
DB_PASSWORD=your-db-password

# Email
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=app-specific-password

# Domain
ALLOWED_HOSTS=yourdomain.com,www.yourdomain.com
CORS_ALLOWED_ORIGINS=https://yourdomain.com
```

## Services Overview

### 1. Core Service (Port 8000)
- Sales & Purchase management
- Inventory management
- Financial tracking
- Reporting & Analytics
- Product management

### 2. Notification Service (Port 8001)
- Email notifications
- SMS notifications (when configured)
- Notification queuing via RabbitMQ

### 3. User Management Service (Port 8002)
- User authentication (JWT)
- Role-based access control
- User profiles
- Activity logging

## Deployment Commands

### Start Services
```bash
# Development
./deploy.sh development

# Production
./deploy.sh production
```

### Stop Services
```bash
# Development
./stop.sh

# Production
./stop.sh production
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f core_service
```

### Database Management
```bash
# Run migrations
docker-compose exec core_service python manage.py migrate

# Create superuser
docker-compose exec core_service python manage.py createsuperuser

# Database shell
docker-compose exec db psql -U postgres
```

### Service Management
```bash
# Restart a service
docker-compose restart core_service

# Rebuild a service
docker-compose build core_service
docker-compose up -d core_service

# Execute command in service
docker-compose exec core_service python manage.py shell
```

## Production Deployment Steps

### 1. Server Setup
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo apt install docker-compose -y
```

### 2. Clone Repository
```bash
git clone <repository-url>
cd niged-ease-backend
```

### 3. Configure Environment
```bash
# Copy and edit production environment
cp .env.production .env
nano .env  # Update with your production values
```

### 4. SSL Setup
```bash
# Create SSL directory
mkdir ssl

# Option 1: Use Let's Encrypt
sudo apt install certbot
sudo certbot certonly --standalone -d yourdomain.com
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem ssl/cert.pem
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem ssl/key.pem

# Option 2: Use your own certificates
cp your-certificate.pem ssl/cert.pem
cp your-private-key.pem ssl/key.pem
```

### 5. Deploy
```bash
# Run deployment script
./deploy.sh production

# Create superusers when prompted
```

### 6. Setup Firewall
```bash
# Allow necessary ports
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp
sudo ufw enable
```

## Monitoring & Maintenance

### Health Checks
```bash
# Check service health
curl http://localhost/health

# Check Docker containers
docker ps
docker-compose ps
```

### Backup Database
```bash
# Backup all databases
docker-compose exec db pg_dumpall -U postgres > backup_$(date +%Y%m%d).sql

# Restore database
docker-compose exec -T db psql -U postgres < backup.sql
```

### Update Services
```bash
# Pull latest code
git pull origin main

# Rebuild and restart
docker-compose build
docker-compose up -d
```

## Troubleshooting

### Common Issues

1. **Port already in use**
```bash
# Find process using port
sudo lsof -i :8000
# Kill process
sudo kill -9 <PID>
```

2. **Database connection errors**
```bash
# Check database is running
docker-compose ps db
# Check database logs
docker-compose logs db
```

3. **Permission errors**
```bash
# Fix permissions
sudo chown -R $USER:$USER .
chmod +x deploy.sh stop.sh
```

4. **Service not starting**
```bash
# Check logs
docker-compose logs <service_name>
# Rebuild service
docker-compose build --no-cache <service_name>
```

## Security Considerations

### Production Checklist
- [ ] Change all default secret keys
- [ ] Use strong database passwords
- [ ] Configure SSL certificates
- [ ] Set up firewall rules
- [ ] Restrict admin panel access
- [ ] Enable rate limiting
- [ ] Regular security updates
- [ ] Implement backup strategy
- [ ] Monitor logs for suspicious activity
- [ ] Use environment-specific settings

### Environment Variables Security
- Never commit .env files to git
- Use strong, unique secret keys
- Rotate keys periodically
- Use secrets management service for production

## API Documentation

Once deployed, API documentation is available at:
- Development: http://localhost:8000/docs/
- Production: https://yourdomain.com/docs/

## Support

For issues or questions:
1. Check service logs: `docker-compose logs -f`
2. Review this documentation
3. Check database connectivity
4. Verify environment variables
5. Ensure all prerequisites are installed

## Performance Optimization

### Docker Optimization
```yaml
# In docker-compose.production.yml
# Adjust worker counts based on server resources
gunicorn --workers 4 --threads 2
```

### Database Optimization
- Configure connection pooling
- Set appropriate cache sizes
- Regular VACUUM and ANALYZE
- Index optimization

### Nginx Optimization
- Enable gzip compression
- Configure caching headers
- Implement rate limiting
- Use HTTP/2

## Scaling Considerations

### Horizontal Scaling
- Use Docker Swarm or Kubernetes
- Implement load balancing
- Use external PostgreSQL cluster
- Configure Redis for caching

### Vertical Scaling
- Increase Docker container resources
- Optimize database queries
- Implement caching strategies
- Use CDN for static files