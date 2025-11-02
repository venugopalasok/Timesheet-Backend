# 🔒 HTTPS Setup Guide for EC2 Backend

This guide will help you set up HTTPS (SSL/TLS) on your EC2 instance so your frontend can communicate securely with the backend.

## 📋 Prerequisites

1. **EC2 instance** running Ubuntu 20.04/22.04
2. **Domain name** (optional but recommended) - You can use:
   - A registered domain (e.g., `api.yourdomain.com`)
   - AWS Route 53 hosted domain
   - Free domain from services like Freenom, No-IP, or DuckDNS
3. **DNS A record** pointing to your EC2 public IP (if using domain)
4. **Access to EC2** via SSH

## 🎯 Two Options

### Option A: With Domain Name (Recommended - Free SSL with Let's Encrypt)
✅ Best security  
✅ Free SSL certificate  
✅ Auto-renewal  
✅ Browser-trusted certificate

### Option B: Without Domain (Self-Signed Certificate)
⚠️ Works but shows browser warnings  
⚠️ Requires trusting the certificate manually

---

## 🚀 Option A: HTTPS with Domain Name + Let's Encrypt

### Step 1: Point Your Domain to EC2 IP

1. **Get your EC2 Public IP**: 
   ```bash
   # From AWS Console or
   curl http://169.254.169.254/latest/meta-data/public-ipv4
   ```
   Your IP: `13.201.189.218`

2. **Create DNS A Record**:
   - If using Route 53: Create A record pointing to `13.201.189.218`
   - If using other DNS: Point A record to `13.201.189.218`
   - Example: `api.yourdomain.com` → `13.201.189.218`
   - Wait 5-10 minutes for DNS propagation

3. **Verify DNS**:
   ```bash
   dig api.yourdomain.com
   # or
   nslookup api.yourdomain.com
   ```
   Should return your EC2 IP.

### Step 2: Install Nginx and Certbot

SSH into your EC2 instance:

```bash
ssh -i your-key.pem ubuntu@13.201.189.218
```

Install Nginx and Certbot:

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Nginx (if not already installed)
sudo apt install -y nginx

# Install Certbot for Let's Encrypt
sudo apt install -y certbot python3-certbot-nginx

# Start and enable Nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

### Step 3: Configure EC2 Security Group

