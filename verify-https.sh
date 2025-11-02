#!/bin/bash

# Script to verify HTTPS is working on EC2 backend

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   HTTPS Verification Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get EC2 IP
EC2_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "13.201.189.218")
echo -e "${GREEN}EC2 IP Address: ${EC2_IP}${NC}"
echo ""

# Check if Nginx is running
echo -e "${GREEN}1. Checking Nginx status...${NC}"
if systemctl is-active --quiet nginx 2>/dev/null; then
    echo -e "${GREEN}✓ Nginx is running${NC}"
else
    echo -e "${RED}✗ Nginx is NOT running${NC}"
    echo -e "${YELLOW}Please start Nginx: sudo systemctl start nginx${NC}"
    exit 1
fi

# Check if Nginx is listening on port 443
echo ""
echo -e "${GREEN}2. Checking if Nginx is listening on port 443 (HTTPS)...${NC}"
if sudo lsof -i :443 2>/dev/null | grep -q nginx; then
    echo -e "${GREEN}✓ Nginx is listening on port 443${NC}"
    sudo lsof -i :443 | grep nginx
else
    echo -e "${RED}✗ Nginx is NOT listening on port 443${NC}"
    echo -e "${YELLOW}Check Nginx configuration: sudo nginx -t${NC}"
    echo -e "${YELLOW}Check config file: sudo cat /etc/nginx/sites-enabled/timesheet-backend${NC}"
fi

# Check if SSL certificate exists
echo ""
echo -e "${GREEN}3. Checking SSL certificate...${NC}"
if [ -f /etc/nginx/ssl/selfsigned.crt ] && [ -f /etc/nginx/ssl/selfsigned.key ]; then
    echo -e "${GREEN}✓ SSL certificate found${NC}"
    echo -e "${BLUE}Certificate: /etc/nginx/ssl/selfsigned.crt${NC}"
    echo -e "${BLUE}Private key: /etc/nginx/ssl/selfsigned.key${NC}"
    
    # Show certificate details
    echo ""
    echo -e "${YELLOW}Certificate details:${NC}"
    sudo openssl x509 -in /etc/nginx/ssl/selfsigned.crt -text -noout | grep -E "Subject:|Issuer:|Not Before|Not After" | head -4
else
    echo -e "${RED}✗ SSL certificate NOT found${NC}"
    echo -e "${YELLOW}Certificate should be at: /etc/nginx/ssl/selfsigned.crt${NC}"
fi

# Test HTTPS endpoints
echo ""
echo -e "${GREEN}4. Testing HTTPS endpoints...${NC}"
echo ""

# Test health endpoint
echo -e "${BLUE}Testing: https://${EC2_IP}/health${NC}"
HEALTH_RESPONSE=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" https://${EC2_IP}/health 2>&1 || echo "ERROR")
if echo "$HEALTH_RESPONSE" | grep -q "HTTP_CODE:200\|healthy"; then
    echo -e "${GREEN}✓ Health endpoint working (HTTPS)${NC}"
    echo "$HEALTH_RESPONSE" | head -1
else
    echo -e "${RED}✗ Health endpoint failed${NC}"
    echo "$HEALTH_RESPONSE"
fi

echo ""

# Test auth-service
echo -e "${BLUE}Testing: https://${EC2_IP}/auth-service/health${NC}"
AUTH_RESPONSE=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" https://${EC2_IP}/auth-service/health 2>&1 || echo "ERROR")
if echo "$AUTH_RESPONSE" | grep -q "HTTP_CODE:200"; then
    echo -e "${GREEN}✓ Auth service accessible over HTTPS${NC}"
    echo "$AUTH_RESPONSE" | grep -v "HTTP_CODE" | head -3
elif echo "$AUTH_RESPONSE" | grep -q "HTTP_CODE:502\|HTTP_CODE:503"; then
    echo -e "${YELLOW}⚠ Auth service backend may not be running${NC}"
    echo -e "${YELLOW}   Check: docker ps | grep auth-service${NC}"
elif echo "$AUTH_RESPONSE" | grep -q "ERROR\|Connection refused"; then
    echo -e "${RED}✗ Cannot connect to auth service${NC}"
