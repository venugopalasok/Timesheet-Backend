# Quick Start Guide - Timesheet Application

Get your Timesheet application up and running in 5 minutes!

## Prerequisites

- Docker & Docker Compose installed
- Node.js 18+ (for frontend development)
- Git

---

## Step 1: Start Backend Services

Navigate to the backend directory and start all services:

```bash
cd Timesheet-backend
docker-compose up -d
```

This will start:
- MongoDB on port `27017`
- Auth Service on port `3002`
- Save Service on port `3000`
- Submit Service on port `3001`

**Verify services are running:**

```bash
# Check all services
docker-compose ps

# Test health endpoints
curl http://localhost:3002/auth-service/health
curl http://localhost:3000/save-service/health
curl http://localhost:3001/submit-service/health
```

All should return `{"status":"OK"}`

---

## Step 2: Start Frontend

Navigate to the frontend directory and start the dev server:

```bash
cd ../Timesheet_Fe_ts
npm install
npm run dev
```

The frontend should be available at `http://localhost:5173` (or similar - check terminal output).

---

## Step 3: Create Your First Account

1. Open your browser and go to `http://localhost:5173`
2. Click "Sign Up" or navigate to `/signup`
3. Fill in the registration form:
   - **First Name**: John
   - **Last Name**: Doe
   - **Email**: john@example.com
   - **Password**: password123
   - **Confirm Password**: password123
4. Click "Sign Up"

✅ You should be automatically logged in and redirected to the timesheet grid!

---

## Step 4: View Your Profile

After signing up, you should see your name and email in the header:

- **Top Right Corner**: Your name "John Doe" and email should be displayed
- **Click Profile Icon**: Opens a dropdown menu
- **Sign Out**: Logs you out and clears authentication data

---

## Step 5: Test Authentication Flow

### Sign Out and Sign In Again

1. Click the profile icon in the top right
2. Click "Sign Out"
3. You should be redirected to `/signin`
4. Enter your credentials:
   - Email: john@example.com
   - Password: password123
5. Click "Sign In"
6. You should be back at the grid with your data

---

## API Testing (Optional)

### Register a User via API

```bash
curl -X POST http://localhost:3002/auth-service/register \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Jane",
    "lastName": "Smith",
    "email": "jane@example.com",
    "password": "password123"
  }'
```

**Expected Response:**
```json
{
  "message": "User registered successfully",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "_id": "...",
    "firstName": "Jane",
    "lastName": "Smith",
    "email": "jane@example.com",
    "role": "user",
    "isActive": true
  }
}
```

### Login via API

```bash
curl -X POST http://localhost:3002/auth-service/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "jane@example.com",
    "password": "password123"
  }'
```

### Get Profile (Protected Endpoint)

First, save the token from login response, then:

```bash
TOKEN="your_jwt_token_here"

curl http://localhost:3002/auth-service/profile \
  -H "Authorization: Bearer $TOKEN"
```

---

## Architecture Overview

```
┌─────────────────────────────────────────┐
│         Frontend (Port 5173)            │
│   React + TypeScript + Tailwind         │
└─────────────┬───────────────────────────┘
              │
              │ HTTP/REST
              │
    ┌─────────┼─────────┬─────────┐
    │         │         │         │
    ▼         ▼         ▼         ▼
┌────────┐ ┌─────┐ ┌──────┐ ┌────────┐
│  Auth  │ │Save │ │Submit│ │  More  │
│ :3002  │ │:3000│ │:3001 │ │Services│
└───┬────┘ └──┬──┘ └──┬───┘ └────────┘
    │         │        │
    └─────────┼────────┘
              │
    ┌─────────▼─────────┐
    │   MongoDB :27017  │
    │  Database: timesheet
    └───────────────────┘
```

---

## What You've Built

✅ **Authentication System**
- User registration with validation
- Secure login with JWT tokens
- Password hashing with bcrypt
- User profile management

✅ **Frontend Integration**
- SignUp page connected to API
- SignIn page connected to API
- User data displayed in header
- Token management in localStorage

✅ **Backend Microservices**
- Auth Service (port 3002)
- Save Service (port 3000)
- Submit Service (port 3001)
- MongoDB database

---

## Common Issues & Solutions

### Port Already in Use

If ports 3000, 3001, or 3002 are in use:

```bash
# Stop all Docker containers
docker-compose down

# Or kill specific port processes
lsof -i :3000 | grep LISTEN | awk '{print $2}' | xargs kill -9
lsof -i :3001 | grep LISTEN | awk '{print $2}' | xargs kill -9
lsof -i :3002 | grep LISTEN | awk '{print $2}' | xargs kill -9
```

### MongoDB Connection Failed

```bash
# Restart MongoDB
docker-compose restart mongo

# Check MongoDB logs
docker-compose logs mongo
```

### Frontend Can't Connect to Backend

1. Check all services are running: `docker-compose ps`
2. Verify health endpoints are accessible
3. Check CORS settings in backend (should allow all origins in dev)
4. Make sure `.env` in frontend has correct URLs:
   ```env
   VITE_AUTH_SERVICE_URL=http://localhost:3002
   VITE_BACKEND_URL=http://localhost:3000
   ```

### Token Not Persisting

- Check browser localStorage (DevTools → Application → Local Storage)
- Should see keys: `timesheet_auth_token` and `timesheet_user`
- Clear localStorage and try logging in again

### Password Validation Errors

- Password must be at least 8 characters
- Must match in both password and confirm password fields
- Check for extra whitespace

---

## Next Steps

Now that you have authentication working, you can:

1. **Add More Features:**
   - Password reset functionality
   - Email verification
   - User roles and permissions
   - Profile picture upload

2. **Enhance Security:**
   - Change JWT_SECRET in production
   - Add rate limiting
   - Implement refresh tokens
   - Add 2FA support

3. **Improve UX:**
   - Add loading states
   - Better error messages
   - Success notifications
   - Form validation feedback

4. **Extend the System:**
   - Add more microservices
   - Implement caching with Redis
   - Add logging and monitoring
   - Create admin dashboard

---

## Useful Commands

### Backend

```bash
# View all logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f auth-service
docker-compose logs -f save-service

# Restart a service
docker-compose restart auth-service

# Stop all services
docker-compose down

# Stop and remove volumes (⚠️ deletes database)
docker-compose down -v

# Rebuild services
docker-compose up --build
```

### Frontend

```bash
# Install dependencies
npm install

# Start dev server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

### Database

```bash
# Access MongoDB shell
docker exec -it timesheet-mongo mongosh -u admin -p password

# Use timesheet database
use timesheet

# List all users
db.users.find()

# List all timesheets
db.timesheets.find()

# Count documents
db.users.countDocuments()
db.timesheets.countDocuments()
```

---

## Documentation

- **[Backend README](./README.md)** - Complete backend documentation
- **[Auth Service Docs](./auth-service/README.md)** - Auth API reference
- **[Frontend Integration](./FRONTEND_INTEGRATION.md)** - Frontend integration guide

---

## Support

If you encounter issues:

1. Check the logs: `docker-compose logs -f`
2. Verify all services are healthy
3. Check the documentation above
4. Review error messages in browser console

---

## Success Checklist

- ✅ Backend services running
- ✅ Frontend dev server running
- ✅ Successfully registered a user
- ✅ Successfully logged in
- ✅ User info displayed in header
- ✅ Successfully logged out
- ✅ Successfully logged in again

**Congratulations! Your Timesheet application is ready! 🎉**


