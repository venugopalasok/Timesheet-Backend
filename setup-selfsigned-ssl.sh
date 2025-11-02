#!/bin/bash

# Self-Signed SSL Certificate Setup Script
# This script sets up HTTPS with a self-signed certificate for EC2 backend

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Self-Signed SSL Certificate Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Get EC2 IP address
EC2_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "13.201.189.218")
echo -e "${BLUE}Detected EC2 IP: ${EC2_IP}${NC}"
read -p "Press Enter to use this IP, or type a different IP: " CUSTOM_IP
if [ ! -z "$CUSTOM_IP" ]; then
    EC2_IP=$CUSTOM_IP
fi

echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: Self-signed certificates will show browser warnings${NC}"
echo -e "${YELLOW}   Users will need to accept the certificate manually${NC}"
echo ""
read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Step 1: Check for port conflicts
echo ""
echo -e "${GREEN}Step 1: Checking for port conflicts...${NC}"

PORT_80_IN_USE=$(sudo lsof -i :80 2>/dev/null | grep LISTEN || true)
PORT_443_IN_USE=$(sudo lsof -i :443 2>/dev/null | grep LISTEN || true)

if [ ! -z "$PORT_80_IN_USE" ]; then
    echo -e "${YELLOW}⚠️  Port 80 is already in use:${NC}"
    echo "$PORT_80_IN_USE"
    echo ""
    
    # Check if it's Docker api-gateway
    if docker ps | grep -q api-gateway; then
        echo -e "${YELLOW}Detected Docker api-gateway container running${NC}"
        read -p "Stop Docker api-gateway to free port 80? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}Stopping Docker api-gateway...${NC}"
            docker stop api-gateway 2>/dev/null || docker-compose stop api-gateway || true
            sleep 2
        else
            echo -e "${RED}Cannot proceed. Port 80 must be available.${NC}"
            echo -e "${YELLOW}You can manually stop the service or configure Nginx to use a different port.${NC}"
            exit 1
        fi
    fi
    
    # Check if it's system Nginx
    if systemctl is-active --quiet nginx 2>/dev/null; then
        echo -e "${YELLOW}System Nginx is already running${NC}"
        read -p "Stop system Nginx and restart with new config? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo systemctl stop nginx
            sleep 2
        fi
    fi
    
    # Verify port is free now
    if sudo lsof -i :80 2>/dev/null | grep -q LISTEN; then
        echo -e "${RED}Port 80 is still in use. Please stop the service manually:${NC}"
        sudo lsof -i :80
        exit 1
    fi
fi

if [ ! -z "$PORT_443_IN_USE" ]; then
    echo -e "${YELLOW}⚠️  Port 443 is already in use:${NC}"
    echo "$PORT_443_IN_USE"
    read -p "Continue anyway? This may cause conflicts. (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Step 2: Install Nginx
echo ""
echo -e "${GREEN}Step 2: Installing Nginx...${NC}"
sudo apt update
sudo apt install -y nginx

# Ensure Nginx is stopped before we configure it
sudo systemctl stop nginx 2>/dev/null || true

# Step 3: Create SSL directory
echo -e "${GREEN}Step 3: Creating SSL certificate directory...${NC}"
sudo mkdir -p /etc/nginx/ssl

# Step 4: Generate self-signed certificate
echo -e "${GREEN}Step 4: Generating self-signed SSL certificate...${NC}"
echo -e "${YELLOW}Generating certificate for: ${EC2_IP}${NC}"

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/selfsigned.key \
  -out /etc/nginx/ssl/selfsigned.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=${EC2_IP}"

# Set proper permissions
sudo chmod 600 /etc/nginx/ssl/selfsigned.key
sudo chmod 644 /etc/nginx/ssl/selfsigned.crt

echo -e "${GREEN}✓ Certificate generated${NC}"

# Step 5: Create Nginx configuration
echo ""
echo -e "${GREEN}Step 5: Creating Nginx configuration...${NC}"

sudo tee /etc/nginx/sites-available/timesheet-backend > /dev/null <<EOF
# HTTP server - redirect to HTTPS
server {
    listen 80;
    server_name ${EC2_IP};

    # Redirect all HTTP traffic to HTTPS
    return 301 https://\$server_name\$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name ${EC2_IP};

    # SSL Certificate paths
    ssl_certificate /etc/nginx/ssl/selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/selfsigned.key;

    # SSL Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # CORS headers
    add_header 'Access-Control-Allow-Origin' '*' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, PATCH, OPTIONS' always;
    add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization, X-Requested-With' always;
    add_header 'Access-Control-Max-Age' '3600' always;

    # Handle preflight requests
    if (\$request_method = 'OPTIONS') {
        add_header 'Access-Control-Allow-Origin' '*';
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, PATCH, OPTIONS';
        add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization, X-Requested-With';
        add_header 'Access-Control-Max-Age' '3600';
        add_header 'Content-Type' 'text/plain; charset=utf-8';
        add_header 'Content-Length' 0;
        return 204;
    }

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

# Step 6: Test Nginx configuration
echo ""
echo -e "${GREEN}Step 6: Testing Nginx configuration...${NC}"
if sudo nginx -t; then
    echo -e "${GREEN}✓ Nginx configuration is valid${NC}"
    sudo systemctl reload nginx
    echo -e "${GREEN}✓ Nginx reloaded${NC}"
else
    echo -e "${RED}✗ Nginx configuration has errors${NC}"
    exit 1
fi

# Step 7: Start Nginx
echo ""
echo -e "${GREEN}Step 7: Starting Nginx service...${NC}"
sudo systemctl start nginx
sudo systemctl enable nginx
sleep 2

# Step 8: Verify setup
echo ""
echo -e "${GREEN}Step 8: Verifying HTTPS setup...${NC}"

sleep 2

if curl -k -s https://${EC2_IP}/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ HTTPS is working!${NC}"
else
    echo -e "${YELLOW}⚠ HTTPS test failed. Check if services are running:${NC}"
    echo -e "${YELLOW}   docker ps${NC}"
    echo -e "${YELLOW}   sudo tail -f /var/log/nginx/error.log${NC}"
fi

# Display summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Your backend is now accessible at:${NC}"
echo -e "${YELLOW}   https://${EC2_IP}${NC}"
echo ""
echo -e "${YELLOW}⚠️  Important Notes:${NC}"
echo -e "${YELLOW}1. Browsers will show a security warning (normal for self-signed)${NC}"
echo -e "${YELLOW}2. Users must click 'Advanced' → 'Proceed to site'${NC}"
echo -e "${YELLOW}3. Make sure EC2 Security Group allows port 443${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Update AWS Amplify environment variables:"
echo "   VITE_AUTH_SERVICE_URL=https://${EC2_IP}"
echo "   VITE_BACKEND_URL=https://${EC2_IP}"
echo ""
echo "2. Test your endpoints:"
echo "   curl -k https://${EC2_IP}/health"
echo "   curl -k https://${EC2_IP}/auth-service/health"
echo ""
echo -e "${GREEN}Your backend is now accessible over HTTPS! 🎉${NC}"

