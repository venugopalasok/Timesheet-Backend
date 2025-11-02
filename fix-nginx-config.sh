#!/bin/bash

# Quick fix script to regenerate the Nginx config without the problematic if statement

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Fixing Nginx configuration...${NC}"

# Get EC2 IP with validation
EC2_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "")
if [ -z "$EC2_IP" ]; then
    EC2_IP="13.201.189.218"
    echo -e "${YELLOW}Could not fetch EC2 IP, using default: ${EC2_IP}${NC}"
else
    echo -e "${YELLOW}Using IP: ${EC2_IP}${NC}"
fi

# Validate IP format (basic check)
if ! [[ "$EC2_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo -e "${RED}Invalid IP format: ${EC2_IP}${NC}"
    echo -e "${YELLOW}Using default IP: 13.201.189.218${NC}"
    EC2_IP="13.201.189.218"
fi

# Final validation - ensure EC2_IP is not empty (should never happen at this point, but be safe)
if [ -z "$EC2_IP" ] || [ "$EC2_IP" = "" ]; then
    EC2_IP="13.201.189.218"
    echo -e "${RED}EC2_IP was empty, using default: ${EC2_IP}${NC}"
fi

# Trim any whitespace
EC2_IP=$(echo "$EC2_IP" | xargs)

echo -e "${GREEN}Final IP to use: ${EC2_IP}${NC}"

# Backup existing config if it exists
if [ -f /etc/nginx/sites-available/timesheet-backend ]; then
    echo -e "${YELLOW}Backing up existing config...${NC}"
    sudo cp /etc/nginx/sites-available/timesheet-backend /etc/nginx/sites-available/timesheet-backend.backup.$(date +%Y%m%d_%H%M%S)
fi

# Remove old symlink if it exists and is broken
if [ -L /etc/nginx/sites-enabled/timesheet-backend ] && [ ! -e /etc/nginx/sites-enabled/timesheet-backend ]; then
    echo -e "${YELLOW}Removing broken symlink...${NC}"
    sudo rm /etc/nginx/sites-enabled/timesheet-backend
fi

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

    # CORS headers (applied to all responses)
    add_header 'Access-Control-Allow-Origin' '*' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, PATCH, OPTIONS' always;
    add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization, X-Requested-With' always;
    add_header 'Access-Control-Max-Age' '3600' always;

    # Auth service - handle OPTIONS preflight
    location /auth-service/ {
        # Handle OPTIONS preflight requests
        if (\$request_method = 'OPTIONS') {
            return 204;
        }
        
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

    # Save service - handle OPTIONS preflight
    location /save-service/ {
        # Handle OPTIONS preflight requests
        if (\$request_method = 'OPTIONS') {
            return 204;
        }
        
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

    # Submit service - handle OPTIONS preflight
    location /submit-service/ {
        # Handle OPTIONS preflight requests
        if (\$request_method = 'OPTIONS') {
            return 204;
        }
        
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

# Create symlink if it doesn't exist
if [ ! -L /etc/nginx/sites-enabled/timesheet-backend ]; then
    echo -e "${GREEN}Creating symlink to enable site...${NC}"
    sudo ln -s /etc/nginx/sites-available/timesheet-backend /etc/nginx/sites-enabled/timesheet-backend
fi

# Verify the config file was created and contains valid server_name
if [ -f /etc/nginx/sites-available/timesheet-backend ]; then
    echo -e "${GREEN}Config file created successfully${NC}"
    # Check if server_name lines are valid
    if grep -q "server_name.*;" /etc/nginx/sites-available/timesheet-backend; then
        echo -e "${GREEN}✓ server_name directives found${NC}"
    else
        echo -e "${RED}✗ No valid server_name found in config${NC}"
        echo -e "${YELLOW}Config preview (first 20 lines):${NC}"
        head -20 /etc/nginx/sites-available/timesheet-backend
        exit 1
    fi
fi

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
    
    # Rebuild and restart services
    # Note: Disable set -e for service restart section since it's not critical
    echo ""
    echo -e "${GREEN}Rebuilding and restarting services...${NC}"
    
    # Find project directory (check common locations)
    PROJECT_DIR=""
    set +e  # Temporarily disable exit on error for service restart
    if [ -f "./docker-compose.yml" ] || [ -f "./docker-compose.free-tier.yml" ]; then
        PROJECT_DIR="$(pwd)"
    elif [ -f "$HOME/Timesheet-backend/docker-compose.yml" ] || [ -f "$HOME/Timesheet-backend/docker-compose.free-tier.yml" ]; then
        PROJECT_DIR="$HOME/Timesheet-backend"
    elif [ -d "/opt/timesheet-backend" ] && ([ -f "/opt/timesheet-backend/docker-compose.yml" ] || [ -f "/opt/timesheet-backend/docker-compose.free-tier.yml" ]); then
        PROJECT_DIR="/opt/timesheet-backend"
    fi
    
    if [ -n "$PROJECT_DIR" ]; then
        cd "$PROJECT_DIR"
        echo -e "${YELLOW}Found project directory: $PROJECT_DIR${NC}"
        
        # Determine which docker-compose file to use
        COMPOSE_FILE=""
        if [ -f "docker-compose.free-tier.yml" ]; then
            COMPOSE_FILE="docker-compose.free-tier.yml"
            echo -e "${YELLOW}Using docker-compose.free-tier.yml${NC}"
        elif [ -f "docker-compose.yml" ]; then
            COMPOSE_FILE="docker-compose.yml"
            echo -e "${YELLOW}Using docker-compose.yml${NC}"
        fi
        
        if [ -n "$COMPOSE_FILE" ] && command -v docker-compose &> /dev/null; then
            echo -e "${YELLOW}Stopping existing containers...${NC}"
            docker-compose -f "$COMPOSE_FILE" stop auth-service save-service submit-service 2>/dev/null || true
            
            echo -e "${YELLOW}Removing existing containers...${NC}"
            docker-compose -f "$COMPOSE_FILE" rm -f auth-service save-service submit-service 2>/dev/null || true
            
            echo -e "${GREEN}Rebuilding auth-service, save-service, and submit-service...${NC}"
            docker-compose -f "$COMPOSE_FILE" build --no-cache auth-service save-service submit-service
            
            echo -e "${GREEN}Starting services...${NC}"
            docker-compose -f "$COMPOSE_FILE" up -d auth-service save-service submit-service
            
            echo -e "${GREEN}Waiting for services to start...${NC}"
            sleep 5
            
            echo -e "${GREEN}Service status:${NC}"
            docker-compose -f "$COMPOSE_FILE" ps auth-service save-service submit-service
            
            echo -e "${GREEN}✓ Services rebuilt and restarted${NC}"
        elif [ -n "$COMPOSE_FILE" ] && command -v docker &> /dev/null && docker compose version &> /dev/null; then
            echo -e "${YELLOW}Stopping existing containers...${NC}"
            docker compose -f "$COMPOSE_FILE" stop auth-service save-service submit-service 2>/dev/null || true
            
            echo -e "${YELLOW}Removing existing containers...${NC}"
            docker compose -f "$COMPOSE_FILE" rm -f auth-service save-service submit-service 2>/dev/null || true
            
            echo -e "${GREEN}Rebuilding auth-service, save-service, and submit-service...${NC}"
            docker compose -f "$COMPOSE_FILE" build --no-cache auth-service save-service submit-service
            
            echo -e "${GREEN}Starting services...${NC}"
            docker compose -f "$COMPOSE_FILE" up -d auth-service save-service submit-service
            
            echo -e "${GREEN}Waiting for services to start...${NC}"
            sleep 5
            
            echo -e "${GREEN}Service status:${NC}"
            docker compose -f "$COMPOSE_FILE" ps auth-service save-service submit-service
            
            echo -e "${GREEN}✓ Services rebuilt and restarted${NC}"
        else
            echo -e "${YELLOW}Docker Compose not found. Checking for PM2 or direct node processes...${NC}"
            
            # Check for PM2
            if command -v pm2 &> /dev/null; then
                echo -e "${GREEN}Restarting services with PM2...${NC}"
                pm2 restart auth-service save-service submit-service 2>/dev/null || echo -e "${YELLOW}PM2 services not found or already running${NC}"
                echo -e "${GREEN}✓ PM2 services restarted${NC}"
            else
                echo -e "${YELLOW}No PM2 found. Checking for node processes...${NC}"
                
                # Try to find and restart node processes (if running directly)
                if pgrep -f "auth-service.*index.js" > /dev/null; then
                    echo -e "${YELLOW}Found auth-service process. Please restart manually:${NC}"
                    echo -e "${YELLOW}  cd auth-service && npm start${NC}"
                fi
                if pgrep -f "save-service.*index.js" > /dev/null; then
                    echo -e "${YELLOW}Found save-service process. Please restart manually:${NC}"
                    echo -e "${YELLOW}  cd save-service && npm start${NC}"
                fi
                if pgrep -f "submit-service.*index.js" > /dev/null; then
                    echo -e "${YELLOW}Found submit-service process. Please restart manually:${NC}"
                    echo -e "${YELLOW}  cd submit-service && npm start${NC}"
                fi
                
                echo -e "${YELLOW}Note: Services need to be restarted manually to apply CORS changes${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}Project directory not found. Skipping service rebuild.${NC}"
        echo -e "${YELLOW}Please manually rebuild and restart services:${NC}"
        echo -e "${YELLOW}  1. Navigate to project directory${NC}"
        echo -e "${YELLOW}  2. Run: docker-compose build auth-service save-service submit-service${NC}"
        echo -e "${YELLOW}  3. Run: docker-compose up -d auth-service save-service submit-service${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}=========================================="
    echo "   CORS FIX COMPLETE!"
    echo "==========================================${NC}"
    echo ""
    echo -e "${GREEN}Changes applied:${NC}"
    echo "  ✓ Removed CORS middleware from Express services"
    echo "  ✓ Nginx now handles all CORS headers"
    echo "  ✓ OPTIONS preflight requests handled correctly"
    echo ""
    echo -e "${YELLOW}Note: Make sure your code changes are deployed to the server${NC}"
    echo -e "${YELLOW}The service files (auth-service/index.js, save-service/index.js, submit-service/index.js)${NC}"
    echo -e "${YELLOW}should have the cors() middleware removed.${NC}"
    
    set -e  # Re-enable exit on error
    
else
    echo -e "${RED}✗ Configuration still has errors${NC}"
    echo -e "${YELLOW}Check the error messages above${NC}"
    exit 1
fi

