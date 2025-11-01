/**
 * AWS SQS Helper - Replaces RabbitMQ for Free Tier Deployment
 * 
 * Free Tier: 1 million requests per month (permanent)
 * No server to manage, fully serverless
 */

const AWS = require('aws-sdk');

// Configure AWS SDK
AWS.config.update({
  region: process.env.AWS_REGION || 'us-east-1',
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
});

const sqs = new AWS.SQS();
const QUEUE_URL = process.env.SQS_QUEUE_URL;

/**
 * Send message to SQS queue (replaces RabbitMQ publish)
 * @param {Object} message - Message object to send
 * @param {string} messageType - Type of message (e.g., 'timesheet_saved', 'timesheet_submitted')
 */
async function sendMessage(message, messageType = 'default') {
  if (!QUEUE_URL) {
    console.warn('SQS_QUEUE_URL not configured. Skipping message.');
    return null;
  }

  const params = {
    QueueUrl: QUEUE_URL,
    MessageBody: JSON.stringify(message),
    MessageAttributes: {
      messageType: {
        DataType: 'String',
        StringValue: messageType
      },
      timestamp: {
        DataType: 'Number',
        StringValue: Date.now().toString()
      }
    }
  };

  try {
    const result = await sqs.sendMessage(params).promise();
    console.log(`Message sent to SQS: ${messageType}`, result.MessageId);
    return result;
  } catch (error) {
    console.error('Error sending message to SQS:', error);
    throw error;
  }
}

/**
 * Receive messages from SQS queue (replaces RabbitMQ consume)
 * @param {Function} callback - Function to process each message
 * @param {number} maxMessages - Maximum messages to receive (1-10)
 */
async function receiveMessages(callback, maxMessages = 1) {
  if (!QUEUE_URL) {
    console.warn('SQS_QUEUE_URL not configured. Cannot receive messages.');
    return;
  }

  const params = {
    QueueUrl: QUEUE_URL,
    MaxNumberOfMessages: maxMessages,
    WaitTimeSeconds: 20, // Long polling (reduces costs)
    MessageAttributeNames: ['All']
  };

  try {
    const data = await sqs.receiveMessage(params).promise();

    if (data.Messages && data.Messages.length > 0) {
      for (const message of data.Messages) {
        try {
          const body = JSON.parse(message.Body);
          const messageType = message.MessageAttributes?.messageType?.StringValue || 'unknown';

          // Process message with callback
          await callback(body, messageType, message);

          // Delete message after successful processing
          await deleteMessage(message.ReceiptHandle);
          console.log(`Message processed and deleted: ${message.MessageId}`);
        } catch (error) {
          console.error('Error processing message:', error);
          // Message will be returned to queue after visibility timeout
        }
      }
    }

    return data.Messages;
  } catch (error) {
    console.error('Error receiving messages from SQS:', error);
    throw error;
  }
}

/**
 * Delete message from queue after processing
 * @param {string} receiptHandle - Receipt handle from received message
 */
async function deleteMessage(receiptHandle) {
  if (!QUEUE_URL) return;

  const params = {
    QueueUrl: QUEUE_URL,
    ReceiptHandle: receiptHandle
  };

  try {
    await sqs.deleteMessage(params).promise();
  } catch (error) {
    console.error('Error deleting message from SQS:', error);
    throw error;
  }
}

/**
 * Start polling for messages (replaces RabbitMQ consumer)
 * @param {Function} callback - Function to process each message
 * @param {number} pollInterval - Interval between polls in ms (default: 0 for continuous)
 */
function startPolling(callback, pollInterval = 0) {
  console.log('Starting SQS message polling...');

  const poll = async () => {
    try {
      await receiveMessages(callback, 10); // Get up to 10 messages
    } catch (error) {
      console.error('Polling error:', error);
    }

    // Continue polling
    setTimeout(poll, pollInterval);
  };

  poll();
}

/**
 * Get queue attributes (for monitoring)
 */
async function getQueueStats() {
  if (!QUEUE_URL) return null;

  const params = {
    QueueUrl: QUEUE_URL,
    AttributeNames: [
      'ApproximateNumberOfMessages',
      'ApproximateNumberOfMessagesNotVisible',
      'ApproximateNumberOfMessagesDelayed'
    ]
  };

  try {
    const data = await sqs.getQueueAttributes(params).promise();
    return {
      available: parseInt(data.Attributes.ApproximateNumberOfMessages),
      inFlight: parseInt(data.Attributes.ApproximateNumberOfMessagesNotVisible),
      delayed: parseInt(data.Attributes.ApproximateNumberOfMessagesDelayed)
    };
  } catch (error) {
    console.error('Error getting queue stats:', error);
    return null;
  }
}

// Export functions
module.exports = {
  sendMessage,
  receiveMessages,
  deleteMessage,
  startPolling,
  getQueueStats
};

/**
 * Example Usage:
 * 
 * // In your service (e.g., save-service):
 * const { sendMessage } = require('./shared/sqs-helper');
 * 
 * app.post('/timesheets', async (req, res) => {
 *   // Save to database...
 *   const timesheet = await Timesheet.create(req.body);
 *   
 *   // Send notification
 *   await sendMessage({
 *     employeeId: timesheet.employeeId,
 *     action: 'saved',
 *     data: timesheet
 *   }, 'timesheet_saved');
 *   
 *   res.json(timesheet);
 * });
 * 
 * // In notification-service:
 * const { startPolling } = require('./shared/sqs-helper');
 * 
 * function handleMessage(message, messageType, rawMessage) {
 *   console.log(`Received ${messageType}:`, message);
 *   
 *   if (messageType === 'timesheet_saved') {
 *     // Send email notification
 *     console.log(`Timesheet saved by employee ${message.employeeId}`);
 *   }
 * }
 * 
 * startPolling(handleMessage);
 */

