"""
SQLAlchemy models for SPIRE-Vault-99 Backend.
"""

from datetime import datetime
from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship

from app.core.database import Base


class User(Base):
    """
    User model for authentication.
    """
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, nullable=False, index=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # Relationships
    github_integration = relationship("GitHubIntegration", back_populates="user", uselist=False)
    audit_logs = relationship("AuditLog", back_populates="user")

    def __repr__(self):
        return f"<User(id={self.id}, username='{self.username}', email='{self.email}')>"


class GitHubIntegration(Base):
    """
    GitHub integration tracking model.
    Stores configuration status but NOT the actual token (token stored in Vault).
    """
    __tablename__ = "github_integrations"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False, index=True)
    is_configured = Column(Boolean, default=False, nullable=False)
    configured_at = Column(DateTime, nullable=True)
    last_accessed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # Relationships
    user = relationship("User", back_populates="github_integration")

    def __repr__(self):
        return f"<GitHubIntegration(id={self.id}, user_id={self.user_id}, is_configured={self.is_configured})>"


class AuditLog(Base):
    """
    Audit log model for tracking user actions.
    """
    __tablename__ = "audit_log"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    action = Column(String(100), nullable=False, index=True)  # e.g., "login", "configure_github", "fetch_repos"
    resource = Column(String(255), nullable=True)  # e.g., "user:123", "github:repos"
    timestamp = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    details = Column(JSONB, nullable=True)  # Additional context as JSON

    # Relationships
    user = relationship("User", back_populates="audit_logs")

    def __repr__(self):
        return f"<AuditLog(id={self.id}, user_id={self.user_id}, action='{self.action}', timestamp={self.timestamp})>"
