# 🔒 Self-Signed SSL Certificate Setup

This guide sets up HTTPS using a self-signed certificate for your EC2 backend. This works without a domain name but browsers will show a security warning that users need to accept.

## ⚠️ Important Notes

- **Browser Warning**: Users will see "Your connection is not private" - they need to click "Advanced" → "Proceed to site"
- **Production**: For production, use a real domain with Let's Encrypt (see `HTTPS_SETUP_GUIDE.md`)
- **Testing**: Perfect for development and testing without a domain

## 🚀 Quick Setup Steps

### Step 1: SSH into EC2

```bash
ssh -i your-key.pem ubuntu@13.201.189.218
```

### Step 2: Install Nginx (if not installed)

```bash
sudo apt update
sudo apt install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx
```

### Step 3: Generate Self-Signed Certificate

```bash
# Create directory for SSL certificates
sudo mkdir -p /etc/nginx/ssl

# Generate self-signed certificate (valid for 1 year)
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/selfsigned.key \
  -out /etc/nginx/ssl/selfsigned.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=13.201.189.218"

# Set proper permissions
sudo chmod 600 /etc/nginx/ssl/selfsigned.key
sudo chmod 644 /etc/nginx/ssl/selfsigned.crt
```

**Alternative: Generate with prompts** (for more details):

```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/selfsigned.key \
  -out /etc/nginx/ssl/selfsigned.crt
```

Fill in the prompts:
- Country Name: `US`
- State: `State`
- City: `City`
- Organization: `Your Company`
- Common Name: `13.201.189.218` (your EC2 IP)

### Step 4: Create Nginx Configuration

```bash
sudo nano /etc/nginx/sites-available/timesheet-backend
```

Paste this configuration:

```nginx
# HTTP server - redirect to HTTPS
server {
    listen 80;
    server_name 13.201.189.218;

    # Redirect all HTTP traffic to HTTPS
    return 301 https://$server_name$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name 13.201.189.218;

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

    # CORS headers (adjust as needed for your frontend domain)
    add_header 'Access-Control-Allow-Origin' '*' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, PATCH, OPTIONS' always;
    add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization, X-Requested-With' always;
    add_header 'Access-Control-Max-Age' '3600' always;

    # Handle preflight requests
    if ($request_method = 'OPTIONS') {
        add_header 'Access-Control-Allow-Origin' '*';
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, PATCH, OPTIONS';
        add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization, X-Requested-With';
        add_header 'Access-Control-Max-Age' '3600';
        add_header 'Content-Type' 'text/plain; charset=utf-8';
        add_header 'Content-Length' 0;
        return 204;
    }

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
        proxy_http_version 1.1;
    }

    # Save service (port 3000)
    location /save-service/ {
        proxy_pass http://localhost:3000/save-service/;
        proxy_http_version 1.1;
    }

    # Submit service (port 3001)
    location /submit-service/ {
        proxy_pass http://localhost:3001/submit-service/;
        proxy_http_version 1.1;
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

Save and exit: `Ctrl+X`, then `Y`, then `Enter`

### Step 5: Enable Site and Test Configuration

```bash
# Enable the site
sudo ln -s /etc/nginx/sites-available/timesheet-backend /etc/nginx/sites-enabled/

# Remove default site (optional)
sudo rm /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t
```

If test passes, reload Nginx:

```bash
sudo systemctl reload nginx
```

### Step 6: Configure EC2 Security Group

1. Go to **AWS Console** → **EC2** → Your instance
2. Click **Security** tab → Click **Security groups**
3. Edit **Inbound rules**:
   - ✅ **HTTPS (443)** - from anywhere (0.0.0.0/0)
   - ✅ **HTTP (80)** - from anywhere (for redirect)
   - ✅ **SSH (22)** - from your IP
4. Save rules

### Step 7: Verify HTTPS Works

```bash
# Test HTTPS endpoint (will show SSL warning, ignore for now)
curl -k https://13.201.189.218/health

