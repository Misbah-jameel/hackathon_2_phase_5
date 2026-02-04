# Implementation Plan: Phase IV — Local Kubernetes Deployment

**Branch**: `003-k8s-local-deploy` | **Date**: 2026-02-03 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/003-k8s-local-deploy/spec.md`

## Summary

Deploy the existing Phase III Todo Chatbot (Next.js frontend + FastAPI backend) on a local Minikube Kubernetes cluster. This involves containerizing both services with Docker, creating Helm charts for templated deployment, and exposing services via NodePort for local browser access. No new application features — infrastructure only.

## Technical Context

**Language/Version**: Python 3.12 (backend), Node.js 18 (frontend)
**Primary Dependencies**: Docker Desktop, Minikube v1.38.0, kubectl v1.34.1, Helm v3.x
**Storage**: SQLite (ephemeral, in-pod) — no PVC needed for local dev
**Testing**: Manual verification via `kubectl get pods`, `helm list`, browser access, health check endpoints
**Target Platform**: Windows 10 Pro with Docker Desktop (Minikube Docker driver)
**Project Type**: Web application (frontend + backend microservices)
**Performance Goals**: Pods running within 2 minutes of Helm install; images build in under 5 minutes each
**Constraints**: Local only (no cloud), no new app features, no container registry, no Ingress
**Scale/Scope**: 2 services, 1 replica each, single Minikube node

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Status | Notes |
|------|--------|-------|
| Verification First | PASS | All existing code read before planning; API contracts confirmed from config.py and constants.ts |
| Code Quality | PASS | No application code changes — infrastructure artifacts only (Dockerfiles, Helm charts) |
| Security (Non-Negotiable) | PASS | No secrets hardcoded — JWT_SECRET injected via Helm values; CORS configured via env vars; no wildcard CORS |
| Communication | PASS | Plan documents all decisions with rationale in research.md |
| No invented APIs | PASS | Uses existing `/health` endpoint; no new API endpoints |
| No modifications outside scope | PASS | Only new files (Dockerfiles, Helm charts, .dockerignore); no changes to existing app code |

**Gate Result: ALL PASS — Proceed to implementation.**

## Project Structure

### Documentation (this feature)

```text
specs/003-k8s-local-deploy/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 research decisions
├── data-model.md        # Infrastructure entity model
├── quickstart.md        # Deployment quickstart guide
├── contracts/           # Helm values contracts and architecture
│   ├── helm-values-backend.yaml
│   ├── helm-values-frontend.yaml
│   └── deployment-architecture.md
└── tasks.md             # Phase 2 output (created by /sp.tasks)
```

### Source Code (new files at repository root)

```text
backend/
├── Dockerfile           # NEW — Multi-stage Python build
└── .dockerignore        # NEW — Exclude __pycache__, .env, .git, etc.

frontend/
├── Dockerfile           # NEW — Multi-stage Node.js build
└── .dockerignore        # NEW — Exclude node_modules, .next, .git, etc.

helm/
├── backend/
│   ├── Chart.yaml       # NEW — Helm chart metadata
│   ├── values.yaml      # NEW — Default configuration values
│   └── templates/
│       ├── deployment.yaml   # NEW — K8s Deployment manifest
│       ├── service.yaml      # NEW — K8s Service manifest
│       ├── configmap.yaml    # NEW — K8s ConfigMap for env vars
│       └── _helpers.tpl      # NEW — Helm template helpers
└── frontend/
    ├── Chart.yaml       # NEW — Helm chart metadata
    ├── values.yaml      # NEW — Default configuration values
    └── templates/
        ├── deployment.yaml   # NEW — K8s Deployment manifest
        ├── service.yaml      # NEW — K8s Service manifest
        ├── configmap.yaml    # NEW — K8s ConfigMap for env vars
        └── _helpers.tpl      # NEW — Helm template helpers
```

**Structure Decision**: Web application pattern (existing frontend/ + backend/ directories). New helm/ directory at project root for Helm charts. Dockerfiles placed in each service's root directory.

## Component Architecture

### Backend Dockerfile Design

```
Stage 1 (builder):
  - Base: python:3.12-slim
  - Install dependencies from requirements.txt
  - Copy application code

Stage 2 (runtime):
  - Base: python:3.12-slim
  - Copy installed packages from builder
  - Copy application code
  - Expose port 8000
  - CMD: uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Frontend Dockerfile Design

```
Stage 1 (deps):
  - Base: node:18-alpine
  - Install npm dependencies

Stage 2 (builder):
  - Copy deps from stage 1
  - Accept NEXT_PUBLIC_API_URL as build arg
  - Run npm run build

Stage 3 (runtime):
  - Base: node:18-alpine
  - Copy built application from builder
  - Expose port 3000
  - CMD: npm start
```

### Helm Chart Design

Each chart follows standard Helm 3 conventions:

**Chart.yaml**: Chart name, version, appVersion, description
**values.yaml**: Configurable values (replicas, image, ports, env vars, probes, resources)
**templates/deployment.yaml**: Pod spec with env vars from ConfigMap, probes, resource limits
**templates/service.yaml**: NodePort service exposing container port
**templates/configmap.yaml**: Environment variables as key-value pairs
**templates/_helpers.tpl**: Reusable template functions (fullname, labels, selectors)

### Service Communication

```
Browser → Frontend NodePort (minikube service URL)
Browser → Backend NodePort (minikube service URL, via NEXT_PUBLIC_API_URL baked into JS)
```

The frontend JavaScript runs in the browser, not in the cluster. Therefore:
- `NEXT_PUBLIC_API_URL` must be set to the backend's Minikube NodePort URL at Docker build time
- The backend's `CORS_ORIGINS` must include the frontend's Minikube NodePort URL
- Both URLs are obtained from `minikube service <name> --url`

### Deployment Sequence

```
1. Start Minikube cluster
2. Configure Docker CLI to use Minikube's daemon
3. Build backend Docker image
4. Deploy backend via Helm
5. Get backend NodePort URL from Minikube
6. Build frontend Docker image with backend URL as build arg
7. Update backend CORS_ORIGINS to include frontend NodePort URL
8. Deploy frontend via Helm
9. Verify all pods running
10. Access frontend via minikube service URL
```

## Complexity Tracking

No constitution violations. All artifacts are new infrastructure files — no existing application code modified.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Next.js build fails in Docker (missing dependencies) | Build blocked | Use exact Node.js version from local dev; copy package-lock.json |
| Minikube Docker daemon not accessible on Windows | Cannot build images | Document PowerShell command for `minikube docker-env`; fallback to `minikube image load` |
| CORS mismatch between frontend and backend NodePort URLs | API calls blocked | Deploy backend first, get URL, update CORS via Helm upgrade before deploying frontend |
| SQLite data lost on pod restart | User confusion | Document clearly in README that data is ephemeral |

## Post-Plan Constitution Re-Check

| Gate | Status | Notes |
|------|--------|-------|
| Verification First | PASS | Confirmed existing endpoints, env vars, config patterns |
| Code Quality | PASS | No app code changes |
| Security | PASS | Secrets via Helm values, not hardcoded in manifests |
| No scope creep | PASS | No new features, no cloud, no CI/CD |
| Communication | PASS | All decisions documented in research.md with rationale |

**Gate Result: ALL PASS — Ready for /sp.tasks.**
