const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const validator = require('validator');

const app = express();
const router = express.Router();

app.use(cors());
app.use(express.json());

const mongoDBURI = process.env.MONGODB_URI || 'mongodb://admin:password@mongo:27017/timesheet?authSource=admin';
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';

// MongoDB Connection with Retry Logic
const connectToDatabase = async (retries = 5, delay = 5000) => {
  for (let i = 0; i < retries; i++) {
    try {
      await mongoose.connect(mongoDBURI, {
        serverSelectionTimeoutMS: 5000,
        connectTimeoutMS: 5000,
        retryWrites: false
      });
      console.log('✓ Connected to MongoDB');
      return true;
    } catch (err) {
      console.error(`✗ MongoDB connection attempt ${i + 1}/${retries} failed:`, err.message);
      
      if (i < retries - 1) {
        console.log(`Retrying in ${delay / 1000} seconds...`);
        await new Promise(resolve => setTimeout(resolve, delay));
      } else {
        console.error('✗ Failed to connect to MongoDB after all retries');
        return false;
      }
    }
  }
};

// Connect to database on startup
connectToDatabase();

// User Schema
const userSchema = new mongoose.Schema({
  employeeId: {
    type: String,
    required: [true, 'Employee ID is required'],
    unique: true,
    trim: true
  },
  firstName: {
    type: String,
    required: [true, 'First name is required'],
    trim: true,
    minlength: [2, 'First name must be at least 2 characters'],
    maxlength: [50, 'First name must be less than 50 characters']
  },
  lastName: {
    type: String,
    required: [true, 'Last name is required'],
    trim: true,
    minlength: [2, 'Last name must be at least 2 characters'],
    maxlength: [50, 'Last name must be less than 50 characters']
  },
  email: {
    type: String,
    required: [true, 'Email is required'],
    unique: true,
    lowercase: true,
    trim: true,
    validate: [validator.isEmail, 'Please provide a valid email']
  },
  password: {
    type: String,
    required: [true, 'Password is required'],
    minlength: [8, 'Password must be at least 8 characters']
  },
  role: {
    type: String,
    enum: ['user', 'admin', 'manager'],
    default: 'user'
  },
  isActive: {
    type: Boolean,
    default: true
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

// Hash password before saving
userSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  
  try {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
    next();
  } catch (error) {
    next(error);
  }
});

// Method to compare password
userSchema.methods.comparePassword = async function(candidatePassword) {
  return await bcrypt.compare(candidatePassword, this.password);
};

// Method to generate JWT token
userSchema.methods.generateAuthToken = function() {
  return jwt.sign(
    { 
      id: this._id, 
      email: this.email,
      firstName: this.firstName,
      lastName: this.lastName,
      role: this.role,
      employeeId: this.employeeId
    },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  );
};

const User = mongoose.model('User', userSchema);

// Helper function to generate unique employee ID
const generateEmployeeId = async () => {
  const prefix = 'EMP';
  let employeeId;
  let exists = true;
  
  while (exists) {
    // Generate random 6-digit number
    const randomNum = Math.floor(100000 + Math.random() * 900000);
    employeeId = `${prefix}${randomNum}`;
    
    // Check if this ID already exists
    const existingUser = await User.findOne({ employeeId });
    exists = !!existingUser;
  }
  
  return employeeId;
};

// Middleware to verify JWT token
const authMiddleware = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({ 
        message: 'Access denied. No token provided.',
        error: 'UNAUTHORIZED'
      });
    }

    const decoded = jwt.verify(token, JWT_SECRET);
    const user = await User.findById(decoded.id).select('-password');
    
    if (!user) {
      return res.status(401).json({ 
        message: 'Invalid token. User not found.',
        error: 'UNAUTHORIZED'
      });
    }

    if (!user.isActive) {
      return res.status(401).json({ 
        message: 'Account is inactive.',
        error: 'ACCOUNT_INACTIVE'
      });
    }

    req.user = user;
    req.token = token;
    next();
  } catch (error) {
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ 
        message: 'Invalid token.',
        error: 'INVALID_TOKEN'
      });
    }
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ 
        message: 'Token expired.',
        error: 'TOKEN_EXPIRED'
      });
    }
    res.status(401).json({ 
      message: 'Authentication failed.',
      error: error.message
    });
  }
};

// ========== ROUTES ==========

