---
id: 004
title: Cloud Deployment Code Fixes
stage: green
date: 2026-02-08
surface: agent
model: claude-opus-4-6
feature: 004-phase-v-cloud-native
branch: main
user: Misbah-jameel
command: implement
labels: [cloud-deploy, aks, helm, ingress, ci-cd, ghcr]
links:
  spec: null
  ticket: null
  adr: null
  pr: null
files:
  - backend/requirements.txt
  - k8s/cloud/ingress.yaml
  - helm/backend/templates/deployment.yaml
  - helm/frontend/templates/deployment.yaml
  - helm/backend/values-cloud.yaml
  - helm/frontend/values-cloud.yaml
  - .github/workflows/ci-cd.yaml
tests:
  - backend/tests/ (178 passed, 1 pre-existing failure)
---

## Prompt

Implement the cloud deployment plan (Part A: Code Changes) covering 7 files:
1. Uncomment psycopg2-binary in requirements.txt
2. Fix Ingress rewrite-target bug in ingress.yaml
3. Add K8s Secret references to backend deployment
4. Add K8s Secret references to frontend deployment
5. Fix backend values-cloud.yaml (image repo, replicaCount, probes)
6. Create frontend values-cloud.yaml
7. Update CI/CD frontend deploy step to use values-cloud.yaml

## Response snapshot

All 7 code changes implemented successfully:
1. `psycopg2-binary>=2.9.9` uncommented for Neon PostgreSQL support
2. Removed `nginx.ingress.kubernetes.io/rewrite-target: /` — prevents /api paths being rewritten to /
3. Added `secretRef: todo-secrets (optional: true)` to backend deployment envFrom
4. Added `secretRef: todo-secrets (optional: true)` to frontend deployment envFrom
5. Fixed image repo to `ghcr.io/misbah-jameel/todo-backend`, added `replicaCount: 1` and full `probes` section
6. Created `helm/frontend/values-cloud.yaml` with ClusterIP service, GHCR image, IfNotPresent pullPolicy
7. Updated CI/CD frontend deploy to use `-f helm/frontend/values-cloud.yaml` instead of raw `--set` flags

All 178 existing tests pass. No regressions introduced.

## Outcome

- ✅ Impact: All code prerequisites for AKS cloud deployment are now in place
- 🧪 Tests: 178 passed, 1 pre-existing fuzzy match failure (unchanged)
- 📁 Files: 6 modified, 1 created (helm/frontend/values-cloud.yaml)
- 🔁 Next prompts: Execute Part B (infrastructure setup) and Part C (deploy to cloud)
- 🧠 Reflection: The rewrite-target removal is critical — with it, all backend API routes would 404 in production

## Evaluation notes (flywheel)

- Failure modes observed: None — all changes are straightforward config/manifest edits
- Graders run and results (PASS/FAIL): pytest PASS (178/179, 1 pre-existing)
- Prompt variant (if applicable): N/A
- Next experiment (smallest change to try): Deploy to AKS and validate end-to-end connectivity
