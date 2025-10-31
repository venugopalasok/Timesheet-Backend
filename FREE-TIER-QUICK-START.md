# ⚡ Free Tier Quick Start (30 Minutes)

Get your timesheet app running on AWS **completely FREE** in under 30 minutes!

## 🎯 What You'll Have

- ✅ Backend API running on AWS EC2 (free)
- ✅ Frontend on AWS Amplify (free)
- ✅ MongoDB Atlas database (free forever)
- ✅ Message queue with AWS SQS (free)
- ✅ **Total Cost: $0 for 12 months!**

---

## 📦 Quick Commands

### 1️⃣ MongoDB Atlas (2 minutes)

```bash
# Go to: https://www.mongodb.com/cloud/atlas/register
# Click: Build a Database → FREE M0 → AWS → us-east-1
# Create user, whitelist 0.0.0.0/0
# Copy connection string
```

---

### 2️⃣ AWS SQS (2 minutes)

```bash
# Open: https://console.aws.amazon.com/sqs
# Create queue: "timesheet-notifications" (Standard)
# Copy queue URL

# Create IAM user:
# IAM → Users → Add User → "timesheet-sqs" → Programmatic access
# Attach: AmazonSQSFullAccess
# Copy Access Key ID & Secret
```

---

### 3️⃣ Launch EC2 (3 minutes)

```bash
# Open: https://console.aws.amazon.com/ec2
# Launch Instance:
#   - Ubuntu 22.04 LTS
#   - t2.micro ✓ Free tier
#   - Create key pair: timesheet-key.pem
#   - Security group: Allow 22, 80, 443, 8080
#   - Launch

# Download timesheet-key.pem
# Copy public IP address
```

---

### 4️⃣ Deploy Backend (10 minutes)

```bash
# SSH into EC2
chmod 400 timesheet-key.pem
ssh -i timesheet-key.pem ubuntu@YOUR_EC2_IP

# One-line setup script
curl -fsSL https://get.docker.com | sh && \
sudo usermod -aG docker ubuntu && \
sudo apt install -y docker-compose git && \
sudo fallocate -l 2G /swapfile && \
sudo chmod 600 /swapfile && \
sudo mkswap /swapfile && \
sudo swapon /swapfile && \
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Re-login for Docker
exit
ssh -i timesheet-key.pem ubuntu@YOUR_EC2_IP

# Clone and configure
cd ~
git clone YOUR_REPO_URL Timesheet-backend
cd Timesheet-backend

# Create .env file
cat > .env << EOF
MONGODB_ATLAS_URI=mongodb+srv://user:pass@cluster.mongodb.net/timesheet
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY
AWS_SECRET_ACCESS_KEY=YOUR_SECRET_KEY
SQS_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/123/timesheet-notifications
JWT_SECRET=$(openssl rand -hex 32)
EOF

# Install AWS SDK in services (if not already in package.json)
cd save-service && npm install aws-sdk && cd ..
cd submit-service && npm install aws-sdk && cd ..
cd notification-service && npm install aws-sdk && cd ..

# Start services
docker-compose -f docker-compose.free-tier.yml up -d

# Check status
docker-compose -f docker-compose.free-tier.yml ps
docker-compose -f docker-compose.free-tier.yml logs -f
```

---

### 5️⃣ Deploy Frontend (10 minutes)

#### Option A: AWS Amplify (Easiest)

```bash
# 1. Push to GitHub
cd Timesheet_Fe_ts
git init
git add .
git commit -m "Initial"
git remote add origin YOUR_REPO_URL
git push -u origin main

# 2. Go to: https://console.aws.amazon.com/amplify
# 3. Connect GitHub → Select repo → Deploy
# 4. Add environment variable:
#    VITE_API_URL = http://YOUR_EC2_IP
# 5. Copy Amplify URL
```

#### Option B: S3 + CloudFront

```bash
cd Timesheet_Fe_ts

# Add API endpoint
echo "VITE_API_URL=http://YOUR_EC2_IP" > .env.production

# Build
npm run build

# Upload to S3 (create bucket first in console)
aws s3 mb s3://timesheet-app-$(date +%s)
aws s3 sync dist/ s3://YOUR_BUCKET_NAME --acl public-read

# Enable static hosting in S3 console
# Create CloudFront distribution → point to S3
```

---

### 6️⃣ Update CORS (2 minutes)