// Register new user
router.post('/register', async (req, res) => {
  try {
    const { firstName, lastName, email, password, confirmPassword } = req.body;

    // Validation
    if (!firstName || !lastName || !email || !password) {
      return res.status(400).json({ 
        message: 'Please provide all required fields',
        required: ['firstName', 'lastName', 'email', 'password']
      });
    }

    // Validate password match (if confirmPassword is provided)
    if (confirmPassword && password !== confirmPassword) {
      return res.status(400).json({ 
        message: 'Passwords do not match'
      });
    }

    // Validate password length
    if (password.length < 8) {
      return res.status(400).json({ 
        message: 'Password must be at least 8 characters long'
      });
    }

    // Validate email format
    if (!validator.isEmail(email)) {
      return res.status(400).json({ 
        message: 'Please provide a valid email address'
      });
    }

    // Check if user already exists
    const existingUser = await User.findOne({ email: email.toLowerCase() });
    if (existingUser) {
      return res.status(409).json({ 
        message: 'User with this email already exists',
        error: 'EMAIL_EXISTS'
      });
    }

    // Generate unique employee ID
    const employeeId = await generateEmployeeId();

    // Create new user
    const user = new User({
      employeeId,
      firstName,
      lastName,
      email: email.toLowerCase(),
      password
    });

    await user.save();

    // Generate token
    const token = user.generateAuthToken();

    // Remove password from response
    const userResponse = user.toObject();
    delete userResponse.password;

    res.status(201).json({
      message: 'User registered successfully',
      token,
      user: userResponse
    });
  } catch (error) {
    console.error('Registration error:', error);
    
    if (error.name === 'ValidationError') {
      const messages = Object.values(error.errors).map(err => err.message);
      return res.status(400).json({ 
        message: 'Validation failed',
        errors: messages
      });
    }
    
    res.status(500).json({ 
      message: 'Error registering user',
      error: error.message
    });
  }
});

// Login user
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    // Validation
    if (!email || !password) {
      return res.status(400).json({ 
        message: 'Please provide email and password'
      });
    }

    // Find user by email
    const user = await User.findOne({ email: email.toLowerCase() });
    if (!user) {
      return res.status(401).json({ 
        message: 'Invalid email or password',
        error: 'INVALID_CREDENTIALS'
      });
    }

    // Check if account is active
    if (!user.isActive) {
      return res.status(401).json({ 
        message: 'Account is inactive. Please contact support.',
        error: 'ACCOUNT_INACTIVE'
      });
    }

    // Check password
    const isPasswordValid = await user.comparePassword(password);
    if (!isPasswordValid) {
      return res.status(401).json({ 
        message: 'Invalid email or password',
        error: 'INVALID_CREDENTIALS'
      });
    }

    // Generate token
    const token = user.generateAuthToken();

    // Remove password from response
    const userResponse = user.toObject();
    delete userResponse.password;

    res.status(200).json({
      message: 'Login successful',
      token,
      user: userResponse
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ 
      message: 'Error logging in',
      error: error.message
    });
  }
});

// Get current user profile (protected route)
router.get('/profile', authMiddleware, async (req, res) => {
  try {
    const user = req.user.toObject();
    
    res.status(200).json({
      message: 'Profile retrieved successfully',
      user: user
    });
  } catch (error) {
    console.error('Profile fetch error:', error);
    res.status(500).json({ 
      message: 'Error fetching profile',
      error: error.message
    });
  }
});

// Update user profile (protected route)
router.put('/profile', authMiddleware, async (req, res) => {
  try {
    const { firstName, lastName, email } = req.body;
    const userId = req.user._id;

    // Build update object
    const updates = {};
    if (firstName) updates.firstName = firstName;
    if (lastName) updates.lastName = lastName;
    if (email && validator.isEmail(email)) {
      // Check if new email already exists
      if (email.toLowerCase() !== req.user.email) {
        const existingUser = await User.findOne({ email: email.toLowerCase() });
        if (existingUser) {
          return res.status(409).json({ 
            message: 'Email already in use',
            error: 'EMAIL_EXISTS'
          });
        }
        updates.email = email.toLowerCase();
      }
    }

    updates.updatedAt = Date.now();

    // Update user
    const user = await User.findByIdAndUpdate(
      userId,
      updates,
      { new: true, runValidators: true }
    ).select('-password');

    if (!user) {
      return res.status(404).json({ 
        message: 'User not found'
      });
    }

    res.status(200).json({
      message: 'Profile updated successfully',
      user: user
    });
  } catch (error) {
    console.error('Profile update error:', error);
    
    if (error.name === 'ValidationError') {
      const messages = Object.values(error.errors).map(err => err.message);
      return res.status(400).json({ 
        message: 'Validation failed',
        errors: messages
      });
    }
    
    res.status(500).json({ 
      message: 'Error updating profile',
      error: error.message
    });
  }
});

