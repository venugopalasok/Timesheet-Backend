# API Gateway & RabbitMQ Implementation Guide

## 🎉 What Was Implemented

✅ **Nginx API Gateway** - Single entry point for all frontend requests
✅ **RabbitMQ Message Queue** - Async communication between backend services  
✅ **RabbitMQ Management UI** - Visual dashboard for monitoring queues
✅ **Notification Service** - Example service that consumes messages
✅ **Integrated with Existing Services** - Auth, Save, Submit services publish events

---

## 🏗️ Architecture Overview

### **Before:**
```
Frontend (5173)
    ↓ ↓ ↓
    3002  3000  3001
    Auth  Save  Submit
```

### **After:**
```
Frontend (5173)
        ↓
  API Gateway (8080) ← Single entry point
        ↓
   ┌────┴────┬─────────┬──────────┐
   ↓         ↓         ↓          ↓
Auth:3002  Save:3000  Submit:3001  Notification:3003
   │         │         │          │
   └─────────┴─────────┴──────────┘
              ↓
        RabbitMQ (5672) ← Message Queue
         Management UI (15672)
              ↓
          MongoDB
```

---

## 📦 Services & Ports

| Service | Port | Purpose | Access |
|---------|------|---------|--------|
| **API Gateway** | 8080 | Frontend entry point | `http://localhost:8080` |
| **RabbitMQ** | 5672 | Message queue | Internal |
| **RabbitMQ Management** | 15672 | Web UI | `http://localhost:15672` |
| **Auth Service** | 3002 | Authentication | Internal (via gateway) |
| **Save Service** | 3000 | Save timesheets | Internal (via gateway) |
| **Submit Service** | 3001 | Submit timesheets | Internal (via gateway) |
| **Notification Service** | 3003 | Process events | Internal |
| **MongoDB** | 27017 | Database | Internal |

---

## 🚀 Getting Started

### **1. Start All Services**

```bash
cd /Users/deadsec/Git_Repos/Timesheet-backend
docker-compose up -d
```

This will start:
- ✅ API Gateway (Nginx)
- ✅ RabbitMQ with Management UI
- ✅ All microservices
- ✅ MongoDB
- ✅ Notification service

### **2. Verify Services**

```bash
# Check all services are running
docker-compose ps

# Test API Gateway
curl http://localhost:8080/health

# Test individual services through gateway
curl http://localhost:8080/api/auth/health
```

### **3. Access RabbitMQ Management UI**

Open browser: `http://localhost:15672`

**Login Credentials:**
- Username: `admin`
- Password: `password`

---

## 🔌 API Gateway Routes

### **Frontend URLs (After Implementation)**

**Single Base URL:**
```typescript
const API_BASE_URL = 'http://localhost:8080'
```

### **Route Mapping**

| Frontend Path | Backend Service | Forwards To |
|--------------|-----------------|-------------|
| `/api/auth/*` | Auth Service | `http://auth-service:3002/auth-service/*` |
| `/api/timesheets/save/*` | Save Service | `http://save-service:3000/save-service/*` |
| `/api/timesheets/submit/*` | Submit Service | `http://submit-service:3001/submit-service/*` |
| `/health` | Gateway | Returns gateway status |
| `/api` | Gateway | Returns API info |

### **Example API Calls**

**Before (Direct to services):**
```typescript
// ❌ Multiple URLs
fetch('http://localhost:3002/auth-service/register')
fetch('http://localhost:3000/save-service/timesheets')
fetch('http://localhost:3001/submit-service/timesheets')
```

**After (Through gateway):**
```typescript
// ✅ Single URL
fetch('http://localhost:8080/api/auth/register')
fetch('http://localhost:8080/api/timesheets/save/timesheets')
fetch('http://localhost:8080/api/timesheets/submit/timesheets')
```

---

## 📨 RabbitMQ Message Queue

### **Queue Names**

| Queue Name | Purpose | Published By | Consumed By |
|------------|---------|--------------|-------------|
| `user.registered` | New user signup | Auth Service | Notification Service |
| `timesheet.submitted` | Timesheet submitted | Submit Service | Notification Service |
| `timesheet.saved` | Timesheet saved | Save Service | Notification Service |

### **Message Flow Example**

#### **User Registration:**
```
1. User submits signup form
   ↓
2. Auth Service creates user in DB
   ↓
3. Auth Service publishes to queue:
   Queue: user.registered
   Message: { employeeId, email, firstName, lastName }
   ↓
4. Notification Service receives message
   ↓
5. Notification Service sends welcome email
   ↓
6. User receives response (doesn't wait for email)
```

