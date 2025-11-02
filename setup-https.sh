#!/bin/bash

# HTTPS Setup Script for EC2 Backend
# This script automates HTTPS setup with Let's Encrypt

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   HTTPS Setup for Timesheet Backend${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
   echo -e "${RED}Please run as normal user (not root). Use sudo when prompted.${NC}"
   exit 1
fi

# Get domain name
read -p "Enter your domain name (e.g., api.yourdomain.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Domain name is required!${NC}"
    exit 1
fi

# Get email for Let's Encrypt
read -p "Enter your email for Let's Encrypt notifications: " EMAIL
if [ -z "$EMAIL" ]; then
    echo -e "${RED}Email is required!${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Setting up HTTPS for: ${DOMAIN}${NC}"
echo ""

# Step 1: Install Nginx and Certbot
echo -e "${GREEN}Step 1: Installing Nginx and Certbot...${NC}"
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx

# Step 2: Create Nginx configuration
echo -e "${GREEN}Step 2: Creating Nginx configuration...${NC}"

sudo tee /etc/nginx/sites-available/timesheet-backend > /dev/null <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    # SSL certificates (will be added by certbot)
    # ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # CORS headers
    add_header 'Access-Control-Allow-Origin' '*' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, PATCH, OPTIONS' always;
    add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization, X-Requested-With' always;

    # Proxy settings
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-Port \$server_port;

    # Increase timeouts
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;

    # Auth service (port 3002)
    location /auth-service/ {
        proxy_pass http://localhost:3002/auth-service/;
        proxy_http_version 1.1;
    }

    # Save service (port 3000)
    location /save-service/ {
        proxy_pass http://localhost:3000/save-service/;
        proxy_http_version 1.1;
    }

    # Submit service (port 3001)
    location /submit-service/ {
        proxy_pass http://localhost:3001/submit-service/;
        proxy_http_version 1.1;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\\n";
        add_header Content-Type text/plain;
    }

    # Default location
    location / {
        return 404;
    }
}
EOF

# Enable site
sudo ln -sf /etc/nginx/sites-available/timesheet-backend /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
echo -e "${GREEN}Testing Nginx configuration...${NC}"
if sudo nginx -t; then
    sudo systemctl reload nginx
    echo -e "${GREEN}✓ Nginx configuration is valid${NC}"
else
    echo -e "${RED}✗ Nginx configuration has errors${NC}"
    exit 1
fi

# Step 3: Obtain SSL certificate
echo ""
echo -e "${GREEN}Step 3: Obtaining SSL certificate from Let's Encrypt...${NC}"
echo -e "${YELLOW}Make sure:${NC}"
echo -e "${YELLOW}  1. Domain ${DOMAIN} points to this server's IP${NC}"
echo -e "${YELLOW}  2. Port 80 is open in EC2 Security Group${NC}"
echo ""
read -p "Press Enter to continue..."

sudo certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos --email ${EMAIL} --redirect

# Step 4: Verify setup
echo ""
echo -e "${GREEN}Step 4: Verifying HTTPS setup...${NC}"

if curl -s https://${DOMAIN}/health > /dev/null; then
    echo -e "${GREEN}✓ HTTPS is working!${NC}"
else
    echo -e "${YELLOW}⚠ HTTPS test failed. Check logs: sudo tail -f /var/log/nginx/error.log${NC}"
fi

# Step 5: Test auto-renewal
echo ""
echo -e "${GREEN}Step 5: Testing certificate auto-renewal...${NC}"
sudo certbot renew --dry-run

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Update AWS Amplify environment variables:"
echo "   VITE_AUTH_SERVICE_URL=https://${DOMAIN}"
echo "   VITE_BACKEND_URL=https://${DOMAIN}"
echo ""
echo "2. Test your endpoints:"
echo "   curl https://${DOMAIN}/health"
echo "   curl https://${DOMAIN}/auth-service/health"
echo ""
echo -e "${GREEN}Your backend is now accessible over HTTPS! 🎉${NC}"

