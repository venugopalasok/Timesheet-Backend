#!/bin/bash

# Script to check Nginx installation and status

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Nginx Installation & Status Check${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if Nginx is installed
echo -e "${GREEN}1. Checking if Nginx is installed...${NC}"
if command -v nginx &> /dev/null; then
    echo -e "${GREEN}✓ Nginx is installed${NC}"
    nginx -v
else
    echo -e "${RED}✗ Nginx is NOT installed${NC}"
    echo ""
    echo -e "${YELLOW}Installing Nginx...${NC}"
    sudo apt update
    sudo apt install -y nginx
    echo -e "${GREEN}✓ Nginx installed${NC}"
fi

echo ""

# Check if Nginx service exists
echo -e "${GREEN}2. Checking if Nginx service exists...${NC}"
if systemctl list-unit-files | grep -q nginx.service; then
    echo -e "${GREEN}✓ Nginx service found${NC}"
else
    echo -e "${RED}✗ Nginx service NOT found${NC}"
    echo ""
    echo -e "${YELLOW}Checking alternative service names...${NC}"
    
    # Some systems use different service names
    if systemctl list-unit-files | grep -q "nginx"; then
        NGINX_SERVICE=$(systemctl list-unit-files | grep nginx | head -1 | awk '{print $1}')
        echo -e "${YELLOW}Found: ${NGINX_SERVICE}${NC}"
    else
        echo -e "${RED}No Nginx service found. Reinstalling...${NC}"
        sudo apt remove --purge nginx nginx-common -y 2>/dev/null || true
        sudo apt update
        sudo apt install -y nginx
        sudo systemctl daemon-reload
    fi
fi

echo ""

# Check Nginx service status
echo -e "${GREEN}3. Checking Nginx service status...${NC}"
if systemctl is-active --quiet nginx 2>/dev/null; then
    echo -e "${GREEN}✓ Nginx is RUNNING${NC}"
    sudo systemctl status nginx --no-pager -l | head -10
elif systemctl is-enabled --quiet nginx 2>/dev/null; then
    echo -e "${YELLOW}⚠ Nginx is installed but NOT running${NC}"
    echo ""
    echo -e "${YELLOW}Starting Nginx...${NC}"
    sudo systemctl start nginx
    sleep 2
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✓ Nginx started successfully${NC}"
    else
        echo -e "${RED}✗ Failed to start Nginx${NC}"
        echo ""
        echo -e "${YELLOW}Checking for errors:${NC}"
        sudo journalctl -u nginx -n 20 --no-pager
        exit 1
    fi
else
    echo -e "${RED}✗ Nginx service not found or not enabled${NC}"
    echo ""
    echo -e "${YELLOW}Attempting to fix...${NC}"
    
    # Try to enable and start
    sudo systemctl daemon-reload
    sudo systemctl enable nginx 2>/dev/null || true
    sudo systemctl start nginx 2>/dev/null || true
    
    sleep 2
    
    if systemctl is-active --quiet nginx 2>/dev/null; then
        echo -e "${GREEN}✓ Nginx is now running${NC}"
    else
        echo -e "${RED}✗ Could not start Nginx automatically${NC}"
        echo ""
        echo -e "${YELLOW}Manual troubleshooting:${NC}"
        echo "1. Check if nginx process exists: ps aux | grep nginx"
        echo "2. Check systemd: systemctl list-units | grep nginx"
        echo "3. Check logs: sudo journalctl -u nginx -n 50"
        echo "4. Check config: sudo nginx -t"
        echo "5. Try starting manually: sudo nginx"
        exit 1
    fi
fi

echo ""

# Check if Nginx is listening on ports
echo -e "${GREEN}4. Checking if Nginx is listening on ports...${NC}"
if sudo lsof -i :80 2>/dev/null | grep -q nginx; then
    echo -e "${GREEN}✓ Nginx is listening on port 80${NC}"
else
    echo -e "${YELLOW}⚠ Nginx is not listening on port 80${NC}"
fi

if sudo lsof -i :443 2>/dev/null | grep -q nginx; then
    echo -e "${GREEN}✓ Nginx is listening on port 443${NC}"
else
    echo -e "${YELLOW}⚠ Nginx is not listening on port 443${NC}"
fi

echo ""

# Test Nginx configuration
echo -e "${GREEN}5. Testing Nginx configuration...${NC}"
if sudo nginx -t; then
    echo -e "${GREEN}✓ Nginx configuration is valid${NC}"
else
    echo -e "${RED}✗ Nginx configuration has errors${NC}"
    echo -e "${YELLOW}Fix the configuration errors above${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Nginx Status: OK${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Nginx is ready to use!${NC}"

