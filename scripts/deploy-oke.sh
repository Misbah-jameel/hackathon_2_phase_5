#!/bin/bash
# =============================================================================
# Oracle OKE (Always Free ARM) Deployment Script
# Cloud-Native Todo Chatbot with Dapr + Strimzi Kafka
# =============================================================================
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
header(){ echo -e "\n${BLUE}========== $1 ==========${NC}\n"; }

# =============================================================================
# Configuration - EDIT THESE BEFORE RUNNING
# =============================================================================
OCI_REGION="${OCI_REGION:-us-ashburn-1}"
OCI_TENANCY_NAMESPACE="${OCI_TENANCY_NAMESPACE:-}"          # oci os ns get
OCI_USERNAME="${OCI_USERNAME:-}"                             # oracleidentitycloudservice/your@email.com
OCI_AUTH_TOKEN="${OCI_AUTH_TOKEN:-}"                         # OCI Auth Token (not API key)
OKE_CLUSTER_OCID="${OKE_CLUSTER_OCID:-}"
OKE_COMPARTMENT_OCID="${OKE_COMPARTMENT_OCID:-}"

DATABASE_URL="${DATABASE_URL:-}"                             # Neon PostgreSQL connection string
JWT_SECRET="${JWT_SECRET:-$(openssl rand -base64 32)}"
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
BETTER_AUTH_SECRET="${BETTER_AUTH_SECRET:-$(openssl rand -base64 32)}"
CORS_ORIGINS="${CORS_ORIGINS:-*}"                            # Updated after LB IP is known

OCIR_REGISTRY="${OCI_REGION}.ocir.io"
BACKEND_IMAGE="${OCIR_REGISTRY}/${OCI_TENANCY_NAMESPACE}/todo-backend"
FRONTEND_IMAGE="${OCIR_REGISTRY}/${OCI_TENANCY_NAMESPACE}/todo-frontend"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# =============================================================================
# Section 1: Prerequisites Check
# =============================================================================
check_prerequisites() {
    header "Section 1: Prerequisites Check"

    local missing=()
    for cmd in oci kubectl helm docker; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        else
            log "$cmd: $(command -v "$cmd")"
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required tools: ${missing[*]}
Install:
  oci   - https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm
  kubectl - https://kubernetes.io/docs/tasks/tools/
  helm  - https://helm.sh/docs/intro/install/
  docker - https://docs.docker.com/get-docker/"
    fi

    # Validate required environment variables
    if [ -z "$OCI_TENANCY_NAMESPACE" ]; then
        error "OCI_TENANCY_NAMESPACE not set. Run: oci os ns get"
    fi
    if [ -z "$DATABASE_URL" ]; then
        error "DATABASE_URL not set. Get from Neon dashboard: https://console.neon.tech"
    fi

    log "All prerequisites met!"
}

# =============================================================================
# Section 2: OKE Cluster Creation (guidance)
# =============================================================================
create_oke_cluster() {
    header "Section 2: OKE Cluster Setup"

    if [ -n "$OKE_CLUSTER_OCID" ]; then
        log "OKE cluster OCID provided: $OKE_CLUSTER_OCID"
        log "Skipping cluster creation."
        return
    fi

    warn "No OKE_CLUSTER_OCID set. Create a cluster first:"
    echo ""
    echo "Option A: OCI Console (Recommended for Always Free)"
    echo "  1. Go to: https://cloud.oracle.com > Developer Services > Kubernetes Clusters (OKE)"
    echo "  2. Click 'Create cluster' > 'Quick create'"
    echo "  3. Settings:"
    echo "     - Name: todo-chatbot-oke"
    echo "     - Kubernetes version: v1.30.x (latest)"
    echo "     - Shape: VM.Standard.A1.Flex (ARM, Always Free)"
    echo "     - OCPUs: 4, Memory: 24GB"
    echo "     - Node count: 1"
    echo "     - Image: Oracle Linux 8 (aarch64)"
    echo "  4. Click 'Create' and wait 10-15 minutes"
    echo ""
    echo "Option B: OCI CLI"
    echo "  oci ce cluster create \\"
    echo "    --compartment-id \$OKE_COMPARTMENT_OCID \\"
    echo "    --name todo-chatbot-oke \\"
    echo "    --kubernetes-version v1.30.1"
    echo ""
    echo "After creation, set OKE_CLUSTER_OCID and re-run this script."
    exit 0
}

