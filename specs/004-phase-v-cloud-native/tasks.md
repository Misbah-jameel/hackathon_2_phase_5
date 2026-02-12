# Tasks: Phase V — Advanced Features, Event-Driven Architecture & Cloud Deployment

**Input**: Design documents from `specs/004-phase-v-cloud-native/`
**Prerequisites**: plan.md (complete), spec.md (complete), data-model.md (complete)

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story/scope this task belongs to
- Include exact file paths in descriptions

---

## Phase 1: Scope A — Extended Data Model & Backend API

**Purpose**: Extend Task model with priority, tags, due_date, recurrence, reminders. Add search, filter, sort.

### P1.1 — Model & Schema Extensions

- [x] T001 [US1] Extend Task model with priority, tags, due_date, reminder, recurrence fields in `backend/app/models/task.py`
  - Add: `priority` (str, default "none"), `tags` (str, default ""), `due_date` (Optional[datetime]), `reminder_at` (Optional[datetime]), `reminder_minutes_before` (int, default 15), `recurrence_pattern` (Optional[str]), `recurrence_cron` (Optional[str]), `recurrence_enabled` (bool, default False), `parent_task_id` (Optional[str], FK→tasks.id)
  - **Test**: Import model, verify all new fields exist with correct defaults

- [x] T002 [P] [US5] Create AuditLog model in `backend/app/models/audit_log.py`
  - Fields: id, event_id, event_type, user_id, task_id, timestamp, payload_snapshot, created_at
  - Register in `backend/app/models/__init__.py`
  - **Test**: Import model, verify table name is "audit_logs"

- [x] T003 [US1] Extend TaskCreate schema in `backend/app/schemas/task.py`
  - Add optional fields: priority (validated enum), tags (List[str], max 10, max 30 chars each), due_date, reminder_minutes_before, recurrence_pattern (validated enum), recurrence_cron
  - **Test**: Create schema with new fields, verify validation passes/fails correctly

- [x] T004 [US1] Extend TaskUpdate schema in `backend/app/schemas/task.py`
  - Add optional fields: priority, tags, due_date, reminder_minutes_before, recurrence_pattern, recurrence_cron, recurrence_enabled
  - **Test**: Create update schema with partial fields, verify optional behavior

- [x] T005 [US1] Extend TaskResponse schema in `backend/app/schemas/task.py`
  - Add: priority, tags (as List[str] — split from comma string), due_date, reminder_at, recurrence_pattern, recurrence_enabled, parent_task_id, is_overdue (computed bool)
  - **Test**: Create response from model with tags="a,b", verify tags=["a","b"]

- [x] T006 [P] [US2] Create filter/sort query schema in `backend/app/schemas/filters.py`
  - TaskQueryParams: search (str), priority (str, comma-separated), tags (str, comma-separated), status (str: pending|completed), due_before (datetime), due_after (datetime), sort_by (str), sort_order (str: asc|desc), page (int), page_size (int)
  - **Test**: Validate query params parse correctly

- [x] T007 [P] [US5] Create event schemas in `backend/app/schemas/events.py`
  - TaskEvent: event_id, event_type, timestamp, version, user_id, task_id, payload
  - EventTypes enum: TASK_CREATED, TASK_UPDATED, TASK_COMPLETED, TASK_DELETED
  - **Test**: Create TaskEvent, verify serialization to JSON

**Checkpoint**: All models and schemas defined. DB will auto-create tables on next startup.

---

### P1.2 — Service Layer Extensions

- [x] T008 [US1] Extend TaskService.create_task() in `backend/app/services/task_service.py`
  - Accept new fields: priority, tags (join list→string), due_date, reminder_minutes_before, recurrence_pattern, recurrence_cron
  - Compute reminder_at = due_date - reminder_minutes_before (if due_date set)
  - Set recurrence_enabled = True if recurrence_pattern is set
  - **Test**: Create task with priority="high", tags=["work"], due_date=tomorrow, verify all fields saved

- [x] T009 [US1] Extend TaskService.update_task() in `backend/app/services/task_service.py`
  - Accept and update all new fields
  - Recompute reminder_at when due_date or reminder_minutes changes
  - **Test**: Update task priority from "none" to "high", verify persisted

