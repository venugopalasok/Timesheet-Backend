const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');

const app = express();
const router = express.Router();

app.use(cors());
app.use(express.json());

const mongoDBURI = process.env.MONGODB_URI || 'mongodb://localhost:27017/timesheet';

mongoose.connect(mongoDBURI, {
  serverSelectionTimeoutMS: 5000,
  connectTimeoutMS: 5000,
  retryWrites: false
}).then(() => {
  console.log('Connected to MongoDB');
}).catch((err) => {
  console.error('Error connecting to MongoDB:', err);
});

const timesheetSchema = new mongoose.Schema({
  date:{type: Date, required: true},
  hours:{type: Number, required: true},
  employeeId:{type: String, required: true},
  projectId:{type: String, required: true},
  taskId:{type: String, required: true},
  recordType:{type: String, required: true},
  status:{type: String, default: 'Submitted'},
  createdAt:{type: Date, default: Date.now},
  updatedAt:{type: Date, default: Date.now},
});

const Timesheet = mongoose.model('Timesheet', timesheetSchema);

router.post('/timesheets', async (req, res) => {
  try{
    const { date, hours, employeeId, projectId, recordType, taskId } = req.body;
    
    // Search for existing record with same date and employeeId
    const existingRecord = await Timesheet.findOneAndUpdate(
      { 
        date: new Date(date), 
        employeeId: employeeId 
      },
      { 
        hours, 
        projectId, 
        recordType, 
        taskId,
        status: 'Submitted',
        updatedAt: Date.now()
      },
      { 
        new: true,  // Return updated document
        upsert: true // Create if doesn't exist
      }
    );

    if (existingRecord) {
      res.status(201).json({ 
        message: 'Timesheet submitted successfully', 
        data: existingRecord,
        action: 'submitted'
      });
    }
  } catch (error) {
    res.status(500).json({ message: 'Error submitting timesheet', error: error.message });
  }
});

router.get('/health', (req, res) => {
  res.json({ status: 'OK' });
});

// Root endpoint to show available routes
app.get('/', (req, res) => {
  res.json({
    message: 'Timesheet Submit Service',
    availableEndpoints: [
      'GET  /health',
      'POST /timesheets'
    ]
  });
});

// Use the router with /submit-service prefix
app.use('/submit-service', router);

// Catch-all 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Route not found',
    message: `${req.method} ${req.originalUrl} is not defined`,
    availableEndpoints: [
      'GET  /submit-service/health',
      'POST /submit-service/timesheets'
    ],
    hint: 'Make sure to include /submit-service prefix in your URL'
  });
});

// Start server immediately (don't wait for MongoDB)
const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`Submit Service running on port ${PORT}`);
  console.log(`Try: http://localhost:${PORT}/submit-service/health`);
});
