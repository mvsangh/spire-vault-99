"""
Configuration module for SPIRE-Vault-99 Backend.
Uses environment variables following 12-factor app principles.
"""

import os
from typing import Optional
from pydantic_settings import BaseSettings
from pydantic import field_validator


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Application
    APP_NAME: str = "SPIRE-Vault-99 Backend"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False

    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000

    # CORS (httpOnly cookie authentication requires allow_credentials=True)
    CORS_ORIGINS: list[str] = [
        "http://localhost:3000",
        "http://localhost:3001",  # Frontend dev server (Next.js)
        "http://localhost:8000",
        "http://frontend.99-apps.svc.cluster.local:3000",  # Kubernetes service
    ]
    CORS_CREDENTIALS: bool = True  # Required for cookies
    CORS_METHODS: list[str] = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    CORS_HEADERS: list[str] = ["Content-Type", "Authorization"]

    # SPIRE
    SPIRE_SOCKET_PATH: str = "/run/spire/sockets/agent.sock"
    SPIFFE_ID: Optional[str] = None  # Will be fetched from SPIRE

    # JWT-SVID Configuration - computed property to avoid Pydantic JSON parsing
    @property
    def JWT_SVID_AUDIENCE(self) -> list[str]:
        """Get JWT-SVID audiences as list from comma-separated env var."""
        audiences_str = os.getenv("JWT_SVID_AUDIENCE", "openbao,vault")
        return [aud.strip() for aud in audiences_str.split(",")]

    # Vault (OpenBao)
    VAULT_ADDR: str = os.getenv(
        "VAULT_ADDR",
        "http://openbao.openbao.svc.cluster.local:8200"
    )
    VAULT_CACERT: Optional[str] = os.getenv("VAULT_CACERT")  # Path to CA certificate for TLS verification
    VAULT_NAMESPACE: Optional[str] = None
    VAULT_KV_PATH: str = "secret"  # KV v2 mount path
    VAULT_DB_PATH: str = "database"  # Database secrets engine path
    VAULT_DB_ROLE: str = "backend-role"  # Database role name

    # PostgreSQL
    DB_HOST: str = os.getenv(
        "DB_HOST",
        "postgresql.99-apps.svc.cluster.local"
    )
    DB_PORT: int = 5432
    DB_NAME: str = "appdb"
    # Dynamic credentials from Vault - no static username/password
    DB_POOL_SIZE: int = 10
    DB_MAX_OVERFLOW: int = 10
    DB_POOL_TIMEOUT: int = 30
    DB_CREDENTIAL_ROTATION_INTERVAL: int = 3000  # 50 minutes in seconds
    DB_ECHO: bool = False  # SQLAlchemy SQL logging

    # JWT Authentication
    JWT_SECRET_KEY: str = os.getenv(
        "JWT_SECRET_KEY",
        "dev-secret-key-change-in-production"  # Change in production!
    )
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    # Password Hashing
    BCRYPT_ROUNDS: int = 12

    # GitHub API
    GITHUB_API_URL: str = "https://api.github.com"

    # Logging
    LOG_LEVEL: str = "INFO"
    LOG_FORMAT: str = "json"  # "json" or "text"

    class Config:
        env_file = ".env"
        case_sensitive = True


# Global settings instance
settings = Settings()
