# SPIRE-Vault-99 Documentation

Complete documentation for the SPIRE-Vault-99 zero-trust security platform demonstration project.

---

## 🚀 Quick Start

New to the project? Start here:

- **[Deployment Guide](quickstart/deployment.md)** - Quick deployment instructions

---

## 📋 Sprint 1: SPIRE-Vault Integration

Complete project development organized into sub-sprints:

### Overview
- **[Architecture & Master Plan](sprint-1-spire-vault-integration/overview.md)** - Overall project architecture and sprint breakdown

### Sub-Sprint 1.1: Infrastructure Foundation
- [Planning](sprint-1-spire-vault-integration/1.1-infrastructure/planning.md) - Infrastructure design and requirements
- Execution - (Documented in planning.md)

### Sub-Sprint 1.2: Backend Development
- [Planning](sprint-1-spire-vault-integration/1.2-backend/planning.md) - Backend architecture and requirements
- [Execution](sprint-1-spire-vault-integration/1.2-backend/execution.md) - Implementation log and lessons learned

### Sub-Sprint 1.3: Frontend Development
- [Planning](sprint-1-spire-vault-integration/1.3-frontend/planning.md) - Frontend architecture and requirements
- [Execution](sprint-1-spire-vault-integration/1.3-frontend/execution.md) - Implementation log and lessons learned

### Sub-Sprint 1.4: Integration & Security
- [Planning](sprint-1-spire-vault-integration/1.4-integration/planning.md) - Integration architecture and security requirements
- [Execution](sprint-1-spire-vault-integration/1.4-integration/execution.md) - Implementation log and lessons learned

---

## 🔧 Setup Guides

Detailed setup instructions for each component:

- **[Cilium + SPIRE Integration](setup-guides/cilium-spire-integration.md)** - Understanding the integration
- **[Cilium + SPIRE Setup](setup-guides/cilium-spire-setup.md)** - Step-by-step setup and automation
- **[OpenBao TLS Setup](setup-guides/openbao-tls-setup.md)** - Production TLS configuration
- **[OpenBao Manual Commands](setup-guides/openbao-manual-commands.md)** - Command reference

---

## 🐛 Troubleshooting

Common issues and solutions:

- **[OpenBao JWT Authentication](troubleshooting/openbao-jwt-auth.md)** - JWT auth issues and fixes
- **[JWT-SVID Refresh Issues](troubleshooting/jwt-svid-refresh.md)** - SPIRE JWT-SVID refresh problems
- **[Session Implementation](troubleshooting/session-implementation.md)** - Session handling issues

---

## 📚 Additional Resources

### Key Technologies
- [SPIRE Documentation](https://spiffe.io/docs/latest/spire/)
- [OpenBao Documentation](https://openbao.org/docs/)
- [Cilium Documentation](https://docs.cilium.io/)

### Project Structure
```
docs/
├── README.md                              # This file
├── quickstart/
│   └── deployment.md
├── sprint-1-spire-vault-integration/
│   ├── overview.md
│   ├── 1.1-infrastructure/
│   ├── 1.2-backend/
│   ├── 1.3-frontend/
│   └── 1.4-integration/
├── setup-guides/
│   ├── cilium-spire-integration.md
│   ├── cilium-spire-setup.md
│   ├── openbao-tls-setup.md
│   └── openbao-manual-commands.md
└── troubleshooting/
    ├── openbao-jwt-auth.md
    ├── jwt-svid-refresh.md
    └── session-implementation.md
```

---

## 🎯 Project Goals

This project demonstrates a production-grade zero-trust security platform featuring:

- ✅ **Workload Identity** - SPIRE/SPIFFE X.509-SVID with 1-hour TTL
- ✅ **Secrets Management** - OpenBao with static + dynamic secrets
- ✅ **Service Mesh** - Cilium with SPIFFE-based network policies
- ✅ **Dynamic Database Credentials** - PostgreSQL credential rotation
- ✅ **Full-Stack Application** - Next.js frontend + FastAPI backend
- ✅ **Zero-Trust Network** - Namespace-based isolation with Cilium policies

**Trust Domain:** `spiffe://demo.local`

---

## 📝 Documentation Standards

All documentation follows these principles:
- **Planning docs** - Architecture, requirements, design decisions
- **Execution docs** - Implementation logs, issues encountered, solutions
- **Setup guides** - Step-by-step instructions with commands
- **Troubleshooting** - Problem-solution format with verification steps

---

**Last Updated:** 2026-01-02
**Project Status:** Sprint 1.4 Complete (100%)
**Documentation Version:** 2.0 (Reorganized)
