# Timesheet Backend - Microservices

A Node.js microservices backend for managing timesheet records with three main services: Authentication, Save, and Submit.

## Project Structure

```
Timesheet-backend/
├── auth-service/          # Authentication & user management service
│   ├── index.js
│   ├── package.json
│   ├── Dockerfile
│   ├── README.md
│   └── .gitignore
├── save-service/          # Service for saving draft timesheets
│   ├── index.js
│   ├── package.json
│   ├── Dockerfile
│   └── .gitignore
├── submit-service/        # Service for submitting final timesheets
│   ├── index.js
│   ├── package.json
│   ├── Dockerfile
│   └── .gitignore
├── docker-compose.yml     # Orchestrate all services
├── FRONTEND_INTEGRATION.md # Frontend integration guide
├── package.json           # Root package.json (optional)
└── README.md
```

## Services

### Auth Service (Port 3002) ⭐ NEW
- **Description**: User authentication, registration, and profile management with JWT
- **Endpoints**:
  - `POST /auth-service/register` - Register new user
  - `POST /auth-service/login` - Login user
  - `GET /auth-service/profile` - Get user profile (protected)
  - `PUT /auth-service/profile` - Update user profile (protected)
  - `PUT /auth-service/change-password` - Change password (protected)
  - `GET /auth-service/verify-token` - Verify JWT token (protected)
  - `GET /auth-service/users` - Get all users (protected)
  - `GET /auth-service/users/:id` - Get user by ID (protected)
  - `GET /auth-service/health` - Health check
- **Documentation**: See [auth-service/README.md](./auth-service/README.md)

### Save Service (Port 3000)
- **Description**: Saves draft timesheet records with status "Saved"
- **Endpoints**:
  - `GET /save-service/health` - Health check
  - `POST /save-service/timesheets` - Create or update timesheet
  - `POST /save-service/timesheets/weekly` - Create/update weekly timesheets
  - `GET /save-service/timesheets` - Get saved timesheets

### Submit Service (Port 3001)
- **Description**: Submits final timesheet records with status "Submitted"
- **Endpoints**:
  - `GET /submit-service/health` - Health check
  - `POST /submit-service/timesheets` - Create or update timesheet
  - `POST /submit-service/timesheets/weekly` - Create/update weekly timesheets
  - `GET /submit-service/timesheets` - Get submitted timesheets

## Prerequisites

- Node.js 18+
- npm or yarn
- MongoDB (local or via Docker)
- Docker & Docker Compose (for containerized setup)

## Local Development

### Option 1: Run Services Individually

**1. Install dependencies for save-service:**
```bash
cd save-service
npm install
npm run dev
```

**2. In another terminal, install dependencies for submit-service:**
```bash
cd submit-service
npm install
npm run dev
```

**Environment Variables:**
Create a `.env` file in each service folder:
```env
MONGODB_URI=mongodb://localhost:27017/timesheet
PORT=3000  # 3001 for submit-service
```

### Option 2: Run with Docker Compose (Recommended)

```bash
# Start all services (MongoDB + Save Service + Submit Service)
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

## API Endpoints

### Auth Service
```bash
# Health Check
curl http://localhost:3002/auth-service/health

# Register New User
curl -X POST http://localhost:3002/auth-service/register \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "John",
    "lastName": "Doe",
    "email": "john.doe@example.com",
    "password": "password123",
    "confirmPassword": "password123"
  }'

# Login User
curl -X POST http://localhost:3002/auth-service/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john.doe@example.com",
    "password": "password123"
  }'

# Get User Profile (Protected - requires JWT token)
curl http://localhost:3002/auth-service/profile \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Update User Profile (Protected)
curl -X PUT http://localhost:3002/auth-service/profile \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "firstName": "Jane",
    "lastName": "Smith"
  }'
```

### Save Service
```bash
# Health Check
curl http://localhost:3000/save-service/health

# Create/Update Timesheet (Draft)
curl -X POST http://localhost:3000/save-service/timesheets \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2025-10-24",
    "hours": 8,
    "employeeId": "EMP001",
    "projectId": "PROJ001",
    "recordType": "task",
    "taskId": "TASK001"
  }'
```

### Submit Service
```bash
# Health Check
curl http://localhost:3001/submit-service/health

