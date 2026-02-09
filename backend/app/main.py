import time
import uuid
import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .database import init_db
from .logging_config import setup_logging
from .routers import (
    auth_router,
    tasks_router,
    chatbot_router,
    events_router,
    subscriptions_router,
)
from .consumers import (
    audit_consumer_router,
    reminder_consumer_router,
    recurrence_consumer_router,
)

# Initialize structured logging
setup_logging()
logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI(
    title="Todo App API",
    description="Backend API for the Todo application with event-driven architecture",
    version="2.0.0",
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Request logging middleware
@app.middleware("http")
async def log_requests(request: Request, call_next):
    request_id = str(uuid.uuid4())[:8]
    start_time = time.time()

    # Attach request_id to request state
    request.state.request_id = request_id

    response = await call_next(request)

    duration_ms = round((time.time() - start_time) * 1000, 2)
    logger.info(
        f"{request.method} {request.url.path} {response.status_code} {duration_ms}ms",
        extra={"request_id": request_id},
    )

    response.headers["X-Request-ID"] = request_id
    return response


# Include API routers
app.include_router(auth_router)
app.include_router(tasks_router)
app.include_router(chatbot_router)
app.include_router(events_router)

# Include Dapr subscription and consumer routers
app.include_router(subscriptions_router)
app.include_router(audit_consumer_router)
app.include_router(reminder_consumer_router)
app.include_router(recurrence_consumer_router)


@app.on_event("startup")
async def startup_event():
    """Initialize database tables on startup."""
    settings.validate_security()
    init_db()
    logger.info("Todo App API started", extra={"request_id": "startup"})


@app.get("/")
async def root():
    """Root endpoint - health check."""
    return {"status": "ok", "message": "Todo App API is running", "version": "2.0.0"}


@app.get("/health")
async def health_check():
    """Enhanced health check endpoint."""
    health = {
        "status": "healthy",
        "version": "2.0.0",
        "db": "ok",
        "dapr": "unknown",
    }

    # Check database connectivity
    try:
        from .database import engine
        from sqlmodel import Session, text
        with Session(engine) as session:
            session.exec(text("SELECT 1"))
        health["db"] = "ok"
    except Exception:
        health["db"] = "error"
        health["status"] = "degraded"

    # Check Dapr sidecar
    try:
        import httpx
        dapr_url = f"http://{settings.dapr_host}:{settings.dapr_port}/v1.0/healthz"
        async with httpx.AsyncClient(timeout=2.0) as client:
            resp = await client.get(dapr_url)
            health["dapr"] = "ok" if resp.status_code < 300 else "error"
    except Exception:
        health["dapr"] = "unavailable"

    return health
