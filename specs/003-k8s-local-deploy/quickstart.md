# Quickstart: Phase IV — Local Kubernetes Deployment

**Feature**: 003-k8s-local-deploy
**Prerequisites**: Docker Desktop, Minikube, kubectl, Helm

## Prerequisites Check

```powershell
# Verify all tools are installed
docker version
minikube version
kubectl version --client
helm version
```

## Step 1: Start Minikube

```powershell
minikube start --driver=docker
minikube status
```

## Step 2: Point Docker CLI to Minikube's Docker Daemon

```powershell
# PowerShell
minikube -p minikube docker-env --shell powershell | Invoke-Expression

# Verify (should show minikube's Docker)
docker images
```

## Step 3: Build Docker Images

```powershell
# Build backend image
docker build -t todo-backend:latest ./backend

# Get the backend service URL (deploy backend first, then build frontend)
# For now, build with placeholder — will rebuild after backend is deployed
docker build -t todo-frontend:latest --build-arg NEXT_PUBLIC_API_URL=http://localhost:8000 ./frontend
```

## Step 4: Deploy with Helm

```powershell
# Deploy backend first
helm install todo-backend ./helm/backend

# Wait for backend to be ready
kubectl wait --for=condition=ready pod -l app=todo-backend --timeout=120s

# Get backend URL
$BACKEND_URL = minikube service todo-backend --url
Write-Output "Backend URL: $BACKEND_URL"

# Rebuild frontend with correct backend URL
docker build -t todo-frontend:latest --build-arg NEXT_PUBLIC_API_URL=$BACKEND_URL ./frontend

# Deploy frontend
helm install todo-frontend ./helm/frontend

# Wait for frontend to be ready
kubectl wait --for=condition=ready pod -l app=todo-frontend --timeout=120s
```

## Step 5: Access the Application

```powershell
# Get frontend URL
minikube service todo-frontend --url

# Open in browser
minikube service todo-frontend
```

## Step 6: Verify Deployment

```powershell
# Check all pods are running
kubectl get pods

# Check services
kubectl get services

# Check Helm releases
helm list

# Check pod logs
kubectl logs -l app=todo-backend
kubectl logs -l app=todo-frontend
```

## Common Operations

```powershell
# Scale replicas
kubectl scale deployment todo-backend --replicas=2

# View pod logs
kubectl logs -f deployment/todo-backend

# Restart a deployment
kubectl rollout restart deployment/todo-frontend

# Uninstall everything
helm uninstall todo-frontend
helm uninstall todo-backend

# Stop Minikube
minikube stop
```