# =============================================================================
# Section 3: Configure kubectl
# =============================================================================
configure_kubectl() {
    header "Section 3: Configure kubectl"

    if [ -z "$OKE_CLUSTER_OCID" ]; then
        error "OKE_CLUSTER_OCID not set"
    fi

    log "Generating kubeconfig for OKE cluster..."
    oci ce cluster create-kubeconfig \
        --cluster-id "$OKE_CLUSTER_OCID" \
        --file "$HOME/.kube/config" \
        --region "$OCI_REGION" \
        --token-version 2.0.0 \
        --kube-endpoint PUBLIC_ENDPOINT

    log "Verifying cluster connectivity..."
    kubectl get nodes || error "Cannot connect to OKE cluster"
    log "kubectl configured successfully!"
}

# =============================================================================
# Section 4: Build ARM64 Docker Images
# =============================================================================
build_images() {
    header "Section 4: Build ARM64 Docker Images"

    # Setup buildx for cross-compilation
    if ! docker buildx inspect arm-builder &>/dev/null; then
        log "Creating Docker buildx builder for ARM64..."
        docker buildx create --name arm-builder --use --platform linux/arm64
        docker buildx inspect --bootstrap
    else
        docker buildx use arm-builder
    fi

    # Login to OCIR
    log "Logging in to OCIR ($OCIR_REGISTRY)..."
    echo "$OCI_AUTH_TOKEN" | docker login "$OCIR_REGISTRY" \
        -u "${OCI_TENANCY_NAMESPACE}/${OCI_USERNAME}" --password-stdin

    # Build and push backend
    log "Building backend (linux/arm64)..."
    docker buildx build \
        --platform linux/arm64 \
        --tag "${BACKEND_IMAGE}:${IMAGE_TAG}" \
        --push \
        ./backend

    # Build and push frontend
    log "Building frontend (linux/arm64)..."
    docker buildx build \
        --platform linux/arm64 \
        --tag "${FRONTEND_IMAGE}:${IMAGE_TAG}" \
        --build-arg NEXT_PUBLIC_API_URL="${CORS_ORIGINS}" \
        --push \
        ./frontend

    log "Images pushed to OCIR!"
    log "  Backend:  ${BACKEND_IMAGE}:${IMAGE_TAG}"
    log "  Frontend: ${FRONTEND_IMAGE}:${IMAGE_TAG}"
}

# =============================================================================
# Section 5: Create Namespaces and Secrets
# =============================================================================
create_secrets() {
    header "Section 5: Create Namespaces & Secrets"

    # Create namespaces
    kubectl create namespace todo-app --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace kafka --dry-run=client -o yaml | kubectl apply -f -

    # OCIR image pull secret
    log "Creating OCIR pull secret..."
    kubectl create secret docker-registry ocir-secret \
        --docker-server="$OCIR_REGISTRY" \
        --docker-username="${OCI_TENANCY_NAMESPACE}/${OCI_USERNAME}" \
        --docker-password="$OCI_AUTH_TOKEN" \
        --docker-email="noreply@oracle.com" \
        -n todo-app --dry-run=client -o yaml | kubectl apply -f -

    # Application secrets
    log "Creating application secrets..."
    kubectl create secret generic todo-secrets \
        --from-literal=DATABASE_URL="$DATABASE_URL" \
        --from-literal=JWT_SECRET="$JWT_SECRET" \
        --from-literal=ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
        --from-literal=BETTER_AUTH_SECRET="$BETTER_AUTH_SECRET" \
        -n todo-app --dry-run=client -o yaml | kubectl apply -f -

    log "Secrets created in todo-app namespace!"
}

# =============================================================================
# Section 6: Install Dapr
# =============================================================================
install_dapr() {
    header "Section 6: Install Dapr"

    if kubectl get namespace dapr-system &>/dev/null; then
        log "Dapr namespace exists, checking status..."
        if kubectl get pods -n dapr-system --no-headers 2>/dev/null | grep -q Running; then
            log "Dapr already running. Skipping installation."
            return
        fi
    fi

    if ! command -v dapr &>/dev/null; then
        warn "Dapr CLI not installed. Installing via Helm..."
        helm repo add dapr https://dapr.github.io/helm-charts/
        helm repo update
        helm upgrade --install dapr dapr/dapr \
            --namespace dapr-system \
            --create-namespace \
            --set global.ha.enabled=false \
            --set dapr_placement.resources.requests.memory=64Mi \
            --set dapr_placement.resources.limits.memory=128Mi \
            --set dapr_sentry.resources.requests.memory=64Mi \
            --set dapr_sentry.resources.limits.memory=128Mi \
            --set dapr_operator.resources.requests.memory=64Mi \
            --set dapr_operator.resources.limits.memory=128Mi \
            --wait --timeout 120s
    else
        dapr init -k --wait
    fi

    log "Waiting for Dapr pods..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=dapr -n dapr-system --timeout=120s
    log "Dapr installed and running!"
}

