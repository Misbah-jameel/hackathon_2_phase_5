# Deployment Runbook

## Table of Contents
1. [Local Development](#1-local-development)
2. [Minikube Deployment](#2-minikube-deployment)
3. [Cloud Deployment](#3-cloud-deployment)
4. [Troubleshooting](#4-troubleshooting)
5. [Rollback Procedures](#5-rollback-procedures)

---

## 1. Local Development

### 1.1 Backend (No Kubernetes)

```bash
cd backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt

# Required environment variables
export DATABASE_URL="sqlite:///./todoapp.db"
export JWT_SECRET="your-secret-key-minimum-32-characters-long"

# Optional
export ANTHROPIC_API_KEY="sk-ant-..."
export CORS_ORIGINS="http://localhost:3000"

uvicorn app.main:app --reload --port 8000
```

Verify: `curl http://localhost:8000/health`

### 1.2 Frontend

```bash
cd frontend
npm install
npm run dev
```

Verify: Open http://localhost:3000

### 1.3 Running Tests

```bash
cd backend
python -m pytest tests/ -v --tb=short
# Expected: 178 passed, 1 known failure (fuzzy match)
```

---

## 2. Minikube Deployment

### Prerequisites
- Docker Desktop running
- Minikube installed (`minikube version`)
- Helm 3.14+ (`helm version`)
- kubectl (`kubectl version --client`)
- Dapr CLI (`dapr version`)

### 2.1 Start Minikube

```bash
minikube start --memory=4096 --cpus=2 --driver=docker
minikube status  # Verify: host=Running, kubelet=Running, apiserver=Running
```

### 2.2 Install Dapr

```bash
dapr init -k --wait
kubectl get pods -n dapr-system  # All pods should be Running
```

### 2.3 Deploy Strimzi Kafka

```bash
# Install Strimzi operator
helm repo add strimzi https://strimzi.io/charts/
helm repo update
kubectl create namespace kafka
helm install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  --namespace kafka \
  --set watchNamespaces="{kafka}" \
  --set resources.requests.memory=256Mi \
  --set resources.requests.cpu=100m \
  --set resources.limits.memory=512Mi \
  --set resources.limits.cpu=250m

# Wait for operator
kubectl wait --for=condition=ready pod -l name=strimzi-cluster-operator -n kafka --timeout=120s

# Deploy Kafka cluster + topics
kubectl apply -f helm/kafka/kafka-cluster.yaml

# Wait for Kafka to be ready (takes 2-3 minutes)
kubectl wait kafka/kafka-cluster --for=condition=Ready -n kafka --timeout=300s
```

### 2.4 Deploy Dapr Components

```bash
kubectl create namespace todo-app
kubectl apply -f backend/dapr/components/pubsub-kafka-local.yaml -n todo-app
kubectl apply -f backend/dapr/components/statestore.yaml -n todo-app
kubectl apply -f backend/dapr/config.yaml -n todo-app
```

### 2.5 Build Docker Images

```bash
# Point Docker to Minikube's daemon
eval $(minikube docker-env)

# Build images
docker build -t todo-backend:latest ./backend
docker build -t todo-frontend:latest ./frontend

# Verify
docker images | grep todo
```

### 2.6 Deploy with Helm

```bash
# Backend
helm install todo-backend helm/backend/ \
  --namespace todo-app \
  --set env.ANTHROPIC_API_KEY="sk-ant-..." \
  --set env.JWT_SECRET="$(python -c 'import secrets; print(secrets.token_urlsafe(32))')"

# Frontend
helm install todo-frontend helm/frontend/ \
  --namespace todo-app
```

### 2.7 Verify Deployment

```bash
# Check pods
kubectl get pods -n todo-app
# Expected: todo-backend-xxx (Running, 2/2 - app + Dapr sidecar)
#           todo-frontend-xxx (Running, 1/1)

# Check logs
kubectl logs -n todo-app deployment/todo-backend -c todo-backend

# Access services
minikube service todo-frontend -n todo-app
minikube service todo-backend -n todo-app  # API docs at /docs
```

### 2.8 End-to-End Validation Checklist

- [ ] Frontend loads at Minikube service URL
- [ ] User can register and login
- [ ] Create a task with priority, tags, due date
- [ ] Search and filter tasks
- [ ] Health endpoint shows `db: ok`, `dapr: ok`
- [ ] Audit log populates (`GET /api/events/audit`)

---

## 3. Cloud Deployment

### 3.1 Prerequisites
- Cloud Kubernetes cluster (AKS/GKE/OKE) with 2+ nodes
- `kubectl` configured with cluster credentials
- Managed PostgreSQL instance (e.g., Neon, Cloud SQL, Azure DB)
- Managed Kafka (e.g., Redpanda Cloud, Confluent Cloud)
- Container registry (GitHub Container Registry)

### 3.2 Create Namespace and Secrets

```bash
kubectl apply -f k8s/cloud/namespace.yaml

# Create secrets (fill in actual values)
kubectl create secret generic todo-secrets \
  --from-literal=JWT_SECRET="$(python -c 'import secrets; print(secrets.token_urlsafe(32))')" \
  --from-literal=DATABASE_URL="postgresql://user:pass@host/db?sslmode=require" \
  --from-literal=ANTHROPIC_API_KEY="sk-ant-..." \
  --from-literal=BETTER_AUTH_SECRET="$(python -c 'import secrets; print(secrets.token_urlsafe(32))')" \
  -n todo-app

kubectl create secret generic kafka-secrets \
  --from-literal=brokers="your-broker:9093" \
  --from-literal=username="your-user" \
  --from-literal=password="your-password" \
  -n todo-app
```

### 3.3 Install Dapr on Cloud Cluster

```bash
dapr init -k --wait
kubectl get pods -n dapr-system  # Verify all running
```

### 3.4 Deploy Dapr Components (Cloud)

```bash
kubectl apply -f backend/dapr/components/pubsub-kafka-cloud.yaml -n todo-app
kubectl apply -f backend/dapr/components/secretstore-k8s.yaml -n todo-app
kubectl apply -f backend/dapr/config.yaml -n todo-app
```

### 3.5 Push Docker Images

```bash
# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Build and push
docker build -t ghcr.io/USERNAME/todo-backend:v5.0 ./backend
docker push ghcr.io/USERNAME/todo-backend:v5.0

docker build -t ghcr.io/USERNAME/todo-frontend:v5.0 \
  --build-arg NEXT_PUBLIC_API_URL=https://your-domain.com ./frontend
docker push ghcr.io/USERNAME/todo-frontend:v5.0
```

### 3.6 Deploy with Helm (Cloud Values)

```bash
helm install todo-backend helm/backend/ \
  -f helm/backend/values-cloud.yaml \
  --set image.tag=v5.0 \
  -n todo-app

helm install todo-frontend helm/frontend/ \
  --set image.repository=ghcr.io/USERNAME/todo-frontend \
  --set image.tag=v5.0 \
  --set image.pullPolicy=IfNotPresent \
  --set service.type=ClusterIP \
  -n todo-app
```

### 3.7 Configure Ingress

```bash
# Install NGINX Ingress Controller (if not already present)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml

# Apply ingress rules
kubectl apply -f k8s/cloud/ingress.yaml

# Get external IP
kubectl get ingress -n todo-app
# Wait for ADDRESS to be assigned
```

### 3.8 Verify Cloud Deployment

```bash
# Check pod status
kubectl get pods -n todo-app

# Check backend logs
kubectl logs -n todo-app deployment/todo-backend -c todo-backend --tail=50

# Test health endpoint
curl https://YOUR-DOMAIN/health

# Test API
curl https://YOUR-DOMAIN/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username": "test", "email": "test@example.com", "password": "testpass123"}'
```

---

## 4. Troubleshooting

### Pod not starting
```bash
kubectl describe pod <pod-name> -n todo-app
kubectl logs <pod-name> -n todo-app -c todo-backend --previous
```

### Dapr sidecar not injected
- Verify annotation `dapr.io/enabled: "true"` in pod spec
- Check Dapr system: `kubectl get pods -n dapr-system`
- Restart Dapr: `dapr uninstall -k && dapr init -k`

### Kafka connection issues
- Verify Kafka is running: `kubectl get kafka -n kafka`
- Check Dapr pub/sub component: `kubectl get component -n todo-app`
- Test Kafka connectivity from pod: `kubectl exec -it <pod> -n todo-app -- curl http://localhost:3500/v1.0/healthz`

### Database connection issues
- Verify DATABASE_URL secret is set: `kubectl get secret todo-secrets -n todo-app -o yaml`
- Check if PostgreSQL allows connections from cluster IP range
- Verify SSL mode in connection string

### Frontend can't reach backend
- Check CORS_ORIGINS includes the frontend URL
- Verify service names: `kubectl get svc -n todo-app`
- Check ingress routing: `kubectl describe ingress todo-ingress -n todo-app`

---

## 5. Rollback Procedures

### Helm Rollback
```bash
# View history
helm history todo-backend -n todo-app

# Rollback to previous revision
helm rollback todo-backend 1 -n todo-app

# Verify
kubectl rollout status deployment/todo-backend -n todo-app
```

### Database Rollback
SQLite (local): Restore from backup file.
PostgreSQL (cloud): Use managed service point-in-time recovery.

### Emergency: Scale to Zero
```bash
kubectl scale deployment todo-backend --replicas=0 -n todo-app
kubectl scale deployment todo-frontend --replicas=0 -n todo-app
```

### Nuclear: Delete Everything
```bash
helm uninstall todo-backend -n todo-app
helm uninstall todo-frontend -n todo-app
kubectl delete namespace todo-app
```
