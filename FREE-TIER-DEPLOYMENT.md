# 🎉 AWS Free Tier Deployment Guide

Deploy your Timesheet Application **completely FREE** for 12 months using AWS Free Tier!

## 💰 What You Get for FREE

| Service | Free Tier Benefit | Value |
|---------|------------------|-------|
| EC2 (t2.micro) | 750 hours/month | ~$8/month |
| S3 + CloudFront | 5GB + 1TB transfer | ~$10/month |
| MongoDB Atlas | 512MB forever | ~$15/month |
| AWS SQS | 1M requests/month | ~$5/month |
| **Total Savings** | | **~$38/month** |

## 📋 Prerequisites

- AWS Account (free tier eligible)
- MongoDB Atlas Account (no credit card required)
- GitHub Account (for Amplify deployment)
- Basic terminal/SSH knowledge

---

## 🚀 Deployment Steps

### Part 1: Setup MongoDB Atlas (5 minutes)

1. **Create Account**: Visit [MongoDB Atlas](https://www.mongodb.com/cloud/atlas/register)

2. **Create Free Cluster**:
   - Click "Build a Database"
   - Choose **M0 Free** tier
   - Provider: **AWS**
   - Region: **us-east-1** (or your preferred region)
   - Cluster Name: `timesheet-cluster`

3. **Create Database User**:
   - Database Access → Add New User
   - Username: `timesheet_user`
   - Password: (generate strong password)
   - Role: **Read and write to any database**

4. **Whitelist IP**:
   - Network Access → Add IP Address
   - Add: `0.0.0.0/0` (allow from anywhere)
   - Or add your EC2 IP later for security

5. **Get Connection String**:
   - Clusters → Connect → Connect your application
   - Copy the connection string:
   ```
   mongodb+srv://timesheet_user:<password>@timesheet-cluster.xxxxx.mongodb.net/timesheet?retryWrites=true&w=majority
   ```
   - Replace `<password>` with your actual password

---

### Part 2: Setup AWS SQS (5 minutes)

1. **Open SQS Console**: [AWS SQS](https://console.aws.amazon.com/sqs)

2. **Create Queue**:
   - Click "Create queue"
   - Type: **Standard Queue**
   - Name: `timesheet-notifications`
   - Leave defaults
   - Click "Create queue"

3. **Copy Queue URL**:
   ```
   https://sqs.us-east-1.amazonaws.com/123456789012/timesheet-notifications
   ```

4. **Create IAM User for SQS Access**:
   - Go to IAM Console → Users → Add User
   - Username: `timesheet-sqs-user`
   - Access type: **Programmatic access**
   - Attach policy: **AmazonSQSFullAccess**
   - Copy `Access Key ID` and `Secret Access Key`

---

### Part 3: Launch EC2 Instance (10 minutes)

1. **Launch Instance**:
   - Go to [EC2 Console](https://console.aws.amazon.com/ec2)
   - Click "Launch Instance"
   - Name: `timesheet-backend`

2. **Choose AMI**:
   - **Ubuntu Server 22.04 LTS** (free tier eligible)

3. **Choose Instance Type**:
   - **t2.micro** (1 vCPU, 1GB RAM) ✓ Free tier eligible

4. **Key Pair**:
   - Create new key pair: `timesheet-key.pem`
   - Download and save securely

5. **Configure Security Group**:
   - Allow SSH (port 22) from your IP
   - Allow HTTP (port 80) from anywhere
   - Allow HTTPS (port 443) from anywhere
   - Allow Custom TCP (port 8080) from anywhere

6. **Configure Storage**:
   - 8GB (default) ✓ Stays within free tier

7. **Launch** and wait for instance to start

8. **Get Public IP**:
   - Copy the public IPv4 address (e.g., `3.15.123.45`)

---

### Part 4: Deploy Backend to EC2 (15 minutes)

1. **SSH into EC2**:
   ```bash
   chmod 400 timesheet-key.pem
   ssh -i timesheet-key.pem ubuntu@YOUR_EC2_PUBLIC_IP
   ```

2. **Run Deployment Script**:
   ```bash
   # Download and run setup script
   curl -O https://raw.githubusercontent.com/YOUR_REPO/deploy-free-tier.sh
   chmod +x deploy-free-tier.sh
   ./deploy-free-tier.sh
   ```

   **OR manually**:

   ```bash
   # Update system
   sudo apt update && sudo apt upgrade -y
   
   # Install Docker
   sudo apt install -y docker.io docker-compose git
   sudo systemctl enable docker
   sudo systemctl start docker
   sudo usermod -aG docker ubuntu
   
   # Re-login for Docker permissions
   exit
   ssh -i timesheet-key.pem ubuntu@YOUR_EC2_PUBLIC_IP
   
   # Clone repository
   cd ~
   git clone https://github.com/YOUR_USERNAME/Timesheet-backend.git
   cd Timesheet-backend
   
   # Create environment file
   cp .env.free-tier.example .env
   nano .env  # Edit with your values
   
   # Create swap (important for 1GB RAM)
   sudo fallocate -l 2G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
   
   # Build and start services
   docker-compose -f docker-compose.free-tier.yml build
   docker-compose -f docker-compose.free-tier.yml up -d
   ```

3. **Verify Services**:
   ```bash
   docker-compose -f docker-compose.free-tier.yml ps
   docker-compose -f docker-compose.free-tier.yml logs -f
   ```

4. **Test API**:
   ```bash
   curl http://localhost/save-service/health
   # Should return: {"status":"OK"}
   ```

---

### Part 5: Deploy Frontend (10 minutes)

#### Option A: AWS Amplify (Recommended)

1. **Push to GitHub**:
   ```bash
   cd Timesheet_Fe_ts
   git init
   git add .
   git commit -m "Initial commit"
   git push origin main
   ```

2. **Deploy with Amplify**:
   - Go to [AWS Amplify Console](https://console.aws.amazon.com/amplify)
   - Click "New app" → "Host web app"
   - Connect GitHub repository
   - Select `Timesheet_Fe_ts` repo
   - Build settings (auto-detected):
     ```yaml
     version: 1
     frontend:
       phases:
         preBuild:
           commands:
             - npm ci
         build:
           commands:
             - npm run build
       artifacts:
         baseDirectory: dist
         files:
           - '**/*'
     ```
   - Add environment variable:
     - Key: `VITE_API_URL`
     - Value: `http://YOUR_EC2_PUBLIC_IP`
   - Save and Deploy

3. **Get URL**: Copy Amplify URL (e.g., `https://main.d1234.amplifyapp.com`)

#### Option B: S3 + CloudFront (Manual)

1. **Build Frontend**:
   ```bash
   cd Timesheet_Fe_ts
   
   # Update API endpoint
   echo "VITE_API_URL=http://YOUR_EC2_PUBLIC_IP" > .env.production
   
   npm run build
   ```

2. **Create S3 Bucket**:
   - Go to S3 Console
   - Create bucket: `timesheet-frontend-RANDOM123`
   - Uncheck "Block all public access"
   - Enable static website hosting

3. **Upload Build**:
   ```bash
   aws s3 sync dist/ s3://timesheet-frontend-RANDOM123 --acl public-read
   ```

4. **Create CloudFront Distribution**:
   - Go to CloudFront Console
   - Create distribution
   - Origin: Your S3 bucket
   - Default root object: `index.html`
   - Wait 10-15 minutes for deployment

5. **Get URL**: Copy CloudFront URL (e.g., `https://d111111abcdef8.cloudfront.net`)

---

### Part 6: Final Configuration (5 minutes)

1. **Update Backend CORS**:
   ```bash
   ssh -i timesheet-key.pem ubuntu@YOUR_EC2_PUBLIC_IP
   cd ~/Timesheet-backend
   nano .env
   
   # Add:
   FRONTEND_URL=https://your-amplify-url.amplifyapp.com
   
   # Restart services
   docker-compose -f docker-compose.free-tier.yml restart
   ```

2. **Test Complete Flow**:
   - Visit your frontend URL
   - Try logging in
   - Create a timesheet entry
   - Verify in MongoDB Atlas

---

## 🎯 Your Live Application

- **Frontend**: `https://your-app.amplifyapp.com`
- **Backend API**: `http://YOUR_EC2_IP:80`
- **Database**: MongoDB Atlas (cloud)
- **Message Queue**: AWS SQS

---

## 📊 Resource Usage (t2.micro - 1GB RAM)

Expected memory usage:
- **API Gateway (nginx)**: ~10MB
- **Auth Service**: ~80MB
- **Save Service**: ~80MB
- **Submit Service**: ~80MB
- **Notification Service**: ~60MB
- **System + Docker**: ~200MB
- **Swap Space**: 2GB (buffer)

**Total**: ~510MB / 1024MB = **50% RAM usage** ✓

---

## 🔧 Common Commands

```bash
# SSH into server
ssh -i timesheet-key.pem ubuntu@YOUR_EC2_IP

# View logs
docker-compose -f docker-compose.free-tier.yml logs -f [service-name]

# Restart services
docker-compose -f docker-compose.free-tier.yml restart

# Stop services
docker-compose -f docker-compose.free-tier.yml down

# Start services
docker-compose -f docker-compose.free-tier.yml up -d

# Check resource usage
docker stats
free -h
df -h

# Update application
cd ~/Timesheet-backend
git pull
docker-compose -f docker-compose.free-tier.yml up -d --build
```

---

## 🚨 Important Limits

### AWS Free Tier (12 months)
- **EC2**: 750 hours/month (= 24/7 for one instance)
- **Data Transfer**: 15GB outbound per month
- **S3**: 5GB storage, 20K GET, 2K PUT requests

### MongoDB Atlas (Permanent)
- **Storage**: 512MB
- **Connections**: 500 max

### AWS SQS (Permanent)
- **Requests**: 1 million per month

**⚠️ Monitor Your Usage**: Set up AWS billing alerts for $1!

---

## 🔒 Security Recommendations

1. **Restrict SSH Access**:
   ```bash
   # Edit security group to allow SSH only from your IP
   ```

2. **Change Default Passwords**:
   - MongoDB Atlas user password
   - JWT_SECRET in .env

3. **Enable HTTPS** (Free with Let's Encrypt):
   ```bash
   sudo apt install certbot python3-certbot-nginx
   sudo certbot --nginx -d yourdomain.com
   ```

4. **Restrict MongoDB Atlas IP**:
   - Change from `0.0.0.0/0` to your EC2 IP

5. **Use IAM Roles** instead of access keys (advanced):
   - Attach IAM role to EC2 with SQS permissions
   - Remove AWS credentials from .env

---

## 🐛 Troubleshooting

### Services Won't Start
```bash
# Check memory
free -h
# If memory full, increase swap or reduce services

# Check logs
docker-compose -f docker-compose.free-tier.yml logs

# Restart
sudo reboot
```

### Can't Connect to MongoDB
```bash
# Test connection from EC2
docker exec -it save-service sh
nc -zv cluster0.xxxxx.mongodb.net 27017

# Check credentials in .env
cat .env | grep MONGODB
```

### API Returns 502
```bash
# Check nginx logs
docker-compose -f docker-compose.free-tier.yml logs api-gateway

# Verify services are running
docker ps
```

---

## 📈 Upgrading Later

When you outgrow free tier:

1. **Scale EC2**: t2.micro → t3.small/medium
2. **Add Load Balancer**: For multiple instances
3. **Upgrade MongoDB**: M0 → M10 (dedicated cluster)
4. **Add Redis Cache**: For better performance
5. **Use RDS**: Instead of MongoDB Atlas

---

## 💡 Cost After Free Tier (12 months)

Estimated monthly cost:
- EC2 t2.micro (24/7): ~$8
- Data transfer: ~$2-5
- S3 + CloudFront: ~$1-5
- **Total**: **$11-18/month**

MongoDB Atlas M0 stays free forever! 🎉

---

## 🆘 Need Help?

- **AWS Support**: Free tier includes basic support
- **MongoDB Atlas**: Community forums + documentation
- **Discord/Slack**: Join cloud development communities

---

## ✅ Checklist

- [ ] MongoDB Atlas cluster created
- [ ] SQS queue created
- [ ] IAM user for SQS created
- [ ] EC2 instance launched
- [ ] SSH key downloaded
- [ ] Backend deployed to EC2
- [ ] Frontend deployed to Amplify/S3
- [ ] CORS configured
- [ ] Test login works
- [ ] Test timesheet creation works
- [ ] Billing alerts set up

---

**🎉 Congratulations!** You're now hosting a full-stack application on AWS for FREE!

**Duration**: 12 months free tier + MongoDB Atlas free forever

**What's Next?**
- Add custom domain name
- Set up SSL/HTTPS
- Configure automated backups
- Add monitoring with CloudWatch
- Implement CI/CD pipeline

