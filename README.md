# DevOps Assignment

This project consists of a FastAPI backend and a Next.js frontend that communicates with the backend.

## Project Structure

```
.
├── backend/               # FastAPI backend
│   ├── app/
│   │   └── main.py       # Main FastAPI application
│   └── requirements.txt    # Python dependencies
└── frontend/              # Next.js frontend
    ├── pages/
    │   └── index.js     # Main page
    ├── public/            # Static files
    └── package.json       # Node.js dependencies
```

## Prerequisites

- Python 3.8+
- Node.js 16+
- npm or yarn

## Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Create a virtual environment (recommended):
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: .\venv\Scripts\activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Run the FastAPI server:
   ```bash
   uvicorn app.main:app --reload --port 8000
   ```

   The backend will be available at `http://localhost:8000`

## Frontend Setup

1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```

2. Install dependencies:
   ```bash
   npm install
   # or
   yarn
   ```

3. Configure the backend URL (if different from default):
   - Open `.env.local`
   - Update `NEXT_PUBLIC_API_URL` with your backend URL
   - Example: `NEXT_PUBLIC_API_URL=https://your-backend-url.com`

4. Run the development server:
   ```bash
   npm run dev
   # or
   yarn dev
   ```

   The frontend will be available at `http://localhost:3000`

## Changing the Backend URL

To change the backend URL that the frontend connects to:

1. Open the `.env.local` file in the frontend directory
2. Update the `NEXT_PUBLIC_API_URL` variable with your new backend URL
3. Save the file
4. Restart the Next.js development server for changes to take effect

Example:
```
NEXT_PUBLIC_API_URL=https://your-new-backend-url.com
```

## For deployment:
   ```bash
   npm run build
   # or
   yarn build
   ```

   AND

   ```bash
   npm run start
   # or
   yarn start
   ```

   The frontend will be available at `http://localhost:3000`

## How to Run Locally

You can run the application locally using Docker Compose, which brings up both the frontend (Next.js) and backend (FastAPI).

```bash
docker-compose up -d --build
```
- Frontend will be available at: `http://localhost:3000`
- Backend API will be available at: `http://localhost:8000/api/health`

---

## 📦 Mandatory Deliverables Links

### 1. High-Level Architecture Overview
- **AWS**: An Application Load Balancer routes traffic to highly available EC2 instances running Docker Compose across multiple Availability Zones, managed by an Auto Scaling Group. Securely runs in private subnets with NAT Gateways for egress.
- **GCP**: Natively secure Cloud Run containers accessed via a Global External HTTP(S) Load Balancer using path-based routing (Serverless NEGs).

### 2. External Documentation
[Documentation covering all 10 Requirements (Google Docs Equivalent)](./docs/Architecture.md)

### 3. Hosted URLs
**AWS (EC2 / ALB)**
- Frontend: `http://YOUR-AWS-ALB-DNS.com`
- Backend Health: `http://YOUR-AWS-ALB-DNS.com/api/health`

**GCP (Cloud Run / Load Balancer)**
- Frontend: `http://YOUR-GCP-LB-IP`
- Backend Health: `http://YOUR-GCP-LB-IP/api/health`

### 4. Demo Video
[Link to Demo Video Walkthrough](https://youtube.com/YOUR-VIDEO-LINK)

## API Endpoints

- `GET /api/health`: Health check endpoint
  - Returns: `{"status": "healthy", "message": "Backend is running successfully"}`

- `GET /api/message`: Get the integration message
  - Returns: `{"message": "You've successfully integrated the backend!"}`
