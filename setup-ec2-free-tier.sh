#!/bin/bash

################################################################################
# AWS EC2 Free Tier Setup Script for Timesheet Application
# 
# This script automates the deployment of your timesheet app on AWS EC2 t2.micro
# Optimized for 1GB RAM with Docker Compose
################################################################################

set -e  # Exit on any error

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   AWS FREE TIER DEPLOYMENT - TIMESHEET APPLICATION       ║
║   Optimized for EC2 t2.micro (1GB RAM)                   ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check if we're root
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}Please do not run this script as root/sudo${NC}"
    echo "Run as: ./setup-ec2-free-tier.sh"
    exit 1
fi

################################################################################
# STEP 1: System Information
################################################################################
echo -e "\n${GREEN}=== STEP 1: System Information ===${NC}\n"

echo "Hostname: $(hostname)"
echo "OS: $(lsb_release -d | cut -f2)"
echo "Kernel: $(uname -r)"
echo "Memory: $(free -h | awk '/^Mem:/ {print $2}')"
echo "CPU: $(nproc) cores"
echo "Disk: $(df -h / | awk 'NR==2 {print $4}') available"

# Detect if on EC2
echo ""
if curl -s -m 2 http://169.254.169.254/latest/meta-data/instance-id > /dev/null 2>&1; then
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
    REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    echo -e "${GREEN}✓ Running on AWS EC2${NC}"
    echo "  Instance ID: $INSTANCE_ID"
    echo "  Public IP: $PUBLIC_IP"
    echo "  Region: $REGION"
else
    echo -e "${YELLOW}⚠ Not running on EC2 (or metadata service unavailable)${NC}"
    PUBLIC_IP="localhost"
fi

echo ""
read -p "Press Enter to continue or Ctrl+C to abort..."

################################################################################
# STEP 2: Update System Packages
################################################################################
echo -e "\n${GREEN}=== STEP 2: Updating System Packages ===${NC}\n"

sudo apt-get update -qq
sudo apt-get upgrade -y -qq

echo -e "${GREEN}✓ System packages updated${NC}"

################################################################################
# STEP 3: Install Docker
################################################################################
echo -e "\n${GREEN}=== STEP 3: Installing Docker ===${NC}\n"

if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓ Docker already installed: $(docker --version)${NC}"
else
    echo "Installing Docker..."
    sudo apt-get install -y docker.io
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker $USER
    echo -e "${GREEN}✓ Docker installed${NC}"
fi

################################################################################
# STEP 4: Install Docker Compose
################################################################################
echo -e "\n${GREEN}=== STEP 4: Installing Docker Compose ===${NC}\n"

if command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}✓ Docker Compose already installed: $(docker-compose --version)${NC}"
else
    echo "Installing Docker Compose..."
    sudo apt-get install -y docker-compose
    echo -e "${GREEN}✓ Docker Compose installed${NC}"
fi

################################################################################
# STEP 5: Create Swap Space (Critical for 1GB RAM)
################################################################################
echo -e "\n${GREEN}=== STEP 5: Creating Swap Space ===${NC}\n"

if [ -f /swapfile ]; then
    echo -e "${YELLOW}Swap file already exists${NC}"
    swapon --show
else
    echo "Creating 2GB swap file (this may take a minute)..."
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile > /dev/null 2>&1
    sudo swapon /swapfile
    
    # Make swap permanent
    if ! grep -q '/swapfile' /etc/fstab; then
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null
    fi
    
    # Optimize swappiness for server
    sudo sysctl vm.swappiness=10
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf > /dev/null
    
    echo -e "${GREEN}✓ Swap created and configured${NC}"
fi

echo "Current memory status:"
free -h

################################################################################
# STEP 6: Install Additional Tools
################################################################################
echo -e "\n${GREEN}=== STEP 6: Installing Additional Tools ===${NC}\n"

sudo apt-get install -y git curl wget nano htop

echo -e "${GREEN}✓ Additional tools installed${NC}"

################################################################################
# STEP 7: Configure Firewall (UFW)
################################################################################
echo -e "\n${GREEN}=== STEP 7: Configuring Firewall ===${NC}\n"

