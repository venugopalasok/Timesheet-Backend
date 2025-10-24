# Timesheet Backend - Microservices

A Node.js microservices backend for managing timesheet records with two main services: Save and Submit.

## Project Structure

```
Timesheet-backend/
├── save-service/          # Service for saving draft timesheets
│   ├── index.js
│   ├── package.json
│   ├── Dockerfile
│   └── .gitignore
├── submit-service/        # Service for submitting final timesheets
│   ├── index.js
│   ├── package.json
│   ├── Dockerfile
│   └── .gitignore
├── docker-compose.yml     # Orchestrate all services
├── package.json          # Root package.json (optional)
└── README.md
```

## Services

### Save Service (Port 3000)
- **Description**: Saves draft timesheet records with status "Saved"
- **Endpoints**:
  - `GET /save-service/health` - Health check
  - `POST /save-service/timesheets` - Create or update timesheet

### Submit Service (Port 3001)
- **Description**: Submits final timesheet records with status "Submitted"
- **Endpoints**:
  - `GET /submit-service/health` - Health check
  - `POST /submit-service/timesheets` - Create or update timesheet

## Prerequisites

- Node.js 18+
- npm or yarn
- MongoDB (local or via Docker)
- Docker & Docker Compose (for containerized setup)

## Local Development

### Option 1: Run Services Individually

**1. Install dependencies for save-service:**
```bash
cd save-service
npm install
npm run dev
```

**2. In another terminal, install dependencies for submit-service:**
```bash
cd submit-service
npm install
npm run dev
```

**Environment Variables:**
Create a `.env` file in each service folder:
```env
MONGODB_URI=mongodb://localhost:27017/timesheet
PORT=3000  # 3001 for submit-service
```

### Option 2: Run with Docker Compose (Recommended)

```bash
# Start all services (MongoDB + Save Service + Submit Service)
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

## API Endpoints

### Save Service
```bash
# Health Check
curl http://localhost:3000/save-service/health

# Create/Update Timesheet (Draft)
curl -X POST http://localhost:3000/save-service/timesheets \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2025-10-24",
    "hours": 8,
    "employeeId": "EMP001",
    "projectId": "PROJ001",
    "recordType": "task",
    "taskId": "TASK001"
  }'
```

### Submit Service
```bash
# Health Check
curl http://localhost:3001/submit-service/health

# Submit Timesheet (Final)
curl -X POST http://localhost:3001/submit-service/timesheets \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2025-10-24",
    "hours": 8,
    "employeeId": "EMP001",
    "projectId": "PROJ001",
    "recordType": "task",
    "taskId": "TASK001"
  }'
```

## Database

Both services share the same MongoDB database: `timesheet`

**Collections:**
- `timesheets` - Stores all timesheet records

**Record Schema:**
```javascript
{
  date: Date,
  hours: Number,
  employeeId: String,
  projectId: String,
  taskId: String,
  recordType: String,
  status: String,  // "Saved" or "Submitted"
  createdAt: Date,
  updatedAt: Date
}
```

## Upsert Logic

Both services use upsert logic: if a record with the same `date` and `employeeId` exists, it will be updated; otherwise, a new record is created.

## Development Scripts

**Save Service:**
```bash
cd save-service
npm run dev      # Run with nodemon
npm run start    # Run in production
```

**Submit Service:**
```bash
cd submit-service
npm run dev      # Run with nodemon
npm run start    # Run in production
```

## Docker Build

**Build individual services:**
```bash
docker build -t timesheet-save-service ./save-service
docker build -t timesheet-submit-service ./submit-service
```

**Run containers:**
```bash
docker run -p 3000:3000 \
  -e MONGODB_URI=mongodb://localhost:27017/timesheet \
  timesheet-save-service

docker run -p 3001:3001 \
  -e MONGODB_URI=mongodb://localhost:27017/timesheet \
  timesheet-submit-service
```

## MongoDB Connection

**Local MongoDB:**
```
mongodb://localhost:27017/timesheet
```

**With Authentication:**
```
mongodb://admin:password@localhost:27017/timesheet
```

**Docker MongoDB (from compose):**
```
mongodb://admin:password@mongo:27017/timesheet
```

## Troubleshooting

**Port already in use:**
```bash
# Kill process on port 3000
lsof -i :3000 | grep LISTEN | awk '{print $2}' | xargs kill -9

# Kill process on port 3001
lsof -i :3001 | grep LISTEN | awk '{print $2}' | xargs kill -9
```

**MongoDB connection issues:**
- Ensure MongoDB is running
- Check connection string in `.env` file
- Verify network connectivity if using Docker

## License

ISC