```bash
# SSH back into EC2
ssh -i timesheet-key.pem ubuntu@YOUR_EC2_IP
cd ~/Timesheet-backend

# Add frontend URL to .env
echo "FRONTEND_URL=https://your-amplify-url.amplifyapp.com" >> .env

# Restart services
docker-compose -f docker-compose.free-tier.yml restart
```

---

## ✅ Verify Everything Works

```bash
# Test backend
curl http://YOUR_EC2_IP/save-service/health
# Expected: {"status":"OK"}

# Test frontend
# Visit: https://your-amplify-url.amplifyapp.com
# Try login and create timesheet
```

---

## 🎓 Architecture Summary

```
┌─────────────────────────────────────────┐
│         Your Application (FREE)          │
├─────────────────────────────────────────┤
│                                           │
│  Frontend: AWS Amplify                   │
│  ↓ API calls to                          │
│  Backend: EC2 t2.micro (1GB RAM)         │
│    ├─ nginx (API Gateway)                │
│    ├─ Auth Service                       │
│    ├─ Save Service                       │
│    ├─ Submit Service                     │
│    └─ Notification Service               │
│  ↓ Connects to                           │
│  Database: MongoDB Atlas M0 (512MB)      │
│  Queue: AWS SQS (1M requests/month)      │
│                                           │
│  Total: $0/month for 12 months! 🎉       │
└─────────────────────────────────────────┘
```

---

## 🔥 Common Issues

### Docker permission denied
```bash
sudo usermod -aG docker ubuntu
exit  # Re-login
```

### Out of memory
```bash
# Add more swap
sudo fallocate -l 4G /swapfile2
sudo chmod 600 /swapfile2
sudo mkswap /swapfile2
sudo swapon /swapfile2
```

### Can't reach MongoDB
```bash
# Test DNS
nslookup cluster.mongodb.net

# Check credentials
docker logs save-service
```

### Frontend can't reach backend
```bash
# Check CORS in your services
# Add: app.use(cors({ origin: process.env.FRONTEND_URL }))

# Verify security group allows port 80
```

---

## 📊 Monitor Free Tier Usage

```bash
# AWS Billing Dashboard
# https://console.aws.amazon.com/billing

# Set billing alert for $1:
# Billing → Budgets → Create Budget
```

---

## 🚀 Performance Tips for t2.micro

1. **Limit container memory** (already set in docker-compose.free-tier.yml)
2. **Use swap space** (2GB recommended)
3. **Enable gzip** in nginx
4. **Minimize Docker images** (use alpine variants)
5. **Monitor with `docker stats`**

---

## 📈 Expected Performance

- **Response Time**: 200-500ms (acceptable)
- **Concurrent Users**: 5-10 (low traffic)
- **Database Size**: Up to 512MB
- **Messages/Month**: Up to 1 million

**Perfect for:**
- Personal projects
- Portfolio demos
- MVPs
- Learning/testing

---

## 🎯 What's Next?

After your app is live:

1. **Custom Domain**: Route53 ($0.50/month)
2. **HTTPS/SSL**: Let's Encrypt (free)
3. **Monitoring**: CloudWatch (free tier)
4. **Backups**: MongoDB Atlas auto-backups (included)
5. **CI/CD**: GitHub Actions (free for public repos)

---

## 💡 Costs After 12 Months

| Service | Monthly Cost |
|---------|-------------|
| EC2 t2.micro | ~$8 |
| Data Transfer | ~$2 |
| S3 + CloudFront | ~$3 |
| **Total** | **~$13/month** |

MongoDB Atlas M0 & SQS stay FREE forever! ✨

---

## 🆘 Get Help

- **Issues?** Check logs: `docker-compose -f docker-compose.free-tier.yml logs -f`
- **AWS Support**: Free tier includes basic support
- **MongoDB**: https://www.mongodb.com/community/forums

---

## 🎉 Success!

**You now have a production-ready full-stack app running on AWS for FREE!**

**Your URLs:**
- Frontend: `https://your-app.amplifyapp.com`
- Backend: `http://YOUR_EC2_IP`
- Database: `cluster.mongodb.net`

**Share your project!** 🚀

---

## 📝 Quick Reference

```bash
# SSH
ssh -i timesheet-key.pem ubuntu@YOUR_EC2_IP

# View logs
cd ~/Timesheet-backend
docker-compose -f docker-compose.free-tier.yml logs -f

# Restart
docker-compose -f docker-compose.free-tier.yml restart

# Update code
git pull
docker-compose -f docker-compose.free-tier.yml up -d --build

# Check resources
docker stats
free -h
df -h
```

---

**Duration: 30 minutes | Cost: $0 | Value: Priceless 💎**

