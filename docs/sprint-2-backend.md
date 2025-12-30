# 🚀 SUB-SPRINT 2: Backend Application Development
**FastAPI + SPIRE + OpenBao + PostgreSQL Integration**

## 📊 Overview

**Objective:** Develop a production-grade FastAPI backend application that integrates with SPIRE for workload identity, OpenBao for secrets management, and PostgreSQL for data persistence.

**Duration:** ASAP
**Prerequisites:** Sub-Sprint 1 (Infrastructure Foundation) completed
**Success Criteria:** Backend running in cluster with full SPIRE/Vault/DB integration, hot-reload development working, all API endpoints functional

---

## 🎯 Deliverables

- ✅ FastAPI application with modular architecture
- ✅ SPIRE client integration (X.509-SVID acquisition)
- ✅ Vault client with mTLS authentication
- ✅ Dynamic database credentials with automatic rotation
- ✅ User authentication system (JWT + bcrypt)
- ✅ GitHub integration (token storage + API calls)
- ✅ Complete REST API (`/api/v1/*`)
- ✅ Tilt development environment (hot-reload)
- ✅ Kubernetes deployment manifests
- ✅ Integration tests and verification

---

## 🗂️ Technology Stack

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Framework** | FastAPI | 0.115.0 | Web framework |
| **ASGI Server** | Uvicorn | 0.32.0 | Production server |
| **SPIRE Client** | py-spiffe | 0.6.0 | Workload identity |
| **Vault Client** | hvac | 2.3.0 | Secrets management |
| **Database ORM** | SQLAlchemy | 2.0.36 | Database abstraction |
| **DB Driver** | asyncpg | 0.30.0 | PostgreSQL async driver |
| **JWT** | python-jose | 3.3.0 | Token generation |
| **Password Hashing** | passlib[bcrypt] | 1.7.4 | Secure hashing |
| **HTTP Client** | httpx | 0.28.1 | GitHub API calls |
| **Validation** | Pydantic | 2.10.0 | Data validation |
| **Dev Tool** | Tilt | Latest | Hot-reload development |

---

## 📋 Phase Breakdown

### **Phase 1: Development Environment & Project Setup**
### **Phase 2: SPIRE Client Integration**
### **Phase 3: Vault Client Integration & Configuration**
### **Phase 4: Database Connection Management**
### **Phase 5: User Authentication System**
### **Phase 6: GitHub Integration**
### **Phase 7: API Endpoints & Documentation**
### **Phase 8: Containerization & Kubernetes Deployment**
### **Phase 9: Integration Testing & Verification**

---

## 🔧 Phase 1: Development Environment & Project Setup

**Objective:** Set up the backend project structure, dependencies, and Tilt development environment.

### **Tasks:**

#### **Task 1.1: Create Backend Directory Structure**

**Description:** Create the complete directory structure for the backend application.

**Commands:**
```bash
cd /home/mandrix-murdock/code/spire-spife/test-vault

# Create backend directory structure
mkdir -p backend/app/api/v1
mkdir -p backend/app/core
mkdir -p backend/app/models
mkdir -p backend/app/middleware
mkdir -p backend/tests/integration
mkdir -p backend/k8s
mkdir -p backend/scripts

# Create __init__.py files
touch backend/app/__init__.py
touch backend/app/api/__init__.py
touch backend/app/api/v1/__init__.py
touch backend/app/core/__init__.py
touch backend/app/models/__init__.py
touch backend/app/middleware/__init__.py
touch backend/tests/__init__.py
touch backend/tests/integration/__init__.py

# Verify structure
tree backend/ -L 3
```

**Expected Directory Structure:**
```
backend/
├── Dockerfile              # Production Docker image
├── Dockerfile.dev          # Development Docker image (with --reload)
├── requirements.txt        # Production dependencies
├── requirements-dev.txt    # Development/testing dependencies
├── .dockerignore
├── .gitignore
├── app/
│   ├── __init__.py
│   ├── main.py            # FastAPI app entry point
│   ├── config.py          # Configuration (environment variables)
│   ├── api/
│   │   ├── __init__.py
│   │   └── v1/
│   │       ├── __init__.py
│   │       ├── auth.py     # /api/v1/auth/* endpoints
│   │       ├── github.py   # /api/v1/github/* endpoints
│   │       └── health.py   # /api/v1/health
│   ├── core/
│   │   ├── __init__.py
│   │   ├── spire.py       # SPIRE client
│   │   ├── vault.py       # Vault client
│   │   ├── database.py    # Database connection pool + rotation
│   │   ├── auth.py        # JWT + password hashing
│   │   └── github.py      # GitHub API client
│   ├── models/
│   │   ├── __init__.py
│   │   ├── user.py        # SQLAlchemy models
│   │   └── schemas.py     # Pydantic request/response schemas
│   └── middleware/
│       ├── __init__.py
│       └── auth.py        # JWT validation middleware
├── tests/
│   ├── __init__.py
│   ├── test_auth.py
│   ├── test_github.py
│   └── integration/
│       ├── __init__.py
│       ├── test_spire.py
│       └── test_vault.py
├── k8s/
│   ├── serviceaccount.yaml
│   ├── deployment.yaml
│   └── service.yaml
└── scripts/
    └── test-in-cluster.sh
```

**Success Criteria:**
- ✅ All directories created
- ✅ All `__init__.py` files in place
- ✅ Structure ready for code

---

#### **Task 1.2: Create Requirements Files**

**Description:** Define production and development dependencies.

**File:** `backend/requirements.txt`

**Content:**
```txt
# Production dependencies for SPIRE-Vault-99 Backend
# Python 3.11+

# Web Framework
fastapi==0.115.0
uvicorn[standard]==0.32.0

# Data Validation
pydantic==2.10.0
pydantic-settings==2.6.0

# Database
sqlalchemy==2.0.36
asyncpg==0.30.0

# Authentication & Security
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4

# HTTP Client (GitHub API)
httpx==0.28.1

# SPIRE Integration
py-spiffe==0.6.0

# Vault Integration
hvac==2.3.0

# Utilities
python-multipart==0.0.18  # For form data
```

**File:** `backend/requirements-dev.txt`

**Content:**
```txt
# Development and testing dependencies
# Includes all production dependencies

-r requirements.txt

# Testing
pytest==8.3.4
pytest-asyncio==0.24.0
pytest-cov==6.0.0

# Debugging
debugpy==1.8.9

# Code Quality (optional)
black==24.10.0
ruff==0.8.4
```

**Success Criteria:**
- ✅ Both requirements files created
- ✅ All dependencies properly versioned

---

#### **Task 1.3: Install Tilt (if not already installed)**

**Description:** Install Tilt for hot-reload Kubernetes development.

**Note:** User already has Tilt installed, but including instructions for reference.

**macOS:**
```bash
brew install tilt-dev/tap/tilt
```

**Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/tilt-dev/tilt/master/scripts/install.sh | bash
```

**Windows (PowerShell):**
```powershell
iex ((new-object net.webclient).DownloadString('https://raw.githubusercontent.com/tilt-dev/tilt/master/scripts/install.ps1'))
```

**Verify Installation:**
```bash
tilt version
```

**Expected Output:**
```
v0.33.x, built 2024-xx-xx
```

**Success Criteria:**
- ✅ Tilt installed and accessible
- ✅ Version command works

---

#### **Task 1.4: Create Development Dockerfile**

**Description:** Create Dockerfile for development with hot-reload support.

**File:** `backend/Dockerfile.dev`

**Content:**
```dockerfile
# Development Dockerfile for SPIRE-Vault-99 Backend
# Includes uvicorn --reload for hot-reload development

FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements-dev.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements-dev.txt

# Copy application code
COPY . .

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/api/v1/health')"

# Run with uvicorn --reload for hot-reload
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
```

**Success Criteria:**
- ✅ Development Dockerfile created
- ✅ Includes --reload flag for hot-reload
- ✅ Installs dev dependencies

---

#### **Task 1.5: Create Production Dockerfile**

**Description:** Create optimized Dockerfile for production deployment.

**File:** `backend/Dockerfile`

**Content:**
```dockerfile
# Production Dockerfile for SPIRE-Vault-99 Backend
# Multi-stage build for smaller image size

# Stage 1: Builder
FROM python:3.11-slim AS builder

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim

WORKDIR /app

# Copy Python dependencies from builder
COPY --from=builder /root/.local /root/.local

# Copy application code
COPY . .

# Update PATH
ENV PATH=/root/.local/bin:$PATH

# Create non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/api/v1/health')"

# Run with uvicorn (production mode, multiple workers)
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
```

**Success Criteria:**
- ✅ Production Dockerfile created
- ✅ Multi-stage build for smaller image
- ✅ Runs as non-root user
- ✅ Multiple workers for production

---

#### **Task 1.6: Create .dockerignore File**

**Description:** Exclude unnecessary files from Docker builds.

**File:** `backend/.dockerignore`

**Content:**
```
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
ENV/
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# Testing
.pytest_cache/
.coverage
htmlcov/

# IDEs
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Git
.git/
.gitignore

# Kubernetes
k8s/

# Documentation
*.md
README.md

# Docker
Dockerfile*
.dockerignore
```

**Success Criteria:**
- ✅ .dockerignore created
- ✅ Excludes unnecessary files

---

#### **Task 1.7: Create Configuration Module**

**Description:** Create centralized configuration using environment variables.

**File:** `backend/app/config.py`

**Content:**
```python
"""
Configuration module for SPIRE-Vault-99 Backend.
Uses environment variables following 12-factor app principles.
"""

import os
from typing import Optional
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Application
    APP_NAME: str = "SPIRE-Vault-99 Backend"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False

    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000

    # CORS
    CORS_ORIGINS: list[str] = ["http://localhost:3000", "http://localhost:8000"]
    CORS_CREDENTIALS: bool = True
    CORS_METHODS: list[str] = ["*"]
    CORS_HEADERS: list[str] = ["*"]

    # SPIRE
    SPIRE_SOCKET_PATH: str = "/run/spire/sockets/agent.sock"
    SPIFFE_ID: Optional[str] = None  # Will be fetched from SPIRE

    # Vault (OpenBao)
    VAULT_ADDR: str = os.getenv(
        "VAULT_ADDR",
        "http://openbao.openbao.svc.cluster.local:8200"
    )
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
    DB_POOL_MAX_OVERFLOW: int = 10
    DB_POOL_TIMEOUT: int = 30
    DB_CREDENTIAL_ROTATION_INTERVAL: int = 3000  # 50 minutes in seconds

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
```

**Success Criteria:**
- ✅ Configuration module created
- ✅ All settings defined with environment variables
- ✅ Proper defaults for development

---

#### **Task 1.8: Create Basic FastAPI Application**

**Description:** Create the main FastAPI application entry point.

**File:** `backend/app/main.py`

**Content:**
```python
"""
Main FastAPI application for SPIRE-Vault-99 Backend.
"""

import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config import settings
from app.api.v1 import health