else
    echo -e "${YELLOW}⚠ Auth service returned: $(echo "$AUTH_RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)${NC}"
fi

echo ""

# Test save-service
echo -e "${BLUE}Testing: https://${EC2_IP}/save-service/health${NC}"
SAVE_RESPONSE=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" https://${EC2_IP}/save-service/health 2>&1 || echo "ERROR")
if echo "$SAVE_RESPONSE" | grep -q "HTTP_CODE:200"; then
    echo -e "${GREEN}✓ Save service accessible over HTTPS${NC}"
    echo "$SAVE_RESPONSE" | grep -v "HTTP_CODE" | head -3
elif echo "$SAVE_RESPONSE" | grep -q "HTTP_CODE:502\|HTTP_CODE:503"; then
    echo -e "${YELLOW}⚠ Save service backend may not be running${NC}"
    echo -e "${YELLOW}   Check: docker ps | grep save-service${NC}"
else
    echo -e "${YELLOW}⚠ Save service returned: $(echo "$SAVE_RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)${NC}"
fi

echo ""

# Check Docker services
echo -e "${GREEN}5. Checking Docker backend services...${NC}"
if command -v docker &> /dev/null; then
    echo ""
    echo -e "${BLUE}Running Docker containers:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "auth-service|save-service|submit-service|NAMES" || echo -e "${YELLOW}No backend services found running${NC}"
    
    echo ""
    echo -e "${BLUE}Testing internal service endpoints:${NC}"
    
    # Test auth-service internally
    if docker ps | grep -q auth-service; then
        echo -e "${GREEN}✓ Auth-service container is running${NC}"
        curl -s http://localhost:3002/auth-service/health > /dev/null && echo -e "${GREEN}  ✓ Internal endpoint accessible${NC}" || echo -e "${YELLOW}  ⚠ Internal endpoint not responding${NC}"
    else
        echo -e "${RED}✗ Auth-service container is NOT running${NC}"
    fi
    
    if docker ps | grep -q save-service; then
        echo -e "${GREEN}✓ Save-service container is running${NC}"
        curl -s http://localhost:3000/save-service/health > /dev/null && echo -e "${GREEN}  ✓ Internal endpoint accessible${NC}" || echo -e "${YELLOW}  ⚠ Internal endpoint not responding${NC}"
    else
        echo -e "${RED}✗ Save-service container is NOT running${NC}"
    fi
else
    echo -e "${YELLOW}Docker not found - skipping container checks${NC}"
fi

# Check EC2 Security Group (reminder)
echo ""
echo -e "${GREEN}6. Security Group Configuration Reminder${NC}"
echo -e "${YELLOW}Make sure your EC2 Security Group allows:${NC}"
echo "  - Port 443 (HTTPS) from anywhere (0.0.0.0/0)"
echo "  - Port 80 (HTTP) from anywhere (for redirect)"
echo ""
echo -e "${BLUE}You can test from your local machine:${NC}"
echo "  curl -k https://${EC2_IP}/health"

# Summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if systemctl is-active --quiet nginx 2>/dev/null && \
   sudo lsof -i :443 2>/dev/null | grep -q nginx && \
   [ -f /etc/nginx/ssl/selfsigned.crt ]; then
    echo -e "${GREEN}✓ HTTPS appears to be configured correctly!${NC}"
    echo ""
    echo -e "${GREEN}Your backend HTTPS URL:${NC}"
    echo -e "${BLUE}  https://${EC2_IP}${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Update AWS Amplify environment variables:"
    echo "   VITE_AUTH_SERVICE_URL=https://${EC2_IP}"
    echo "   VITE_BACKEND_URL=https://${EC2_IP}"
    echo ""
    echo "2. Note: Browsers will show a security warning (self-signed cert)"
    echo "   Users need to click 'Advanced' → 'Proceed to site'"
else
    echo -e "${RED}⚠ HTTPS setup may be incomplete${NC}"
    echo -e "${YELLOW}Check the errors above and fix them${NC}"
fi

echo ""

