# Deployment Guide

## Live Deployment

| Service | Platform | URL |
|---------|----------|-----|
| Frontend | Vercel | https://todo-frontend-app-liart.vercel.app |
| Backend API | Vercel (Serverless Python) | https://todo-backend-api-three.vercel.app |
| Database | Neon PostgreSQL | us-east-1 (pooler endpoint) |
| Health Check | - | https://todo-backend-api-three.vercel.app/health |

## Deployment Architecture

```
User (Browser)
     │
     ▼
┌─────────────────────┐     ┌──────────────────────┐
│  Vercel (Frontend)   │────▶│  Vercel (Backend)     │
│  Next.js 14 SSR      │     │  FastAPI Serverless   │
│  todo-frontend-app   │     │  todo-backend-api     │
└─────────────────────┘     └──────────┬───────────┘
                                       │
                                       ▼
                            ┌──────────────────────┐
                            │  Neon PostgreSQL      │
                            │  Serverless Postgres  │
                            │  us-east-1            │
                            └──────────────────────┘
```

> **Note**: On Vercel serverless, Dapr sidecar and Kafka are not available. Event publishing degrades gracefully (logged but not published). For the full event-driven pipeline, use the Kubernetes deployment.

## Environment Variables

### Backend (Vercel)

| Variable | Required | Description |
|----------|----------|-------------|
| `DATABASE_URL` | Yes | Neon PostgreSQL connection string |
| `JWT_SECRET` | Yes | JWT signing key (32+ characters) |
| `CORS_ORIGINS` | Yes | Allowed CORS origins (`*` for all) |
| `ANTHROPIC_API_KEY` | No | Claude API key for chatbot |
| `ANTHROPIC_MODEL` | No | Claude model ID (default: claude-3-haiku) |

### Frontend (Vercel)

| Variable | Required | Description |
|----------|----------|-------------|
| `NEXT_PUBLIC_API_URL` | Yes | Backend API URL |

## Quick Deploy Steps

### 1. Backend
```bash
cd backend
vercel login
vercel deploy --prod --yes
# Set env vars via Vercel dashboard or CLI
```

### 2. Frontend
```bash
cd frontend
vercel deploy --prod --yes
# Set NEXT_PUBLIC_API_URL to backend URL
vercel deploy --prod --yes  # Redeploy with env var
```

### 3. Verify
```bash
curl https://todo-backend-api-three.vercel.app/health
# {"status":"healthy","version":"2.0.0","db":"ok","dapr":"unavailable"}
```

## Redeployment

```bash
# Backend
cd backend && vercel deploy --prod --yes

# Frontend
cd frontend && vercel deploy --prod --yes
```

## For Full Stack (Kubernetes)

See [deployment-runbook.md](deployment-runbook.md) for complete Minikube and cloud Kubernetes deployment with Dapr + Kafka.
