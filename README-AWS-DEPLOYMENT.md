# 🚀 AWS Deployment Guide - Timesheet Application

Complete guide for deploying your timesheet application to AWS Cloud.

## 📚 Documentation Overview

This repository contains multiple deployment guides tailored to different needs:

| Document | Purpose | Best For | Time Required |
|----------|---------|----------|---------------|
| **[FREE-TIER-QUICK-START.md](FREE-TIER-QUICK-START.md)** | Fast deployment with copy-paste commands | Getting started quickly | 30 minutes |
| **[FREE-TIER-DEPLOYMENT.md](FREE-TIER-DEPLOYMENT.md)** | Detailed step-by-step free tier guide | Complete understanding | 1 hour |
| **[AWS-COST-COMPARISON.md](AWS-COST-COMPARISON.md)** | Cost analysis of different AWS options | Budget planning | 15 minutes |
| **setup-ec2-free-tier.sh** | Automated deployment script | Hands-off deployment | 20 minutes |

---

## 🎯 Quick Start (Choose Your Path)

### Option 1: Automated Script (Easiest) ⚡

```bash
# On your EC2 instance
chmod +x setup-ec2-free-tier.sh
./setup-ec2-free-tier.sh
```

**What it does:**
- ✅ Installs Docker & Docker Compose
- ✅ Creates swap space for 1GB RAM optimization
- ✅ Configures firewall
- ✅ Clones your repository
- ✅ Sets up environment variables
- ✅ Builds and starts all services
- ✅ Verifies deployment

### Option 2: Manual Deployment (More Control) 📋

Follow **[FREE-TIER-QUICK-START.md](FREE-TIER-QUICK-START.md)** for copy-paste commands.

### Option 3: Detailed Learning (Best Understanding) 📖

Follow **[FREE-TIER-DEPLOYMENT.md](FREE-TIER-DEPLOYMENT.md)** for comprehensive explanations.

---

## 💰 Cost: $0 for 12 Months!

Your application uses **100% FREE AWS resources**:

| Service | Free Tier | What You Get |
|---------|-----------|--------------|
| **EC2 t2.micro** | 750 hrs/month | Backend server |
| **S3** | 5GB storage | Frontend hosting |
| **CloudFront** | 1TB transfer | CDN distribution |
| **MongoDB Atlas** | 512MB forever | Database |
| **AWS SQS** | 1M requests/month | Message queue |

**Total Savings:** ~$38/month × 12 = **$456/year!** 🎉

See **[AWS-COST-COMPARISON.md](AWS-COST-COMPARISON.md)** for detailed cost analysis.

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────┐
│              YOUR APPLICATION                    │
├─────────────────────────────────────────────────┤
│                                                  │
│  Frontend (React + Vite)                        │
│    ↓ hosted on                                  │
│  AWS Amplify or S3 + CloudFront                 │
│                                                  │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━    │
│                                                  │
│  Backend (Node.js Microservices)                │
│    ↓ running on                                 │
│  EC2 t2.micro (1GB RAM, Docker Compose)         │
│    ├─ API Gateway (nginx)                       │
│    ├─ Auth Service (JWT authentication)         │
│    ├─ Save Service (timesheet CRUD)             │
│    ├─ Submit Service (submission logic)         │
│    └─ Notification Service (async events)       │
│                                                  │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━    │
│                                                  │
│  Database                                        │
│    ↓ hosted on                                  │
│  MongoDB Atlas M0 (512MB, FREE forever!)        │
│                                                  │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━    │
│                                                  │
│  Message Queue                                   │
│    ↓ using                                      │
│  AWS SQS (FREE tier, 1M requests/month)         │
│                                                  │
└─────────────────────────────────────────────────┘
```

---

## 📦 What's Included

### New Files for AWS Deployment

```
Timesheet-backend/
├── 📄 README-AWS-DEPLOYMENT.md           ← You are here
├── 📄 FREE-TIER-QUICK-START.md           ← 30-min quick guide
├── 📄 FREE-TIER-DEPLOYMENT.md            ← Complete deployment guide
├── 📄 AWS-COST-COMPARISON.md             ← Cost analysis
├── 🐳 docker-compose.free-tier.yml       ← Optimized for 1GB RAM
├── 📝 .env.free-tier.example             ← Environment template
├── 🔧 setup-ec2-free-tier.sh             ← Automated setup script
├── 🔧 deploy-free-tier.sh                ← Alternative deploy script
└── shared/
    ├── sqs-helper.js                     ← SQS utilities (replaces RabbitMQ)
    └── package.json                      ← AWS SDK dependency
