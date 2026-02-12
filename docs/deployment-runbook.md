# Deployment Runbook

## Table of Contents
1. [Local Development](#1-local-development)
2. [Minikube Deployment](#2-minikube-deployment)
3. [Vercel Cloud Deployment](#3-vercel-cloud-deployment-recommended-for-quick-deploy)
4. [Kubernetes Cloud Deployment](#4-kubernetes-cloud-deployment)
5. [OKE Cloud Deployment (Oracle Always Free)](#5-oke-cloud-deployment-oracle-always-free)
6. [Troubleshooting](#5-troubleshooting)
7. [Rollback Procedures](#6-rollback-procedures)

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

## 3. Vercel Cloud Deployment (Recommended for Quick Deploy)

### 3.1 Prerequisites
- Vercel account and CLI (`npm i -g vercel`)
- Neon PostgreSQL database (free tier: https://neon.tech)
- Anthropic API key (optional, for chatbot)

### 3.2 Deploy Backend

```bash
cd backend
vercel login
vercel deploy --prod --yes
```

### 3.3 Set Backend Environment Variables

```bash
echo "postgresql://user:pass@host.neon.tech/db?sslmode=require" | vercel env add DATABASE_URL production
echo "your-jwt-secret-32-chars-minimum" | vercel env add JWT_SECRET production
echo "*" | vercel env add CORS_ORIGINS production
echo "sk-ant-api03-..." | vercel env add ANTHROPIC_API_KEY production
echo "claude-3-haiku-20240307" | vercel env add ANTHROPIC_MODEL production

# Redeploy to pick up env vars
vercel deploy --prod --yes
```

### 3.4 Deploy Frontend

```bash
cd frontend
vercel deploy --prod --yes

# Set API URL pointing to backend
echo "https://your-backend-url.vercel.app" | vercel env add NEXT_PUBLIC_API_URL production

# Redeploy with env var
vercel deploy --prod --yes
```

### 3.5 Verify Vercel Deployment

```bash
# Health check
curl https://your-backend-url.vercel.app/health
# Expected: {"status":"healthy","version":"2.0.0","db":"ok","dapr":"unavailable"}

# Test signup
curl -X POST https://your-backend-url.vercel.app/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"email":"test@demo.com","password":"Test12345","name":"Test"}'
```

> **Note**: Dapr sidecar is not available on Vercel (serverless). Event publishing and Kafka consumers are gracefully degraded. For full event-driven features, use the Kubernetes deployment below.

### 3.6 Current Live URLs

| Service | URL |
|---------|-----|
| Frontend | https://todo-frontend-app-liart.vercel.app |
| Backend API | https://todo-backend-api-three.vercel.app |
| Database | Neon PostgreSQL (us-east-1) |

---

## 4. Kubernetes Cloud Deployment

### 4.1 Prerequisites
- Cloud Kubernetes cluster (AKS/GKE/OKE) with 2+ nodes
- `kubectl` configured with cluster credentials
- Managed PostgreSQL instance (e.g., Neon, Cloud SQL, Azure DB)
- Managed Kafka (e.g., Redpanda Cloud, Confluent Cloud)
- Container registry (GitHub Container Registry)

### 4.2 Create Namespace and Secrets

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

### 4.3 Install Dapr on Cloud Cluster

```bash
dapr init -k --wait
kubectl get pods -n dapr-system  # Verify all running
```

### 4.4 Deploy Dapr Components (Cloud)

```bash
kubectl apply -f backend/dapr/components/pubsub-kafka-cloud.yaml -n todo-app
kubectl apply -f backend/dapr/components/secretstore-k8s.yaml -n todo-app
kubectl apply -f backend/dapr/config.yaml -n todo-app
```

### 4.5 Push Docker Images

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

### 4.6 Deploy with Helm (Cloud Values)

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

### 4.7 Configure Ingress

```bash
# Install NGINX Ingress Controller (if not already present)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml

# Apply ingress rules
kubectl apply -f k8s/cloud/ingress.yaml

# Get external IP
kubectl get ingress -n todo-app
# Wait for ADDRESS to be assigned
```

### 4.8 Verify Cloud Deployment

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

## 5. OKE Cloud Deployment (Oracle Always Free)

Full event-driven deployment on Oracle Kubernetes Engine (OKE) with Strimzi Kafka + Dapr on the Always Free ARM tier (4 OCPUs, 24GB RAM).

### 5.1 Prerequisites
- OCI account with Always Free tier eligible
- OCI CLI installed and configured (`oci setup config`)
- `kubectl`, `helm`, `docker` installed
- Neon PostgreSQL database (external, free tier)
- Anthropic API key (optional, for chatbot)

### 5.2 Resource Budget (Fits in 24GB ARM)

| Component | Memory Request | Memory Limit |
|-----------|---------------|-------------|
| kube-system | ~1.5GB | ~3GB |
| Dapr control plane | 256Mi | 512Mi |
| Strimzi operator | 256Mi | 512Mi |
| Kafka broker | 384Mi | 768Mi |
| Backend + Dapr sidecar | 256Mi | 512Mi |
| Frontend | 128Mi | 256Mi |
| **Total** | **~3GB** | **~5.5GB** |

### 5.3 Automated Deployment

The fastest way to deploy is using the automated script:

```bash
# Set required environment variables
export OCI_REGION="us-ashburn-1"
export OCI_TENANCY_NAMESPACE="your-namespace"   # oci os ns get
export OCI_USERNAME="oracleidentitycloudservice/your@email.com"
export OCI_AUTH_TOKEN="your-auth-token"
export OKE_CLUSTER_OCID="ocid1.cluster.oc1..."
export DATABASE_URL="postgresql://user:pass@host.neon.tech/db?sslmode=require"
export ANTHROPIC_API_KEY="sk-ant-..."            # Optional

# Run full deployment
bash scripts/deploy-oke.sh

# Or run individual sections
bash scripts/deploy-oke.sh prereqs   # Check prerequisites
bash scripts/deploy-oke.sh build     # Build ARM64 images
bash scripts/deploy-oke.sh deploy    # Deploy apps only
bash scripts/deploy-oke.sh verify    # Verify deployment
```

### 5.4 Manual Step-by-Step

#### 5.4.1 Create OKE Cluster

1. Go to OCI Console > Developer Services > Kubernetes Clusters (OKE)
2. Click "Create cluster" > "Quick create"
3. Settings:
   - Name: `todo-chatbot-oke`
   - Kubernetes version: v1.30.x (latest)
   - Shape: **VM.Standard.A1.Flex** (ARM, Always Free)
   - OCPUs: 4, Memory: 24GB
   - Node count: 1
   - Image: Oracle Linux 8 (aarch64)
4. Wait 10-15 minutes for cluster creation

#### 5.4.2 Configure kubectl

```bash
oci ce cluster create-kubeconfig \
  --cluster-id $OKE_CLUSTER_OCID \
  --file $HOME/.kube/config \
  --region $OCI_REGION \
  --token-version 2.0.0 \
  --kube-endpoint PUBLIC_ENDPOINT

kubectl get nodes  # Verify: 1 ARM node Ready
```

#### 5.4.3 Build and Push ARM64 Images to OCIR

```bash
# Setup cross-compilation
docker buildx create --name arm-builder --use --platform linux/arm64
docker buildx inspect --bootstrap

# Login to Oracle Container Image Registry
echo "$OCI_AUTH_TOKEN" | docker login "${OCI_REGION}.ocir.io" \
  -u "${OCI_TENANCY_NAMESPACE}/${OCI_USERNAME}" --password-stdin

# Build and push
OCIR="${OCI_REGION}.ocir.io/${OCI_TENANCY_NAMESPACE}"
docker buildx build --platform linux/arm64 --tag "${OCIR}/todo-backend:latest" --push ./backend
docker buildx build --platform linux/arm64 --tag "${OCIR}/todo-frontend:latest" --push ./frontend
```

#### 5.4.4 Create Namespaces and Secrets

```bash
kubectl create namespace todo-app
kubectl create namespace kafka

# OCIR image pull secret
kubectl create secret docker-registry ocir-secret \
  --docker-server="${OCI_REGION}.ocir.io" \
  --docker-username="${OCI_TENANCY_NAMESPACE}/${OCI_USERNAME}" \
  --docker-password="$OCI_AUTH_TOKEN" \
  -n todo-app

# Application secrets
kubectl create secret generic todo-secrets \
  --from-literal=DATABASE_URL="$DATABASE_URL" \
  --from-literal=JWT_SECRET="$(openssl rand -base64 32)" \
  --from-literal=ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" \
  --from-literal=BETTER_AUTH_SECRET="$(openssl rand -base64 32)" \
  -n todo-app
```

#### 5.4.5 Install Dapr

```bash
dapr init -k --wait
kubectl get pods -n dapr-system  # All 3 pods Running
```

#### 5.4.6 Deploy Strimzi Kafka

```bash
# Install Strimzi operator
helm repo add strimzi https://strimzi.io/charts/
helm repo update
helm install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  --namespace kafka \
  --set watchNamespaces="{kafka}" \
  --set resources.requests.memory=256Mi \
  --set resources.limits.memory=512Mi

kubectl wait --for=condition=ready pod -l name=strimzi-cluster-operator -n kafka --timeout=120s

# Deploy ARM-optimized Kafka cluster + topics
kubectl apply -f helm/kafka/kafka-cluster-oke.yaml
kubectl wait kafka/kafka-cluster --for=condition=Ready -n kafka --timeout=300s
```

#### 5.4.7 Apply Dapr Components

```bash
kubectl apply -f backend/dapr/components/pubsub-kafka-oke.yaml
kubectl apply -f backend/dapr/components/statestore-oke.yaml
kubectl apply -f backend/dapr/config.yaml -n todo-app
```

#### 5.4.8 Deploy with Helm

```bash
OCIR="${OCI_REGION}.ocir.io/${OCI_TENANCY_NAMESPACE}"

helm install todo-backend helm/backend/ \
  -f helm/backend/values-oke.yaml \
  --set image.repository="${OCIR}/todo-backend" \
  -n todo-app

helm install todo-frontend helm/frontend/ \
  -f helm/frontend/values-oke.yaml \
  --set image.repository="${OCIR}/todo-frontend" \
  -n todo-app
```

#### 5.4.9 Setup NGINX Ingress

```bash
# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=controller -n ingress-nginx --timeout=120s

# Apply OKE ingress rules (with OCI LB annotations)
kubectl apply -f k8s/cloud/ingress-oke.yaml

# Get Load Balancer IP (wait 1-3 minutes)
kubectl get ingress todo-ingress -n todo-app
```

#### 5.4.10 Update CORS with Load Balancer IP

```bash
LB_IP=$(kubectl get ingress todo-ingress -n todo-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

helm upgrade todo-backend helm/backend/ \
  -f helm/backend/values-oke.yaml \
  --set image.repository="${OCIR}/todo-backend" \
  --set env.CORS_ORIGINS="http://${LB_IP}" \
  -n todo-app
```

### 5.5 Verify OKE Deployment

```bash
# Quick health check
bash scripts/check-oke-status.sh

# Or manual verification:
kubectl get pods -n todo-app        # backend 2/2, frontend 1/1
kubectl get pods -n kafka           # kafka broker Running
kubectl get pods -n dapr-system     # 3 pods Running

# Health endpoint
curl http://<LB_IP>/health
# Expected: {"status":"healthy","version":"2.0.0","db":"ok","dapr":"ok"}

# Test full flow
# 1. Open http://<LB_IP>/ in browser
# 2. Register a new user
# 3. Login and create a task
# 4. Verify audit events: kubectl logs -n todo-app deployment/todo-backend -c todo-backend | grep "audit"
```

### 5.6 CI/CD for OKE

GitHub Actions is configured to deploy to OKE automatically. Add these secrets to your GitHub repository:

| Secret | Description |
|--------|-------------|
| `OCI_REGION` | OCI region (e.g., `us-ashburn-1`) |
| `OCI_TENANCY_NAMESPACE` | Object Storage namespace |
| `OCI_USERNAME` | OCIR login username |
| `OCI_AUTH_TOKEN` | OCI Auth Token for OCIR |
| `OKE_CLUSTER_OCID` | OKE cluster OCID |
| `CORS_ORIGINS` | Comma-separated allowed origins |
| `NEXT_PUBLIC_API_URL` | Backend URL for frontend |

The `deploy-oke` job runs after the build job on push to main.

---

## 6. Troubleshooting

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

## 7. Rollback Procedures

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
