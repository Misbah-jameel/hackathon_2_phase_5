# Cloud-Native Todo Chatbot

A full-stack, event-driven todo application with AI chatbot integration, built on cloud-native infrastructure using Kafka, Dapr, and Kubernetes.

## Live Demo

| Service | URL |
|---------|-----|
| Frontend | https://todo-frontend-app-liart.vercel.app |
| Backend API | https://todo-backend-api-three.vercel.app |
| Health Check | https://todo-backend-api-three.vercel.app/health |

## Architecture

```
                    ┌──────────────┐
                    │   Frontend   │
                    │  (Next.js)   │
                    └──────┬───────┘
                           │ HTTP
                    ┌──────▼───────┐
                    │   Backend    │
                    │  (FastAPI)   │
                    └──┬───────┬───┘
                       │       │
              ┌────────▼──┐ ┌──▼────────┐
              │  SQLite /  │ │   Dapr    │
              │ PostgreSQL │ │  Sidecar  │
              └────────────┘ └─────┬─────┘
                                   │ Pub/Sub
                            ┌──────▼──────┐
                            │    Kafka    │
                            │  (Strimzi)  │
                            └──────┬──────┘
                                   │
                    ┌──────────────┼──────────────┐
                    │              │              │
              ┌─────▼─────┐ ┌─────▼─────┐ ┌─────▼──────┐
              │   Audit   │ │ Reminder  │ │ Recurrence │
              │ Consumer  │ │ Consumer  │ │  Consumer  │
              └───────────┘ └───────────┘ └────────────┘
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Next.js 14, React 18, TypeScript, Tailwind CSS |
| Backend | FastAPI, Python 3.12, SQLModel |
| Database | SQLite (local) / PostgreSQL (cloud via Neon) |
| Messaging | Apache Kafka via Dapr Pub/Sub |
| Infrastructure | Dapr (pub/sub, state, service invocation, jobs, secrets) |
| Orchestration | Kubernetes (Minikube local, AKS/GKE/OKE cloud) |
| Kafka Operator | Strimzi (local) / Redpanda Cloud (production) |
| Cloud Hosting | Vercel (backend serverless + frontend) |
| CI/CD | GitHub Actions |
| AI | Anthropic Claude API (chatbot) |

## Features

### Core
- User authentication (JWT-based)
- CRUD task management with AI chatbot interface
- Natural language task creation via Claude

### Advanced (Phase V)
- **Task Priorities**: High, Medium, Low with color-coded badges
- **Tags**: Multi-tag support with chip UI and filtering
- **Due Dates**: Date picker with overdue/due-soon indicators
- **Reminders**: Scheduled via Dapr Jobs API, delivered through Kafka events
- **Recurring Tasks**: Daily, weekly, monthly, yearly, or custom cron patterns
- **Search**: Case-insensitive keyword search across title and description
- **Filter**: By status, priority, tags, due date range (AND logic)
- **Sort**: By created date, due date, priority, title (asc/desc)
- **Pagination**: Server-side with configurable page size

### Event-Driven Architecture
- Task lifecycle events (created, updated, completed, deleted) published to Kafka
- Audit trail consumer logs all events for compliance
- Reminder consumer processes scheduled notifications
- Recurrence consumer generates next task instances

## Project Structure

```
├── backend/
│   ├── app/
│   │   ├── consumers/          # Kafka event consumers
│   │   │   ├── audit_consumer.py
│   │   │   ├── reminder_consumer.py
│   │   │   └── recurrence_consumer.py
│   │   ├── models/             # SQLModel data models
│   │   ├── routers/            # FastAPI route handlers
│   │   ├── schemas/            # Pydantic request/response schemas
│   │   ├── services/           # Business logic & Dapr client
│   │   ├── config.py           # Environment configuration
│   │   ├── database.py         # Database engine setup
│   │   ├── logging_config.py   # Structured JSON logging
│   │   └── main.py             # FastAPI application entry
│   ├── dapr/                   # Dapr component definitions
│   │   └── components/
│   ├── tests/                  # 178 passing tests
│   ├── Dockerfile
│   └── requirements.txt
├── frontend/
│   ├── app/                    # Next.js app router pages
│   ├── components/tasks/       # Task UI components
│   ├── hooks/                  # React hooks (useTasks)
│   ├── lib/                    # API client, validation schemas
│   ├── types/                  # TypeScript type definitions
│   └── Dockerfile
├── helm/
│   ├── backend/                # Backend Helm chart
│   ├── frontend/               # Frontend Helm chart
│   └── kafka/                  # Strimzi Kafka manifests
├── k8s/cloud/                  # Cloud deployment manifests
├── .github/workflows/          # CI/CD pipeline
└── specs/                      # Design specifications
```

## Quick Start

### Prerequisites
- Python 3.12+
- Node.js 18+
- Docker Desktop
- Minikube
- Helm 3.14+
- Dapr CLI

### Local Development (No Kubernetes)

**Backend:**
```bash
cd backend
python -m venv venv
source venv/bin/activate  # or venv\Scripts\activate on Windows
pip install -r requirements.txt

