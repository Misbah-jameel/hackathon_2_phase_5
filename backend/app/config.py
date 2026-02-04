from pydantic_settings import BaseSettings
from typing import List, Optional
from pathlib import Path
import warnings


# Get the directory containing this file (app/) and go up to backend/
_BASE_DIR = Path(__file__).resolve().parent.parent
_ENV_FILE = _BASE_DIR / ".env"


# Known insecure default secrets to detect
INSECURE_SECRETS = {
    "development-secret-key-change-in-production",
    "your-super-secret-jwt-key-change-in-production",
    "your-super-secret-jwt-key-change-in-production-12345",
    "secret",
    "changeme",
}


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Database - SQLite by default for easy local development
    # For production, use: postgresql://user:pass@host/db
    database_url: str = "sqlite:///./todoapp.db"

    # JWT
    jwt_secret: str = "development-secret-key-change-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expiry_hours: int = 24

    # CORS
    cors_origins: str = "http://localhost:3000,http://127.0.0.1:3000"

    # Anthropic AI Configuration
    anthropic_api_key: Optional[str] = None
    anthropic_model: str = "claude-3-haiku-20240307"

    @property
    def cors_origins_list(self) -> List[str]:
        return [origin.strip() for origin in self.cors_origins.split(",")]

    @property
    def is_sqlite(self) -> bool:
        return self.database_url.startswith("sqlite")

    @property
    def is_jwt_secret_secure(self) -> bool:
        """Check if the JWT secret is secure (not a known default)."""
        if not self.jwt_secret:
            return False
        if len(self.jwt_secret) < 32:
            return False
        if self.jwt_secret.lower() in INSECURE_SECRETS:
            return False
        return True

    @property
    def has_anthropic_key(self) -> bool:
        """Check if Anthropic API key is configured."""
        return bool(self.anthropic_api_key and self.anthropic_api_key.strip())

    def validate_security(self) -> None:
        """Validate security settings and print warnings."""
        if not self.is_jwt_secret_secure:
            warnings.warn(
                "\n"
                "=" * 60 + "\n"
                "SECURITY WARNING: JWT secret is insecure!\n"
                "Using a default or weak JWT secret in production is dangerous.\n"
                "Generate a secure secret with:\n"
                "  python -c \"import secrets; print(secrets.token_urlsafe(32))\"\n"
                "Then set JWT_SECRET in your .env file.\n"
                "=" * 60,
                UserWarning,
                stacklevel=2,
            )

    class Config:
        env_file = str(_ENV_FILE)
        env_file_encoding = "utf-8"


settings = Settings()
