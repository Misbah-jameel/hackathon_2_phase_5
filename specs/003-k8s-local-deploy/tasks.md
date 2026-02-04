# Tasks: Phase IV — Local Kubernetes Deployment

**Input**: Design documents from `/specs/003-k8s-local-deploy/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Not requested in spec. Manual verification via kubectl, helm, and browser access.

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Web app**: `backend/`, `frontend/`, `helm/backend/`, `helm/frontend/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verify prerequisites and prepare project structure for Kubernetes deployment artifacts

- [x] T001 Verify prerequisites: confirm Docker Desktop is running, Minikube cluster is started (`minikube status`), kubectl is connected (`kubectl get nodes`), and Helm is installed (`helm version`)
- [x] T002 Ensure Minikube cluster is running with Docker driver: run `minikube start --driver=docker` if not already started
- [x] T003 Create Helm chart directory structure at project root: `helm/backend/templates/` and `helm/frontend/templates/`

**Checkpoint**: Minikube cluster running, directory structure ready for Dockerfiles and Helm charts

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Create Docker build infrastructure that MUST be complete before any Helm deployment

**CRITICAL**: No Kubernetes deployment can proceed until Docker images build successfully

- [x] T004 [P] Create backend `.dockerignore` file at `backend/.dockerignore` excluding: `__pycache__`, `*.pyc`, `.env`, `.git`, `*.db`, `.pytest_cache`, `venv/`, `.venv/`
- [x] T005 [P] Create frontend `.dockerignore` file at `frontend/.dockerignore` excluding: `node_modules/`, `.next/`, `.git/`, `.env.local`, `.env`, `*.md`
- [x] T006 Create backend Dockerfile at `backend/Dockerfile` using multi-stage build: Stage 1 (builder) — `python:3.12-slim` base, copy `requirements.txt`, run `pip install --no-cache-dir`, copy `app/` directory. Stage 2 (runtime) — `python:3.12-slim` base, copy installed packages from builder (`/usr/local/lib/python3.12/site-packages` and `/usr/local/bin`), copy `app/` directory, set `WORKDIR /app`, expose port 8000, CMD `uvicorn app.main:app --host 0.0.0.0 --port 8000`
- [x] T007 Create frontend Dockerfile at `frontend/Dockerfile` using multi-stage build: Stage 1 (deps) — `node:18-alpine` base, copy `package.json` and `package-lock.json`, run `npm ci`. Stage 2 (builder) — copy deps from stage 1, copy all source, accept `NEXT_PUBLIC_API_URL` and `NEXT_PUBLIC_APP_URL` as `ARG`, set them as `ENV`, run `npm run build`. Stage 3 (runtime) — `node:18-alpine` base, copy `.next/standalone` and `.next/static` and `public/` from builder, expose port 3000, CMD `node server.js`. Note: requires `output: 'standalone'` in next.config.js — update that file to add this setting
- [x] T008 Update `frontend/next.config.js` to add `output: 'standalone'` to the nextConfig object (required for Docker standalone build)
- [x] T009 Configure Docker CLI to use Minikube's Docker daemon: run `minikube -p minikube docker-env --shell powershell | Invoke-Expression` (PowerShell) and verify with `docker images` showing Minikube's images
- [x] T010 Build backend Docker image inside Minikube's daemon: run `docker build -t todo-backend:latest ./backend` and verify image appears in `docker images | grep todo-backend`
- [x] T011 Build frontend Docker image inside Minikube's daemon with placeholder URL: run `docker build -t todo-frontend:latest --build-arg NEXT_PUBLIC_API_URL=http://localhost:8000 --build-arg NEXT_PUBLIC_APP_URL=http://localhost:3000 ./frontend` and verify with `docker images | grep todo-frontend`
- [x] T012 Verify backend image works standalone: run `docker run --rm -d -p 8000:8000 --name test-backend todo-backend:latest`, test `curl http://localhost:8000/health` returns `{"status":"healthy"}`, then `docker stop test-backend`
- [x] T013 Verify frontend image works standalone: run `docker run --rm -d -p 3000:3000 --name test-frontend todo-frontend:latest`, test `curl http://localhost:3000` returns HTML, then `docker stop test-frontend`