- [x] T010 [US2] Add TaskService.search_tasks() in `backend/app/services/task_service.py`
  - Case-insensitive LIKE search on title and description
  - Accept: search query, user_id
  - Return: filtered task list
  - **Test**: Create 3 tasks, search "grocery", verify only matching returned

- [x] T011 [US2] Add TaskService.filter_tasks() in `backend/app/services/task_service.py`
  - Filter by: status (completed/pending), priority (list), tags (any match), due_date range
  - Combine filters with AND logic
  - Return: filtered task list
  - **Test**: Create tasks with different priorities, filter by "high", verify results

- [x] T012 [US2] Add TaskService.sort_tasks() in `backend/app/services/task_service.py`
  - Sort by: created_at, updated_at, due_date, priority, title
  - Support: asc/desc order
  - Priority order: high=3, medium=2, low=1, none=0
  - **Test**: Create 3 tasks with different priorities, sort by priority desc, verify order

- [x] T013 [US2] Add TaskService.get_tasks_paginated() in `backend/app/services/task_service.py`
  - Combine search + filter + sort + pagination
  - Accept: TaskQueryParams + user_id
  - Return: paginated results with total count
  - **Test**: Create 25 tasks, request page=2, page_size=10, verify 10 returned with correct offset

**Checkpoint**: All backend service logic for Scope A complete.

---

### P1.3 — Router Extensions

- [x] T014 [US1+US2] Extend GET /api/tasks in `backend/app/routers/tasks.py`
  - Accept query params: search, priority, tags, status, due_before, due_after, sort_by, sort_order, page, page_size
  - Use TaskService.get_tasks_paginated()
  - Return extended TaskResponse with all new fields
  - **Test**: `GET /api/tasks?priority=high&sort_by=due_date&sort_order=asc` returns correct results

- [x] T015 [US1] Extend POST /api/tasks in `backend/app/routers/tasks.py`
  - Accept new fields in request body (priority, tags, due_date, etc.)
  - Pass to extended TaskService.create_task()
  - Return extended TaskResponse
  - **Test**: `POST /api/tasks` with priority="high", tags=["work"], verify response includes new fields

- [x] T016 [US1] Extend PATCH /api/tasks/{task_id} in `backend/app/routers/tasks.py`
  - Accept new fields in request body
  - Pass to extended TaskService.update_task()
  - **Test**: `PATCH /api/tasks/{id}` with priority="medium", verify updated

- [x] T017 [US1] Update task_to_response() helper in `backend/app/routers/tasks.py`
  - Map all new model fields to TaskResponse
  - Compute is_overdue: due_date < now and not completed
  - Split tags string to list
  - **Test**: Model with tags="a,b" produces response with tags=["a","b"]

- [x] T018 [P] [US3] Add POST /api/tasks/{task_id}/reminder in `backend/app/routers/tasks.py`
  - Manually schedule/reschedule a reminder for a task
  - Update reminder_at field
  - **Test**: Set reminder for task, verify reminder_at updated

- [x] T019 [P] [US4] Add DELETE /api/tasks/{task_id}/recurrence in `backend/app/routers/tasks.py`
  - Disable recurrence on a task
  - Set recurrence_enabled=False, clear recurrence_pattern
  - **Test**: Disable recurrence, verify recurrence_enabled=False

**Checkpoint**: All Scope A API endpoints complete and testable.

---

## Phase 2: Scope A — Frontend UI

**Purpose**: Update frontend to display and manage priorities, tags, due dates, search, filter, sort.

### P2.1 — Type & API Updates

- [x] T020 [US1] Extend Task type in `frontend/types/index.ts`
  - Add: priority (enum), tags (string[]), dueDate (string|null), reminderAt (string|null), recurrencePattern (string|null), recurrenceEnabled (boolean), parentTaskId (string|null), isOverdue (boolean)
  - Add: CreateTaskInput extensions (priority, tags, dueDate, reminderMinutesBefore, recurrencePattern, recurrenceCron)
  - Add: UpdateTaskInput extensions
  - Add: TaskSortBy, TaskSortOrder, TaskQueryParams types
  - **Test**: TypeScript compilation passes with no errors

