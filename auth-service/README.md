# Timesheet Authentication Service

A robust authentication microservice for the Timesheet application, providing user registration, login, and profile management with JWT-based authentication.

## Features

- ✅ User Registration
- ✅ User Login with JWT tokens
- ✅ Password hashing with bcrypt
- ✅ Protected routes with JWT middleware
- ✅ User profile management
- ✅ Password change functionality
- ✅ Token verification
- ✅ User search and listing

## Tech Stack

- **Node.js** with Express
- **MongoDB** with Mongoose
- **JWT** for authentication
- **bcryptjs** for password hashing
- **Validator** for email validation

## Getting Started

### Prerequisites

- Docker and Docker Compose
- Node.js 20+ (for local development)

### Installation

1. Install dependencies:
```bash
cd auth-service
npm install
```

2. Set up environment variables (see Configuration section)

3. Start the service with Docker Compose:
```bash
cd ..
docker-compose up auth-service
```

The service will be available at `http://localhost:3002`

## Configuration

Environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Service port | `3002` |
| `MONGODB_URI` | MongoDB connection string | `mongodb://admin:password@mongo:27017/timesheet?authSource=admin` |
| `JWT_SECRET` | Secret key for JWT signing | `your-secret-key-change-in-production` |
| `JWT_EXPIRES_IN` | JWT expiration time | `7d` |

⚠️ **Important:** Change `JWT_SECRET` in production!

## API Endpoints

### Public Endpoints (No Authentication Required)

#### 1. Health Check
```http
GET /auth-service/health
```

**Response:**
```json
{
  "status": "OK",
  "service": "auth-service",
  "timestamp": "2025-10-30T12:00:00.000Z"
}
```

---

#### 2. Register User
```http
POST /auth-service/register
Content-Type: application/json
```

**Request Body:**
```json
{
  "firstName": "John",
  "lastName": "Doe",
  "email": "john.doe@example.com",
  "password": "password123",
  "confirmPassword": "password123"
}
```

**Success Response (201):**
```json
{
  "message": "User registered successfully",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "_id": "507f1f77bcf86cd799439011",
    "firstName": "John",
    "lastName": "Doe",
    "email": "john.doe@example.com",
    "role": "user",
    "isActive": true,
    "createdAt": "2025-10-30T12:00:00.000Z",
    "updatedAt": "2025-10-30T12:00:00.000Z"
  }
}
```

**Error Responses:**
- `400` - Validation error (missing fields, invalid email, short password)
- `409` - Email already exists
- `500` - Server error

---

#### 3. Login User
```http
POST /auth-service/login
Content-Type: application/json
```

**Request Body:**
```json
{
  "email": "john.doe@example.com",
  "password": "password123"
}
```

**Success Response (200):**
```json
{
  "message": "Login successful",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "_id": "507f1f77bcf86cd799439011",
    "firstName": "John",
    "lastName": "Doe",
    "email": "john.doe@example.com",
    "role": "user",
    "isActive": true,
    "createdAt": "2025-10-30T12:00:00.000Z",
    "updatedAt": "2025-10-30T12:00:00.000Z"
  }
}
```

**Error Responses:**
- `400` - Missing email or password
- `401` - Invalid credentials or inactive account
- `500` - Server error

---

### Protected Endpoints (Authentication Required)

All protected endpoints require a JWT token in the Authorization header:
```http
Authorization: Bearer YOUR_JWT_TOKEN
```

---

#### 4. Get User Profile
```http
GET /auth-service/profile
Authorization: Bearer YOUR_JWT_TOKEN
```

**Success Response (200):**
```json
{
  "message": "Profile retrieved successfully",
  "user": {
    "_id": "507f1f77bcf86cd799439011",
    "firstName": "John",
    "lastName": "Doe",
    "email": "john.doe@example.com",
    "role": "user",
    "isActive": true,
    "createdAt": "2025-10-30T12:00:00.000Z",
    "updatedAt": "2025-10-30T12:00:00.000Z"
  }
}
```

---

#### 5. Update User Profile
```http
PUT /auth-service/profile
Authorization: Bearer YOUR_JWT_TOKEN
Content-Type: application/json
```

**Request Body:**
```json
{
  "firstName": "Jane",
  "lastName": "Smith",
  "email": "jane.smith@example.com"
}
```

**Success Response (200):**
```json
{
  "message": "Profile updated successfully",
  "user": {
    "_id": "507f1f77bcf86cd799439011",
    "firstName": "Jane",
    "lastName": "Smith",
    "email": "jane.smith@example.com",
    "role": "user",
    "isActive": true,
    "createdAt": "2025-10-30T12:00:00.000Z",
    "updatedAt": "2025-10-30T12:00:00.000Z"
  }
}
```

