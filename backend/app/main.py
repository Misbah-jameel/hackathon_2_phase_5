from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .database import init_db
from .routers import auth_router, tasks_router, chatbot_router


# Create FastAPI app
app = FastAPI(
    title="Todo App API",
    description="Backend API for the Todo application with chatbot integration",
    version="1.0.0",
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth_router)
app.include_router(tasks_router)
app.include_router(chatbot_router)


@app.on_event("startup")
async def startup_event():
    """Initialize database tables on startup."""
    # Validate security settings once
    settings.validate_security()
    init_db()


@app.get("/")
async def root():
    """Root endpoint - health check."""
    return {"status": "ok", "message": "Todo App API is running"}


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy"}
