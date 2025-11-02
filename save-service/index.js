const express = require('express');
const mongoose = require('mongoose');

const app = express();
const router = express.Router();

// CORS is handled by nginx reverse proxy - no need to configure here
app.use(express.json());

const mongoDBURI = process.env.MONGODB_URI || 'mongodb://admin:password@mongo:27017/timesheet?authSource=admin';

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

const timesheetSchema = new mongoose.Schema({
  date:{type: Date, required: true},
  hours:{type: Number, required: true},
  employeeId:{type: String, required: true},
  projectId:{type: String, required: true},
  taskId:{type: String, required: true},
  recordType:{type: String, required: true},
  wfh:{type: Boolean, default: false},
  status:{type: String, default: 'Saved'},
  createdAt:{type: Date, default: Date.now},
  updatedAt:{type: Date, default: Date.now},
});

const Timesheet = mongoose.model('Timesheet', timesheetSchema);

router.get('/timesheets', async (req, res) => {
  try {
    const { employeeId, startDate, endDate } = req.query;

    // Build filter query
    let filter = {};
    if (employeeId) {
      filter.employeeId = employeeId;
    }
    if (startDate || endDate) {
      filter.date = {};
      if (startDate) {
        filter.date.$gte = new Date(startDate);
      }
      if (endDate) {
        filter.date.$lte = new Date(endDate);
      }
    }

    const timesheets = await Timesheet.find(filter).sort({ date: 1 }).lean();
    
    console.log('[DEBUG-GET] Raw timesheets from DB:', timesheets.length);
    console.log('[DEBUG-GET] Sample record:', timesheets[0]);
    
    // Ensure wfh field exists in all records (for backward compatibility)
    const enrichedTimesheets = timesheets.map(sheet => {
      const enriched = {
        ...sheet,
        wfh: sheet.wfh !== undefined ? sheet.wfh : false
      };
      return enriched;
    });
    
    console.log('[DEBUG-GET] Enriched sample:', enrichedTimesheets[0]);
    
    res.status(200).json({
      message: 'Timesheets retrieved successfully',
      count: enrichedTimesheets.length,
      data: enrichedTimesheets
    });
  } catch (error) {
    res.status(500).json({ message: 'Error retrieving timesheets', error: error.message });
  }
});

router.get('/timesheets/:id', async (req, res) => {
  try {
    const timesheet = await Timesheet.findById(req.params.id).lean();
    if (!timesheet) {
      return res.status(404).json({ message: 'Timesheet not found' });
    }
    
    // Ensure wfh field exists (for backward compatibility)
    if (timesheet.wfh === undefined) {
      timesheet.wfh = false;
    }
    
    res.status(200).json({
      message: 'Timesheet retrieved successfully',
      data: timesheet
    });
  } catch (error) {
    res.status(500).json({ message: 'Error retrieving timesheet', error: error.message });
  }
});

router.post('/timesheets', async (req, res) => {
  try{
    const { date, hours, employeeId, projectId, recordType, taskId, wfh } = req.body;
    
    console.log('[DEBUG-POST] Received:', { date, hours, employeeId, recordType, wfh });
    
    // Search for existing record with same date, employeeId, AND recordType
    const existingRecord = await Timesheet.findOneAndUpdate(
      { 
        date: new Date(date), 
        employeeId: employeeId,
        recordType: recordType
      },
      { 
        hours, 
        projectId, 
        recordType, 
        taskId,
        wfh: wfh !== undefined ? wfh : false,
        updatedAt: Date.now()
      },
      { 
        new: true,  // Return updated document
        upsert: true // Create if doesn't exist
      }
    );

    console.log('[DEBUG-POST] Saved record:', existingRecord);

    if (existingRecord) {
      res.status(201).json({ 
        message: 'Timesheet saved successfully', 
        data: existingRecord,
        action: 'updated'
      });
    }
  } catch (error) {
    res.status(500).json({ message: 'Error saving timesheet', error: error.message });
  }
});

// Weekly Timesheets Endpoint - Create/Update records for entire week
router.post('/timesheets/weekly', async (req, res) => {
  try {
    const { startDate, endDate, hours, employeeId, projectId, recordType, taskId, wfh } = req.body;

    // Validate inputs
    if (startDate === undefined || startDate === null || 
        endDate === undefined || endDate === null || 
        hours === undefined || hours === null || 
        employeeId === undefined || employeeId === null || 
        projectId === undefined || projectId === null || 
        recordType === undefined || recordType === null || 
        taskId === undefined || taskId === null) {
      return res.status(400).json({ 
        message: 'Missing required fields', 
        required: ['startDate', 'endDate', 'hours', 'employeeId', 'projectId', 'recordType', 'taskId']
      });
    }

    const start = new Date(startDate);
    const end = new Date(endDate);

    if (start > end) {
      return res.status(400).json({ message: 'startDate must be before endDate' });
    }

    // Generate array of dates for the week
    const dates = [];
    for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
      dates.push(new Date(d));
    }

    // Create or update records for each day in the week
    const results = [];
    for (const date of dates) {
      const record = await Timesheet.findOneAndUpdate(
        { 
          date: date, 
          employeeId: employeeId,
          recordType: recordType
        },
        { 
          hours, 
          projectId, 
          recordType, 
          taskId,
          wfh: wfh !== undefined ? wfh : false,
          updatedAt: Date.now()
        },
        { 
          new: true,
          upsert: true
        }
      );
      results.push(record);
    }

    res.status(201).json({ 
      message: 'Timesheets saved successfully', 
      count: results.length,
      startDate: start.toISOString().split('T')[0],
      endDate: end.toISOString().split('T')[0],
      data: results,
      action: 'bulk_saved'
    });
  } catch (error) {
    res.status(500).json({ message: 'Error saving timesheet', error: error.message });
  }
});

router.get('/health', (req, res) => {
  res.json({ status: 'OK' });
});

// Root endpoint to show available routes
app.get('/', (req, res) => {
  res.json({
    message: 'Timesheet Save Service',
    availableEndpoints: [
      'GET  /health',
      'POST /timesheets',
      'POST /timesheets/weekly'
    ]
  });
});

// Use the router with /save-service prefix
app.use('/save-service', router);

// Catch-all 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Route not found',
    message: `${req.method} ${req.originalUrl} is not defined`,
    availableEndpoints: [
      'GET  /save-service/health',
      'POST /save-service/timesheets',
      'POST /save-service/timesheets/weekly'
    ],
    hint: 'Make sure to include /save-service prefix in your URL'
  });
});

// Start server immediately (don't wait for MongoDB)
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Save Service running on port ${PORT}`);
  console.log(`Try: http://localhost:${PORT}/save-service/health`);
});