```

---

## 🚀 Deployment Prerequisites

Before you start, you'll need:

### 1. AWS Account (Free Tier)
- Sign up: [aws.amazon.com](https://aws.amazon.com)
- No credit card charges for free tier resources
- **Set up billing alerts!**

### 2. MongoDB Atlas Account (Free)
- Sign up: [mongodb.com/cloud/atlas](https://www.mongodb.com/cloud/atlas)
- No credit card required
- 512MB free forever

### 3. Tools Installed Locally
- Git
- SSH client
- AWS CLI (optional but helpful)

### 4. Accounts Ready
- GitHub account (for code repository)
- Domain name (optional, for custom URL)

---

## 📋 Deployment Checklist

### Phase 1: Pre-Deployment (15 minutes)

- [ ] Create AWS account
- [ ] Create MongoDB Atlas account
- [ ] Create MongoDB cluster (M0 free tier)
- [ ] Get MongoDB connection string
- [ ] Create AWS SQS queue
- [ ] Create IAM user for SQS access
- [ ] Note down all credentials

### Phase 2: Backend Deployment (20 minutes)

- [ ] Launch EC2 t2.micro instance
- [ ] Download SSH key (.pem file)
- [ ] Note EC2 public IP
- [ ] SSH into EC2 instance
- [ ] Run setup script or manual commands
- [ ] Configure environment variables
- [ ] Build and start Docker containers
- [ ] Verify services are running

### Phase 3: Frontend Deployment (15 minutes)

- [ ] Push code to GitHub
- [ ] Deploy to AWS Amplify (or S3)
- [ ] Update API endpoint configuration
- [ ] Test frontend can reach backend
- [ ] Verify CORS is configured

### Phase 4: Post-Deployment (10 minutes)

- [ ] Test complete user flow
- [ ] Set up AWS billing alerts
- [ ] Configure SSL/HTTPS (optional)
- [ ] Set up custom domain (optional)
- [ ] Document your deployment

---

## 🎮 Quick Commands Reference

### SSH into EC2
```bash
chmod 400 timesheet-key.pem
ssh -i timesheet-key.pem ubuntu@YOUR_EC2_IP
```

### View Application Logs
```bash
cd ~/Timesheet-backend
docker-compose -f docker-compose.free-tier.yml logs -f
```

### Restart Services
```bash
docker-compose -f docker-compose.free-tier.yml restart
```

### Stop Services
```bash
docker-compose -f docker-compose.free-tier.yml down
```

### Start Services
```bash
docker-compose -f docker-compose.free-tier.yml up -d
```

### Check Resource Usage
```bash
docker stats
free -h
df -h
```

### Update Application
```bash
cd ~/Timesheet-backend
git pull
docker-compose -f docker-compose.free-tier.yml up -d --build
```

---

## 🔧 Configuration

### Environment Variables

All configuration is done via `.env` file:

```bash
# MongoDB Atlas (FREE forever - 512MB)
MONGODB_ATLAS_URI=mongodb+srv://user:pass@cluster.mongodb.net/timesheet

# AWS SQS (FREE - 1M requests/month)
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=YOUR_KEY
AWS_SECRET_ACCESS_KEY=YOUR_SECRET
SQS_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/123/queue-name

# Security
JWT_SECRET=your-random-secret-key

# CORS
FRONTEND_URL=https://your-app.amplifyapp.com
```

See `.env.free-tier.example` for complete template.

---

## 🎯 Service Endpoints

After deployment, your services will be available at:

| Service | Internal | External | Purpose |
|---------|----------|----------|---------|
| **API Gateway** | localhost:80 | `http://YOUR_EC2_IP` | Main entry point |
| **Auth Service** | localhost:3002 | `http://YOUR_EC2_IP:3002` | Authentication |
| **Save Service** | localhost:3000 | `http://YOUR_EC2_IP:3000` | Save timesheets |
| **Submit Service** | localhost:3001 | `http://YOUR_EC2_IP:3001` | Submit timesheets |
| **Notifications** | localhost:3003 | `http://YOUR_EC2_IP:3003` | Event processing |

---

## 📊 Resource Usage (1GB RAM)

Optimized memory allocation for t2.micro:

| Component | Memory | CPU |
|-----------|--------|-----|
| nginx (API Gateway) | 128MB | 0.2 cores |
| Auth Service | 256MB | 0.25 cores |
| Save Service | 256MB | 0.25 cores |
| Submit Service | 256MB | 0.25 cores |
| Notification Service | 128MB | 0.05 cores |
| **Total** | **~1024MB** | **1 core** |

Plus 2GB swap space for safety buffer.

---

## 🔒 Security Best Practices

### Implemented by Default
- ✅ Firewall (UFW) with minimal open ports
- ✅ JWT authentication
- ✅ Environment variables for secrets
- ✅ MongoDB Atlas network security
- ✅ IAM user with limited permissions

