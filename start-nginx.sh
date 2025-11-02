#!/bin/bash

# Quick script to start Nginx after fixing config

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Testing Nginx configuration...${NC}"

if sudo nginx -t; then
    echo -e "${GREEN}✓ Configuration is valid${NC}"
    echo ""
    
    # Check current status
    if systemctl is-active --quiet nginx; then
        echo -e "${YELLOW}Nginx is already running${NC}"
        echo -e "${GREEN}Reloading Nginx...${NC}"
        sudo systemctl reload nginx
        echo -e "${GREEN}✓ Nginx reloaded${NC}"
    else
        echo -e "${YELLOW}Nginx is not running${NC}"
        echo -e "${GREEN}Starting Nginx...${NC}"
        sudo systemctl start nginx
        sudo systemctl enable nginx
        
        sleep 2
        
        if systemctl is-active --quiet nginx; then
            echo -e "${GREEN}✓ Nginx started successfully${NC}"
            echo -e "${GREEN}✓ Nginx is enabled to start on boot${NC}"
        else
            echo -e "${RED}✗ Failed to start Nginx${NC}"
            echo ""
            echo -e "${YELLOW}Troubleshooting:${NC}"
            echo "1. Check status: sudo systemctl status nginx"
            echo "2. Check logs: sudo journalctl -u nginx -n 50"
            echo "3. Check for port conflicts: sudo lsof -i :80"
            echo "4. Check config: sudo nginx -t"
            exit 1
        fi
    fi
    
    echo ""
    echo -e "${GREEN}✓ Nginx is running!${NC}"
    echo -e "${YELLOW}Test your endpoints:${NC}"
    EC2_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "13.201.189.218")
    echo "  curl -k https://${EC2_IP}/health"
    echo "  curl -k https://${EC2_IP}/auth-service/health"
else
    echo -e "${RED}✗ Configuration has errors${NC}"
    echo ""
    echo -e "${YELLOW}Fix the configuration errors above, then run this script again${NC}"
    exit 1
fi

