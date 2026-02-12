#!/bin/bash
# =============================================================================
# OKE Health Check Script
# Quick status check for all cluster components
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}[OK]${NC} $1"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; }

check_pods() {
    local ns=$1
    local label=$2
    local name=$3

    local status
    status=$(kubectl get pods -n "$ns" -l "$label" --no-headers 2>/dev/null || true)
    if [ -z "$status" ]; then
        fail "$name: No pods found"
        return 1
    fi

    local running
    running=$(echo "$status" | grep -c Running || true)
    local total
    total=$(echo "$status" | wc -l | tr -d ' ')

    if [ "$running" -eq "$total" ]; then
        ok "$name: $running/$total Running"
    else
        warn "$name: $running/$total Running"
        echo "$status" | while read -r line; do echo "       $line"; done
    fi
}

echo ""
echo -e "${BLUE}=== OKE Cluster Health Check ===${NC}"
echo ""

# Nodes
echo -e "${BLUE}Nodes:${NC}"
node_count=$(kubectl get nodes --no-headers 2>/dev/null | grep -c Ready || true)
if [ "$node_count" -gt 0 ]; then
    ok "$node_count node(s) Ready"
    kubectl get nodes -o wide --no-headers 2>/dev/null | while read -r line; do echo "       $line"; done
else
    fail "No Ready nodes found"
fi

# Dapr
echo ""
echo -e "${BLUE}Dapr System:${NC}"
check_pods "dapr-system" "app.kubernetes.io/part-of=dapr" "Dapr control plane"

# Kafka
echo ""
echo -e "${BLUE}Kafka:${NC}"
check_pods "kafka" "name=strimzi-cluster-operator" "Strimzi operator"
check_pods "kafka" "strimzi.io/cluster=kafka-cluster" "Kafka broker"

kafka_ready=$(kubectl get kafka kafka-cluster -n kafka -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
if [ "$kafka_ready" = "True" ]; then
    ok "Kafka cluster: Ready"
else
    warn "Kafka cluster: Not Ready (status: $kafka_ready)"
fi

# Application
echo ""
echo -e "${BLUE}Application (todo-app):${NC}"
check_pods "todo-app" "app.kubernetes.io/name=todo-backend" "Backend"
check_pods "todo-app" "app.kubernetes.io/name=todo-frontend" "Frontend"

# Backend container count (should be 2/2 with Dapr sidecar)
backend_ready=$(kubectl get pods -n todo-app -l app.kubernetes.io/name=todo-backend -o jsonpath='{.items[0].status.containerStatuses[*].ready}' 2>/dev/null || true)
if echo "$backend_ready" | grep -q "false"; then
    warn "Backend: Not all containers ready (Dapr sidecar?)"
fi

# Services
echo ""
echo -e "${BLUE}Services:${NC}"
kubectl get svc -n todo-app --no-headers 2>/dev/null | while read -r line; do
    ok "$line"
done

# Ingress
echo ""
echo -e "${BLUE}Ingress:${NC}"
lb_ip=$(kubectl get ingress todo-ingress -n todo-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
if [ -n "$lb_ip" ]; then
    ok "Load Balancer IP: $lb_ip"
else
    warn "No external IP assigned yet"
fi

# Dapr Components
echo ""
echo -e "${BLUE}Dapr Components:${NC}"
kubectl get components -n todo-app --no-headers 2>/dev/null | while read -r line; do
    ok "$line"
done

# Health endpoint
echo ""
echo -e "${BLUE}Health Check:${NC}"
if [ -n "$lb_ip" ]; then
    health=$(curl -s --connect-timeout 5 "http://${lb_ip}/health" 2>/dev/null || true)
    if [ -n "$health" ]; then
        ok "Health endpoint: $health"
    else
        warn "Health endpoint not responding"
    fi
else
    warn "Skipping health check (no LB IP)"
fi

# Resource usage
echo ""
echo -e "${BLUE}Resource Usage:${NC}"
kubectl top nodes 2>/dev/null || warn "Metrics server not available (kubectl top)"

echo ""
echo -e "${GREEN}Health check complete.${NC}"
