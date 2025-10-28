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
  wfh:{type: Boolean, default: false},
  status:{type: String, default: 'Saved'},
  createdAt:{type: Date, default: Date.now},
  updatedAt:{type: Date, default: Date.now},
});

const Timesheet = mongoose.model('Timesheet', timesheetSchema);

router.post('/timesheets', async (req, res) => {
  try{
    const { date, hours, employeeId, projectId, recordType, taskId, wfh } = req.body;
    
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
        wfh: wfh !== undefined ? wfh : false,
        updatedAt: Date.now()
      },
      { 
        new: true,  // Return updated document
        upsert: true // Create if doesn't exist
      }
    );

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

router.get('/health', (req, res) => {
  res.json({ status: 'OK' });
});

// Use the router with /save-service prefix
app.use('/save-service', router);

// Start server immediately (don't wait for MongoDB)
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Try: http://localhost:${PORT}/save-service/health`);
});