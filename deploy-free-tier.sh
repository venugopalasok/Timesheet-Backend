#!/bin/bash

# AWS FREE TIER DEPLOYMENT SCRIPT
# This script sets up your timesheet application on AWS EC2 t2.micro
#
# Usage:
#   ./deploy-free-tier.sh                    # Will prompt for branch (defaults to main)
#   ./deploy-free-tier.sh message-queue       # Deploy from specific branch
#   ./deploy-free-tier.sh main                # Explicitly deploy from main branch

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

# Allow branch selection via command line argument or prompt
DEPLOY_BRANCH="${1:-}"

if [ -d "$APP_DIR" ]; then
    echo "Application directory exists. Pulling latest changes..."
    cd "$APP_DIR"
    
    # If branch specified and different from current, checkout
    if [ -n "$DEPLOY_BRANCH" ]; then
        CURRENT_BRANCH=$(git branch --show-current)
        if [ "$CURRENT_BRANCH" != "$DEPLOY_BRANCH" ]; then
            echo "Switching to branch: $DEPLOY_BRANCH"
            git fetch origin
            git checkout "$DEPLOY_BRANCH" 2>/dev/null || git checkout -b "$DEPLOY_BRANCH" "origin/$DEPLOY_BRANCH"
        fi
    fi
    
    git pull
else
    echo "Cloning repository..."
    echo "Please enter your repository URL:"
    read -r REPO_URL
    
    # Clone the repository
    if [ -n "$DEPLOY_BRANCH" ]; then
        echo "Cloning branch: $DEPLOY_BRANCH"
        git clone -b "$DEPLOY_BRANCH" "$REPO_URL" "$APP_DIR"
    else
        # Ask for branch if not provided via argument
        echo "Which branch would you like to deploy? (default: main)"
        read -r BRANCH_INPUT
        BRANCH_TO_USE="${BRANCH_INPUT:-main}"
        echo "Cloning branch: $BRANCH_TO_USE"
        git clone -b "$BRANCH_TO_USE" "$REPO_URL" "$APP_DIR" || {
            echo -e "${YELLOW}Branch '$BRANCH_TO_USE' not found, cloning default branch...${NC}"
            git clone "$REPO_URL" "$APP_DIR"
            cd "$APP_DIR"
            git checkout "$BRANCH_TO_USE" 2>/dev/null || echo -e "${YELLOW}Using default branch${NC}"
        }
    fi
    
    cd "$APP_DIR"
fi

# Step 6: Configure environment
echo -e "${GREEN}Step 6: Configuring environment variables...${NC}"
cd "$APP_DIR"

if [ ! -f .env ]; then
    echo ""
    echo -e "${YELLOW}Creating .env file...${NC}"
    echo -e "${YELLOW}You'll need the following information:${NC}"
    echo "  1. MongoDB Atlas connection string"
    echo "  2. AWS Access Key ID (for SQS)"
    echo "  3. AWS Secret Access Key"
    echo "  4. SQS Queue URL"
    echo ""
    
    # MongoDB Atlas URI
    while [ -z "$MONGODB_URI" ]; do
        read -p "MongoDB Atlas URI: " MONGODB_URI
        if [ -z "$MONGODB_URI" ]; then
            echo -e "${RED}MongoDB Atlas URI is required!${NC}"
        fi
    done
    
    # AWS Region (with default)
    read -p "AWS Region [us-east-1]: " AWS_REGION
    AWS_REGION=${AWS_REGION:-us-east-1}
    
    # AWS Access Key ID
    while [ -z "$AWS_ACCESS_KEY" ]; do
        read -p "AWS Access Key ID: " AWS_ACCESS_KEY
        if [ -z "$AWS_ACCESS_KEY" ]; then
            echo -e "${RED}AWS Access Key ID is required!${NC}"
        fi
    done
    
    # AWS Secret Access Key (hidden input)
    while [ -z "$AWS_SECRET_KEY" ]; do
        read -sp "AWS Secret Access Key: " AWS_SECRET_KEY
        echo
        if [ -z "$AWS_SECRET_KEY" ]; then
            echo -e "${RED}AWS Secret Access Key is required!${NC}"
        fi
    done
    
    # SQS Queue URL
    while [ -z "$SQS_URL" ]; do
        read -p "SQS Queue URL: " SQS_URL
        if [ -z "$SQS_URL" ]; then
            echo -e "${RED}SQS Queue URL is required!${NC}"
        fi
    done
    
    # Frontend URL (optional)
    read -p "Frontend URL (optional, press Enter to skip): " FRONTEND_URL
    
    # Generate JWT secret automatically
    if command -v openssl &> /dev/null; then
        JWT_SECRET=$(openssl rand -hex 32)
        echo -e "${GREEN}Generated JWT secret automatically${NC}"
    else
        # Fallback: use /dev/urandom if openssl not available
        JWT_SECRET=$(head -c 32 /dev/urandom | base64 | tr -d '\n' | head -c 64)
        echo -e "${YELLOW}Generated JWT secret (consider using openssl for stronger secret)${NC}"
    fi
    
    # Create .env file
    cat > .env << EOF
# MongoDB Atlas Connection
MONGODB_ATLAS_URI=$MONGODB_URI

# AWS Configuration
AWS_REGION=$AWS_REGION
AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY
AWS_SECRET_ACCESS_KEY=$AWS_SECRET_KEY

# SQS Queue
SQS_QUEUE_URL=$SQS_URL

# JWT Configuration
JWT_SECRET=$JWT_SECRET
JWT_EXPIRES_IN=7d

# CORS Configuration (optional)
FRONTEND_URL=$FRONTEND_URL

# Environment
NODE_ENV=production
EOF
    
    # Set secure permissions
    chmod 600 .env
    
    echo ""
    echo -e "${GREEN}✓ .env file created successfully!${NC}"
    echo -e "${YELLOW}You can edit it later if needed: nano .env${NC}"
    echo ""
else
    echo ".env file already exists"
    echo -e "${YELLOW}If you need to update it, edit: nano .env${NC}"
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