# Set environment variables
export DATABASE_URL="sqlite:///./todoapp.db"
export JWT_SECRET="your-secret-key-at-least-32-characters-long"
export ANTHROPIC_API_KEY="sk-ant-..."

uvicorn app.main:app --reload --port 8000
```

**Frontend:**
```bash
cd frontend
npm install
npm run dev
```

Access at http://localhost:3000 (frontend) and http://localhost:8000/docs (API docs).

### Cloud Deployment (Vercel + Neon)

**Backend:**
```bash
cd backend
vercel login
vercel deploy --prod --yes

# Set environment variables (one-time)
echo "postgresql://user:pass@host.neon.tech/db?sslmode=require" | vercel env add DATABASE_URL production
echo "your-jwt-secret-32-chars-minimum" | vercel env add JWT_SECRET production
echo "*" | vercel env add CORS_ORIGINS production
echo "sk-ant-..." | vercel env add ANTHROPIC_API_KEY production
```

**Frontend:**
```bash
cd frontend
vercel deploy --prod --yes

# Set backend URL
echo "https://your-backend.vercel.app" | vercel env add NEXT_PUBLIC_API_URL production

# Redeploy to pick up env var
vercel deploy --prod --yes
```

### Local Kubernetes (Minikube)

See [docs/deployment-runbook.md](docs/deployment-runbook.md) for full instructions.

```bash
# 1. Start Minikube
minikube start --memory=4096 --cpus=2

# 2. Install Dapr
dapr init -k

# 3. Install Strimzi Kafka
helm repo add strimzi https://strimzi.io/charts/
helm install strimzi-kafka-operator strimzi/strimzi-kafka-operator -n kafka --create-namespace
kubectl apply -f helm/kafka/kafka-cluster.yaml

# 4. Build images
eval $(minikube docker-env)
docker build -t todo-backend:latest ./backend
docker build -t todo-frontend:latest ./frontend

# 5. Deploy with Helm
helm install todo-backend helm/backend/ -n todo-app --create-namespace
helm install todo-frontend helm/frontend/ -n todo-app

# 6. Access
minikube service todo-frontend -n todo-app
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register new user |
| POST | `/api/auth/login` | Login, returns JWT |
| GET | `/api/tasks` | List tasks (search, filter, sort, paginate) |
| POST | `/api/tasks` | Create task |
| GET | `/api/tasks/{id}` | Get task by ID |
| PUT | `/api/tasks/{id}` | Update task |
| DELETE | `/api/tasks/{id}` | Delete task |
| POST | `/api/chatbot/chat` | AI chatbot interaction |
| GET | `/api/events/audit` | Get audit log |
| GET | `/health` | Health check (DB + Dapr status) |
| GET | `/dapr/subscribe` | Dapr subscription definitions |

### Query Parameters for GET /api/tasks

| Parameter | Type | Description |
|-----------|------|-------------|
| `search` | string | Keyword search (title + description) |
| `priority` | string | Comma-separated: high,medium,low,none |
| `tags` | string | Comma-separated tag filter |
| `status` | string | `pending` or `completed` |
| `due_before` | datetime | Due date upper bound |
| `due_after` | datetime | Due date lower bound |
| `sort_by` | string | `created_at`, `due_date`, `priority`, `title` |
| `sort_order` | string | `asc` or `desc` |
| `page` | int | Page number (default: 1) |
| `page_size` | int | Items per page (default: 20, max: 100) |

## Testing

```bash
cd backend
python -m pytest tests/ -v --tb=short
```

178 tests covering: schemas, routers, services, dependencies, configuration.

## CI/CD Pipeline

The GitHub Actions pipeline (`.github/workflows/ci-cd.yaml`) runs:

1. **Lint**: ruff (Python) + TypeScript check (frontend)
2. **Test**: pytest with SQLite test database
3. **Build**: Docker images pushed to GitHub Container Registry (on main push)
4. **Deploy**: Helm upgrade to cloud Kubernetes cluster (on main push)

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DATABASE_URL` | Yes | `sqlite:///./todoapp.db` | Database connection string |
| `JWT_SECRET` | Yes | - | JWT signing key (32+ chars) |
| `ANTHROPIC_API_KEY` | No | - | Claude API key for chatbot |
| `CORS_ORIGINS` | No | `http://localhost:3000` | Allowed CORS origins |
| `DAPR_HOST` | No | `localhost` | Dapr sidecar host |
| `DAPR_PORT` | No | `3500` | Dapr sidecar port |
| `DAPR_PUBSUB_NAME` | No | `pubsub` | Dapr pub/sub component name |

## Phase History

| Phase | Description | Status |
|-------|-------------|--------|
| I | Backend API (FastAPI + SQLModel) | Complete |
| II | Frontend (Next.js + Tailwind) | Complete |
| III | AI Chatbot (Claude integration) | Complete |
| IV | Docker + Helm + Minikube | Complete |
| V | Event-driven architecture + Cloud | Complete |