**Checkpoint**: Both Docker images build and run successfully as standalone containers. Foundation ready for Helm chart creation.

---

## Phase 3: User Story 1 — Containerize Applications (Priority: P1)

**Goal**: Complete containerization with verified, production-ready Docker images for both services

**Independent Test**: Build both images, run as containers, verify frontend on port 3000 and backend `/health` endpoint responds

**Note**: Most containerization work is done in Phase 2 (Foundational). This phase validates completeness and traces to FR-001 through FR-007.

### Implementation for User Story 1

- [x] T014 [US1] Validate FR-001: Confirm backend Dockerfile at `backend/Dockerfile` produces a working image — run `docker build -t todo-backend:latest ./backend` and verify exit code 0
- [x] T015 [US1] Validate FR-002: Confirm frontend Dockerfile at `frontend/Dockerfile` produces a working image — run `docker build -t todo-frontend:latest ./frontend` and verify exit code 0
- [x] T016 [US1] Validate FR-003 and FR-004: Run both containers and confirm frontend responds on port 3000, backend on port 8000
- [x] T017 [US1] Validate FR-005: Verify backend container has all Python packages — run `docker run --rm todo-backend:latest pip list` and check for fastapi, uvicorn, sqlmodel, bcrypt, anthropic, rapidfuzz
- [x] T018 [US1] Validate FR-007: Confirm `.dockerignore` files exclude expected patterns — verify `docker images` shows reasonably small image sizes (backend < 300MB, frontend < 500MB)

**Checkpoint**: User Story 1 complete — both images verified as production-ready containers

---

## Phase 4: User Story 2 — Deploy to Local Kubernetes Cluster (Priority: P1)

**Goal**: Create Helm charts and deploy both services to Minikube with pods in Running state

**Independent Test**: Run `kubectl get pods` — both pods show `Running` status `1/1`. Run `helm list` — both releases show `deployed`.

**Dependencies**: Requires User Story 1 (Docker images must exist)

### Implementation for User Story 2

