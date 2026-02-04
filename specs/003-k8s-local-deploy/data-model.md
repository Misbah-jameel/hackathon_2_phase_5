# Data Model: Phase IV — Local Kubernetes Deployment

**Feature**: 003-k8s-local-deploy
**Date**: 2026-02-03

## Overview

Phase IV does not introduce new data entities. The application data model (Users, Tasks) remains unchanged from Phase III. This document describes the **infrastructure entities** — the deployment artifacts and their relationships.

## Infrastructure Entities

### Docker Image

| Attribute      | Description                                      |
|----------------|--------------------------------------------------|
| name           | Image name (e.g., `todo-frontend`, `todo-backend`) |
| tag            | Version tag (e.g., `latest`, `v1.0.0`)           |
| base_image     | Parent image (e.g., `node:18-alpine`, `python:3.12-slim`) |
| exposed_port   | Container port (frontend: 3000, backend: 8000)   |
| build_context  | Source directory (frontend/, backend/)            |

**Relationships**: One Docker Image per service. Referenced by Helm Chart values.

### Helm Release

| Attribute      | Description                                      |
|----------------|--------------------------------------------------|
| release_name   | Helm release name (e.g., `todo-frontend`, `todo-backend`) |
| chart_path     | Path to chart (e.g., `helm/frontend/`, `helm/backend/`) |
| namespace      | Kubernetes namespace (default)                   |
| values         | Configuration overrides (replicas, env vars, image tag) |

**Relationships**: One Helm Release per service. Contains Deployment, Service, ConfigMap.

### Kubernetes Deployment

| Attribute      | Description                                      |
|----------------|--------------------------------------------------|
| name           | Deployment name (matches release name)           |
| replicas       | Number of pod replicas (default: 1)              |
| image          | Docker image reference                           |
| container_port | Port the container listens on                    |
| env_vars       | Environment variables from ConfigMap             |
| probes         | Liveness and readiness probe configuration       |

**Relationships**: Managed by Helm Release. Creates Pods. Targeted by Service.

### Kubernetes Service

| Attribute      | Description                                      |
|----------------|--------------------------------------------------|
| name           | Service name (used for DNS: `<name>.default.svc.cluster.local`) |
| type           | NodePort (for Minikube local access)             |
| port           | Service port (external-facing)                   |
| target_port    | Container port to forward to                     |
| node_port      | Host-accessible port (auto-assigned or specified) |

**Relationships**: Routes traffic to Deployment pods via label selector.

## Configuration Flow

```
Helm values.yaml
  ├── image.repository + image.tag → Deployment container image
  ├── replicaCount → Deployment replicas
  ├── service.type + service.port → Service configuration
  ├── env.* → ConfigMap → Deployment env vars
  └── probes.* → Deployment liveness/readiness
```

## Environment Variable Mapping

### Backend Pod

| Variable          | Source          | K8s Value                                          |
|-------------------|-----------------|-----------------------------------------------------|
| DATABASE_URL      | ConfigMap       | `sqlite:///./todoapp.db`                            |
| JWT_SECRET        | Helm values     | Generated secure string                             |
| JWT_ALGORITHM     | ConfigMap       | `HS256`                                             |
| JWT_EXPIRY_HOURS  | ConfigMap       | `24`                                                |
| CORS_ORIGINS      | ConfigMap       | Frontend NodePort URL (from `minikube service`)     |
| ANTHROPIC_API_KEY | Helm values     | Empty (optional)                                    |
| ANTHROPIC_MODEL   | ConfigMap       | `claude-3-haiku-20240307`                           |

### Frontend Pod

| Variable               | Source     | K8s Value                                       |
|------------------------|-----------|-------------------------------------------------|
| NEXT_PUBLIC_API_URL    | Build-time | Backend NodePort URL (baked into JS bundle)     |
| NEXT_PUBLIC_APP_URL    | Build-time | Frontend NodePort URL                           |
| BETTER_AUTH_SECRET     | ConfigMap  | Development secret string                       |
