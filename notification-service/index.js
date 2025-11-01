const express = require('express');
const cors = require('cors');
const amqp = require('amqplib');

const app = express();
app.use(cors());
app.use(express.json());

const RABBITMQ_URL = process.env.RABBITMQ_URL || 'amqp://admin:password@rabbitmq:5672';
const PORT = process.env.PORT || 3003;

let channel = null;
let connection = null;

// Queue names
const QUEUES = {
  TIMESHEET_SUBMITTED: 'timesheet.submitted',
  TIMESHEET_SAVED: 'timesheet.saved',
  USER_REGISTERED: 'user.registered'
};

// Connect to RabbitMQ with retry logic
const connectToRabbitMQ = async (retries = 10, delay = 5000) => {
  for (let i = 0; i < retries; i++) {
    try {
      console.log(`Attempting to connect to RabbitMQ (attempt ${i + 1}/${retries})...`);
      connection = await amqp.connect(RABBITMQ_URL);
      channel = await connection.createChannel();
      
      // Declare queues
      for (const queueName of Object.values(QUEUES)) {
        await channel.assertQueue(queueName, { 
          durable: true,
          arguments: {
            'x-message-ttl': 86400000, // 24 hours TTL
            'x-max-length': 10000 // Max 10k messages
          }
        });
        console.log(`✓ Queue declared: ${queueName}`);
      }
      
      console.log('✓ Connected to RabbitMQ successfully');
      
      // Start consuming messages
      startConsumers();
      
      return true;
    } catch (err) {
      console.error(`✗ RabbitMQ connection attempt ${i + 1}/${retries} failed:`, err.message);
      
      if (i < retries - 1) {
        console.log(`Retrying in ${delay / 1000} seconds...`);
        await new Promise(resolve => setTimeout(resolve, delay));
      } else {
        console.error('✗ Failed to connect to RabbitMQ after all retries');
        return false;
      }
    }
  }
};

// Start message consumers
const startConsumers = () => {
  // Consumer for timesheet submitted events
  channel.consume(QUEUES.TIMESHEET_SUBMITTED, async (msg) => {
    if (msg) {
      try {
        const data = JSON.parse(msg.content.toString());
        console.log('[TIMESHEET_SUBMITTED] Received:', data);
        
        // Simulate notification processing
        await processTimesheetSubmitted(data);
        
        // Acknowledge message
        channel.ack(msg);
        console.log('[TIMESHEET_SUBMITTED] Processed and acknowledged');
      } catch (error) {
        console.error('[TIMESHEET_SUBMITTED] Error processing message:', error);
        // Reject and requeue if processing fails
        channel.nack(msg, false, true);
      }
    }
  });

  // Consumer for timesheet saved events
  channel.consume(QUEUES.TIMESHEET_SAVED, async (msg) => {
    if (msg) {
      try {
        const data = JSON.parse(msg.content.toString());
        console.log('[TIMESHEET_SAVED] Received:', data);
        
        // Simulate notification processing
        await processTimesheetSaved(data);
        
        channel.ack(msg);
        console.log('[TIMESHEET_SAVED] Processed and acknowledged');
      } catch (error) {
        console.error('[TIMESHEET_SAVED] Error processing message:', error);
        channel.nack(msg, false, true);
      }
    }
  });

  // Consumer for user registered events
  channel.consume(QUEUES.USER_REGISTERED, async (msg) => {
    if (msg) {
      try {
        const data = JSON.parse(msg.content.toString());
        console.log('[USER_REGISTERED] Received:', data);
        
        // Simulate welcome email
        await processUserRegistered(data);
        
        channel.ack(msg);
        console.log('[USER_REGISTERED] Processed and acknowledged');
      } catch (error) {
        console.error('[USER_REGISTERED] Error processing message:', error);
        channel.nack(msg, false, true);
      }
    }
  });

  console.log('✓ All consumers started');
};