if command -v ufw &> /dev/null; then
    echo "Configuring UFW firewall..."
    sudo ufw --force enable
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow 22/tcp comment 'SSH'
    sudo ufw allow 80/tcp comment 'HTTP'
    sudo ufw allow 443/tcp comment 'HTTPS'
    sudo ufw allow 8080/tcp comment 'API Gateway'
    echo -e "${GREEN}✓ Firewall configured${NC}"
    sudo ufw status
else
    echo -e "${YELLOW}UFW not available, skipping firewall config${NC}"
fi

################################################################################
# STEP 8: Clone Repository
################################################################################
echo -e "\n${GREEN}=== STEP 8: Setting Up Application ===${NC}\n"

APP_DIR="$HOME/timesheet-backend"

if [ -d "$APP_DIR" ]; then
    echo -e "${YELLOW}Application directory already exists${NC}"
    read -p "Pull latest changes? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd "$APP_DIR"
        git pull
        echo -e "${GREEN}✓ Repository updated${NC}"
    fi
else
    echo ""
    echo "To clone your repository, you have two options:"
    echo "  1. Public repo: Just provide the URL"
    echo "  2. Private repo: Set up SSH key first"
    echo ""
    read -p "Enter repository URL (or press Enter to skip): " REPO_URL
    
    if [ ! -z "$REPO_URL" ]; then
        git clone "$REPO_URL" "$APP_DIR"
        cd "$APP_DIR"
        echo -e "${GREEN}✓ Repository cloned${NC}"
    else
        echo -e "${YELLOW}Skipping repository clone${NC}"
        echo "You can clone manually later with:"
        echo "  git clone YOUR_REPO_URL $APP_DIR"
        mkdir -p "$APP_DIR"
        cd "$APP_DIR"
    fi
fi

################################################################################
# STEP 9: Configure Environment Variables
################################################################################
echo -e "\n${GREEN}=== STEP 9: Configuring Environment Variables ===${NC}\n"

ENV_FILE="$APP_DIR/.env"

if [ -f "$ENV_FILE" ]; then
    echo -e "${YELLOW}.env file already exists${NC}"
    read -p "Reconfigure? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing configuration"
        cat "$ENV_FILE"
    else
        rm "$ENV_FILE"
    fi
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "Creating .env file..."
    echo ""
    echo -e "${YELLOW}You'll need the following information:${NC}"
    echo "  1. MongoDB Atlas connection string"
    echo "  2. AWS Access Key ID (for SQS)"
    echo "  3. AWS Secret Access Key"
    echo "  4. SQS Queue URL"
    echo ""
    
    # MongoDB URI
    read -p "MongoDB Atlas URI: " MONGODB_URI
    
    # AWS Region
    read -p "AWS Region [us-east-1]: " AWS_REGION
    AWS_REGION=${AWS_REGION:-us-east-1}
    
    # AWS Credentials
    read -p "AWS Access Key ID: " AWS_ACCESS_KEY
    read -sp "AWS Secret Access Key: " AWS_SECRET_KEY
    echo
    
    # SQS Queue URL
    read -p "SQS Queue URL: " SQS_URL
    
    # Frontend URL
    read -p "Frontend URL (optional): " FRONTEND_URL
    
    # Generate JWT secret
    JWT_SECRET=$(openssl rand -hex 32)
    
    # Create .env file
    cat > "$ENV_FILE" << EOF
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

# CORS Configuration
FRONTEND_URL=$FRONTEND_URL

# Environment
NODE_ENV=production
EOF
    
    chmod 600 "$ENV_FILE"
    echo -e "${GREEN}✓ Environment configured${NC}"
fi

################################################################################
# STEP 10: Install Node Dependencies (if needed)
################################################################################
echo -e "\n${GREEN}=== STEP 10: Installing Dependencies ===${NC}\n"

# Install AWS SDK in shared folder
if [ -d "$APP_DIR/shared" ]; then
    cd "$APP_DIR/shared"
    if [ ! -d "node_modules" ]; then
        echo "Installing shared dependencies..."
        npm install
    fi
fi