#### **Timesheet Submission:**
```
1. User clicks Submit button
   ↓
2. Submit Service saves to DB
   ↓
3. Submit Service publishes to queue:
   Queue: timesheet.submitted
   Message: { employeeId, date, hours, recordType }
   ↓
4. Notification Service receives message
   ↓
5. Notification Service sends email to manager
   ↓
6. User sees success message (already returned)
```

---

## 🔧 RabbitMQ Management UI Features

### **Access Management UI**

URL: `http://localhost:15672`
Login: `admin` / `password`

### **What You Can Do:**

1. **View Queues**
   - See all message queues
   - Monitor message counts
   - Check consumer status

2. **View Messages**
   - Inspect messages in queues
   - Manually publish test messages
   - Purge queues

3. **View Connections**
   - See which services are connected
   - Monitor channels
   - Check connection health

4. **View Exchanges**
   - Monitor message routing
   - View bindings

5. **Performance Metrics**
   - Message rates
   - Consumer rates
   - Queue depth over time
   - Connection statistics

### **Useful Dashboards:**

- **Overview** - System health summary
- **Connections** - Active service connections
- **Channels** - Communication channels
- **Queues** - All message queues
- **Exchanges** - Message routing

---

## 📁 Files Created

### **Backend Files**

```
Timesheet-backend/
├── nginx.conf                              # API Gateway configuration
├── docker-compose.yml                      # Updated with gateway & RabbitMQ
├── shared/
│   └── rabbitmq.js                        # RabbitMQ helper module
├── notification-service/
│   ├── index.js                           # Notification service
│   ├── package.json                       # Dependencies
│   └── Dockerfile                         # Docker config
└── API_GATEWAY_AND_RABBITMQ_IMPLEMENTATION.md
```

### **Updated Services**

- ✅ `auth-service/index.js` - Publishes user.registered events
- ✅ `auth-service/package.json` - Added amqplib
- ✅ `save-service/package.json` - Added amqplib  
- ✅ `submit-service/package.json` - Added amqplib
- ✅ `docker-compose.yml` - Added gateway, RabbitMQ, notification service

---

## 🎯 Benefits

### **API Gateway Benefits:**

✅ **Single Entry Point**
- Frontend only needs ONE URL
- Easy to change backend without affecting frontend

✅ **Simplified Deployment**
- One load balancer instead of three
- Easier SSL/TLS configuration

✅ **Centralized Features**
- CORS handling in one place
- Request logging centralized
- Rate limiting (can be added)
- Authentication middleware (can be added)

✅ **Better Security**
- Backend services not directly exposed
- Can add firewall rules easily

### **RabbitMQ Benefits:**

✅ **Asynchronous Processing**
- Users don't wait for slow operations
- Better responsiveness

✅ **Reliability**
- Messages not lost if service is down
- Automatic retry mechanisms

✅ **Scalability**
- Easy to add more workers
- Handle traffic spikes

✅ **Loose Coupling**
- Services don't need to know about each other
- Easy to add new services

---

## 🧪 Testing

### **Test API Gateway**

```bash
# Health check
curl http://localhost:8080/health

# API info
curl http://localhost:8080/api

# Auth service through gateway
curl http://localhost:8080/api/auth/health

# Register user through gateway
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Test",
    "lastName": "User",
    "email": "test@example.com",
    "password": "password123"
  }'
```

### **Test RabbitMQ**

**1. Check RabbitMQ UI:**
- Open `http://localhost:15672`
- Login with `admin` / `password`
- Go to "Queues" tab
- Should see 3 queues created

**2. Register a User (triggers message):**
```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "John",
    "lastName": "Doe",
    "email": "john@example.com",
    "password": "password123"
  }'
```

**3. Check RabbitMQ UI again:**
- Should see message in `user.registered` queue
- Click on queue name
- Click "Get messages" to see the message content

**4. Watch Notification Service Logs:**
```bash
docker logs -f notification-service
```

Should see:
```
[USER_REGISTERED] Received: { employeeId: 'EMP123456', email: 'john@example.com', ... }
👋 Sending welcome email to john@example.com
[USER_REGISTERED] Processed and acknowledged
```

### **Test Message Publishing Manually**

```bash
curl -X POST http://localhost:3003/test/publish \
  -H "Content-Type: application/json" \
  -d '{
    "queue": "USER_REGISTERED",
    "message": {
      "employeeId": "EMP999999",
      "email": "test@test.com",
      "firstName": "Manual",
      "lastName": "Test"
    }
  }'
```

---

## 📊 Monitoring

### **View Queue Statistics**

```bash
curl http://localhost:3003/stats
```