// Change password (protected route)
router.put('/change-password', authMiddleware, async (req, res) => {
  try {
    const { currentPassword, newPassword, confirmNewPassword } = req.body;
    const userId = req.user._id;

    // Validation
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ 
        message: 'Please provide current and new password'
      });
    }

    if (newPassword !== confirmNewPassword) {
      return res.status(400).json({ 
        message: 'New passwords do not match'
      });
    }

    if (newPassword.length < 8) {
      return res.status(400).json({ 
        message: 'New password must be at least 8 characters long'
      });
    }

    // Get user with password field
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ 
        message: 'User not found'
      });
    }

    // Verify current password
    const isPasswordValid = await user.comparePassword(currentPassword);
    if (!isPasswordValid) {
      return res.status(401).json({ 
        message: 'Current password is incorrect',
        error: 'INVALID_PASSWORD'
      });
    }

    // Update password
    user.password = newPassword;
    user.updatedAt = Date.now();
    await user.save();

    res.status(200).json({
      message: 'Password changed successfully'
    });
  } catch (error) {
    console.error('Password change error:', error);
    res.status(500).json({ 
      message: 'Error changing password',
      error: error.message
    });
  }
});

// Get user by ID (protected route - for admin/manager use)
router.get('/users/:id', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.params.id).select('-password');
    
    if (!user) {
      return res.status(404).json({ 
        message: 'User not found'
      });
    }

    res.status(200).json({
      message: 'User retrieved successfully',
      user: user
    });
  } catch (error) {
    console.error('User fetch error:', error);
    res.status(500).json({ 
      message: 'Error fetching user',
      error: error.message
    });
  }
});

// Get all users (protected route - for admin/manager use)
router.get('/users', authMiddleware, async (req, res) => {
  try {
    const { page = 1, limit = 10, search = '' } = req.query;

    // Build search query
    let query = {};
    if (search) {
      query = {
        $or: [
          { firstName: { $regex: search, $options: 'i' } },
          { lastName: { $regex: search, $options: 'i' } },
          { email: { $regex: search, $options: 'i' } }
        ]
      };
    }

    const users = await User.find(query)
      .select('-password')
      .limit(parseInt(limit))
      .skip((parseInt(page) - 1) * parseInt(limit))
      .sort({ createdAt: -1 });

    const total = await User.countDocuments(query);

    res.status(200).json({
      message: 'Users retrieved successfully',
      users: users,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: total,
        pages: Math.ceil(total / parseInt(limit))
      }
    });
  } catch (error) {
    console.error('Users fetch error:', error);
    res.status(500).json({ 
      message: 'Error fetching users',
      error: error.message
    });
  }
});

// Verify token endpoint (useful for frontend to check if token is still valid)
router.get('/verify-token', authMiddleware, async (req, res) => {
  res.status(200).json({
    message: 'Token is valid',
    user: req.user
  });
});

// Health check
router.get('/health', (req, res) => {
  res.json({ 
    status: 'OK',
    service: 'auth-service',
    timestamp: new Date().toISOString()
  });
});

// Root endpoint to show available routes
app.get('/', (req, res) => {
  res.json({
    message: 'Timesheet Authentication Service',
    version: '1.0.0',
    availableEndpoints: [
      'GET  /auth-service/health',
      'POST /auth-service/register',
      'POST /auth-service/login',
      'GET  /auth-service/profile (protected)',
      'PUT  /auth-service/profile (protected)',
      'PUT  /auth-service/change-password (protected)',
      'GET  /auth-service/verify-token (protected)',
      'GET  /auth-service/users (protected)',
      'GET  /auth-service/users/:id (protected)'
    ],
    documentation: {
      register: {
        method: 'POST',
        url: '/auth-service/register',
        body: {
          firstName: 'string (required)',
          lastName: 'string (required)',
          email: 'string (required)',
          password: 'string (required, min 8 chars)',
          confirmPassword: 'string (optional)'
        }
      },
      login: {
        method: 'POST',
        url: '/auth-service/login',
        body: {
          email: 'string (required)',
          password: 'string (required)'
        }
      },
      protectedRoutes: {
        note: 'Include JWT token in Authorization header',
        header: 'Authorization: Bearer YOUR_TOKEN_HERE'
      }
    }
  });
});

// Use the router with /auth-service prefix
app.use('/auth-service', router);

// Catch-all 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Route not found',
    message: `${req.method} ${req.originalUrl} is not defined`,
    hint: 'Make sure to include /auth-service prefix in your URL',
    availableEndpoints: [
      'GET  /auth-service/health',
      'POST /auth-service/register',
      'POST /auth-service/login',
      'GET  /auth-service/profile (protected)',
      'PUT  /auth-service/profile (protected)',
      'PUT  /auth-service/change-password (protected)',
      'GET  /auth-service/verify-token (protected)',
      'GET  /auth-service/users (protected)',
      'GET  /auth-service/users/:id (protected)'
    ]
  });
});

// Start server immediately (don't wait for MongoDB)
const PORT = process.env.PORT || 3002;
app.listen(PORT, () => {
  console.log(`Auth Service running on port ${PORT}`);
  console.log(`Try: http://localhost:${PORT}/auth-service/health`);
});