# Check each service
for SERVICE_DIR in save-service submit-service auth-service notification-service; do
    if [ -d "$APP_DIR/$SERVICE_DIR" ]; then
        cd "$APP_DIR/$SERVICE_DIR"
        if [ -f "package.json" ] && [ ! -d "node_modules" ]; then
            echo "Installing dependencies for $SERVICE_DIR..."
            npm install
        fi
    fi
done

echo -e "${GREEN}✓ Dependencies installed${NC}"

################################################################################
# STEP 11: Build and Start Services
################################################################################
echo -e "\n${GREEN}=== STEP 11: Building Docker Images ===${NC}\n"

cd "$APP_DIR"

if [ -f "docker-compose.free-tier.yml" ]; then
    COMPOSE_FILE="docker-compose.free-tier.yml"
else
    COMPOSE_FILE="docker-compose.yml"
    echo -e "${YELLOW}Using $COMPOSE_FILE (free-tier version not found)${NC}"
fi

echo "Building images (this may take several minutes)..."
docker-compose -f "$COMPOSE_FILE" build

echo -e "${GREEN}✓ Images built${NC}"

################################################################################
# STEP 12: Start Services
################################################################################
echo -e "\n${GREEN}=== STEP 12: Starting Services ===${NC}\n"

docker-compose -f "$COMPOSE_FILE" up -d

echo "Waiting for services to start..."
sleep 15

echo -e "${GREEN}✓ Services started${NC}"

################################################################################
# STEP 13: Verify Deployment
################################################################################
echo -e "\n${GREEN}=== STEP 13: Verifying Deployment ===${NC}\n"

echo "Service Status:"
docker-compose -f "$COMPOSE_FILE" ps

echo ""
echo "Testing API Gateway health..."
HEALTH_CHECK=$(curl -s http://localhost/save-service/health || echo "FAILED")

if [[ "$HEALTH_CHECK" == *"OK"* ]] || [[ "$HEALTH_CHECK" == *"status"* ]]; then
    echo -e "${GREEN}✓ Health check passed!${NC}"
else
    echo -e "${RED}✗ Health check failed${NC}"
    echo "Response: $HEALTH_CHECK"
fi

echo ""
echo "Container Resource Usage:"
docker stats --no-stream

################################################################################
# STEP 14: Final Instructions
################################################################################
echo -e "\n${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║              DEPLOYMENT COMPLETE! 🎉                      ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${GREEN}Your timesheet application is now running!${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}Application URLs:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$PUBLIC_IP" != "localhost" ]; then
    echo "  API Gateway:  http://$PUBLIC_IP"
    echo "  Auth Service: http://$PUBLIC_IP:3002"
    echo "  Save Service: http://$PUBLIC_IP:3000"
    echo "  Submit:       http://$PUBLIC_IP:3001"
    echo "  Notifications: http://$PUBLIC_IP:3003"
else
    echo "  API Gateway:  http://localhost"
    echo "  (Use your EC2 public IP for external access)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}Useful Commands:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  View logs:       docker-compose -f $COMPOSE_FILE logs -f"
echo "  Restart:         docker-compose -f $COMPOSE_FILE restart"
echo "  Stop:            docker-compose -f $COMPOSE_FILE down"
echo "  Start:           docker-compose -f $COMPOSE_FILE up -d"
echo "  Check resources: docker stats"
echo "  Check memory:    free -h"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}Next Steps:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  1. Update frontend API URL to: http://$PUBLIC_IP"
echo "  2. Set up custom domain (optional)"
echo "  3. Configure SSL/HTTPS with Let's Encrypt"
echo "  4. Set up AWS billing alerts"
echo "  5. Configure automated backups"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}Important Notes:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  • Monitor your AWS Free Tier usage"
echo "  • Set billing alerts at \$1 threshold"
echo "  • MongoDB Atlas M0 is FREE forever (512MB)"
echo "  • AWS SQS is FREE for 1M requests/month"
echo "  • EC2 t2.micro is FREE for 750 hours/month (12 months)"
echo ""

if [ "$USER" != "$(id -gn docker)" ]; then
    echo -e "${YELLOW}⚠  You may need to log out and back in for Docker group changes to take effect${NC}"
fi

echo ""
echo -e "${GREEN}Happy coding! 🚀${NC}"
echo ""