- [x] T021 [US1] Extend API client in `frontend/lib/api.ts`
  - Update fetchTasks() to accept query params (search, priority, tags, status, sort_by, sort_order)
  - Build query string from params
  - Update createTask() / updateTask() to send new fields
  - **Test**: API calls include correct query params

- [x] T022 [P] [US1] Update mock API in `frontend/lib/mock-api.ts`
  - Add new fields to mock tasks (priority, tags, due_date)
  - Support filtering and sorting in mock mode
  - **Test**: Mock API returns tasks with new fields

### P2.2 — Task Components

- [x] T023 [US1] Update TaskCard component in `frontend/components/tasks/TaskCard.tsx`
  - Display priority badge (colored: red=high, yellow=medium, blue=low)
  - Display tags as removable chips
  - Display due date with overdue/due-soon indicators
  - Display recurrence icon if recurring
  - **Test**: Render task with priority="high", tags=["work"], verify visual elements

- [x] T024 [US1] Update TaskForm/TaskFormModal in `frontend/components/tasks/TaskForm.tsx` and `TaskFormModal.tsx`
  - Add priority dropdown (High/Medium/Low/None)
  - Add tags input (comma-separated or chip input)
  - Add due date picker (date + time)
  - Add reminder minutes input (default 15)
  - Add recurrence pattern dropdown (None/Daily/Weekly/Monthly/Custom)
  - **Test**: Fill form with all new fields, submit, verify payload includes them

- [x] T025 [US2] Update TaskFilters in `frontend/components/tasks/TaskFilters.tsx`
  - Add search input (text field with debounce)
  - Add priority filter dropdown (multi-select: High/Medium/Low)
  - Add tag filter (clickable tag chips or dropdown)
  - Add date range filter (due before/after)
  - Add sort dropdown (created, due date, priority, title)
  - Add sort order toggle (asc/desc)
  - Add "Clear All Filters" button
  - **Test**: Select filters, verify query params update

- [x] T026 [US2] Update TaskList in `frontend/components/tasks/TaskList.tsx`
  - Pass search/filter/sort params to API call
  - Show empty state when filters return zero results ("No tasks match your filters")
  - Show result count
  - **Test**: Apply filter, verify list updates with matching tasks

- [x] T027 [US2] Update useTasks hook in `frontend/hooks/useTasks.ts`
  - Add state for: searchQuery, priorityFilter, tagFilter, sortBy, sortOrder
  - Debounce search input (300ms)
  - Pass all params to fetchTasks API call
  - **Test**: Set search query, verify API called with correct params after debounce

- [x] T028 [P] [US3] Create ReminderToast component in `frontend/components/tasks/ReminderToast.tsx`
  - Display reminder notification for due tasks
  - Show task title, time until due
  - Action: "View Task" button
  - **Test**: Render with task data, verify shows correct info

**Checkpoint**: Frontend fully displays and manages all new task attributes. Search, filter, sort operational.

---

## Phase 3: Scope B+C — Event-Driven Architecture & Dapr Integration

**Purpose**: Implement Kafka event pipeline via Dapr pub/sub. Add event consumers.

### P3.1 — Dapr Client & Event Service

