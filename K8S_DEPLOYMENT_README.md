# Kubernetes Local Deployment Guide

Deploy the Todo Chatbot application (Next.js frontend + FastAPI backend) on a local Minikube Kubernetes cluster.

## Prerequisites

- **Docker Desktop** (running)
- **Minikube** v1.38+
- **kubectl** v1.34+
- **Helm** v3.x

Verify all tools are installed:

```powershell
docker version
minikube version
kubectl version --client
helm version
```

## Architecture

```
Browser --> Frontend NodePort (Next.js, port 3000)
Browser --> Backend NodePort (FastAPI, port 8000)
```

- Both services run as Kubernetes Deployments with 1 replica each
- Exposed via NodePort services for host access through Minikube
- Frontend JS runs in the browser and calls backend API directly via NodePort URL
- Backend uses ephemeral SQLite (data lost on pod restart)
- No Ingress, no container registry -- images built directly in Minikube's Docker daemon

## Step-by-Step Deployment

### 1. Start Minikube

```powershell
minikube start --driver=docker
minikube status
```

### 2. Point Docker CLI to Minikube's Daemon

```powershell
# PowerShell
minikube -p minikube docker-env --shell powershell | Invoke-Expression

# Bash / Git Bash
eval $(minikube docker-env)

# Verify (should show Minikube's images, not local Docker)
docker images
```

### 3. Build Docker Images

```powershell
# Build backend
docker build -t todo-backend:latest ./backend

# Build frontend (with placeholder URL -- will rebuild after backend deploys)
docker build -t todo-frontend:latest --build-arg NEXT_PUBLIC_API_URL=http://localhost:8000 ./frontend
```

### 4. Deploy Backend

```powershell
helm install todo-backend ./helm/backend
kubectl wait --for=condition=ready pod -l app=todo-backend --timeout=120s
```

### 5. Get Backend URL and Rebuild Frontend

```powershell
# Get backend's NodePort URL
$BACKEND_URL = minikube service todo-backend --url
Write-Output "Backend URL: $BACKEND_URL"

# Rebuild frontend with the actual backend URL
docker build -t todo-frontend:latest --build-arg NEXT_PUBLIC_API_URL=$BACKEND_URL ./frontend
```

### 6. Deploy Frontend

```powershell
helm install todo-frontend ./helm/frontend
kubectl wait --for=condition=ready pod -l app=todo-frontend --timeout=120s
```

### 7. Update Backend CORS

Create a file `helm/backend/cors-override.yaml`:

```yaml
env:
  CORS_ORIGINS: "<frontend-url>,<backend-url>,http://localhost:3000"
```

Then upgrade:

```powershell
$FRONTEND_URL = minikube service todo-frontend --url
helm upgrade todo-backend ./helm/backend -f ./helm/backend/cors-override.yaml
```

### 8. Access the Application

```powershell
# Get the frontend URL
minikube service todo-frontend --url

# Or open directly in browser
minikube service todo-frontend
```

## Verification

```powershell
# All pods should show Running 1/1
kubectl get pods

# Both releases should show deployed
helm list

# Backend health check
curl <backend-url>/health
# Expected: {"status":"healthy"}
```

## Common Operations

### View Logs

```powershell
kubectl logs -f deployment/todo-backend
kubectl logs -f deployment/todo-frontend
```

### Scale Replicas

```powershell
kubectl scale deployment todo-backend --replicas=2
kubectl get pods  # Verify 2 backend pods
kubectl scale deployment todo-backend --replicas=1  # Scale back
```

### Restart a Deployment

```powershell
kubectl rollout restart deployment/todo-backend
kubectl rollout restart deployment/todo-frontend
```

### Update Configuration

```powershell
# Modify values in helm/backend/values.yaml or use --set
helm upgrade todo-backend ./helm/backend
helm upgrade todo-frontend ./helm/frontend
```

### Uninstall Everything

```powershell
helm uninstall todo-frontend
helm uninstall todo-backend
kubectl get all  # Verify no orphaned resources
```

### Stop/Start Minikube

```powershell
minikube stop
minikube start  # Cluster state is preserved
```

## Troubleshooting

### Pod in CrashLoopBackOff

```powershell
kubectl logs -l app=todo-backend --tail=50
kubectl describe pod -l app=todo-backend
```

Common causes:
- Missing Python dependency (check `requirements.txt`)
- Invalid environment variables in ConfigMap
- Port conflict

### Images Not Found

Ensure Docker CLI is pointed to Minikube's daemon:

```powershell
minikube -p minikube docker-env --shell powershell | Invoke-Expression
docker images | Select-String "todo"
```

The `imagePullPolicy` must be `Never` in values.yaml (already configured).

### CORS Errors in Browser

Update backend CORS_ORIGINS to include the frontend's NodePort URL:

```powershell
$FRONTEND_URL = minikube service todo-frontend --url
# Update cors-override.yaml with the correct URL, then:
helm upgrade todo-backend ./helm/backend -f ./helm/backend/cors-override.yaml
```

### Frontend Shows Blank Page / API Errors

The frontend JS bundle has the backend URL baked in at build time. If the backend NodePort changed, rebuild the frontend image:

```powershell
$BACKEND_URL = minikube service todo-backend --url
docker build -t todo-frontend:latest --build-arg NEXT_PUBLIC_API_URL=$BACKEND_URL ./frontend
kubectl rollout restart deployment/todo-frontend
```

### Data Lost After Pod Restart

This is expected behavior. SQLite data is ephemeral and stored in the pod's filesystem. For persistent storage, consider PostgreSQL with a PersistentVolumeClaim (out of scope for local dev).

## AI DevOps Tools (Optional)

### kubectl-ai

If installed, use natural language to manage the cluster:

```powershell
kubectl-ai "show me the status of all pods and services"
kubectl-ai "scale the todo-backend deployment to 2 replicas"
kubectl-ai "show me the logs of the todo-backend pod"
```

### kagent

If available, use for automated cluster health checks and operations.

## File Structure

```
backend/
  Dockerfile           # Multi-stage Python build
  .dockerignore        # Excludes __pycache__, .env, etc.

frontend/
  Dockerfile           # 3-stage Node.js build (deps, builder, runtime)
  .dockerignore        # Excludes node_modules, .next, etc.

helm/
  backend/
    Chart.yaml         # Chart metadata
    values.yaml        # Default configuration
    templates/
      deployment.yaml  # Pod spec with probes and resources
      service.yaml     # NodePort service
      configmap.yaml   # Environment variables
      _helpers.tpl     # Template helpers

  frontend/
    Chart.yaml
    values.yaml
    templates/
      deployment.yaml
      service.yaml
      configmap.yaml
      _helpers.tpl
```
