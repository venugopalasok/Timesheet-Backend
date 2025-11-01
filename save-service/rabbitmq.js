const amqp = require('amqplib');

let channel = null;
let connection = null;

const RABBITMQ_URL = process.env.RABBITMQ_URL || 'amqp://admin:password@rabbitmq:5672';

// Queue names - centralized for consistency
const QUEUES = {
  TIMESHEET_SUBMITTED: 'timesheet.submitted',
  TIMESHEET_SAVED: 'timesheet.saved',
  USER_REGISTERED: 'user.registered'
};

/**
 * Connect to RabbitMQ with retry logic
 */
const connectToRabbitMQ = async (retries = 10, delay = 5000) => {
  for (let i = 0; i < retries; i++) {
    try {
      console.log(`[RabbitMQ] Attempting connection (${i + 1}/${retries})...`);
      connection = await amqp.connect(RABBITMQ_URL);
      channel = await connection.createChannel();
      
      // Declare all queues
      for (const queueName of Object.values(QUEUES)) {
        await channel.assertQueue(queueName, {
          durable: true,
          arguments: {
            'x-message-ttl': 86400000, // 24 hours
            'x-max-length': 10000
          }
        });
      }
      
      console.log('[RabbitMQ] ✓ Connected successfully');
      return true;
    } catch (err) {
      console.error(`[RabbitMQ] ✗ Connection failed: ${err.message}`);
      if (i < retries - 1) {
        console.log(`[RabbitMQ] Retrying in ${delay / 1000}s...`);
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
  }
  console.error('[RabbitMQ] ✗ Failed to connect after all retries');
  return false;
};

/**
 * Publish a message to a queue
 */
const publishMessage = async (queueName, message) => {
  try {
    if (!channel) {
      console.warn('[RabbitMQ] Channel not available, skipping message publish');
      return false;
    }
    
    const messageBuffer = Buffer.from(JSON.stringify(message));
    channel.sendToQueue(queueName, messageBuffer, {
      persistent: true,
      timestamp: Date.now()
    });
    
    console.log(`[RabbitMQ] ✓ Published to ${queueName}:`, message);
    return true;
  } catch (error) {
    console.error(`[RabbitMQ] ✗ Error publishing message:`, error);
    return false;
  }
};

/**
 * Publish user registered event
 */
const publishUserRegistered = async (user) => {
  return await publishMessage(QUEUES.USER_REGISTERED, {
    employeeId: user.employeeId,
    email: user.email,
    firstName: user.firstName,
    lastName: user.lastName,
    timestamp: new Date().toISOString()
  });
};

/**
 * Publish timesheet submitted event
 */
const publishTimesheetSubmitted = async (timesheet) => {
  return await publishMessage(QUEUES.TIMESHEET_SUBMITTED, {
    employeeId: timesheet.employeeId,
    date: timesheet.date,
    hours: timesheet.hours,
    totalHours: timesheet.hours,
    recordType: timesheet.recordType,
    wfh: timesheet.wfh,
    timestamp: new Date().toISOString()
  });
};

/**
 * Publish timesheet saved event
 */
const publishTimesheetSaved = async (timesheet) => {
  return await publishMessage(QUEUES.TIMESHEET_SAVED, {
    employeeId: timesheet.employeeId,
    date: timesheet.date,
    hours: timesheet.hours,
    totalHours: timesheet.hours,
    recordType: timesheet.recordType,
    wfh: timesheet.wfh,
    timestamp: new Date().toISOString()
  });
};

/**
 * Close RabbitMQ connection
 */
const closeConnection = async () => {
  if (channel) await channel.close();
  if (connection) await connection.close();
  console.log('[RabbitMQ] Connection closed');
};

// Graceful shutdown
process.on('SIGINT', closeConnection);
process.on('SIGTERM', closeConnection);

module.exports = {
  connectToRabbitMQ,
  publishMessage,
  publishUserRegistered,
  publishTimesheetSubmitted,
  publishTimesheetSaved,
  closeConnection,
  QUEUES
};