// Process timesheet submitted
const processTimesheetSubmitted = async (data) => {
  // Simulate email notification to manager
  console.log(`📧 Sending email notification to manager for employee ${data.employeeId}`);
  console.log(`   Timesheet submitted for ${data.date} with ${data.totalHours} hours`);
  
  // Simulate delay
  await new Promise(resolve => setTimeout(resolve, 100));
  
  // In production, you would:
  // - Send actual email via SendGrid/AWS SES
  // - Update analytics dashboard
  // - Trigger approval workflow
  // - Log to audit system
};

// Process timesheet saved
const processTimesheetSaved = async (data) => {
  console.log(`💾 Timesheet auto-saved for employee ${data.employeeId}`);
  console.log(`   Date: ${data.date}, Hours: ${data.totalHours}`);
  
  await new Promise(resolve => setTimeout(resolve, 50));
  
  // In production:
  // - Update user's last activity timestamp
  // - Check for data consistency
  // - Backup to secondary storage
};

// Process user registered
const processUserRegistered = async (data) => {
  console.log(`👋 Sending welcome email to ${data.email}`);
  console.log(`   Employee ID: ${data.employeeId}`);
  console.log(`   Name: ${data.firstName} ${data.lastName}`);
  
  await new Promise(resolve => setTimeout(resolve, 200));
  
  // In production:
  // - Send welcome email with getting started guide
  // - Create default settings for user
  // - Add to mailing list
  // - Notify admin of new user
};

// Publish message to queue (helper function)
const publishMessage = async (queueName, message) => {
  if (!channel) {
    throw new Error('RabbitMQ channel not available');
  }
  
  const messageBuffer = Buffer.from(JSON.stringify(message));
  channel.sendToQueue(queueName, messageBuffer, {
    persistent: true,
    timestamp: Date.now()
  });
  
  console.log(`✓ Published message to ${queueName}:`, message);
};

// REST API endpoints

// Health check
app.get('/health', (req, res) => {
  const isHealthy = channel !== null && connection !== null;
  res.status(isHealthy ? 200 : 503).json({
    status: isHealthy ? 'OK' : 'Unhealthy',
    service: 'notification-service',
    rabbitmq: isHealthy ? 'connected' : 'disconnected',
    timestamp: new Date().toISOString()
  });
});

// Get queue stats (for debugging)
app.get('/stats', async (req, res) => {
  try {
    if (!channel) {
      return res.status(503).json({ error: 'RabbitMQ not connected' });
    }
    
    const stats = {};
    for (const [key, queueName] of Object.entries(QUEUES)) {
      const queueInfo = await channel.checkQueue(queueName);
      stats[key] = {
        queue: queueName,
        messages: queueInfo.messageCount,
        consumers: queueInfo.consumerCount
      };
    }
    
    res.json({
      message: 'Queue statistics',
      stats: stats,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Test endpoint to publish messages manually
app.post('/test/publish', async (req, res) => {
  try {
    const { queue, message } = req.body;
    
    if (!QUEUES[queue]) {
      return res.status(400).json({ 
        error: 'Invalid queue name',
        availableQueues: Object.keys(QUEUES)
      });
    }
    
    await publishMessage(QUEUES[queue], message);
    
    res.json({
      message: 'Test message published successfully',
      queue: QUEUES[queue],
      data: message
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Timesheet Notification Service',
    version: '1.0.0',
    rabbitmq: {
      connected: channel !== null,
      queues: QUEUES
    },
    endpoints: [
      'GET  /health - Health check',
      'GET  /stats - Queue statistics',
      'POST /test/publish - Publish test message'
    ]
  });
});

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('\nShutting down gracefully...');
  if (channel) await channel.close();
  if (connection) await connection.close();
  process.exit(0);
});

// Start server
app.listen(PORT, async () => {
  console.log(`Notification Service running on port ${PORT}`);
  await connectToRabbitMQ();
});

// Export for use by other services
module.exports = { publishMessage, QUEUES };


