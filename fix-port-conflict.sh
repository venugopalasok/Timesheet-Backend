#!/bin/bash

# Script to fix port 80 conflict for Nginx setup

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Checking what's using port 80...${NC}"

# Check what's using port 80
PORT_80_PROCESS=$(sudo lsof -i :80 | grep LISTEN || true)

if [ -z "$PORT_80_PROCESS" ]; then
    echo -e "${GREEN}Port 80 is free!${NC}"
    exit 0
fi

echo -e "${RED}Port 80 is in use:${NC}"
echo "$PORT_80_PROCESS"
echo ""

# Check if it's Docker Nginx
if echo "$PORT_80_PROCESS" | grep -q "docker\|nginx"; then
    echo -e "${YELLOW}Looks like Docker Nginx or another Nginx is using port 80${NC}"
    echo ""
    echo "Options:"
    echo "1. Stop Docker api-gateway container"
    echo "2. Stop system Nginx (if running)"
    echo "3. Use different port for host Nginx"
    echo ""
    read -p "What would you like to do? (1/2/3): " choice
    
    case $choice in
        1)
            echo -e "${GREEN}Stopping Docker api-gateway...${NC}"
            docker stop api-gateway 2>/dev/null || docker-compose stop api-gateway || true
            echo -e "${GREEN}✓ Docker api-gateway stopped${NC}"
            ;;
        2)
            echo -e "${GREEN}Stopping system Nginx...${NC}"
            sudo systemctl stop nginx
            echo -e "${GREEN}✓ System Nginx stopped${NC}"
            ;;
        3)
            echo -e "${YELLOW}You'll need to modify the Nginx config to use a different port${NC}"
            exit 1
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
fi

# Verify port 80 is now free
sleep 2
if sudo lsof -i :80 | grep -q LISTEN; then
    echo -e "${RED}Port 80 is still in use. Please manually stop the service using it.${NC}"
    sudo lsof -i :80
    exit 1
else
    echo -e "${GREEN}✓ Port 80 is now free!${NC}"
fi