# Submit Timesheet (Final)
curl -X POST http://localhost:3001/submit-service/timesheets \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2025-10-24",
    "hours": 8,
    "employeeId": "EMP001",
    "projectId": "PROJ001",
    "recordType": "task",
    "taskId": "TASK001"
  }'
```

## Database

All services share the same MongoDB database: `timesheet`

**Collections:**
- `users` - Stores user accounts and authentication data
- `timesheets` - Stores all timesheet records

**User Schema:**
```javascript
{
  firstName: String,
  lastName: String,
  email: String,        // unique, lowercase
  password: String,     // bcrypt hashed
  role: String,         // "user" | "admin" | "manager"
  isActive: Boolean,
  createdAt: Date,
  updatedAt: Date
}
```

**Timesheet Schema:**
```javascript
{
  date: Date,
  hours: Number,
  employeeId: String,
  projectId: String,
  taskId: String,
  recordType: String,
  wfh: Boolean,         // Work from home flag
  status: String,       // "Saved" or "Submitted"
  createdAt: Date,
  updatedAt: Date
}
```

## Upsert Logic

Both services use upsert logic: if a record with the same `date` and `employeeId` exists, it will be updated; otherwise, a new record is created.

## Development Scripts

**Save Service:**
```bash
cd save-service
npm run dev      # Run with nodemon
npm run start    # Run in production
```

**Submit Service:**
```bash
cd submit-service
npm run dev      # Run with nodemon
npm run start    # Run in production
```

## Docker Build

**Build individual services:**
```bash
docker build -t timesheet-save-service ./save-service
docker build -t timesheet-submit-service ./submit-service
```

**Run containers:**
```bash
docker run -p 3000:3000 \
  -e MONGODB_URI=mongodb://localhost:27017/timesheet \
  timesheet-save-service

docker run -p 3001:3001 \
  -e MONGODB_URI=mongodb://localhost:27017/timesheet \
  timesheet-submit-service
```

## MongoDB Connection

**Local MongoDB:**
```
mongodb://localhost:27017/timesheet
```

**With Authentication:**
```
mongodb://admin:password@localhost:27017/timesheet
```

**Docker MongoDB (from compose):**
```
mongodb://admin:password@mongo:27017/timesheet
```

## Troubleshooting

**Port already in use:**
```bash
# Kill process on port 3000
lsof -i :3000 | grep LISTEN | awk '{print $2}' | xargs kill -9

# Kill process on port 3001
lsof -i :3001 | grep LISTEN | awk '{print $2}' | xargs kill -9
```

**MongoDB connection issues:**
- Ensure MongoDB is running
- Check connection string in `.env` file
- Verify network connectivity if using Docker

## Frontend Integration

The authentication service is designed to work seamlessly with the React/TypeScript frontend.

### Quick Start

1. **Start the backend services:**
```bash
docker-compose up -d
```

2. **Use the auth API in your frontend:**
```typescript
import { register, login, logout } from './services/authAPI'

// Register user
await register({
  firstName: 'John',
  lastName: 'Doe',
  email: 'john@example.com',
  password: 'password123'
})

// Login user
await login({
  email: 'john@example.com',
  password: 'password123'
})

// Logout
logout()
```

3. **Frontend integration files provided:**
   - `src/services/authAPI.ts` - Auth API client
   - `src/contexts/AuthContext.tsx` - React context for auth state
   - `src/pages/SignUp.tsx` - Updated signup page
   - `src/pages/SignIn.tsx` - Updated signin page
   - `src/components/Header.tsx` - Updated to display user info

**📚 Complete Integration Guide:** See [FRONTEND_INTEGRATION.md](./FRONTEND_INTEGRATION.md)

**📖 Auth API Documentation:** See [auth-service/README.md](./auth-service/README.md)

## Security Notes

⚠️ **Important for Production:**

1. **Change JWT Secret**: Update `JWT_SECRET` in docker-compose.yml
2. **Use HTTPS**: Always use HTTPS in production
3. **Secure MongoDB**: Use strong passwords and authentication
4. **Environment Variables**: Never commit `.env` files with sensitive data
5. **CORS Configuration**: Restrict CORS to your frontend domain only

## Quick Test

Test all services are running:

```bash
# Test Auth Service
curl http://localhost:3002/auth-service/health

# Test Save Service  
curl http://localhost:3000/save-service/health

# Test Submit Service
curl http://localhost:3001/submit-service/health
```

All should return `{"status":"OK"}`

## License

ISC
