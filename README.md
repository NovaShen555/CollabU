# CollabU - Student Team Collaboration System

## Project Structure

- `backend/`: Flask-based REST API & WebSocket Server
- `frontend/`: Vue 3 + Vite + Element Plus Frontend (Basic Setup)

## Setup & Run

### Backend

1. Navigate to `backend` directory:
   ```bash
   cd backend
   ```
2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
3. Initialize Database:
   ```bash
   $env:FLASK_APP="run.py"
   flask db init
   flask db migrate
   flask db upgrade
   ```
4. Run Server:
   ```bash
   flask run --port 5000
   ```
   (Or run `python run.py`)

### Frontend

1. Navigate to `frontend` directory:
   ```bash
   cd frontend
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Run Development Server:
   ```bash
   npm run dev
   ```

## Features Implemented (Backend)

- **User Auth**: Register, Login, JWT Profile
- **Team Management**: Create, Join (Invite Code), Leave, List Members
- **Project Management**: Create, Update, List, Delete
- **Task Management**: CRUD, Infinite Subtasks, Progress Tracking
- **Collaboration**:
  - **Comments**: Async discussion on tasks
  - **Real-time Chat**: WebSocket based chat rooms per task
  - **Files**: Upload/Download attachments
  - **Notifications**: System notifications

## API Documentation

See `DESIGN.md` for API specification. The implementation follows the design closely.
