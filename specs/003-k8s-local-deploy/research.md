# Research: Phase IV — Local Kubernetes Deployment

**Feature**: 003-k8s-local-deploy
**Date**: 2026-02-03

## R1: Next.js NEXT_PUBLIC Environment Variables in Docker/K8s

**Decision**: Use a two-stage approach — build the Next.js app with a placeholder API URL, then override at container startup using a runtime script.

**Rationale**: `NEXT_PUBLIC_*` variables are embedded into the JavaScript bundle at `npm run build` time. In Kubernetes, the backend URL depends on how services are exposed (NodePort, minikube service URL). Since this is local Minikube deployment, the frontend runs in the **browser** (not in-cluster), so it needs to reach the backend via the Minikube-exposed URL, not K8s internal DNS.

**Approach chosen**: Build with `NEXT_PUBLIC_API_URL` set at Docker build time. For Minikube, both frontend and backend will be exposed via NodePort services, and the frontend will be built pointing to the backend's NodePort URL. Since `minikube service` provides the actual URL, we accept that images may need rebuilding if ports change. For local dev simplicity, this is acceptable.

**Simpler alternative**: Since this is local-only, we build images inside Minikube's Docker daemon with the correct URL baked in at build time. No runtime substitution needed.

**Alternatives considered**:
- Runtime env var injection via entrypoint script (complex for Next.js SSR)
- Nginx reverse proxy in frontend container (adds unnecessary layer)
- Next.js API routes as proxy (adds code changes — violates scope)

## R2: Frontend-to-Backend Communication Pattern in Minikube

**Decision**: Expose both services as NodePort, use `minikube service` to get URLs. Frontend is built with backend's NodePort URL.

**Rationale**: Minikube on Windows with Docker driver supports NodePort access via `minikube service --url`. The frontend JavaScript runs in the user's browser, so it needs a URL reachable from the host machine, not K8s internal DNS. The backend NodePort URL is stable for the lifetime of the minikube cluster.

**Alternatives considered**:
- ClusterIP + kubectl port-forward (requires manual port-forward management)
- Ingress controller (out of scope per spec, adds complexity)
- LoadBalancer type (Minikube tunnel required, adds complexity)

## R3: Docker Multi-Stage Builds for Image Size

**Decision**: Use multi-stage Docker builds for both frontend and backend to minimize image size.

**Rationale**: Multi-stage builds separate build-time dependencies from runtime, producing smaller images. Frontend: Node.js build stage + Node.js slim runtime. Backend: Python build stage with pip install + Python slim runtime.

**Alternatives considered**:
- Single-stage builds (larger images, include build tools)
- Distroless images (too restrictive for debugging in local dev)

## R4: Helm Chart Structure

**Decision**: Two separate Helm charts — one for frontend (`helm/frontend/`), one for backend (`helm/backend/`). Each chart contains Deployment, Service, and ConfigMap templates.

**Rationale**: Separate charts allow independent deployment, scaling, and configuration of each service. This mirrors microservice best practices and prepares for Phase V cloud deployment.

**Alternatives considered**:
- Single umbrella chart with subcharts (overengineered for 2 services)
- Raw kubectl manifests without Helm (loses templating and values management)

## R5: SQLite in Kubernetes Pods

**Decision**: SQLite database is stored ephemerally within the backend pod. Data is lost on pod restart. This is acceptable for local development.

**Rationale**: Per spec FR-023, ephemeral storage is acceptable. Adding PersistentVolumeClaims is out of scope. Users are informed that data does not persist across pod restarts.

**Alternatives considered**:
- PVC for SQLite file (out of scope, adds complexity)
- PostgreSQL as separate pod (out of scope for Phase IV)

## R6: Minikube Docker Daemon for Image Builds

**Decision**: Use `eval $(minikube docker-env)` (or Windows equivalent `minikube -p minikube docker-env --shell powershell | Invoke-Expression`) to build images directly in Minikube's Docker daemon. Set `imagePullPolicy: Never` in Helm charts.

**Rationale**: Per spec FR-019, no container registry is needed. Building in Minikube's Docker daemon makes images immediately available to the cluster without pushing to a registry.

**Alternatives considered**:
- Push to Docker Hub (requires account, network dependency)
- Minikube image load command (slower, copies images)

## R7: Health Check Probes

**Decision**: Backend uses HTTP GET `/health` for both liveness and readiness probes. Frontend uses HTTP GET on `/` (Next.js landing page) for liveness, TCP check on port 3000 for readiness.

**Rationale**: Backend already has a dedicated `/health` endpoint. Frontend doesn't have a dedicated health endpoint, but the landing page serves as adequate liveness check. TCP readiness check on the port is lightweight and confirms the server is accepting connections.

**Alternatives considered**:
- Custom health endpoint in frontend (requires code changes — out of scope)
- Exec-based probes running curl inside container (heavier, requires curl in image)

## R8: Base Image Selection

**Decision**: Frontend uses `node:18-alpine` (build) and `node:18-alpine` (runtime). Backend uses `python:3.12-slim` (build and runtime).

**Rationale**: Alpine images are smallest for Node.js. Python slim images provide good balance of size and compatibility. Python 3.12 is the latest stable version compatible with all dependencies.

**Alternatives considered**:
- `node:18-slim` (larger than alpine but better glibc compatibility)
- `python:3.12-alpine` (can cause issues with compiled Python packages like bcrypt)