- [x] T019 [P] [US2] Create backend Helm chart metadata at `helm/backend/Chart.yaml` with name `todo-backend`, version `0.1.0`, appVersion `1.0.0`, description `Helm chart for Todo App FastAPI backend`
- [x] T020 [P] [US2] Create frontend Helm chart metadata at `helm/frontend/Chart.yaml` with name `todo-frontend`, version `0.1.0`, appVersion `1.0.0`, description `Helm chart for Todo App Next.js frontend`
- [x] T021 [P] [US2] Create backend Helm values at `helm/backend/values.yaml` per contract `specs/003-k8s-local-deploy/contracts/helm-values-backend.yaml`: replicaCount 1, image todo-backend:latest with pullPolicy Never, service type NodePort port 8000, env vars (DATABASE_URL, JWT_SECRET, JWT_ALGORITHM, JWT_EXPIRY_HOURS, CORS_ORIGINS, ANTHROPIC_API_KEY, ANTHROPIC_MODEL), liveness/readiness probes on /health, resource requests/limits
- [x] T022 [P] [US2] Create frontend Helm values at `helm/frontend/values.yaml` per contract `specs/003-k8s-local-deploy/contracts/helm-values-frontend.yaml`: replicaCount 1, image todo-frontend:latest with pullPolicy Never, service type NodePort port 3000, env vars (BETTER_AUTH_SECRET), liveness probe on /, readiness TCP on 3000, resource requests/limits
- [x] T023 [P] [US2] Create backend Helm helpers template at `helm/backend/templates/_helpers.tpl` with functions: `todo-backend.fullname` (release name), `todo-backend.labels` (app, chart, release, managed-by), `todo-backend.selectorLabels` (app, release)
- [x] T024 [P] [US2] Create frontend Helm helpers template at `helm/frontend/templates/_helpers.tpl` with functions: `todo-frontend.fullname` (release name), `todo-frontend.labels` (app, chart, release, managed-by), `todo-frontend.selectorLabels` (app, release)
- [x] T025 [P] [US2] Create backend ConfigMap template at `helm/backend/templates/configmap.yaml` — ConfigMap with all env vars from values.yaml `env` section, using `{{ range $key, $value := .Values.env }}` loop
- [x] T026 [P] [US2] Create frontend ConfigMap template at `helm/frontend/templates/configmap.yaml` — ConfigMap with env vars from values.yaml `env` section
- [x] T027 [US2] Create backend Deployment template at `helm/backend/templates/deployment.yaml` — Deployment with: replicas from values, container image from values (repository:tag), containerPort 8000, envFrom ConfigMap ref, livenessProbe httpGet /health port 8000 (initialDelay 10s, period 30s), readinessProbe httpGet /health port 8000 (initialDelay 5s, period 10s), resource requests/limits from values
- [x] T028 [US2] Create frontend Deployment template at `helm/frontend/templates/deployment.yaml` — Deployment with: replicas from values, container image from values (repository:tag), containerPort 3000, envFrom ConfigMap ref, livenessProbe httpGet / port 3000 (initialDelay 15s, period 30s), readinessProbe tcpSocket port 3000 (initialDelay 10s, period 10s), resource requests/limits from values
- [x] T029 [P] [US2] Create backend Service template at `helm/backend/templates/service.yaml` — Service type NodePort, port 8000, targetPort 8000, selector labels from helpers
- [x] T030 [P] [US2] Create frontend Service template at `helm/frontend/templates/service.yaml` — Service type NodePort, port 3000, targetPort 3000, selector labels from helpers
- [x] T031 [US2] Validate Helm charts with `helm lint ./helm/backend` and `helm lint ./helm/frontend` — both must pass without errors
- [x] T032 [US2] Deploy backend to Minikube: run `helm install todo-backend ./helm/backend` and wait for pod ready with `kubectl wait --for=condition=ready pod -l app=todo-backend --timeout=120s`
- [x] T033 [US2] Get backend NodePort URL: run `minikube service todo-backend --url` and save the URL for frontend configuration
- [x] T034 [US2] Rebuild frontend Docker image with correct backend URL: run `docker build -t todo-frontend:latest --build-arg NEXT_PUBLIC_API_URL=<backend-url-from-T033> ./frontend`
- [x] T035 [US2] Update backend CORS_ORIGINS to include frontend NodePort URL: run `helm upgrade todo-backend ./helm/backend --set env.CORS_ORIGINS="<frontend-url>\,<backend-url>"` after getting the frontend URL
- [x] T036 [US2] Deploy frontend to Minikube: run `helm install todo-frontend ./helm/frontend` and wait for pod ready with `kubectl wait --for=condition=ready pod -l app=todo-frontend --timeout=120s`
- [x] T037 [US2] Verify deployment: run `kubectl get pods` — both pods show `Running` `1/1`. Run `helm list` — both releases show `deployed` status
- [x] T038 [US2] Verify self-healing: delete backend pod with `kubectl delete pod -l app=todo-backend`, wait 30 seconds, confirm new pod is created and reaches Running state

**Checkpoint**: User Story 2 complete — both services deployed on Minikube via Helm, pods healthy, self-healing verified

---

## Phase 5: User Story 3 — Access Services Locally (Priority: P1)

**Goal**: Verify end-to-end application access from host browser through Minikube-exposed NodePort services

**Independent Test**: Open frontend URL in browser, perform signup/login/task CRUD/chatbot operations

**Dependencies**: Requires User Story 2 (services must be deployed on Minikube)

### Implementation for User Story 3

- [x] T039 [US3] Get frontend service URL: run `minikube service todo-frontend --url` and open in browser
- [ ] T040 [US3] Verify frontend landing page loads in browser at the NodePort URL
- [ ] T041 [US3] Verify end-to-end: perform user signup, login, create a task, complete a task, delete a task, and test chatbot — all operations must succeed through K8s services
- [x] T042 [US3] Verify backend API is accessible: run `curl <backend-url>/health` from host machine — should return `{"status":"healthy"}`
- [ ] T043 [US3] Verify CORS is correctly configured: frontend API calls to backend should not produce CORS errors in browser console

