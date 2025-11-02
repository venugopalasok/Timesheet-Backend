#!/bin/bash

# Quick fix script to regenerate the Nginx config without the problematic if statement

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Fixing Nginx configuration...${NC}"

# Get EC2 IP
EC2_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "13.201.189.218")
echo -e "${YELLOW}Using IP: ${EC2_IP}${NC}"

# Create fixed config
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

    # Handle OPTIONS preflight requests
    if (\$request_method = 'OPTIONS') {
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, PATCH, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization, X-Requested-With' always;
        add_header 'Access-Control-Max-Age' '3600' always;
        add_header 'Content-Type' 'text/plain charset=UTF-8';
        add_header 'Content-Length' 0;
        return 204;
    }

    # CORS headers (applied to all responses)
    add_header 'Access-Control-Allow-Origin' '*' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, PATCH, OPTIONS' always;
    add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization, X-Requested-With' always;
    add_header 'Access-Control-Max-Age' '3600' always;

    # Auth service
    location /auth-service/ {
        proxy_pass http://localhost:3002/auth-service/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Save service
    location /save-service/ {
        proxy_pass http://localhost:3000/save-service/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Submit service
    location /submit-service/ {
        proxy_pass http://localhost:3001/submit-service/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Default location
    location / {
        return 404;
    }
}
EOF

echo -e "${GREEN}Testing Nginx configuration...${NC}"
if sudo nginx -t; then
    echo -e "${GREEN}✓ Configuration is valid${NC}"
    
    # Check if Nginx is running
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}Reloading Nginx...${NC}"
        sudo systemctl reload nginx
        echo -e "${GREEN}✓ Nginx reloaded successfully${NC}"
    else
        echo -e "${YELLOW}Nginx is not running. Starting Nginx...${NC}"
        sudo systemctl start nginx
        sudo systemctl enable nginx
        echo -e "${GREEN}✓ Nginx started successfully${NC}"
        
        # Verify it's running
        sleep 2
        if systemctl is-active --quiet nginx; then
            echo -e "${GREEN}✓ Nginx is now running${NC}"
        else
            echo -e "${RED}✗ Failed to start Nginx. Check logs: sudo journalctl -u nginx${NC}"
            exit 1
        fi
    fi
else
    echo -e "${RED}✗ Configuration still has errors${NC}"
    echo -e "${YELLOW}Check the error messages above${NC}"
    exit 1
fi