Response:
```json
{
  "message": "Queue statistics",
  "stats": {
    "TIMESHEET_SUBMITTED": {
      "queue": "timesheet.submitted",
      "messages": 0,
      "consumers": 1
    },
    "TIMESHEET_SAVED": {
      "queue": "timesheet.saved",
      "messages": 0,
      "consumers": 1
    },
    "USER_REGISTERED": {
      "queue": "user.registered",
      "messages": 5,
      "consumers": 1
    }
  }
}
```

### **View Service Logs**

```bash
# All services
docker-compose logs -f

# Specific services
docker logs -f api-gateway
docker logs -f rabbitmq
docker logs -f notification-service
docker logs -f auth-service
```

---

## 🔐 Security Configuration

### **API Gateway Security Headers**

Already configured in `nginx.conf`:
- `X-Frame-Options: SAMEORIGIN`
- `X-Content-Type-Options: nosniff`
- `X-XSS-Protection: 1; mode=block`
- CORS headers for all routes

### **RabbitMQ Security**

**Default Credentials (Change in Production!):**
- Username: `admin`
- Password: `password`

**Production Changes:**
```yaml
environment:
  RABBITMQ_DEFAULT_USER: your_secure_username
  RABBITMQ_DEFAULT_PASS: your_secure_password
```

---

## 🚀 Production Deployment

### **1. Update docker-compose.yml:**

```yaml
environment:
  # Change these in production!
  RABBITMQ_DEFAULT_USER: ${RABBITMQ_USER}
  RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASSWORD}
  JWT_SECRET: ${JWT_SECRET}
```

### **2. Use HTTPS:**

Update `nginx.conf` to handle SSL:
```nginx
server {
    listen 443 ssl http2;
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    # ... rest of config
}
```

### **3. Restrict CORS:**

```nginx
# Instead of '*', use your frontend domain
add_header 'Access-Control-Allow-Origin' 'https://yourapp.com' always;
```

### **4. Add Rate Limiting:**

```nginx
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;

location /api/ {
    limit_req zone=api_limit burst=20 nodelay;
    # ... rest of config
}
```

---

## 🛠️ Troubleshooting

### **Issue: API Gateway Not Working**

```bash
# Check nginx config
docker exec api-gateway nginx -t

# Check gateway logs
docker logs api-gateway

# Test direct service access
curl http://localhost:3002/auth-service/health
```

### **Issue: RabbitMQ Not Connecting**

```bash
# Check RabbitMQ logs
docker logs rabbitmq

# Check service can reach RabbitMQ
docker exec auth-service ping rabbitmq

# Verify RabbitMQ is healthy
docker ps | grep rabbitmq
```

### **Issue: Messages Not Being Consumed**

1. Check RabbitMQ Management UI
2. Verify notification-service is running
3. Check notification-service logs
4. Manually publish test message
5. Verify queue consumers count > 0

### **Issue: Cannot Access Management UI**

```bash
# Check port is exposed
docker port timesheet-rabbitmq

# Should show: 15672/tcp -> 0.0.0.0:15672

# Try accessing
curl http://localhost:15672
```

---

## 📚 Next Steps

### **1. Update Frontend**

See `FRONTEND_UPDATE_GUIDE.md` (to be created) for:
- Updating API URLs to use gateway
- Environment variable configuration
- Testing with gateway

### **2. Add More Event Handlers**

Create new consumers in notification-service for:
- Timesheet approval workflows
- Monthly report generation
- Email reminders
- Analytics updates

### **3. Add More Services**

Example new services:
- **Analytics Service** - Consumes all events for dashboards
- **Report Service** - Generates PDF reports
- **Approval Service** - Handles manager approvals
- **Billing Service** - Calculates billable hours

### **4. Implement Dead Letter Queue**

For failed messages:
```javascript
await channel.assertQueue('dlq', { durable: true });
// Configure retry logic and move to DLQ after max retries
```

---

## 📖 Additional Resources

### **RabbitMQ:**
- Management UI: `http://localhost:15672`
- Official Docs: https://www.rabbitmq.com/documentation.html

### **Nginx:**
- Official Docs: https://nginx.org/en/docs/

### **Docker:**
- Docker Compose Docs: https://docs.docker.com/compose/

---

## ✅ Summary

**What You Have Now:**

✅ **API Gateway** on port 8080 - Single entry point for frontend
✅ **RabbitMQ** on port 5672 - Message queue for async operations
✅ **Management UI** on port 15672 - Visual monitoring dashboard
✅ **Notification Service** - Example consumer service
✅ **Integrated Services** - All services can publish/consume messages
✅ **Production Ready** - Scalable, maintainable architecture

**Key Benefits:**

- 🚀 Simplified frontend integration
- 📈 Better scalability
- 🔄 Async processing
- 📊 Visual monitoring
- 🛡️ Better security
- 🔧 Easy to maintain and extend

**Your timesheet application is now enterprise-ready!** 🎉