**Checkpoint**: User Story 3 complete — full application accessible and functional from host browser via Minikube

---

## Phase 6: User Story 4 — AI-Assisted DevOps Operations (Priority: P2)

**Goal**: Demonstrate kubectl-ai and kagent usage for cluster operations

**Independent Test**: Issue natural language commands via kubectl-ai and verify cluster state changes

**Dependencies**: Requires User Story 2 (cluster must have running deployments)

### Implementation for User Story 4

- [x] T044 [US4] Check if kubectl-ai is installed: run `kubectl-ai --version` or equivalent — if not installed, document installation steps
- [ ] T045 [US4] Use kubectl-ai to scale backend: issue command `kubectl-ai "scale the todo-backend deployment to 2 replicas"` and verify with `kubectl get pods` showing 2 backend pods
- [ ] T046 [US4] Use kubectl-ai to get cluster status: issue command `kubectl-ai "show me the status of all pods and services"` and verify output matches `kubectl get pods,svc`
- [ ] T047 [US4] Use kubectl-ai to debug: issue command `kubectl-ai "show me the logs of the todo-backend pod"` and verify logs are displayed
- [x] T048 [US4] Check if kagent is available: verify installation — if available, run cluster health check and document output. If not available, document that kagent was not found and skip
- [ ] T049 [US4] Scale backend back to 1 replica: `kubectl scale deployment todo-backend --replicas=1`

**Checkpoint**: User Story 4 complete — AI DevOps tools demonstrated for deploy, scale, and debug operations

---

## Phase 7: User Story 5 — Deployment Documentation (Priority: P2)

**Goal**: Create comprehensive deployment README for reproducibility

**Independent Test**: A new developer can follow the README to deploy from scratch

**Dependencies**: Requires User Stories 1-3 complete (to document accurate commands and URLs)

### Implementation for User Story 5

- [x] T050 [US5] Create deployment README at `K8S_DEPLOYMENT_README.md` in project root covering: prerequisites (Docker Desktop, Minikube, kubectl, Helm), step-by-step deployment instructions (from `minikube start` to accessing the app), common operations (scale, logs, restart, uninstall), troubleshooting (common errors and fixes), AI DevOps tooling usage (kubectl-ai examples, kagent if available)
- [x] T051 [US5] Document the exact commands used during deployment (with actual NodePort URLs) in the README troubleshooting section
- [x] T052 [US5] Add architecture diagram section to README describing service topology (reference `specs/003-k8s-local-deploy/contracts/deployment-architecture.md`)

**Checkpoint**: User Story 5 complete — deployment fully documented and reproducible

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and cleanup

- [ ] T053 Verify Helm uninstall is clean: run `helm uninstall todo-frontend && helm uninstall todo-backend`, then `kubectl get all` — no orphaned resources should remain
- [ ] T054 Verify Helm reinstall works: run the full deployment sequence again from T032 to T037 — everything should redeploy cleanly
- [ ] T055 Run quickstart.md validation: follow `specs/003-k8s-local-deploy/quickstart.md` end-to-end and confirm all commands work as documented
- [x] T056 Final deployment state: ensure both services are deployed, running, and accessible. Capture `kubectl get pods,svc` output and `helm list` output as evidence

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — verify tools are ready
- **Foundational (Phase 2)**: Depends on Setup — creates Docker images (BLOCKS all K8s deployment)
- **US1 (Phase 3)**: Depends on Foundational — validates container images
- **US2 (Phase 4)**: Depends on US1 — creates Helm charts and deploys to Minikube
- **US3 (Phase 5)**: Depends on US2 — validates end-to-end browser access
- **US4 (Phase 6)**: Depends on US2 — uses kubectl-ai on running cluster
- **US5 (Phase 7)**: Depends on US1-US3 — documents the complete workflow
- **Polish (Phase 8)**: Depends on all user stories — final validation