# =============================================================================
# Section 7: Install Strimzi Kafka
# =============================================================================
install_kafka() {
    header "Section 7: Install Strimzi Kafka"

    # Install Strimzi operator
    if ! helm list -n kafka 2>/dev/null | grep -q strimzi; then
        log "Installing Strimzi operator..."
        helm repo add strimzi https://strimzi.io/charts/
        helm repo update
        helm install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
            --namespace kafka \
            --set watchNamespaces="{kafka}" \
            --set resources.requests.memory=256Mi \
            --set resources.requests.cpu=100m \
            --set resources.limits.memory=512Mi \
            --set resources.limits.cpu=250m \
            --wait --timeout 180s
    else
        log "Strimzi operator already installed."
    fi

    log "Waiting for Strimzi operator..."
    kubectl wait --for=condition=ready pod -l name=strimzi-cluster-operator -n kafka --timeout=120s

    # Deploy ARM-optimized Kafka cluster
    log "Deploying ARM-optimized Kafka cluster..."
    kubectl apply -f helm/kafka/kafka-cluster-oke.yaml

    log "Waiting for Kafka cluster to be ready (this takes 2-5 minutes)..."
    kubectl wait kafka/kafka-cluster --for=condition=Ready -n kafka --timeout=300s || {
        warn "Kafka not ready yet. Check with: kubectl get kafka -n kafka"
        warn "Continuing... Kafka may need more time on ARM."
    }

    log "Strimzi Kafka deployed!"
}

# =============================================================================
# Section 8: Apply Dapr Components
# =============================================================================
apply_dapr_components() {
    header "Section 8: Apply Dapr Components"

    log "Applying Dapr pubsub component (Strimzi Kafka)..."
    kubectl apply -f backend/dapr/components/pubsub-kafka-oke.yaml

    log "Applying Dapr statestore component (Neon PostgreSQL)..."
    kubectl apply -f backend/dapr/components/statestore-oke.yaml

    if [ -f backend/dapr/config.yaml ]; then
        log "Applying Dapr configuration..."
        kubectl apply -f backend/dapr/config.yaml -n todo-app
    fi

    log "Dapr components applied!"
    kubectl get components -n todo-app
}

# =============================================================================
# Section 9: Deploy Backend + Frontend via Helm
# =============================================================================
deploy_apps() {
    header "Section 9: Deploy Applications"

    # Deploy backend
    log "Deploying backend..."
    helm upgrade --install todo-backend helm/backend/ \
        -f helm/backend/values-oke.yaml \
        --set image.repository="${BACKEND_IMAGE}" \
        --set image.tag="${IMAGE_TAG}" \
        --set env.CORS_ORIGINS="${CORS_ORIGINS}" \
        -n todo-app

    # Deploy frontend
    log "Deploying frontend..."
    helm upgrade --install todo-frontend helm/frontend/ \
        -f helm/frontend/values-oke.yaml \
        --set image.repository="${FRONTEND_IMAGE}" \
        --set image.tag="${IMAGE_TAG}" \
        -n todo-app

    log "Waiting for deployments to roll out..."
    kubectl rollout status deployment/todo-backend -n todo-app --timeout=180s || {
        warn "Backend not fully ready. Check: kubectl describe pod -n todo-app -l app.kubernetes.io/name=todo-backend"
    }
    kubectl rollout status deployment/todo-frontend -n todo-app --timeout=120s || {
        warn "Frontend not fully ready. Check: kubectl describe pod -n todo-app -l app.kubernetes.io/name=todo-frontend"
    }

    log "Applications deployed!"
}