- [x] T029 [US6] Create Dapr HTTP client wrapper in `backend/app/services/dapr_client.py`
  - DaprClient class with methods: publish_event(), get_state(), save_state(), delete_state(), get_secret()
  - Base URL: `http://localhost:3500` (configurable via env)
  - Use httpx async client
  - Graceful fallback when Dapr sidecar is not available (log warning, don't crash)
  - **Test**: Mock httpx, verify correct URL paths called

- [x] T030 [US5] Create EventService in `backend/app/services/event_service.py`
  - publish_task_event(event_type, user_id, task_id, payload) → builds TaskEvent and publishes via DaprClient
  - Event types: task.created, task.updated, task.completed, task.deleted
  - Auto-generate event_id (UUID), timestamp (now), version (1)
  - **Test**: Call publish_task_event(), verify DaprClient.publish_event() called with correct topic and schema

- [x] T031 [US3] Create ReminderService in `backend/app/services/reminder_service.py`
  - schedule_reminder(task_id, user_id, fire_at) → creates Dapr Job via HTTP API
  - cancel_reminder(task_id) → cancels Dapr Job
  - Job name format: `reminder-{task_id}`
  - **Test**: Call schedule_reminder(), verify Dapr Jobs API called with correct schedule

### P3.2 — Integrate Events into Task CRUD

- [x] T032 [US5] Add event publishing to task creation in `backend/app/routers/tasks.py`
  - After TaskService.create_task() succeeds, call EventService.publish_task_event("task.created", ...)
  - Include task payload in event
  - If event publish fails, log error but don't fail the request (fire-and-forget)
  - **Test**: Create task, verify task.created event published

- [x] T033 [US5] Add event publishing to task update in `backend/app/routers/tasks.py`
  - After update, publish "task.updated" with before/after changes
  - After toggle complete, publish "task.completed" or "task.updated"
  - **Test**: Update task, verify task.updated event published

- [x] T034 [US5] Add event publishing to task deletion in `backend/app/routers/tasks.py`
  - Before delete, publish "task.deleted" event
  - **Test**: Delete task, verify task.deleted event published

- [x] T035 [US3] Add reminder scheduling on task create/update in `backend/app/routers/tasks.py`
  - When task created with due_date: schedule reminder via ReminderService
  - When task updated with new due_date: reschedule reminder
  - When task completed: cancel reminder
  - **Test**: Create task with due_date, verify reminder scheduled

### P3.3 — Event Consumers (Dapr Subscriptions)

- [x] T036 [US5] Create Dapr subscription endpoint in `backend/app/routers/subscriptions.py`
  - GET /dapr/subscribe → returns subscription list (task-events, reminders, task-updates routes)
  - **Test**: GET /dapr/subscribe returns 3 subscription entries

- [x] T037 [US5] Create audit log consumer in `backend/app/consumers/audit_consumer.py`
  - POST /api/events/task-events → receives event, writes AuditLog to DB
  - Idempotent: skip if event_id already exists
  - **Test**: Post event to endpoint, verify AuditLog record created

- [x] T038 [US3] Create reminder consumer in `backend/app/consumers/reminder_consumer.py`
  - POST /api/events/reminders → receives reminder trigger, publishes notification
  - Skip if task is already completed
  - **Test**: Post reminder event, verify processing (notification publish)

- [x] T039 [US4] Create recurrence consumer in `backend/app/consumers/recurrence_consumer.py`
  - POST /api/events/task-updates → on task.completed for recurring task, generate next instance
  - Copy task attributes, set new due_date based on pattern, link parent_task_id
  - **Test**: Post task.completed event for recurring task, verify new task created

- [x] T040 [P] [US5] Create audit trail endpoint in `backend/app/routers/events.py`
  - GET /api/events/audit?task_id={id} → return audit log entries for a task
  - **Test**: Create audit entries, query by task_id, verify correct entries returned

- [x] T041 [US5+US6] Register all new routers in `backend/app/main.py`
  - Import and include: events_router, subscriptions_router
  - Register consumer routes
  - **Test**: App starts, all new endpoints accessible

- [x] T042 [US6] Add Dapr configuration to `backend/app/config.py`
  - Add: dapr_host (default "localhost"), dapr_port (default 3500), dapr_pubsub_name (default "pubsub")
  - **Test**: Settings load Dapr config from env vars

**Checkpoint**: Event-driven pipeline fully implemented in code. Ready for infrastructure deployment.

---

## Phase 4: Scope B+C — Dapr Component Configuration

**Purpose**: Create Dapr component YAML files and Kafka setup manifests.

- [x] T043 [P] [US6] Create Dapr pub/sub component for local Kafka in `backend/dapr/components/pubsub-kafka-local.yaml`
  - Type: pubsub.kafka, brokers: kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092, authType: none
  - **Test**: YAML validates with dapr component schema

- [x] T044 [P] [US6] Create Dapr pub/sub component for cloud Kafka in `backend/dapr/components/pubsub-kafka-cloud.yaml`
  - Type: pubsub.kafka, brokers: from secret, authType: sasl, SCRAM-SHA-256
  - **Test**: YAML validates, references correct secret keys

- [x] T045 [P] [US6] Create Dapr state store component in `backend/dapr/components/statestore.yaml`
  - Type: state.postgresql (cloud) / state.in-memory (local fallback)
  - **Test**: YAML validates

- [x] T046 [P] [US6] Create Dapr secrets store component in `backend/dapr/components/secretstore-k8s.yaml`
  - Type: secretstores.kubernetes
  - **Test**: YAML validates

- [x] T047 [P] [US6] Create Dapr configuration in `backend/dapr/config.yaml`
  - Enable tracing, metrics, API logging
  - **Test**: YAML validates

- [x] T048 [P] [US7] Create Strimzi Kafka cluster manifest in `helm/kafka/kafka-cluster.yaml`
  - Single broker, KRaft mode (no ZooKeeper), 1GB memory limit
  - 3 topics: task-events (3 partitions), reminders (1 partition), task-updates (1 partition)
  - **Test**: YAML validates against Strimzi CRD schema

- [x] T049 [P] [US7] Create Strimzi operator installation manifest in `helm/kafka/strimzi-operator.yaml`
  - Install Strimzi cluster operator via Helm reference or manifest
  - Namespace: kafka
  - **Test**: Operator installs and runs

**Checkpoint**: All Dapr and Kafka configuration files ready.

---

## Phase 5: Scope A+B+C — Backend Dependencies & Dockerfile

**Purpose**: Update requirements.txt, Dockerfile for Dapr compatibility.

- [x] T050 [US6] Update `backend/requirements.txt`
  - Add: httpx>=0.27.0 (Dapr HTTP calls)
  - Verify existing deps are compatible
  - **Test**: `pip install -r requirements.txt` succeeds

- [x] T051 [US6] Update `backend/Dockerfile`
  - Ensure port 8000 exposed (unchanged)
  - Add DAPR_HTTP_PORT env var (default 3500)
  - No Dapr SDK install needed (using HTTP directly)
  - **Test**: Docker image builds successfully

**Checkpoint**: Backend fully updated for Phase V.

---

## Phase 6: Scope D — Helm Chart Updates & Local Validation

**Purpose**: Update Helm charts for Dapr sidecar injection, deploy and validate on Minikube.

### P6.1 — Helm Chart Updates

- [x] T052 [US7] Update backend Helm deployment template `helm/backend/templates/deployment.yaml`
  - Add Dapr annotations: dapr.io/enabled, dapr.io/app-id, dapr.io/app-port, dapr.io/app-protocol
  - **Test**: `helm template` renders correct annotations

- [x] T053 [US7] Update backend Helm values `helm/backend/values.yaml`
  - Add: dapr.enabled (true), dapr.appId (todo-backend), dapr.appPort (8000)
  - Add environment variables: DAPR_HOST, DAPR_PORT, DAPR_PUBSUB_NAME
  - **Test**: Values render correctly in templates

- [x] T054 [US7] Create Dapr components Helm template `helm/backend/templates/dapr-components.yaml`
  - Render Dapr component manifests from values (conditional local vs cloud)
  - **Test**: `helm template` produces valid Dapr component YAMLs

- [x] T055 [US7] Update backend ConfigMap `helm/backend/templates/configmap.yaml`
  - Add Dapr-related environment variables
  - **Test**: ConfigMap includes DAPR_HOST, DAPR_PORT

- [x] T056 [P] [US7] Create cloud values override `helm/backend/values-cloud.yaml`
  - Image from registry (not local), imagePullPolicy: IfNotPresent
  - Cloud Kafka brokers, PostgreSQL DATABASE_URL
  - Resource limits for cloud
  - **Test**: Cloud values override local defaults correctly

### P6.2 — Minikube Deployment & Validation

- [ ] T057 [US7] Deploy Strimzi Kafka on Minikube
  - Install Strimzi operator in kafka namespace
  - Deploy single-broker Kafka cluster (KRaft mode)
  - Verify broker pod running
  - Create topics: task-events, reminders, task-updates
  - **Test**: `kubectl get kafka -n kafka` shows cluster ready, topics created

- [ ] T058 [US7] Install Dapr on Minikube
  - `dapr init -k` or Helm install
  - Verify Dapr control plane pods running
  - Apply Dapr component configs (pubsub pointing to Strimzi)
  - **Test**: `dapr status -k` shows all components healthy

- [ ] T059 [US7] Build and deploy updated backend on Minikube
  - Build Docker image with new code in Minikube Docker daemon
  - `helm upgrade --install todo-backend ./helm/backend`
  - Verify backend pod running with Dapr sidecar (2/2 containers)
  - **Test**: `kubectl get pods` shows backend pod with 2/2 ready

- [ ] T060 [US7] Build and deploy frontend on Minikube
  - Rebuild frontend image (with updated types/components)
  - `helm upgrade --install todo-frontend ./helm/frontend`
  - Verify frontend pod running
  - **Test**: Frontend accessible via `minikube service todo-frontend --url`

- [ ] T061 [US7] End-to-end local validation
  - Create task with priority, tags, due_date via UI
  - Verify task.created event in Kafka (check consumer logs)
  - Filter tasks by priority, verify results
  - Search tasks, verify results
  - Sort tasks, verify order
  - Complete recurring task, verify new instance auto-created
  - Verify audit log records exist
  - **Test**: All E2E scenarios pass

**Checkpoint**: Full stack validated on Minikube with Kafka + Dapr.

---

## Phase 7: Scope E — Cloud Deployment

**Purpose**: Deploy to managed Kubernetes with public URL.

- [ ] T062 [US8] Set up cloud Kubernetes cluster
  - Create cluster (AKS/GKE/OKE)
  - Configure kubectl context
  - Create namespace: todo-app
  - **Test**: `kubectl get nodes` shows healthy node(s)

- [ ] T063 [US8] Set up managed PostgreSQL
  - Create PostgreSQL instance (Neon free tier or equivalent)
  - Get connection string
  - Verify connectivity from local machine
  - **Test**: `psql` connects successfully

- [ ] T064 [US8] Set up managed Kafka
  - Create Redpanda Cloud cluster (serverless/free tier)
  - Get broker URL and SASL credentials
  - Create topics: task-events, reminders, task-updates
  - **Test**: Topics created and accessible

- [ ] T065 [US8] Push Docker images to registry
  - Build production images for backend and frontend
  - Tag: `<registry>/todo-backend:v5.0`, `<registry>/todo-frontend:v5.0`
  - Push to Docker Hub or GHCR
  - **Test**: Images pullable from registry

- [ ] T066 [US8] Create Kubernetes secrets on cloud cluster
  - JWT_SECRET, DATABASE_URL, ANTHROPIC_API_KEY, KAFKA_USERNAME, KAFKA_PASSWORD, BETTER_AUTH_SECRET
  - **Test**: `kubectl get secrets -n todo-app` shows all secrets

- [ ] T067 [US8] Install Dapr on cloud cluster
  - `dapr init -k` or Helm install
  - Apply cloud Dapr components (pubsub-kafka-cloud, statestore-cloud, secretstore-k8s)
  - **Test**: `dapr status -k` shows healthy

- [ ] T068 [US8] Deploy backend to cloud cluster
  - `helm upgrade --install todo-backend ./helm/backend -f helm/backend/values-cloud.yaml -n todo-app`
  - Verify pod running with Dapr sidecar (2/2)
  - **Test**: `kubectl logs` shows backend started, Dapr connected

- [ ] T069 [US8] Deploy frontend to cloud cluster
  - `helm upgrade --install todo-frontend ./helm/frontend -f helm/frontend/values-cloud.yaml -n todo-app`
  - Verify pod running
  - **Test**: Pod running and healthy

- [ ] T070 [US8] Configure Ingress and public URL
  - Install nginx-ingress controller (or use cloud-native)
  - Create Ingress resource: / → frontend, /api → backend
  - Get external IP / LoadBalancer URL
  - Update CORS_ORIGINS with public URL
  - **Test**: Public URL loads frontend, API responds at /api/health

- [ ] T071 [US8] Cloud end-to-end validation
  - Access public URL from browser
  - Sign up, create tasks with all new features
  - Verify events flowing through cloud Kafka
  - Verify data persists in PostgreSQL
  - **Test**: All features work from public URL

**Checkpoint**: Application publicly accessible on cloud Kubernetes.

---

## Phase 8: Scope F — CI/CD & Observability

**Purpose**: GitHub Actions pipeline, structured logging, monitoring.

- [x] T072 [P] [US10] Add structured JSON logging to backend in `backend/app/logging_config.py`
  - JSONFormatter: timestamp, level, message, module, request_id
  - Request ID middleware: generate UUID per request, attach to all logs
  - **Test**: Backend logs emit valid JSON

- [x] T073 [P] [US10] Add request logging middleware in `backend/app/main.py`
  - Log: method, path, status_code, duration_ms for every request
  - **Test**: API request produces structured log entry

- [x] T074 [US9] Create GitHub Actions CI/CD workflow in `.github/workflows/ci-cd.yaml`
  - Trigger: push to main
  - Jobs:
    1. lint: ruff check backend, tsc --noEmit frontend
    2. test: pytest backend
    3. build: docker build backend + frontend
    4. push: docker push to registry (only on main)
    5. deploy: helm upgrade on cloud cluster (only on main)
  - Secrets needed: DOCKER_USERNAME, DOCKER_PASSWORD, KUBECONFIG
  - **Test**: Pipeline runs on push, all stages pass

- [x] T075 [US10] Update health check endpoint in `backend/app/main.py`
  - Enhanced /health: check DB connectivity, Dapr sidecar status
  - Return: { status, db: ok/error, dapr: ok/error, version }
  - **Test**: Health endpoint returns all checks

**Checkpoint**: CI/CD pipeline active, structured logging in place.

---

## Phase 9: Finalization & Documentation

**Purpose**: Final validation, documentation, cleanup.

- [x] T076 [P] Update README.md with Phase V architecture, setup instructions, public URL
  - Architecture diagram
  - Local setup (Minikube + Strimzi + Dapr)
  - Cloud deployment steps
  - CI/CD pipeline description
  - API documentation summary
  - **Test**: README is accurate and complete

- [x] T077 [P] Create deployment runbook in `docs/DEPLOYMENT.md`
  - Step-by-step: local → cloud deployment
  - Troubleshooting common issues
  - Rollback procedures
  - **Test**: New developer can follow runbook

- [ ] T078 Final success criteria validation
  - SC-001: All 8 new task fields persisted ✓
  - SC-002: Search <500ms ✓
  - SC-003: Filter+sort correct ✓
  - SC-004: Events published <200ms ✓
  - SC-005: Audit log 100% capture ✓
  - SC-006: Reminders fire <60s accuracy ✓
  - SC-007: Recurring tasks auto-generate ✓
  - SC-008: Zero direct Kafka calls ✓
  - SC-009: Infra swap = YAML only ✓
  - SC-010: Public URL works E2E ✓
  - SC-011: CI/CD <10min ✓
  - SC-012: Pods healthy <120s ✓
  - **Test**: All 12 success criteria pass

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Model+API) → Phase 2 (Frontend) → Phase 3 (Events+Dapr code)
                                               ↓
Phase 4 (Dapr/Kafka YAML) ←──── can parallel with Phase 3
                                               ↓
Phase 5 (Deps+Docker) → Phase 6 (Minikube validation)
                                               ↓
                         Phase 7 (Cloud deployment)
                                               ↓
                         Phase 8 (CI/CD+Observability)
                                               ↓
                         Phase 9 (Finalization)
```

### Parallel Opportunities

- T002, T006, T007 can run in parallel (different files)
- T043, T044, T045, T046, T047, T048, T049 can all run in parallel (independent YAML files)
- T056, T072, T073 can run in parallel
- T076, T077 can run in parallel

### Critical Path

T001 → T003-T005 → T008-T009 → T014-T017 → T020-T027 → T029-T035 → T036-T041 → T052-T055 → T057-T061 → T062-T071 → T074 → T078

---

## Total Task Count: 78 tasks across 9 phases
