# Frontend Integration Guide for Timesheet Auth Service

This guide explains how to integrate the authentication service with your React/TypeScript frontend.

## Table of Contents

1. [Setup](#setup)
2. [Environment Variables](#environment-variables)
3. [Using the Auth API](#using-the-auth-api)
4. [Authentication Context (Optional)](#authentication-context-optional)
5. [Protected Routes](#protected-routes)
6. [Example Usage](#example-usage)

---

## Setup

The frontend integration is already set up in the `Timesheet_Fe_ts` project with the following files:

- **`src/services/authAPI.ts`** - API service for auth operations
- **`src/contexts/AuthContext.tsx`** - React context for auth state management
- **`src/pages/SignUp.tsx`** - Updated to use auth API
- **`src/pages/SignIn.tsx`** - Updated to use auth API
- **`src/components/Header.tsx`** - Updated to display user info

---

## Environment Variables

Create a `.env` file in your frontend project root:

```env
VITE_AUTH_SERVICE_URL=http://localhost:3002
VITE_BACKEND_URL=http://localhost:3000
```

For production, update these URLs to your production backend URLs.

---

## Using the Auth API

### Import the API Functions

```typescript
import {
  register,
  login,
  logout,
  getProfile,
  updateProfile,
  changePassword,
  getCurrentUser,
  getUserFullName,
  isAuthenticated,
} from '../services/authAPI'
```

### Registration

```typescript
import { register } from '../services/authAPI'

const handleRegister = async () => {
  try {
    const response = await register({
      firstName: 'John',
      lastName: 'Doe',
      email: 'john@example.com',
      password: 'password123',
      confirmPassword: 'password123'
    })
    
    console.log('Registration successful:', response.user)
    console.log('Token:', response.token)
    
    // Token is automatically stored in localStorage
    // Navigate to dashboard
    navigate('/grid')
  } catch (error) {
    console.error('Registration failed:', error.message)
  }
}
```

### Login

```typescript
import { login } from '../services/authAPI'

const handleLogin = async () => {
  try {
    const response = await login({
      email: 'john@example.com',
      password: 'password123'
    })
    
    console.log('Login successful:', response.user)
    console.log('Token:', response.token)
    
    // Token is automatically stored in localStorage
    // Navigate to dashboard
    navigate('/grid')
  } catch (error) {
    console.error('Login failed:', error.message)
  }
}
```

### Logout

```typescript
import { logout } from '../services/authAPI'

const handleLogout = () => {
  logout() // Clears token and user data from localStorage
  navigate('/signin')
}
```

### Get Current User

```typescript
import { getCurrentUser, getUserFullName } from '../services/authAPI'

const MyComponent = () => {
  const user = getCurrentUser()
  
  if (user) {
    console.log('User ID:', user._id)
    console.log('Full Name:', getUserFullName(user))
    console.log('Email:', user.email)
    console.log('Role:', user.role)
  }
}
```

### Get User Profile from Server

```typescript
import { getProfile } from '../services/authAPI'

const fetchProfile = async () => {
  try {
    const response = await getProfile()
    console.log('Profile:', response.user)
  } catch (error) {
    console.error('Failed to fetch profile:', error.message)
  }
}
```

### Update Profile

```typescript
import { updateProfile } from '../services/authAPI'

const handleUpdateProfile = async () => {
  try {
    const response = await updateProfile({
      firstName: 'Jane',
      lastName: 'Smith',
      email: 'jane@example.com'
    })
    
    console.log('Profile updated:', response.user)
  } catch (error) {
    console.error('Update failed:', error.message)
  }
}
```

### Change Password

```typescript
import { changePassword } from '../services/authAPI'

const handleChangePassword = async () => {
  try {
    await changePassword({
      currentPassword: 'oldpassword',
      newPassword: 'newpassword123',
      confirmNewPassword: 'newpassword123'
    })
    
    console.log('Password changed successfully')
  } catch (error) {
    console.error('Password change failed:', error.message)
  }
}
```

---

## Authentication Context (Optional)

For easier state management across your app, use the `AuthContext`:

### Wrap Your App with AuthProvider

```typescript
// src/main.tsx or src/App.tsx
import { AuthProvider } from './contexts/AuthContext'

function App() {
  return (
    <AuthProvider>
      <YourRoutes />
    </AuthProvider>
  )
}
```

### Use the Auth Hook in Components

```typescript
import { useAuth } from '../contexts/AuthContext'

function MyComponent() {
  const { user, isAuthenticated, login, logout, isLoading, error } = useAuth()

  if (isLoading) {
    return <div>Loading...</div>
  }

  if (!isAuthenticated) {
    return <div>Please log in</div>
  }

  return (
    <div>
      <h1>Welcome, {user?.firstName}!</h1>
      <p>Email: {user?.email}</p>
      <button onClick={logout}>Logout</button>
    </div>
  )
}
```

---

## Protected Routes

Create a protected route component to restrict access to authenticated users:

```typescript
// src/components/ProtectedRoute.tsx
import { Navigate } from 'react-router-dom'
import { isAuthenticated } from '../services/authAPI'

interface ProtectedRouteProps {
  children: React.ReactNode
}

export const ProtectedRoute = ({ children }: ProtectedRouteProps) => {
  if (!isAuthenticated()) {
    return <Navigate to="/signin" replace />
  }

  return <>{children}</>
}
```

### Use Protected Routes in Your Router

```typescript
import { BrowserRouter, Routes, Route } from 'react-router-dom'
import { ProtectedRoute } from './components/ProtectedRoute'
import SignIn from './pages/SignIn'
import SignUp from './pages/SignUp'
import Grid from './pages/Grid'

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/signin" element={<SignIn />} />
        <Route path="/signup" element={<SignUp />} />
        <Route
          path="/grid"
          element={
            <ProtectedRoute>
              <Grid />
            </ProtectedRoute>
          }
        />
      </Routes>
    </BrowserRouter>
  )
}
```

---

## Example Usage

### Complete SignUp Page Example

```typescript
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { register } from '../services/authAPI'

function SignUp() {
  const navigate = useNavigate()
  const [formData, setFormData] = useState({
    firstName: '',
    lastName: '',
    email: '',
    password: '',
    confirmPassword: ''
  })
  const [error, setError] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)
    setIsLoading(true)

    try {
      await register(formData)
      navigate('/grid') // Navigate to dashboard on success
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Registration failed')
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit}>
      {error && <div className="error">{error}</div>}
      
      <input
        type="text"
        name="firstName"
        placeholder="First Name"
        value={formData.firstName}
        onChange={(e) => setFormData({ ...formData, firstName: e.target.value })}
        required
      />
      
      {/* Add other inputs */}
      
      <button type="submit" disabled={isLoading}>
        {isLoading ? 'Signing up...' : 'Sign Up'}
      </button>
    </form>
  )
}
```

### Display User Info in Header

```typescript
import { getCurrentUser, getUserFullName, logout } from '../services/authAPI'
import { useNavigate } from 'react-router-dom'

function Header() {
  const navigate = useNavigate()
  const user = getCurrentUser()

  const handleLogout = () => {
    logout()
    navigate('/signin')
  }

  return (
    <header>
      {user ? (
        <div>
          <span>Welcome, {getUserFullName(user)}</span>
          <span>{user.email}</span>
          <button onClick={handleLogout}>Sign Out</button>
        </div>
      ) : (
        <div>
          <a href="/signin">Sign In</a>
          <a href="/signup">Sign Up</a>
        </div>
      )}
    </header>
  )
}
```

---

## API Response Examples

### Successful Registration/Login

```json
{
  "message": "User registered successfully",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "_id": "507f1f77bcf86cd799439011",
    "firstName": "John",
    "lastName": "Doe",
    "email": "john@example.com",
    "role": "user",
    "isActive": true,
    "createdAt": "2025-10-30T12:00:00.000Z",
    "updatedAt": "2025-10-30T12:00:00.000Z"
  }
}
```

### Error Response

```json
{
  "message": "User with this email already exists",
  "error": "EMAIL_EXISTS"
}
```

---

## Common Error Codes

| Error Code | Description | How to Handle |
|------------|-------------|---------------|
| `EMAIL_EXISTS` | Email already registered | Show error, suggest sign in |
| `INVALID_CREDENTIALS` | Wrong email/password | Show error, allow retry |
| `ACCOUNT_INACTIVE` | Account is disabled | Show error, contact support |
| `UNAUTHORIZED` | No token or invalid token | Redirect to login |
| `TOKEN_EXPIRED` | JWT token expired | Redirect to login |

---

## Token Management

The auth API automatically handles token storage in `localStorage`:

- **Token Key**: `timesheet_auth_token`
- **User Key**: `timesheet_user`

Tokens are automatically included in API requests via the `Authorization` header:

```
Authorization: Bearer YOUR_JWT_TOKEN
```

---

## Best Practices

1. **Always handle errors**: Wrap API calls in try-catch blocks
2. **Show loading states**: Disable buttons and show spinners during API calls
3. **Clear sensitive data on logout**: Use the `logout()` function
4. **Verify token on app load**: Check `isAuthenticated()` when app starts
5. **Handle expired tokens**: Redirect to login when getting 401 errors
6. **Store minimal data**: Only store what's necessary in localStorage
7. **Use HTTPS in production**: Never send passwords over HTTP

---

## Troubleshooting

### CORS Issues

If you get CORS errors, make sure the backend has CORS enabled for your frontend URL:

```javascript
// Backend already has CORS enabled
app.use(cors())
```

### Token Not Persisting

Check that you're calling the API functions correctly - they automatically store tokens:

```typescript
// ✅ Correct - token is stored automatically
await login({ email, password })

// ❌ Wrong - manually storing token is unnecessary
const response = await login({ email, password })
setAuthToken(response.token) // Already done by login()
```

### User Data Not Updating

Refresh user data after updates:

```typescript
await updateProfile({ firstName: 'New Name' })
// User data in localStorage is already updated
const user = getCurrentUser() // Gets updated data
```

---

## Next Steps

1. Start the backend services: `docker-compose up`
2. Test registration: Try creating a new account
3. Test login: Sign in with created credentials
4. Test protected routes: Try accessing `/grid` without logging in
5. Test logout: Sign out and verify token is cleared

For more information, see:
- [Auth Service API Documentation](./auth-service/README.md)
- [Main README](./README.md)

