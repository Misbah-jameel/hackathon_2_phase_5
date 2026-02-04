# Deployment Architecture Contract

## Service Topology (Minikube)

```
┌─────────────────────────────────────────────────────────┐
│                    Minikube Cluster                       │
│                                                          │
│  ┌──────────────────┐     ┌──────────────────┐          │
│  │  Frontend Pod     │     │  Backend Pod      │          │
│  │  ┌──────────────┐ │     │  ┌──────────────┐ │          │
│  │  │  Next.js      │ │     │  │  FastAPI      │ │          │
│  │  │  Port: 3000   │ │     │  │  Port: 8000   │ │          │
│  │  │  (SSR + SPA)  │ │     │  │  (REST API)   │ │          │
│  │  └──────────────┘ │     │  │  SQLite (local)│ │          │
│  └────────┬─────────┘     │  └──────────────┘ │          │
│           │                └────────┬─────────┘          │
│  ┌────────▼─────────┐     ┌────────▼─────────┐          │
│  │  Frontend Service │     │  Backend Service  │          │
│  │  Type: NodePort   │     │  Type: NodePort   │          │
│  │  Port: 3000       │     │  Port: 8000       │          │
│  └────────┬─────────┘     └────────┬─────────┘          │
└───────────┼────────────────────────┼─────────────────────┘
            │                        │
    ┌───────▼────────┐      ┌───────▼────────┐
    │  Host Browser   │ ──→ │  Host Browser   │
    │  (via minikube  │      │  (API calls     │
    │   service URL)  │      │   from browser) │
    └────────────────┘      └────────────────┘
```

## Communication Flow

1. User opens browser → Frontend NodePort URL (via `minikube service todo-frontend --url`)
2. Browser loads Next.js app (HTML/JS/CSS)
3. Browser JavaScript makes API calls to Backend NodePort URL
4. Backend processes requests, reads/writes SQLite
5. Backend returns JSON responses to browser

## Port Assignments

| Service  | Container Port | Service Port | NodePort     |
|----------|---------------|-------------|--------------|
| Frontend | 3000          | 3000        | Auto-assigned |
| Backend  | 8000          | 8000        | Auto-assigned |

## Image Build Strategy

```
Developer Machine
  │
  ├─ eval $(minikube docker-env)     # Point Docker CLI to Minikube daemon
  │
  ├─ docker build -t todo-backend:latest ./backend
  │
  ├─ docker build -t todo-frontend:latest \
  │     --build-arg NEXT_PUBLIC_API_URL=<backend-nodeport-url> \
  │     ./frontend
  │
  └─ helm install todo-backend ./helm/backend
  └─ helm install todo-frontend ./helm/frontend
```

## Helm Release Names

| Release        | Chart Path      | Namespace |
|----------------|-----------------|-----------|
| todo-backend   | helm/backend/   | default   |
| todo-frontend  | helm/frontend/  | default   |