# =============================================================================
# Section 10: Setup NGINX Ingress + OCI Load Balancer
# =============================================================================
setup_ingress() {
    header "Section 10: NGINX Ingress + OCI Load Balancer"

    # Install NGINX Ingress Controller
    if ! kubectl get namespace ingress-nginx &>/dev/null; then
        log "Installing NGINX Ingress Controller..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml

        log "Waiting for ingress controller..."
        kubectl wait --for=condition=ready pod \
            -l app.kubernetes.io/component=controller \
            -n ingress-nginx --timeout=120s
    else
        log "NGINX Ingress Controller already installed."
    fi

    # Apply OKE ingress rules
    log "Applying OKE ingress rules..."
    kubectl apply -f k8s/cloud/ingress-oke.yaml

    # Wait for Load Balancer IP
    log "Waiting for OCI Load Balancer external IP..."
    echo "  (This may take 1-3 minutes on OCI)"

    local retries=0
    local lb_ip=""
    while [ $retries -lt 30 ]; do
        lb_ip=$(kubectl get ingress todo-ingress -n todo-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
        if [ -n "$lb_ip" ]; then
            break
        fi
        sleep 10
        retries=$((retries + 1))
    done

    if [ -n "$lb_ip" ]; then
        log "Load Balancer IP: $lb_ip"
        echo ""
        echo "  Frontend: http://$lb_ip/"
        echo "  Backend:  http://$lb_ip/api"
        echo "  Health:   http://$lb_ip/health"
        echo "  Docs:     http://$lb_ip/docs"
    else
        warn "Load Balancer IP not assigned yet."
        warn "Check: kubectl get ingress -n todo-app"
        warn "Or:    kubectl get svc -n ingress-nginx"
    fi
}

# =============================================================================
# Section 11: Post-Deploy - Update CORS
# =============================================================================
post_deploy() {
    header "Section 11: Post-Deployment Configuration"

    local lb_ip
    lb_ip=$(kubectl get ingress todo-ingress -n todo-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)

    if [ -n "$lb_ip" ]; then
        log "Updating CORS_ORIGINS with Load Balancer IP..."
        CORS_ORIGINS="http://${lb_ip},http://${lb_ip}:3000,http://localhost:3000"

        helm upgrade todo-backend helm/backend/ \
            -f helm/backend/values-oke.yaml \
            --set image.repository="${BACKEND_IMAGE}" \
            --set image.tag="${IMAGE_TAG}" \
            --set env.CORS_ORIGINS="${CORS_ORIGINS}" \
            -n todo-app

        log "Backend redeployed with updated CORS."
    else
        warn "No LB IP yet. Update CORS manually after IP is assigned:"
        warn "  helm upgrade todo-backend helm/backend/ -f helm/backend/values-oke.yaml --set env.CORS_ORIGINS=\"http://<LB_IP>\" -n todo-app"
    fi
}

# =============================================================================
# Section 12: Verification
# =============================================================================
verify_deployment() {
    header "Section 12: Verification"

    echo "--- Nodes ---"
    kubectl get nodes -o wide

    echo ""
    echo "--- Dapr System ---"
    kubectl get pods -n dapr-system

    echo ""
    echo "--- Kafka ---"
    kubectl get pods -n kafka

    echo ""
    echo "--- Application ---"
    kubectl get pods -n todo-app

    echo ""
    echo "--- Services ---"
    kubectl get svc -n todo-app

    echo ""
    echo "--- Ingress ---"
    kubectl get ingress -n todo-app

    echo ""
    echo "--- Dapr Components ---"
    kubectl get components -n todo-app

    # Health check
    local lb_ip
    lb_ip=$(kubectl get ingress todo-ingress -n todo-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
    if [ -n "$lb_ip" ]; then
        echo ""
        echo "--- Health Check ---"
        curl -s "http://${lb_ip}/health" | python3 -m json.tool 2>/dev/null || warn "Health endpoint not responding yet"
    fi

    echo ""
    log "Deployment complete! Run 'scripts/check-oke-status.sh' for ongoing monitoring."
}

# =============================================================================
# Main
# =============================================================================
main() {
    echo ""
    echo "========================================="
    echo "  OKE Deployment: Cloud-Native Todo App"
    echo "  Oracle Always Free ARM (A1.Flex)"
    echo "========================================="
    echo ""

    check_prerequisites
    create_oke_cluster
    configure_kubectl
    build_images
    create_secrets
    install_dapr
    install_kafka
    apply_dapr_components
    deploy_apps
    setup_ingress
    post_deploy
    verify_deployment
}

# Allow running individual sections
if [ $# -gt 0 ]; then
    case "$1" in
        prereqs)     check_prerequisites ;;
        cluster)     create_oke_cluster ;;
        kubectl)     configure_kubectl ;;
        build)       build_images ;;
        secrets)     create_secrets ;;
        dapr)        install_dapr ;;
        kafka)       install_kafka ;;
        components)  apply_dapr_components ;;
        deploy)      deploy_apps ;;
        ingress)     setup_ingress ;;
        post)        post_deploy ;;
        verify)      verify_deployment ;;
        *)           echo "Usage: $0 [prereqs|cluster|kubectl|build|secrets|dapr|kafka|components|deploy|ingress|post|verify]"
                     echo "  No argument runs all sections in order." ;;
    esac
else
    main
fi