### Recommended Additions
- [ ] Change default ports
- [ ] Restrict MongoDB Atlas to EC2 IP only
- [ ] Set up CloudWatch monitoring
- [ ] Enable AWS GuardDuty
- [ ] Configure automated backups
- [ ] Set up SSL/HTTPS with Let's Encrypt
- [ ] Use AWS Secrets Manager (paid)

### Enable HTTPS (Free with Let's Encrypt)
```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
```

---

## 📈 Monitoring & Maintenance

### Check Service Health
```bash
curl http://localhost/save-service/health
```

### Monitor Container Stats
```bash
docker stats
```

### Check Memory Usage
```bash
free -h
```

### View System Load
```bash
htop
```

### Check Disk Space
```bash
df -h
```

### MongoDB Atlas Dashboard
- Login to [cloud.mongodb.com](https://cloud.mongodb.com)
- View metrics, connections, storage usage

### AWS Billing Dashboard
- Monitor free tier usage
- Set up billing alerts
- View cost breakdowns

---

## 🐛 Troubleshooting

### Services Won't Start
```bash
# Check logs
docker-compose -f docker-compose.free-tier.yml logs

# Check memory
free -h

# Restart
sudo reboot
```

### Can't Connect to MongoDB
```bash
# Test DNS
nslookup cluster.mongodb.net

# Test from container
docker exec -it save-service sh
nc -zv cluster.mongodb.net 27017
```

### Out of Memory
```bash
# Add more swap
sudo fallocate -l 4G /swapfile2
sudo chmod 600 /swapfile2
sudo mkswap /swapfile2
sudo swapon /swapfile2
```

### Frontend Can't Reach Backend
- Check EC2 security group allows port 80
- Verify CORS configuration
- Check nginx logs

### SQS Messages Not Processing
- Verify IAM permissions
- Check AWS credentials in .env
- View SQS queue in AWS console

---

## 🎓 Learning Resources

### AWS Documentation
- [EC2 Free Tier](https://aws.amazon.com/ec2/pricing/)
- [S3 Documentation](https://docs.aws.amazon.com/s3/)
- [CloudFront Guide](https://docs.aws.amazon.com/cloudfront/)
- [SQS Tutorial](https://docs.aws.amazon.com/sqs/)

### MongoDB Atlas
- [Atlas Documentation](https://docs.atlas.mongodb.com/)
- [Free Tier Details](https://www.mongodb.com/pricing)

### Docker
- [Docker Compose](https://docs.docker.com/compose/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

---

## 🚀 Scaling Up Later

When you outgrow free tier:

### Step 1: Upgrade EC2
```bash
# t2.micro (1GB) → t3.small (2GB) → t3.medium (4GB)
# Done via AWS Console in minutes
```

### Step 2: Upgrade MongoDB
```bash
# M0 (512MB, FREE) → M10 (2GB, $57/mo) → M20 (4GB, $115/mo)
```

### Step 3: Add Load Balancer
```bash
# Application Load Balancer for multiple EC2 instances
```

### Step 4: Consider ECS/Fargate
```bash
# Move from EC2 to container orchestration
```

See **[AWS-COST-COMPARISON.md](AWS-COST-COMPARISON.md)** for upgrade paths.

---

## 💡 Tips for Success

1. **Start Simple**: Use free tier, learn AWS, then scale
2. **Monitor Costs**: Set billing alerts early
3. **Automate Backups**: MongoDB Atlas has this built-in
4. **Use CloudWatch**: Basic monitoring is free
5. **Keep Learning**: AWS has great documentation
6. **Join Communities**: AWS forums, Reddit r/aws
7. **Document Everything**: Keep notes of your setup

---

## 🎉 What You'll Achieve

By following this guide, you'll have:

- ✅ **Production-grade deployment** on AWS
- ✅ **Zero cost** for 12 months (then ~$13-17/month)
- ✅ **Scalable architecture** ready to grow
- ✅ **Real cloud experience** for your resume
- ✅ **Live URLs** to share with others
- ✅ **Professional portfolio** piece

---

## 📞 Support & Community

- **GitHub Issues**: Report problems or ask questions
- **AWS Support**: Free tier includes basic support
- **MongoDB Community**: Active forums and chat
- **Stack Overflow**: Tag with `aws`, `docker`, `mongodb`

---

## 📝 License

This deployment guide is part of your Timesheet Application project.

---

## 🙏 Acknowledgments

- AWS for comprehensive free tier
- MongoDB Atlas for permanent free tier
- Docker for containerization
- Open source community

---

**Ready to deploy? Start with [FREE-TIER-QUICK-START.md](FREE-TIER-QUICK-START.md)!** 🚀

---

## 📅 Deployment Versions

| Date | Version | Changes |
|------|---------|---------|
| 2025-10-31 | 1.0.0 | Initial AWS deployment guide |

---

**Questions?** Open an issue or check the documentation files above.

**Good luck with your deployment!** 🎉