# Test service endpoints
curl -k https://13.201.189.218/auth-service/health
curl -k https://13.201.189.218/save-service/health
curl -k https://13.201.189.218/submit-service/health
```

The `-k` flag ignores SSL certificate verification (since it's self-signed).

### Step 8: Update Frontend Environment Variables

In **AWS Amplify Console**:

1. Go to your Amplify app → **App settings** → **Environment variables**
2. Update:
   ```
   VITE_AUTH_SERVICE_URL=https://13.201.189.218
   VITE_BACKEND_URL=https://13.201.189.218
   ```
3. **Save** and **Redeploy** your frontend

### Step 9: Handle Browser Warning

When accessing your frontend:
1. Browser will show "Your connection is not private"
2. Click **"Advanced"** or **"Show Details"**
3. Click **"Proceed to site (unsafe)"** or **"Accept the Risk and Continue"**

**Note**: This is expected with self-signed certificates. For production, use a real certificate.

---

## 🔄 Automated Setup Script

For faster setup, use the provided script:

```bash
# Download and run
cd ~/Timesheet-backend
chmod +x setup-selfsigned-ssl.sh
./setup-selfsigned-ssl.sh
```

---

## ✅ Verification Checklist

- [ ] SSL certificate generated (`/etc/nginx/ssl/selfsigned.crt`)
- [ ] Nginx configuration created
- [ ] Nginx test passed (`sudo nginx -t`)
- [ ] Nginx reloaded successfully
- [ ] Security group allows port 443
- [ ] HTTPS endpoint responds (`curl -k https://13.201.189.218/health`)
- [ ] Frontend environment variables updated
- [ ] Frontend redeployed

---

## 🔧 Troubleshooting

### "502 Bad Gateway" Error

**Check if services are running:**
```bash
# Check Docker containers
docker ps

# Test services directly
curl http://localhost:3002/auth-service/health
curl http://localhost:3000/save-service/health
```

**Check Nginx logs:**
```bash
sudo tail -f /var/log/nginx/error.log
```

### "Connection Refused" or Timeout

**Check security group:**
- Ensure port 443 is open in EC2 Security Group
- Ensure Nginx is listening on port 443:
  ```bash
  sudo netstat -tlnp | grep :443
  ```

### Certificate Error in Browser

This is **normal** with self-signed certificates. Users must:
1. Click "Advanced"
2. Click "Proceed to site"

To avoid this, use Let's Encrypt with a real domain.

### Mixed Content Error Persists

**Check:**
1. Frontend is using `https://` URLs (not `http://`)
2. Environment variables are set correctly in Amplify
3. Frontend has been redeployed after changing variables

**Debug in browser console:**
- Check Network tab - see what URL the frontend is calling
- Ensure all API calls use `https://`

---

## 🎯 Next Steps

### Option 1: Keep Self-Signed (For Testing)
- Current setup works for development/testing
- Users accept browser warning
- No additional configuration needed

### Option 2: Upgrade to Let's Encrypt (For Production)
1. Get a domain name
2. Point domain to EC2 IP
3. Follow `HTTPS_SETUP_GUIDE.md` for Let's Encrypt setup
4. Get a trusted certificate (no browser warnings)

---

## 📝 Quick Reference

**Test HTTPS:**
```bash
curl -k https://13.201.189.218/health
```

**Check Nginx status:**
```bash
sudo systemctl status nginx
```

**View Nginx logs:**
```bash
sudo tail -f /var/log/nginx/error.log
```

**Reload Nginx after config changes:**
```bash
sudo nginx -t && sudo systemctl reload nginx
```

**Check SSL certificate:**
```bash
sudo openssl x509 -in /etc/nginx/ssl/selfsigned.crt -text -noout
```

---

## 🎉 Success!

Your backend is now accessible over HTTPS with a self-signed certificate!

**What works:**
- ✅ HTTPS encryption
- ✅ No Mixed Content errors
- ✅ Secure API communication

**What to expect:**
- ⚠️ Browser security warnings (normal for self-signed)
- ⚠️ Users need to accept certificate manually

For production without warnings, set up a domain with Let's Encrypt! 🚀