1. Go to **EC2 Console** → Your instance → **Security** tab
2. Click on **Security groups**
3. Edit **Inbound rules**:
   - ✅ HTTP (port 80) - from anywhere (needed for Let's Encrypt)
   - ✅ HTTPS (port 443) - from anywhere
   - ✅ SSH (port 22) - from your IP
4. Save rules

### Step 4: Stop Docker Nginx (Port 8080 Conflict)

Your Docker Compose has an Nginx gateway on port 8080. We'll use host Nginx on ports 80/443:

```bash
cd ~/Timesheet-backend  # or wherever your backend is

# Stop only the api-gateway container, keep other services running
docker-compose stop api-gateway

# Or comment out the api-gateway service in docker-compose.yml temporarily
```

### Step 5: Create Nginx Configuration for Backend Services

Create a new Nginx config file:

```bash
sudo nano /etc/nginx/sites-available/timesheet-backend
```

Paste this configuration (replace `api.yourdomain.com` with your domain):

```nginx
server {
    listen 80;
    server_name api.yourdomain.com;  # Change to your domain

    # Let's Encrypt challenge location (will be auto-configured by certbot)
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Temporary: Redirect to HTTPS (after SSL setup)
    # For now, proxy to backend services
    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name api.yourdomain.com;  # Change to your domain

    # SSL certificates (will be added by certbot)
    # ssl_certificate /etc/letsencrypt/live/api.yourdomain.com/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/api.yourdomain.com/privkey.pem;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Proxy settings
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Port $server_port;

    # Increase timeouts for long requests
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;

    # Auth service (port 3002)
    location /auth-service/ {
        proxy_pass http://localhost:3002/auth-service/;
    }

    # Save service (port 3000)
    location /save-service/ {
        proxy_pass http://localhost:3000/save-service/;
    }

    # Submit service (port 3001)
    location /submit-service/ {
        proxy_pass http://localhost:3001/submit-service/;
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
```

Save and exit (`Ctrl+X`, then `Y`, then `Enter`).

Enable the site:

```bash
# Create symbolic link
sudo ln -s /etc/nginx/sites-available/timesheet-backend /etc/nginx/sites-enabled/

# Remove default site (optional)
sudo rm /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

# If test passes, reload Nginx
sudo systemctl reload nginx
```

### Step 6: Obtain SSL Certificate from Let's Encrypt

```bash
# Get SSL certificate (replace with your domain and email)
sudo certbot --nginx -d api.yourdomain.com --non-interactive --agree-tos --email your-email@example.com --redirect
```

Certbot will:
- ✅ Verify domain ownership
- ✅ Obtain SSL certificate
- ✅ Update Nginx config with SSL paths
- ✅ Set up auto-renewal
- ✅ Configure HTTPS redirect

### Step 7: Verify HTTPS Works

```bash
# Test your endpoints
curl https://api.yourdomain.com/health
curl https://api.yourdomain.com/auth-service/health
curl https://api.yourdomain.com/save-service/health
```

You should see responses without certificate errors.

### Step 8: Update Frontend Environment Variables

In **AWS Amplify Console**:

1. Go to your Amplify app → **App settings** → **Environment variables**
2. Update:
   ```
   VITE_AUTH_SERVICE_URL=https://api.yourdomain.com
   VITE_BACKEND_URL=https://api.yourdomain.com
   ```
3. **Save** and **Redeploy**

### Step 9: Test Auto-Renewal

Let's Encrypt certificates expire every 90 days. Certbot sets up auto-renewal:

```bash
# Test renewal manually
sudo certbot renew --dry-run

# Check renewal timer
sudo systemctl status certbot.timer
```

Auto-renewal is already configured! ✅

---

## 🚀 Option B: HTTPS Without Domain (Self-Signed Certificate)

**⚠️ Warning**: Self-signed certificates will show browser warnings. Only use this for testing or if you control all clients.

### Step 1: Install Nginx

```bash
sudo apt update
sudo apt install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx
```

### Step 2: Generate Self-Signed Certificate

```bash
# Create directory for certificates
sudo mkdir -p /etc/nginx/ssl

# Generate self-signed certificate (valid for 365 days)
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/selfsigned.key \
  -out /etc/nginx/ssl/selfsigned.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=13.201.189.218"
```

### Step 3: Create Nginx Configuration

```bash
sudo nano /etc/nginx/sites-available/timesheet-backend
```

Paste:

```nginx
server {
    listen 80;
    server_name 13.201.189.218;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name 13.201.189.218;

    ssl_certificate /etc/nginx/ssl/selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/selfsigned.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    location /auth-service/ {
        proxy_pass http://localhost:3002/auth-service/;
    }

    location /save-service/ {
        proxy_pass http://localhost:3000/save-service/;
    }

    location /submit-service/ {
        proxy_pass http://localhost:3001/submit-service/;
    }

    location /health {
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
```

Enable and reload:

```bash
sudo ln -s /etc/nginx/sites-available/timesheet-backend /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Step 4: Update Frontend (with IP)

In AWS Amplify:
```
VITE_AUTH_SERVICE_URL=https://13.201.189.218
VITE_BACKEND_URL=https://13.201.189.218
```

**Note**: Browsers will show "Not Secure" warning. Users must click "Advanced" → "Proceed" to access.

---

## 🐳 Alternative: HTTPS with Docker Nginx

If you prefer to keep everything in Docker, you can set up HTTPS on the Docker Nginx container:

### Step 1: Mount SSL Certificates into Container

```yaml
# In docker-compose.yml, update api-gateway:
api-gateway:
  image: nginx:alpine
  container_name: api-gateway
  ports:
    - "80:80"
    - "443:443"  # Add HTTPS port
  volumes:
    - ./nginx.conf:/etc/nginx/nginx.conf:ro
    - /etc/letsencrypt:/etc/letsencrypt:ro  # Mount Let's Encrypt certs
  depends_on:
    - auth-service
    - save-service
    - submit-service
```

### Step 2: Update nginx.conf with SSL

```nginx
server {
    listen 80;
    server_name api.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/api.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.yourdomain.com/privkey.pem;

    # ... rest of your config
}
```

---

## ✅ Verification Checklist

After setup, verify:

- [ ] HTTPS works: `curl https://your-domain/health`
- [ ] Auth service: `curl https://your-domain/auth-service/health`
- [ ] Save service: `curl https://your-domain/save-service/health`
- [ ] Submit service: `curl https://your-domain/submit-service/health`
- [ ] Security group allows port 443
- [ ] Frontend environment variables updated in Amplify
- [ ] Frontend redeployed with new variables
- [ ] No Mixed Content errors in browser console

## 🔧 Troubleshooting

### Certificate Not Trusted (Self-Signed)

**Symptom**: Browser shows "Your connection is not private"

**Solution**: 
- For testing: Click "Advanced" → "Proceed to site"
- For production: Use Option A with a real domain and Let's Encrypt

### 502 Bad Gateway

**Check**:
```bash
# Verify services are running
docker ps

# Check Nginx logs
sudo tail -f /var/log/nginx/error.log

# Test backend services directly
curl http://localhost:3002/auth-service/health
```

### Certbot Fails with "Connection Refused"

**Solution**:
- Ensure port 80 is open in security group
- Ensure Nginx is running: `sudo systemctl status nginx`
- Check firewall: `sudo ufw status`

### Nginx "Address Already in Use"

**Solution**:
```bash
# Check what's using port 80/443
sudo lsof -i :80
sudo lsof -i :443

# Stop conflicting service or change Nginx ports
```

## 📚 Additional Resources

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Nginx Reverse Proxy Guide](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)
- [AWS EC2 Security Groups](https://docs.aws.amazon.com/AEC2/latest/UserGuide/working-with-security-groups.html)

---

## 🎉 Success!

Once HTTPS is configured:

1. ✅ Your backend is accessible over HTTPS
2. ✅ Frontend can make secure API calls
3. ✅ No more Mixed Content errors
4. ✅ SSL certificate auto-renews (Let's Encrypt)

**Next Steps**:
- Update AWS Amplify environment variables with HTTPS URLs
- Redeploy frontend
- Test registration/login flow