# Configure logging
logging.basicConfig(
    level=getattr(logging, settings.LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application lifespan manager.
    Handles startup and shutdown events.
    """
    # Startup
    logger.info(f"Starting {settings.APP_NAME} v{settings.APP_VERSION}")
    logger.info(f"SPIRE socket: {settings.SPIRE_SOCKET_PATH}")
    logger.info(f"Vault address: {settings.VAULT_ADDR}")
    logger.info(f"Database host: {settings.DB_HOST}")

    # TODO: Initialize SPIRE client (Phase 2)
    # TODO: Initialize Vault client (Phase 3)
    # TODO: Initialize database pool (Phase 4)
    # TODO: Start credential rotation task (Phase 4)

    yield

    # Shutdown
    logger.info("Shutting down application...")
    # TODO: Close database pool (Phase 4)
    # TODO: Revoke Vault lease (Phase 4)
    logger.info("Shutdown complete")


# Create FastAPI app
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Zero-trust demo platform with SPIRE/SPIFFE + OpenBao + Cilium",
    lifespan=lifespan,
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=settings.CORS_CREDENTIALS,
    allow_methods=settings.CORS_METHODS,
    allow_headers=settings.CORS_HEADERS,
)

# Include routers
app.include_router(health.router, prefix="/api/v1", tags=["health"])
# TODO: Add auth router (Phase 5)
# TODO: Add github router (Phase 6)

# Root endpoint
@app.get("/")
async def root():
    """Root endpoint with API information."""
    return {
        "name": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "status": "running",
        "docs": "/docs",
    }


# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Handle uncaught exceptions."""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"}
    )
```

**Success Criteria:**
- ✅ FastAPI app created
- ✅ CORS configured
- ✅ Lifespan events defined
- ✅ Logging configured

---

#### **Task 1.9: Create Health Endpoint**

**Description:** Create health check endpoints for Kubernetes probes.

**File:** `backend/app/api/v1/health.py`

**Content:**
```python
"""
Health check endpoints for Kubernetes liveness/readiness probes.
"""

from fastapi import APIRouter, status
from pydantic import BaseModel

router = APIRouter()


class HealthResponse(BaseModel):
    """Health check response model."""
    status: str
    version: str
    spire: str = "not_initialized"
    vault: str = "not_initialized"
    database: str = "not_initialized"


@router.get(
    "/health",
    response_model=HealthResponse,
    status_code=status.HTTP_200_OK,
    summary="Health check",
    description="Basic health check endpoint for liveness probe"
)
async def health_check():
    """
    Health check endpoint.
    Returns 200 if the application is running.
    """
    from app.config import settings

    return HealthResponse(
        status="healthy",
        version=settings.APP_VERSION,
        # TODO: Add real status checks in later phases
    )


@router.get(
    "/health/ready",
    response_model=HealthResponse,
    status_code=status.HTTP_200_OK,
    summary="Readiness check",
    description="Readiness check endpoint - verifies all dependencies are ready"
)
async def readiness_check():
    """
    Readiness check endpoint.
    Returns 200 only if SPIRE, Vault, and Database are ready.
    """
    from app.config import settings

    # TODO: Implement real readiness checks in later phases
    # - Check SPIRE connection
    # - Check Vault authentication
    # - Check database connection

    return HealthResponse(
        status="ready",
        version=settings.APP_VERSION,
    )
```

**Success Criteria:**
- ✅ Health endpoints created
- ✅ `/api/v1/health` for liveness
- ✅ `/api/v1/health/ready` for readiness

---

#### **Task 1.10: Create Tiltfile**

**Description:** Create Tiltfile for hot-reload Kubernetes development.

**File:** `Tiltfile` (in project root)

**Content:**
```python
# Tiltfile for SPIRE-Vault-99 Backend Development
# Enables hot-reload development with real SPIRE, Vault, and PostgreSQL

# Load Kubernetes YAML
k8s_yaml('backend/k8s/serviceaccount.yaml')
k8s_yaml('backend/k8s/deployment.yaml')
k8s_yaml('backend/k8s/service.yaml')

# Build Docker image with live update
docker_build(
    'backend',
    context='./backend',
    dockerfile='./backend/Dockerfile.dev',
    live_update=[
        # Sync Python files
        sync('./backend/app', '/app/app'),

        # Restart uvicorn when requirements change
        run(
            'pip install -r /app/requirements-dev.txt',
            trigger=['./backend/requirements-dev.txt']
        ),
    ]
)

# Configure backend resource
k8s_resource(
    'backend',
    port_forwards=[
        '8000:8000',  # API
    ],
    labels=['app'],
    resource_deps=[],  # No dependencies yet
)

# Display startup message
print("""
🚀 SPIRE-Vault-99 Backend Development

Tilt is now watching your backend code!

📝 Edit files in backend/app/ and Tilt will:
   1. Sync changes to the pod (~2 seconds)
   2. uvicorn --reload will auto-restart
   3. See changes at http://localhost:8000

📊 Resources:
   - API:     http://localhost:8000
   - Docs:    http://localhost:8000/docs
   - Health:  http://localhost:8000/api/v1/health

🔍 Tilt UI: http://localhost:10350

Press space to open the Tilt UI in your browser.
""")
```

**Success Criteria:**
- ✅ Tiltfile created
- ✅ Live update configured for .py files
- ✅ Port forwarding configured

---

#### **Task 1.11: Test Basic Setup**

**Description:** Verify the basic application structure works.

**Commands:**
```bash
cd backend

# Install dependencies locally (for IDE support)
pip install -r requirements-dev.txt

# Test running locally (without SPIRE/Vault)
uvicorn app.main:app --reload

# In another terminal, test health endpoint
curl http://localhost:8000/api/v1/health
```

**Expected Output:**
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "spire": "not_initialized",
  "vault": "not_initialized",
  "database": "not_initialized"
}
```

**Test with Tilt (in cluster):**
```bash
# Build Docker image first
docker build -t backend:dev -f backend/Dockerfile.dev backend/

# Load into kind cluster
kind load docker-image backend:dev --name precinct-99

# Note: Don't start Tilt yet - we need K8s manifests first (Phase 8)
```

**Success Criteria:**
- ✅ Application runs locally
- ✅ Health endpoint responds
- ✅ No errors in logs

---

### 📋 EXECUTION LOG - Phase 1

**Date:** [To be filled during implementation]
**Status:** ⏳ PENDING

**Summary:** [To be filled after implementation]

**Issues Faced:** [To be documented]

**Important Decisions:** [To be documented]

**Next Phase:** Phase 2 - SPIRE Client Integration

---

## 🔐 Phase 2: SPIRE Client Integration

**Objective:** Integrate py-spiffe library to fetch X.509-SVIDs from the SPIRE agent.

### **Tasks:**

#### **Task 2.1: Create SPIRE Client Module**

**Description:** Implement SPIRE Workload API client to fetch SVIDs.

**File:** `backend/app/core/spire.py`

**Content:**
```python
"""
SPIRE client for workload identity.
Fetches X.509-SVID from SPIRE agent via Workload API.
"""

import logging
from typing import Optional
from spiffe.workloadapi import WorkloadApiClient
from spiffe.x509svid import X509Svid
from spiffe.spiffe_id import SpiffeId

from app.config import settings

logger = logging.getLogger(__name__)


class SPIREClient:
    """
    SPIRE Workload API client.
    Manages X.509-SVID acquisition and rotation.
    """

    def __init__(self, socket_path: str = settings.SPIRE_SOCKET_PATH):
        """
        Initialize SPIRE client.

        Args:
            socket_path: Path to SPIRE agent socket
        """
        self.socket_path = socket_path
        self._client: Optional[WorkloadApiClient] = None
        self._svid: Optional[X509Svid] = None
        self._spiffe_id: Optional[SpiffeId] = None
        logger.info(f"SPIRE client initialized with socket: {socket_path}")

    async def connect(self) -> None:
        """
        Connect to SPIRE agent and fetch initial SVID.
        """
        try:
            logger.info("Connecting to SPIRE agent...")

            # Create Workload API client
            self._client = WorkloadApiClient(self.socket_path)

            # Fetch X.509-SVID
            self._svid = self._client.fetch_x509_svid()
            self._spiffe_id = self._svid.spiffe_id

            logger.info(f"✅ SPIRE connected - SPIFFE ID: {self._spiffe_id}")
            logger.info(f"SVID expires at: {self._svid.not_after}")

        except Exception as e:
            logger.error(f"❌ Failed to connect to SPIRE: {e}")
            raise

    async def close(self) -> None:
        """Close SPIRE client connection."""
        if self._client:
            self._client.close()
            logger.info("SPIRE client closed")

    def get_svid(self) -> X509Svid:
        """
        Get current X.509-SVID.

        Returns:
            Current X.509-SVID

        Raises:
            RuntimeError: If SVID not available
        """
        if not self._svid:
            raise RuntimeError("SVID not available - call connect() first")
        return self._svid

    def get_spiffe_id(self) -> str:
        """
        Get SPIFFE ID as string.

        Returns:
            SPIFFE ID (e.g., spiffe://demo.local/ns/99-apps/sa/backend)
        """
        if not self._spiffe_id:
            raise RuntimeError("SPIFFE ID not available - call connect() first")
        return str(self._spiffe_id)

    def get_certificate_pem(self) -> bytes:
        """
        Get certificate in PEM format for mTLS.

        Returns:
            Certificate chain in PEM format
        """
        svid = self.get_svid()
        return svid.cert_chain_pem

    def get_private_key_pem(self) -> bytes:
        """
        Get private key in PEM format for mTLS.

        Returns:
            Private key in PEM format
        """
        svid = self.get_svid()
        return svid.private_key_pem

    def is_connected(self) -> bool:
        """Check if connected to SPIRE and SVID is available."""
        return self._svid is not None


# Global SPIRE client instance
spire_client = SPIREClient()
```

**Success Criteria:**
- ✅ SPIRE client module created
- ✅ Can fetch X.509-SVID
- ✅ Exposes certificate and key for mTLS

---

#### **Task 2.2: Update Application Startup**

**Description:** Initialize SPIRE client on application startup.

**File:** `backend/app/main.py` (update lifespan function)

**Content:**
```python
# Add import at top
from app.core.spire import spire_client

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application lifespan manager.
    Handles startup and shutdown events.
    """
    # Startup
    logger.info(f"Starting {settings.APP_NAME} v{settings.APP_VERSION}")
    logger.info(f"SPIRE socket: {settings.SPIRE_SOCKET_PATH}")
    logger.info(f"Vault address: {settings.VAULT_ADDR}")
    logger.info(f"Database host: {settings.DB_HOST}")

    # Initialize SPIRE client
    try:
        await spire_client.connect()
        logger.info(f"✅ SPIRE initialized - ID: {spire_client.get_spiffe_id()}")
    except Exception as e:
        logger.error(f"❌ SPIRE initialization failed: {e}")
        raise

    # TODO: Initialize Vault client (Phase 3)
    # TODO: Initialize database pool (Phase 4)
    # TODO: Start credential rotation task (Phase 4)

    yield

    # Shutdown
    logger.info("Shutting down application...")
    await spire_client.close()
    # TODO: Close database pool (Phase 4)
    # TODO: Revoke Vault lease (Phase 4)
    logger.info("Shutdown complete")
```

**Success Criteria:**
- ✅ SPIRE client initialized on startup
- ✅ SPIFFE ID logged
- ✅ Graceful shutdown on close

---

#### **Task 2.3: Update Health Endpoint**

**Description:** Add SPIRE status to health checks.

**File:** `backend/app/api/v1/health.py` (update)

**Content:**
```python
# Add import
from app.core.spire import spire_client

@router.get("/health/ready")
async def readiness_check():
    """
    Readiness check endpoint.
    Returns 200 only if SPIRE, Vault, and Database are ready.
    """
    from app.config import settings

    # Check SPIRE connection
    spire_status = "ready" if spire_client.is_connected() else "not_ready"

    # TODO: Check Vault authentication (Phase 3)
    # TODO: Check database connection (Phase 4)

    return HealthResponse(
        status="ready" if spire_status == "ready" else "not_ready",
        version=settings.APP_VERSION,
        spire=spire_status,
    )
```

**Success Criteria:**
- ✅ Health endpoint shows SPIRE status
- ✅ Returns "ready" when SPIRE connected

---

#### **Task 2.4: Create SPIRE Registration Entry**

**Description:** Create SPIRE registration entry for the backend service.

**Commands:**
```bash
# Create registration entry for backend
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry create \
    -spiffeID spiffe://demo.local/ns/99-apps/sa/backend \
    -parentID spiffe://demo.local/spire/agent/k8s_psat/precinct-99 \
    -selector k8s:ns:99-apps \
    -selector k8s:sa:backend \
    -ttl 3600

# Verify entry created
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry show \
    -spiffeID spiffe://demo.local/ns/99-apps/sa/backend
```

**Expected Output:**
```
Entry ID         : <some-uuid>
SPIFFE ID        : spiffe://demo.local/ns/99-apps/sa/backend
Parent ID        : spiffe://demo.local/spire/agent/k8s_psat/precinct-99
Revision         : 0
TTL              : 3600
Selector         : k8s:ns:99-apps
Selector         : k8s:sa:backend
```

**Success Criteria:**
- ✅ Registration entry created
- ✅ SPIFFE ID matches backend service
- ✅ Selectors match namespace and service account

---

#### **Task 2.5: Test SPIRE Integration**

**Description:** Test SPIRE client in a temporary pod.

**Create test script:** `backend/scripts/test-spire.py`

**Content:**
```python
"""
Test script to verify SPIRE integration.
Run inside a pod with SPIRE socket access.
"""

import sys
from spiffe.workloadapi import WorkloadApiClient

def test_spire():
    socket_path = "/run/spire/sockets/agent.sock"

    print(f"🔍 Testing SPIRE connection...")
    print(f"Socket path: {socket_path}")

    try:
        client = WorkloadApiClient(socket_path)
        svid = client.fetch_x509_svid()

        print(f"✅ SPIRE connection successful!")
        print(f"SPIFFE ID: {svid.spiffe_id}")
        print(f"Expires: {svid.not_after}")
        print(f"Certificate chain length: {len(svid.cert_chain)}")

        client.close()
        return 0
    except Exception as e:
        print(f"❌ SPIRE connection failed: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(test_spire())
```

**Test in cluster:**
```bash
# We'll test this in Phase 8 when we deploy to cluster
# For now, this script is ready
```

**Success Criteria:**
- ✅ Test script created
- ✅ Ready for cluster testing

---

### 📋 EXECUTION LOG - Phase 2

**Date:** [To be filled during implementation]
**Status:** ⏳ PENDING

**Summary:** [To be filled after implementation]

**Next Phase:** Phase 3 - Vault Client Integration & Configuration

---

## 🔑 Phase 3: Vault Client Integration & Configuration

**Objective:** Configure OpenBao JWT auth and implement Vault client with JWT-SVID authentication.

**⚠️ PIVOT NOTE:** Originally planned for X.509-SVID cert auth, but pivoted to JWT-SVID due to OpenBao limitation (cert auth requires CN field, SPIFFE uses URI SANs). JWT-SVID is the **official SPIFFE recommendation** for Vault/OpenBao integration. See `docs/SESSION_IMPLEMENTATION_LOG.md` for detailed investigation.

### **Tasks:**

#### **Task 3.1: Create Vault Configuration Helper Script**

**Description:** Create idempotent script to configure Vault JWT auth (with SPIRE OIDC discovery), secrets engines, and policies.

**File:** `scripts/helpers/configure-vault-backend.sh`

**✅ IMPLEMENTATION NOTE:** Script updated to use JWT auth instead of cert auth. Key changes:
- Step 1: Enable JWT auth method (instead of cert auth)
- Step 2: Configure JWT auth with SPIRE OIDC discovery URL (`http://spire-server.spire-system.svc.cluster.local:8090`)
- Step 3: Create JWT auth role with `bound_audiences=["openbao","vault"]` and `bound_subject="spiffe://demo.local/ns/99-apps/sa/backend"`
- Steps 4-9: KV v2, Database secrets engine, and policies (unchanged)

**Content (see actual file for complete implementation):**
```bash
#!/bin/bash
set -e

# SPIRE-Vault-99: Configure OpenBao for Backend Service
# This script is idempotent - safe to run multiple times

echo "🔐 Configuring OpenBao for Backend Service..."

# Set Vault address
export BAO_ADDR='http://localhost:8200'
export BAO_TOKEN='root'

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#
# 1. Enable Cert Auth Method
#
echo ""
echo "📋 Step 1: Enable Cert Auth Method"
if kubectl exec -n openbao deploy/openbao -- bao auth list | grep -q "cert/"; then
    echo -e "${YELLOW}✓ Cert auth already enabled${NC}"
else
    echo "Enabling cert auth..."
    kubectl exec -n openbao deploy/openbao -- bao auth enable cert
    echo -e "${GREEN}✅ Cert auth enabled${NC}"
fi

#
# 2. Get SPIRE Trust Bundle
#
echo ""
echo "📋 Step 2: Extract SPIRE Trust Bundle"
kubectl get configmap -n spire-system spire-bundle -o jsonpath='{.data.bundle\.crt}' > /tmp/spire-bundle.crt
echo -e "${GREEN}✅ Trust bundle extracted${NC}"
cat /tmp/spire-bundle.crt

#
# 3. Configure Cert Auth with SPIRE CA
#
echo ""
echo "📋 Step 3: Configure Cert Auth with SPIRE CA"
kubectl exec -n openbao deploy/openbao -- sh -c "cat > /tmp/bundle.crt <<'EOF'
$(cat /tmp/spire-bundle.crt)
EOF"

# Check if backend-role exists
if kubectl exec -n openbao deploy/openbao -- bao list auth/cert/certs 2>/dev/null | grep -q "backend-role"; then
    echo -e "${YELLOW}✓ backend-role already exists${NC}"
else
    echo "Creating backend-role for cert auth..."
    kubectl exec -n openbao deploy/openbao -- bao write auth/cert/certs/backend-role \
        certificate=@/tmp/bundle.crt \
        allowed_common_names="spiffe://demo.local/ns/99-apps/sa/backend" \
        token_policies="backend-policy" \
        token_ttl=3600 \
        token_max_ttl=7200
    echo -e "${GREEN}✅ backend-role created${NC}"
fi

#
# 4. Enable KV v2 Secrets Engine
#
echo ""
echo "📋 Step 4: Enable KV v2 Secrets Engine"
if kubectl exec -n openbao deploy/openbao -- bao secrets list | grep -q "secret/"; then
    echo -e "${YELLOW}✓ KV v2 already enabled at secret/${NC}"
else
    echo "Enabling KV v2 at secret/..."
    kubectl exec -n openbao deploy/openbao -- bao secrets enable -version=2 -path=secret kv
    echo -e "${GREEN}✅ KV v2 enabled${NC}"
fi

#
# 5. Enable Database Secrets Engine
#
echo ""
echo "📋 Step 5: Enable Database Secrets Engine"
if kubectl exec -n openbao deploy/openbao -- bao secrets list | grep -q "database/"; then
    echo -e "${YELLOW}✓ Database secrets engine already enabled${NC}"
else
    echo "Enabling database secrets engine..."
    kubectl exec -n openbao deploy/openbao -- bao secrets enable database
    echo -e "${GREEN}✅ Database secrets engine enabled${NC}"
fi

#
# 6. Configure PostgreSQL Connection
#
echo ""
echo "📋 Step 6: Configure PostgreSQL Connection"
kubectl exec -n openbao deploy/openbao -- bao write database/config/postgresql \
    plugin_name=postgresql-database-plugin \
    allowed_roles="backend-role" \
    connection_url="postgresql://{{username}}:{{password}}@postgresql.99-apps.svc.cluster.local:5432/appdb?sslmode=disable" \
    username="postgres" \
    password="postgres"
echo -e "${GREEN}✅ PostgreSQL connection configured${NC}"

#
# 7. Create Database Role
#
echo ""
echo "📋 Step 7: Create Database Role for Backend"
kubectl exec -n openbao deploy/openbao -- bao write database/roles/backend-role \
    db_name=postgresql \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' INHERIT; \
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\"; \
        GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="2h"
echo -e "${GREEN}✅ Database role created${NC}"

#
# 8. Create Backend Policy
#
echo ""
echo "📋 Step 8: Create Backend Policy"
kubectl exec -n openbao deploy/openbao -- sh -c 'cat > /tmp/backend-policy.hcl <<EOF
# Backend service policy
# Allows read/write to GitHub secrets and read from database credentials

# KV v2 secrets - GitHub tokens
path "secret/data/github/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/github/*" {
  capabilities = ["list", "read"]
}

# Database dynamic credentials
path "database/creds/backend-role" {
  capabilities = ["read"]
}

# Allow token renewal
path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF'

kubectl exec -n openbao deploy/openbao -- bao policy write backend-policy /tmp/backend-policy.hcl
echo -e "${GREEN}✅ Backend policy created${NC}"

#
# 9. Test Configuration
#
echo ""
echo "📋 Step 9: Test Configuration"
echo "Testing database credential generation..."
if kubectl exec -n openbao deploy/openbao -- bao read database/creds/backend-role; then
    echo -e "${GREEN}✅ Database credential generation works!${NC}"
else
    echo -e "${YELLOW}⚠️  Database credential test failed - will retry in Phase 4${NC}"
fi

echo ""
echo -e "${GREEN}✅ OpenBao configuration complete!${NC}"
echo ""
echo "Summary:"
echo "  - Cert auth: ✅ Enabled with SPIRE trust bundle"
echo "  - KV v2:     ✅ Enabled at secret/"
echo "  - Database:  ✅ Enabled with PostgreSQL connection"
echo "  - Role:      ✅ backend-role created (1h TTL)"
echo "  - Policy:    ✅ backend-policy created"
echo ""
echo "Next: Deploy backend to test mTLS authentication!"

# Cleanup
rm -f /tmp/spire-bundle.crt
```

**Make executable:**
```bash
chmod +x scripts/helpers/configure-vault-backend.sh
```

**Success Criteria:**
- ✅ Script created and executable
- ✅ Idempotent (safe to run multiple times)
- ✅ Configures all necessary Vault components

---

#### **Task 3.2: Run Vault Configuration Script**

**Description:** Execute the Vault configuration script.

**Commands:**
```bash
./scripts/helpers/configure-vault-backend.sh
```

**Expected Output:**
```
🔐 Configuring OpenBao for Backend Service...

📋 Step 1: Enable Cert Auth Method
✅ Cert auth enabled

📋 Step 2: Extract SPIRE Trust Bundle
✅ Trust bundle extracted

...

✅ OpenBao configuration complete!
```

**Verify configuration:**
```bash
# Verify cert auth enabled
kubectl exec -n openbao deploy/openbao -- bao auth list

# Verify secrets engines
kubectl exec -n openbao deploy/openbao -- bao secrets list

# Verify backend policy
kubectl exec -n openbao deploy/openbao -- bao policy read backend-policy
```

**Success Criteria:**
- ✅ All Vault components configured
- ✅ No errors in script execution
- ✅ Can generate test database credentials

---

#### **Task 3.3: Create Vault Client Module**

**Description:** Implement Vault client with JWT authentication using SPIRE JWT-SVID.

**✅ IMPLEMENTATION NOTE:** Vault client updated to use JWT-SVID authentication. Key changes:
- `connect()` method now fetches JWT-SVID from SPIRE (instead of X.509 certificate)
- Uses `hvac` client's `auth.jwt.login()` method (instead of `auth.cert.login()`)
- Still supports TLS verification with CA certificate for HTTPS connections
- Dual-mode: JWT auth for HTTPS, token auth for HTTP dev mode

**File:** `backend/app/core/vault.py`

**Content (see actual file for complete implementation):**
```python
"""
Vault (OpenBao) client for secrets management.
Authenticates using SPIRE X.509-SVID via mTLS.
"""

import logging
import tempfile
from typing import Dict, Any, Optional
import hvac

from app.config import settings
from app.core.spire import spire_client

logger = logging.getLogger(__name__)


class VaultClient:
    """
    OpenBao client with mTLS authentication using SPIRE certificates.
    """

    def __init__(self):
        """Initialize Vault client."""
        self.vault_addr = settings.VAULT_ADDR
        self.kv_path = settings.VAULT_KV_PATH
        self.db_path = settings.VAULT_DB_PATH
        self.db_role = settings.VAULT_DB_ROLE
        self._client: Optional[hvac.Client] = None
        self._authenticated = False
        logger.info(f"Vault client initialized - Address: {self.vault_addr}")

    async def connect(self) -> None:
        """
        Connect to Vault and authenticate using SPIRE certificate.
        """
        try:
            logger.info("Connecting to Vault with SPIRE certificate...")

            # Get SPIRE certificate and key
            cert_pem = spire_client.get_certificate_pem()
            key_pem = spire_client.get_private_key_pem()

            # Write cert and key to temporary files (required by hvac)
            with tempfile.NamedTemporaryFile(mode='wb', delete=False, suffix='.pem') as cert_file:
                cert_file.write(cert_pem)
                cert_path = cert_file.name

            with tempfile.NamedTemporaryFile(mode='wb', delete=False, suffix='.pem') as key_file:
                key_file.write(key_pem)
                key_path = key_file.name

            # Create Vault client with mTLS
            self._client = hvac.Client(
                url=self.vault_addr,
                cert=(cert_path, key_path),
                verify=False  # Dev mode - in production, verify=True with CA bundle
            )

            # Authenticate using cert auth
            auth_response = self._client.auth.cert.login()

            self._authenticated = True
            logger.info(f"✅ Vault authenticated - Token TTL: {auth_response['auth']['lease_duration']}s")
            logger.info(f"Vault policies: {auth_response['auth']['policies']}")

        except Exception as e:
            logger.error(f"❌ Failed to authenticate to Vault: {e}")
            raise

    def is_authenticated(self) -> bool:
        """Check if authenticated to Vault."""
        return self._authenticated and self._client is not None and self._client.is_authenticated()

    async def write_secret(self, path: str, data: Dict[str, Any]) -> None:
        """
        Write secret to KV v2 store.

        Args:
            path: Secret path (e.g., "github/api-token")
            data: Secret data (dict)
        """
        if not self.is_authenticated():
            raise RuntimeError("Not authenticated to Vault")

        full_path = f"{self.kv_path}/data/{path}"

        try:
            self._client.secrets.kv.v2.create_or_update_secret(
                path=path,
                secret=data,
                mount_point=self.kv_path
            )
            logger.info(f"✅ Secret written to Vault: {full_path}")
        except Exception as e:
            logger.error(f"❌ Failed to write secret to {full_path}: {e}")
            raise

    async def read_secret(self, path: str) -> Dict[str, Any]:
        """
        Read secret from KV v2 store.

        Args:
            path: Secret path (e.g., "github/api-token")

        Returns:
            Secret data (dict)
        """
        if not self.is_authenticated():
            raise RuntimeError("Not authenticated to Vault")

        full_path = f"{self.kv_path}/data/{path}"

        try:
            response = self._client.secrets.kv.v2.read_secret_version(
                path=path,
                mount_point=self.kv_path
            )
            logger.debug(f"✅ Secret read from Vault: {full_path}")
            return response['data']['data']
        except Exception as e:
            logger.error(f"❌ Failed to read secret from {full_path}: {e}")
            raise

    async def get_database_credentials(self) -> Dict[str, str]:
        """
        Get dynamic database credentials from Vault.

        Returns:
            Dict with 'username', 'password', and 'lease_id'
        """
        if not self.is_authenticated():
            raise RuntimeError("Not authenticated to Vault")

        try:
            response = self._client.read(f"{self.db_path}/creds/{self.db_role}")

            username = response['data']['username']
            password = response['data']['password']
            lease_id = response['lease_id']
            lease_duration = response['lease_duration']

            logger.info(f"✅ Database credentials obtained - User: {username}, TTL: {lease_duration}s")

            return {
                'username': username,
                'password': password,
                'lease_id': lease_id,
                'lease_duration': lease_duration
            }
        except Exception as e:
            logger.error(f"❌ Failed to get database credentials: {e}")
            raise

    async def revoke_lease(self, lease_id: str) -> None:
        """
        Revoke a Vault lease (e.g., database credentials).

        Args:
            lease_id: Lease ID to revoke
        """
        if not self.is_authenticated():
            raise RuntimeError("Not authenticated to Vault")

        try:
            self._client.sys.revoke_lease(lease_id)
            logger.info(f"✅ Lease revoked: {lease_id}")
        except Exception as e:
            logger.error(f"❌ Failed to revoke lease {lease_id}: {e}")
            # Don't raise - lease will expire anyway


# Global Vault client instance
vault_client = VaultClient()
```

**Success Criteria:**
- ✅ Vault client module created
- ✅ mTLS authentication with SPIRE cert
- ✅ KV v2 read/write methods
- ✅ Database credential methods

---

#### **Task 3.4: Update Application Startup**

**Description:** Initialize Vault client on application startup.

**File:** `backend/app/main.py` (update)

**Content:**
```python
# Add import
from app.core.vault import vault_client

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager."""
    # Startup
    logger.info(f"Starting {settings.APP_NAME} v{settings.APP_VERSION}")

    # Initialize SPIRE client
    try:
        await spire_client.connect()
        logger.info(f"✅ SPIRE initialized - ID: {spire_client.get_spiffe_id()}")
    except Exception as e:
        logger.error(f"❌ SPIRE initialization failed: {e}")
        raise

    # Initialize Vault client
    try:
        await vault_client.connect()
        logger.info("✅ Vault initialized")
    except Exception as e:
        logger.error(f"❌ Vault initialization failed: {e}")
        raise

    # TODO: Initialize database pool (Phase 4)
    # TODO: Start credential rotation task (Phase 4)

    yield

    # Shutdown
    logger.info("Shutting down application...")
    await spire_client.close()
    # TODO: Close database pool (Phase 4)
    # TODO: Revoke Vault lease (Phase 4)
    logger.info("Shutdown complete")
```

**Success Criteria:**
- ✅ Vault client initialized on startup
- ✅ Authentication successful
- ✅ Logs show connection status

---

#### **Task 3.5: Update Health Endpoint**

**Description:** Add Vault status to health checks.

**File:** `backend/app/api/v1/health.py` (update)

**Content:**
```python
# Add import
from app.core.vault import vault_client

@router.get("/health/ready")
async def readiness_check():
    """Readiness check endpoint."""
    from app.config import settings

    # Check SPIRE connection
    spire_status = "ready" if spire_client.is_connected() else "not_ready"

    # Check Vault authentication
    vault_status = "ready" if vault_client.is_authenticated() else "not_ready"

    # TODO: Check database connection (Phase 4)

    return HealthResponse(
        status="ready" if (spire_status == "ready" and vault_status == "ready") else "not_ready",
        version=settings.APP_VERSION,
        spire=spire_status,
        vault=vault_status,
    )
```

**Success Criteria:**
- ✅ Health endpoint shows Vault status
- ✅ Returns "ready" when Vault authenticated

---

### 📋 EXECUTION LOG - Phase 3

**Date:** [To be filled during implementation]
**Status:** ⏳ PENDING

**Summary:** [To be filled after implementation]

**Next Phase:** Phase 4 - Database Connection Management

---

## 🗄️ Phase 4: Database Connection Management

**Objective:** Implement database connection pool with dynamic Vault credentials and automatic rotation.


**Note:** Phase 4 contains detailed implementation tasks. Due to document length, Phases 5-9 are provided in summary format below. Detailed task-by-task instructions can be expanded during implementation if needed.

### **Tasks:** (Summary - expand during implementation)

**Task 4.1:** Create Database Module with Connection Pool
- Implement `DatabaseManager` class with SQLAlchemy async engine
- Dynamic credential fetching from Vault
- Connection pool (size: 10, max_overflow: 10)
- Credential rotation background task (every 3000 seconds / 50 minutes)
- Graceful pool migration on rotation

**Task 4.2:** Create SQLAlchemy Models
- `User` model (id, username, email, password_hash, timestamps)
- `GitHubIntegration` model (user_id, is_configured, timestamps)
- `AuditLog` model (user_id, action, resource, timestamp, details JSONB)

**Task 4.3:** Create Pydantic Schemas
- Request/response schemas for all API endpoints
- Validation rules (min/max lengths, email format, etc.)

**Task 4.4:** Update Application Startup
- Initialize `db_manager` in lifespan function
- Start credential rotation task
- Add graceful shutdown

**Task 4.5:** Update Health Endpoint  
- Add database status check
- Return "ready" only when DB pool initialized

**Task 4.6:** Test Database Integration
- Verify connection pool creation
- Test credential rotation (manual trigger or wait)
- Verify old credentials revoked

---

### 📋 EXECUTION LOG - Phase 4

**Date:** [To be filled during implementation]
**Status:** ⏳ PENDING

**Next Phase:** Phase 5 - User Authentication System

---

## 🔐 Phase 5: User Authentication System

**Objective:** Implement JWT-based authentication with bcrypt password hashing.

### **Tasks:** (Summary)

**Task 5.1:** Create Authentication Utility Module (`app/core/auth.py`)
- Password hashing with bcrypt (cost: 12)
- Password verification
- JWT token generation (HS256, 1-hour expiry)
- JWT token validation
- Extract user data from token

**Task 5.2:** Create Authentication Middleware (`app/middleware/auth.py`)
- JWT validation dependency for FastAPI
- Extract `Authorization: Bearer <token>` header
- Validate token and extract user_id/username
- Raise 401 if invalid/missing token

**Task 5.3:** Implement User Registration Endpoint
- `POST /api/v1/auth/register`
- Validate username/email/password (Pydantic)
- Check if username already exists
- Hash password with bcrypt
- Insert user into database
- Return success response (no token - must login)

**Task 5.4:** Implement User Login Endpoint
- `POST /api/v1/auth/login`
- Fetch user by username
- Verify password with bcrypt
- Generate JWT token
- Return token response

**Task 5.5:** Create Protected Route Example
- `GET /api/v1/auth/me` - Get current user info
- Requires JWT token
- Returns user data from database

**Task 5.6:** Add Auth Router to Main App
- Create `app/api/v1/auth.py` router
- Include in main.py

**Task 5.7:** Test Authentication Flow
- Register new user
- Login with correct password
- Login with wrong password (should fail)
- Access protected route with token
- Access protected route without token (should fail)

---

### 📋 EXECUTION LOG - Phase 5

**Date:** [To be filled during implementation]
**Status:** ⏳ PENDING

**Next Phase:** Phase 6 - GitHub Integration

---

## 🐙 Phase 6: GitHub Integration

**Objective:** Implement GitHub token storage in Vault and GitHub API integration.

### **Tasks:** (Summary)

**Task 6.1:** Create GitHub API Client Module (`app/core/github.py`)
- Initialize with base URL (https://api.github.com)
- Method: `fetch_repositories(token)` - GET /user/repos
- Method: `fetch_user_profile(token)` - GET /user
- Proper error handling for GitHub API errors

**Task 6.2:** Implement GitHub Token Storage Endpoint
- `POST /api/v1/github/configure`
- Protected route (requires JWT)
- Extract user_id from token
- Store GitHub PAT in Vault at `secret/data/github/user-{user_id}/token`
- Update `github_integrations` table (is_configured=true, configured_at=now)
- Return success response

**Task 6.3:** Implement Repository Listing Endpoint
- `GET /api/v1/github/repos`
- Protected route
- Retrieve GitHub token from Vault for current user
- Call GitHub API `/user/repos`
- Update last_accessed timestamp
- Return list of repositories

**Task 6.4:** Implement User Profile Endpoint
- `GET /api/v1/github/user`
- Protected route
- Retrieve token from Vault
- Call GitHub API `/user`
- Return GitHub user profile

**Task 6.5:** Add GitHub Router to Main App
- Create `app/api/v1/github.py` router
- Include in main.py

**Task 6.6:** Test GitHub Integration
- Configure token (use your real PAT)
- Fetch repositories
- Fetch user profile
- Verify token stored in Vault KV v2
- Verify database tracking works

---

### 📋 EXECUTION LOG - Phase 6

**Date:** [To be filled during implementation]
**Status:** ⏳ PENDING

**Next Phase:** Phase 7 - API Endpoints & Documentation

---

## 📡 Phase 7: API Endpoints & Documentation

**Objective:** Finalize all API endpoints and ensure proper documentation.

### **Tasks:** (Summary)

**Task 7.1:** Review All Endpoints
- Ensure consistent `/api/v1/` prefix
- Proper HTTP methods (GET/POST/PUT/DELETE)
- Proper status codes (200, 201, 400, 401, 404, 500)

**Task 7.2:** Configure OpenAPI Documentation
- Update FastAPI app metadata (title, version, description)
- Add endpoint descriptions and summaries
- Add response examples
- Verify Swagger UI at `/docs`

**Task 7.3:** Add Request/Response Examples
- Use Pydantic `Config.json_schema_extra` for examples
- Document all error responses

**Task 7.4:** Verify CORS Configuration
- Ensure frontend origins allowed
- Test preflight requests

**Task 7.5:** Add API Versioning Header (Optional)
- Add custom header `X-API-Version: 1.0`

**Task 7.6:** Test All Endpoints
- Use Swagger UI to test each endpoint
- Verify validation errors return 422
- Verify auth errors return 401
- Verify not found returns 404

---

### 📋 EXECUTION LOG - Phase 7

**Date:** [To be filled during implementation]
**Status:** ⏳ PENDING

**Next Phase:** Phase 8 - Containerization & Kubernetes Deployment

---

## 🐳 Phase 8: Containerization & Kubernetes Deployment

**Objective:** Deploy backend to kind cluster with Tilt hot-reload workflow.

### **Tasks:** (Summary)

**Task 8.1:** Create Kubernetes ServiceAccount
**File:** `backend/k8s/serviceaccount.yaml`
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend
  namespace: 99-apps
```

**Task 8.2:** Create Kubernetes Deployment
**File:** `backend/k8s/deployment.yaml`
- Image: `backend:dev` (Tilt will build)
- ServiceAccount: `backend`
- Volume mount: SPIRE socket at `/run/spire/sockets`
- Environment variables from ConfigMap
- Health/readiness probes
- Resource limits (requests/limits)

**Task 8.3:** Create Kubernetes Service
**File:** `backend/k8s/service.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: 99-apps
spec:
  type: NodePort
  ports:
    - port: 8000
      targetPort: 8000
      nodePort: 30001
  selector:
    app: backend
```

**Task 8.4:** Update Tiltfile
- Add K8s YAML files
- Configure live_update for Python files
- Add port forwards (8000:8000)

**Task 8.5:** Deploy with Tilt
```bash
tilt up
```
- Verify pod starts
- Verify SPIRE SVID acquired
- Verify Vault authentication
- Verify database connection

**Task 8.6:** Test Hot-Reload
- Edit Python file
- Save
- Verify Tilt syncs (~2 seconds)
- Verify uvicorn restarts
- Test API endpoint shows changes

---

### 📋 EXECUTION LOG - Phase 8

**Date:** [To be filled during implementation]
**Status:** ⏳ PENDING

**Next Phase:** Phase 9 - Integration Testing & Verification

---

## ✅ Phase 9: Integration Testing & Verification

**Objective:** Comprehensive end-to-end testing of all integrations.

### **Tasks:** (Summary)

**Task 9.1:** Test SPIRE Integration
- Verify backend gets SPIFFE ID
- Verify certificate details
- Check logs for SPIRE connection

**Task 9.2:** Test Vault Integration
- Verify mTLS authentication
- Test KV v2 secret storage/retrieval
- Test dynamic DB credential generation

**Task 9.3:** Test Database Integration
- Verify connection pool created
- Test queries work
- Manually trigger credential rotation or wait 50 minutes
- Verify old credentials revoked
- Verify new pool working

**Task 9.4:** Test User Authentication
- Register 3 test users
- Login with each
- Test JWT validation
- Test protected routes

**Task 9.5:** Test GitHub Integration
- Configure GitHub token
- Fetch repositories (verify real GitHub API call)
- Fetch user profile
- Verify Vault storage

**Task 9.6:** Test Complete User Flow
1. Register user
2. Login (get JWT)
3. Configure GitHub token
4. Fetch repos
5. Fetch profile
6. Logout (optional - just discard token)

**Task 9.7:** Create Verification Script
**File:** `scripts/helpers/verify-backend.sh`
```bash
#!/bin/bash
# Verify backend deployment and integration

echo "🔍 Verifying Backend Integration..."

# Check pod status
kubectl get pods -n 99-apps -l app=backend

# Check health endpoints
curl -s http://localhost:8000/api/v1/health
curl -s http://localhost:8000/api/v1/health/ready

# Check SPIRE logs
kubectl logs -n 99-apps -l app=backend --tail=50 | grep SPIRE

# Check Vault logs  
kubectl logs -n 99-apps -l app=backend --tail=50 | grep Vault

# Check database logs
kubectl logs -n 99-apps -l app=backend --tail=50 | grep Database

# Test registration
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"test123"}'

# Test login
TOKEN=$(curl -s -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"jake","password":"jake99"}' \
  | jq -r '.access_token')

# Test protected route
curl -s -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/api/v1/auth/me

echo "✅ Backend verification complete!"
```

**Task 9.8:** Load Testing (Optional)
```bash
# Simple load test with curl
for i in {1..100}; do
  curl -s http://localhost:8000/api/v1/health > /dev/null &
done
wait
```

**Task 9.9:** Review Logs
- Check for any errors or warnings
- Verify credential rotation logs
- Check Tilt UI for any issues

**Task 9.10:** Document Known Issues
- Add to TROUBLESHOOTING.md if needed

---

### 📋 EXECUTION LOG - Phase 9

**Date:** [To be filled during implementation]
**Status:** ⏳ PENDING

**Completion:** All phases complete, ready for Sub-Sprint 3!

---

## 🎯 Sub-Sprint 2 Success Criteria

The backend is complete when:

- ✅ **Infrastructure Integration:**
  - Backend pod running in `99-apps` namespace
  - SPIRE SVID acquired successfully
  - Vault authenticated via mTLS
  - Dynamic database credentials working
  - Credential rotation verified (manual or automatic)

- ✅ **Application Features:**
  - User registration working
  - User login returning JWT tokens
  - Protected routes validating JWTs
  - GitHub token storage in Vault working
  - GitHub API integration functional (repos + profile)

- ✅ **Development Workflow:**
  - Tilt hot-reload working (~2 second file sync)
  - Can edit code locally and see changes in cluster
  - Logs visible in Tilt UI
  - No errors in startup logs

- ✅ **API Endpoints:**
  - `/api/v1/health` - liveness
  - `/api/v1/health/ready` - readiness
  - `/api/v1/auth/register` - user registration
  - `/api/v1/auth/login` - user login
  - `/api/v1/auth/me` - get current user
  - `/api/v1/github/configure` - store GitHub token
  - `/api/v1/github/repos` - list repositories
  - `/api/v1/github/user` - get GitHub profile

- ✅ **Testing:**
  - Integration tests passing
  - Verification script passes
  - Demo users can login (jake, amy, rosa, etc.)
  - Complete user flow tested

- ✅ **Documentation:**
  - All code documented with docstrings
  - OpenAPI/Swagger UI functional
  - README includes setup instructions

---

## 📝 Implementation Notes

### **Tilt Development Workflow**

```bash
# Initial setup
cd /home/mandrix-murdock/code/spire-spife/test-vault

# Ensure Vault is configured
./scripts/helpers/configure-vault-backend.sh

# Start Tilt
tilt up

# Tilt will:
# 1. Build backend:dev image (Dockerfile.dev)
# 2. Load image into kind cluster
# 3. Deploy Kubernetes manifests
# 4. Watch for file changes
# 5. Sync .py files on save (~2s)
# 6. uvicorn --reload auto-restarts

# View Tilt UI
open http://localhost:10350

# Edit code (example)
vim backend/app/api/v1/auth.py
# Save file → Tilt syncs → Backend restarts → Test

# Test API
curl http://localhost:8000/api/v1/health

# View logs
# Option 1: Tilt UI (http://localhost:10350)
# Option 2: kubectl
kubectl logs -f -n 99-apps deploy/backend

# Stop Tilt
# Press Ctrl+C or:
tilt down
```

### **Common Commands**

```bash
# Check backend pod
kubectl get pods -n 99-apps -l app=backend

# Get pod logs
kubectl logs -n 99-apps -l app=backend --tail=100 -f

# Exec into pod
kubectl exec -it -n 99-apps deploy/backend -- bash

# Inside pod:
# - Run tests: pytest tests/
# - Check SPIRE: ls -la /run/spire/sockets/
# - Test Vault: curl http://openbao.openbao:8200/v1/sys/health

# Port-forward (if not using Tilt)
kubectl port-forward -n 99-apps svc/backend 8000:8000

# Manual image rebuild (if needed)
docker build -t backend:dev -f backend/Dockerfile.dev backend/
kind load docker-image backend:dev --name precinct-99
kubectl rollout restart deployment/backend -n 99-apps
```

### **Troubleshooting**

**Issue:** Backend pod CrashLoopBackOff
```bash
# Check logs
kubectl logs -n 99-apps -l app=backend --previous

# Common causes:
# 1. SPIRE socket not mounted - check deployment YAML
# 2. Vault not configured - run configure-vault-backend.sh
# 3. Database not ready - check PostgreSQL pod
# 4. Python syntax error - check logs
```

**Issue:** SPIRE SVID acquisition fails
```bash
# Check SPIRE registration entry exists
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry show \
    -spiffeID spiffe://demo.local/ns/99-apps/sa/backend

# If not exists, create it (should be done in Phase 2):
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry create \
    -spiffeID spiffe://demo.local/ns/99-apps/sa/backend \
    -parentID spiffe://demo.local/spire/agent/k8s_psat/precinct-99 \
    -selector k8s:ns:99-apps \
    -selector k8s:sa:backend \
    -ttl 3600
```

**Issue:** Vault authentication fails
```bash
# Check Vault configuration
kubectl exec -n openbao deploy/openbao -- bao auth list
kubectl exec -n openbao deploy/openbao -- bao policy read backend-policy

# Re-run configuration script
./scripts/helpers/configure-vault-backend.sh
```

**Issue:** Database connection fails
```bash
# Check PostgreSQL is running
kubectl get pods -n 99-apps -l app=postgresql

# Check Vault can generate credentials
kubectl exec -n openbao deploy/openbao -- \
  bao read database/creds/backend-role

# Check PostgreSQL users
kubectl exec -it -n 99-apps postgresql-0 -- \
  psql -U postgres -d appdb -c "SELECT usename FROM pg_user WHERE usename LIKE 'v-token%';"
```

**Issue:** Tilt file sync not working
```bash
# Restart Tilt
tilt down
tilt up

# Check Tilt logs for sync errors
# Check Docker Desktop is running
# Check kind cluster is accessible: kubectl cluster-info
```

---

## 🔗 References

- **FastAPI Documentation:** https://fastapi.tiangolo.com/
- **py-spiffe Library:** https://github.com/spiffe/py-spiffe
- **hvac (Vault Client):** https://hvac.readthedocs.io/
- **SQLAlchemy Async:** https://docs.sqlalchemy.org/en/20/orm/extensions/asyncio.html
- **Tilt Documentation:** https://docs.tilt.dev/
- **Tilt Live Update:** https://docs.tilt.dev/tutorial/5-live-update.html
- **Pydantic:** https://docs.pydantic.dev/
- **asyncpg:** https://magicstack.github.io/asyncpg/
- **python-jose:** https://python-jose.readthedocs.io/
- **passlib:** https://passlib.readthedocs.io/

---

## 📞 Next Steps

After completing Sub-Sprint 2:

1. **Commit all code** to git
2. **Test end-to-end** user flow
3. **Document any issues** encountered
4. **Proceed to Sub-Sprint 3:** Frontend Application Development
5. **Reference:** The frontend will consume these backend APIs

---

**Document Version:** 1.0
**Last Updated:** 2025-12-29
**Status:** ✅ COMPLETE - Ready for Implementation
**Prerequisite:** Sub-Sprint 1 (Infrastructure Foundation)
**Next:** Sub-Sprint 3 - Frontend Development

---

**End of Sub-Sprint 2: Backend Application Development**