### User Story Dependencies

- **US1 (Containerize)**: Foundational prerequisite — MUST complete first
- **US2 (K8s Deploy)**: Depends on US1 (needs Docker images)
- **US3 (Local Access)**: Depends on US2 (needs running pods and services)
- **US4 (AI DevOps)**: Depends on US2 (needs running cluster) — can run in parallel with US3
- **US5 (Documentation)**: Depends on US1+US2+US3 (needs accurate deployment info)

### Within Each User Story

- Helm chart files (Chart.yaml, values.yaml, helpers) can be created in parallel [P]
- Template files (deployment.yaml, service.yaml, configmap.yaml) can be created in parallel [P]
- Deployment commands must run sequentially (backend before frontend)

### Parallel Opportunities

**Within Phase 2 (Foundational)**:
- T004 and T005 (.dockerignore files) can run in parallel
- T006 and T007 (Dockerfiles) can run in parallel after .dockerignore

**Within Phase 4 (US2 — Helm Charts)**:
- T019-T026 (Chart.yaml, values.yaml, helpers, configmaps — all different files) can run in parallel
- T029 and T030 (Service templates) can run in parallel
- T027 and T028 (Deployment templates) can run in parallel after configmaps

---

## Parallel Example: User Story 2 — Helm Chart Creation

```bash
# Launch all chart metadata in parallel:
Task: "Create backend Chart.yaml at helm/backend/Chart.yaml"
Task: "Create frontend Chart.yaml at helm/frontend/Chart.yaml"

# Launch all values files in parallel:
Task: "Create backend values.yaml at helm/backend/values.yaml"
Task: "Create frontend values.yaml at helm/frontend/values.yaml"

# Launch all helpers in parallel:
Task: "Create backend _helpers.tpl at helm/backend/templates/_helpers.tpl"
Task: "Create frontend _helpers.tpl at helm/frontend/templates/_helpers.tpl"

# Launch all configmaps in parallel:
Task: "Create backend configmap.yaml at helm/backend/templates/configmap.yaml"
Task: "Create frontend configmap.yaml at helm/frontend/templates/configmap.yaml"

# Launch all services in parallel:
Task: "Create backend service.yaml at helm/backend/templates/service.yaml"
Task: "Create frontend service.yaml at helm/frontend/templates/service.yaml"
```

---

## Implementation Strategy

### MVP First (User Stories 1+2+3 = Core Deployment)

1. Complete Phase 1: Setup (verify tools)
2. Complete Phase 2: Foundational (Docker images)
3. Complete Phase 3: US1 (validate images)
4. Complete Phase 4: US2 (Helm deploy to Minikube)
5. Complete Phase 5: US3 (verify browser access)
6. **STOP and VALIDATE**: Full deployment working end-to-end
7. Demo to stakeholders

### Incremental Delivery

1. Setup + Foundational → Docker images ready
2. US1 → Containers verified
3. US2 → Kubernetes deployment live
4. US3 → End-to-end accessible (MVP complete!)
5. US4 → AI DevOps evidence collected
6. US5 → Documentation finalized
7. Polish → Clean uninstall/reinstall verified

---

## Task Summary

| Phase | User Story | Task Count | Parallel Tasks |
|-------|-----------|------------|----------------|
| Phase 1 | Setup | 3 | 0 |
| Phase 2 | Foundational | 10 | 2 |
| Phase 3 | US1 — Containerize | 5 | 0 |
| Phase 4 | US2 — K8s Deploy | 20 | 12 |
| Phase 5 | US3 — Local Access | 5 | 0 |
| Phase 6 | US4 — AI DevOps | 6 | 0 |
| Phase 7 | US5 — Documentation | 3 | 0 |
| Phase 8 | Polish | 4 | 0 |
| **Total** | | **56** | **14** |

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each phase completion
- Stop at any checkpoint to validate story independently
- FR references trace tasks back to spec functional requirements
- All NodePort URLs are dynamic — obtained from `minikube service <name> --url` at deployment time
