import re
from pydantic import BaseModel, EmailStr, field_validator
from datetime import datetime


class LoginInput(BaseModel):
    """Login request schema."""
    email: EmailStr
    password: str


class SignupInput(BaseModel):
    """Signup request schema."""
    email: EmailStr
    password: str
    name: str

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        """
        Validate password strength.

        Requirements:
        - Minimum 8 characters
        - At least one uppercase letter
        - At least one lowercase letter
        - At least one number
        """
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters long")

        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain at least one uppercase letter")

        if not re.search(r"[a-z]", v):
            raise ValueError("Password must contain at least one lowercase letter")

        if not re.search(r"\d", v):
            raise ValueError("Password must contain at least one number")

        return v


class UserResponse(BaseModel):
    """User response schema (excludes password)."""
    id: str
    email: str
    name: str
    createdAt: datetime

    class Config:
        from_attributes = True


class AuthResponse(BaseModel):
    """Authentication response with user and token."""
    user: UserResponse
    token: str