---

#### 6. Change Password
```http
PUT /auth-service/change-password
Authorization: Bearer YOUR_JWT_TOKEN
Content-Type: application/json
```

**Request Body:**
```json
{
  "currentPassword": "oldpassword123",
  "newPassword": "newpassword123",
  "confirmNewPassword": "newpassword123"
}
```

**Success Response (200):**
```json
{
  "message": "Password changed successfully"
}
```

---

#### 7. Verify Token
```http
GET /auth-service/verify-token
Authorization: Bearer YOUR_JWT_TOKEN
```

**Success Response (200):**
```json
{
  "message": "Token is valid",
  "user": {
    "_id": "507f1f77bcf86cd799439011",
    "firstName": "John",
    "lastName": "Doe",
    "email": "john.doe@example.com",
    "role": "user",
    "isActive": true
  }
}
```

---

#### 8. Get All Users
```http
GET /auth-service/users?page=1&limit=10&search=john
Authorization: Bearer YOUR_JWT_TOKEN
```

**Query Parameters:**
- `page` (optional) - Page number (default: 1)
- `limit` (optional) - Items per page (default: 10)
- `search` (optional) - Search term for firstName, lastName, or email

**Success Response (200):**
```json
{
  "message": "Users retrieved successfully",
  "users": [...],
  "pagination": {
    "page": 1,
    "limit": 10,
    "total": 25,
    "pages": 3
  }
}
```

---

#### 9. Get User by ID
```http
GET /auth-service/users/:id
Authorization: Bearer YOUR_JWT_TOKEN
```

**Success Response (200):**
```json
{
  "message": "User retrieved successfully",
  "user": {
    "_id": "507f1f77bcf86cd799439011",
    "firstName": "John",
    "lastName": "Doe",
    "email": "john.doe@example.com",
    "role": "user",
    "isActive": true,
    "createdAt": "2025-10-30T12:00:00.000Z",
    "updatedAt": "2025-10-30T12:00:00.000Z"
  }
}
```

---

## Error Codes

| Code | Message | Description |
|------|---------|-------------|
| `EMAIL_EXISTS` | Email already in use | User tried to register/update with existing email |
| `INVALID_CREDENTIALS` | Invalid email or password | Login failed |
| `ACCOUNT_INACTIVE` | Account is inactive | User account is deactivated |
| `UNAUTHORIZED` | Access denied | No token provided or invalid token |
| `INVALID_TOKEN` | Invalid token | JWT token is malformed |
| `TOKEN_EXPIRED` | Token expired | JWT token has expired |
| `INVALID_PASSWORD` | Current password is incorrect | Password change failed |

---

## User Schema

```javascript
{
  firstName: String (required, 2-50 chars),
  lastName: String (required, 2-50 chars),
  email: String (required, unique, valid email),
  password: String (required, min 8 chars, hashed),
  role: String (enum: 'user', 'admin', 'manager', default: 'user'),
  isActive: Boolean (default: true),
  createdAt: Date (auto),
  updatedAt: Date (auto)
}
```

---

## Security Features

- ✅ Passwords are hashed using bcrypt with salt rounds of 10
- ✅ JWT tokens with configurable expiration
- ✅ Email validation
- ✅ Password strength validation (minimum 8 characters)
- ✅ Protected routes with authentication middleware
- ✅ Account status checking (isActive)
- ✅ Secure password comparison

---

## Development

### Local Development (without Docker)

1. Make sure MongoDB is running locally
2. Update `.env` with local MongoDB URI:
```
MONGODB_URI=mongodb://localhost:27017/timesheet
```
3. Run the service:
```bash
npm run dev
```

### Testing the API

Using curl:

**Register:**
```bash
curl -X POST http://localhost:3002/auth-service/register \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "John",
    "lastName": "Doe",
    "email": "john@example.com",
    "password": "password123"
  }'
```

**Login:**
```bash
curl -X POST http://localhost:3002/auth-service/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john@example.com",
    "password": "password123"
  }'
```

**Get Profile:**
```bash
curl http://localhost:3002/auth-service/profile \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

## Integration with Frontend

See the frontend integration guide in the main README.

The frontend should:
1. Store the JWT token in localStorage or a secure cookie
2. Include the token in the Authorization header for protected API calls
3. Handle token expiration and redirect to login
4. Clear the token on logout

---

## License

ISC

