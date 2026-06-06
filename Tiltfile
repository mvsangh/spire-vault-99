# Tiltfile for SPIRE-Vault-99 Development
# Enables hot-reload development with real SPIRE, Vault, and PostgreSQL

# Build Docker image with live update
docker_build(
    'backend:dev',
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

# --- Backend ---
k8s_yaml('backend/k8s/serviceaccount.yaml')
k8s_yaml('backend/k8s/configmap.yaml')
k8s_yaml('backend/k8s/deployment.yaml')
k8s_yaml('backend/k8s/service.yaml')

k8s_resource(
    'backend',
    port_forwards=['8000:8000'],
    labels=['app'],
)

# --- Frontend ---
docker_build(
    'frontend:dev',
    context='./frontend',
    dockerfile='./frontend/Dockerfile',
)

k8s_yaml('frontend/k8s/serviceaccount.yaml')
k8s_yaml('frontend/k8s/configmap.yaml')
k8s_yaml('frontend/k8s/deployment.yaml')
k8s_yaml('frontend/k8s/service.yaml')

k8s_resource(
    'frontend',
    port_forwards=['3000:3000'],
    labels=['app'],
)

# Display startup message
print("""
SPIRE-Vault-99 Development Environment

  Backend API:   http://localhost:8000
  Backend docs:  http://localhost:8000/docs
  Frontend:      http://localhost:3000

  curl http://localhost:8000/api/v1/health
""")
