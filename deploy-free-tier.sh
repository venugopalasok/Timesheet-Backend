#!/bin/bash

# AWS FREE TIER DEPLOYMENT SCRIPT
# This script sets up your timesheet application on AWS EC2 t2.micro

set -e  # Exit on error

echo "=========================================="
echo "   AWS FREE TIER DEPLOYMENT SCRIPT"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if running on EC2
if [ ! -f /sys/hypervisor/uuid ] || ! grep -q "ec2" /sys/hypervisor/uuid 2>/dev/null; then
    echo -e "${YELLOW}Warning: This doesn't appear to be an EC2 instance${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Step 1: Update system
echo -e "${GREEN}Step 1: Updating system packages...${NC}"
sudo apt update && sudo apt upgrade -y

# Step 2: Install Docker
echo -e "${GREEN}Step 2: Installing Docker...${NC}"
if ! command -v docker &> /dev/null; then
    sudo apt install -y docker.io
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker $USER
    echo -e "${YELLOW}Docker installed. You may need to log out and back in.${NC}"
else
    echo "Docker already installed"
fi

# Step 3: Install Docker Compose
echo -e "${GREEN}Step 3: Installing Docker Compose...${NC}"
if ! command -v docker-compose &> /dev/null; then
    sudo apt install -y docker-compose
else
    echo "Docker Compose already installed"
fi

# Step 4: Install Git
echo -e "${GREEN}Step 4: Installing Git...${NC}"
if ! command -v git &> /dev/null; then
    sudo apt install -y git
else
    echo "Git already installed"
fi

# Step 5: Clone repository (or update if exists)
echo -e "${GREEN}Step 5: Setting up application...${NC}"
APP_DIR="$HOME/timesheet-backend"

if [ -d "$APP_DIR" ]; then
    echo "Application directory exists. Pulling latest changes..."
    cd "$APP_DIR"
    git pull
else
    echo "Cloning repository..."
    echo "Please enter your repository URL:"
    read -r REPO_URL
    git clone "$REPO_URL" "$APP_DIR"
    cd "$APP_DIR"
fi

# Step 6: Configure environment
echo -e "${GREEN}Step 6: Configuring environment variables...${NC}"
if [ ! -f .env ]; then
    if [ -f .env.free-tier.example ]; then
        cp .env.free-tier.example .env
        echo -e "${YELLOW}Created .env file from template.${NC}"
        echo -e "${YELLOW}Please edit .env and add your MongoDB Atlas and AWS credentials:${NC}"
        echo "  nano .env"
        echo ""
        echo "Press Enter when ready to continue..."
        read
    else
        echo -e "${RED}Error: .env.free-tier.example not found${NC}"
        exit 1
    fi
else
    echo ".env file already exists"
fi

# Step 7: Create swap file (important for t2.micro 1GB RAM)
echo -e "${GREEN}Step 7: Creating swap space (helps with low memory)...${NC}"
if [ ! -f /swapfile ]; then
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo "Swap created: 2GB"
else
    echo "Swap already configured"
fi

# Step 8: Configure firewall
echo -e "${GREEN}Step 8: Configuring firewall...${NC}"
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw allow 8080/tcp # API Gateway
echo "Firewall rules configured"

# Step 9: Build and start services
echo -e "${GREEN}Step 9: Building Docker images...${NC}"
docker-compose -f docker-compose.free-tier.yml build

echo -e "${GREEN}Step 10: Starting services...${NC}"
docker-compose -f docker-compose.free-tier.yml up -d

# Step 11: Wait for services to be ready
echo -e "${GREEN}Waiting for services to start...${NC}"
sleep 10

# Step 12: Check service status
echo -e "${GREEN}Service Status:${NC}"
docker-compose -f docker-compose.free-tier.yml ps

# Step 13: Display useful information
echo ""
echo -e "${GREEN}=========================================="
echo "   DEPLOYMENT COMPLETE!"
echo "==========================================${NC}"
echo ""
echo "Your application is now running!"
echo ""
echo "API Gateway: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):80"
echo ""
echo "Service endpoints:"
echo "  - Auth:         http://localhost:3002"
echo "  - Save:         http://localhost:3000"
echo "  - Submit:       http://localhost:3001"
echo "  - Notification: http://localhost:3003"
echo ""
echo "Useful commands:"
echo "  - View logs:          docker-compose -f docker-compose.free-tier.yml logs -f"
echo "  - Stop services:      docker-compose -f docker-compose.free-tier.yml down"
echo "  - Restart services:   docker-compose -f docker-compose.free-tier.yml restart"
echo "  - Check memory:       free -h"
echo "  - Monitor containers: docker stats"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Update frontend API endpoint to point to this server"
echo "  2. Set up a domain name (optional)"
echo "  3. Configure SSL with Let's Encrypt (optional)"
echo ""

