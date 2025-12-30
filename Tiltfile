# Tiltfile for SPIRE-Vault-99 Backend Development
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

# Load Kubernetes manifests
k8s_yaml('backend/k8s/serviceaccount.yaml')
k8s_yaml('backend/k8s/configmap.yaml')
k8s_yaml('backend/k8s/deployment.yaml')
k8s_yaml('backend/k8s/service.yaml')

# Configure backend resource
k8s_resource(
    'backend',
    port_forwards=[
        '8000:8000',  # API
    ],
    labels=['app'],
)

# Display startup message
print("""
🚀 SPIRE-Vault-99 Backend Development

Tiltfile ready for hot-reload development!

Usage:
  tilt up              # Start development environment
  tilt down            # Stop and clean up

The backend will be available at:
  http://localhost:8000           # API root
  http://localhost:8000/docs      # Swagger UI
  http://localhost:8000/redoc     # ReDoc

Test endpoints:
  curl http://localhost:8000/api/v1/health
  curl http://localhost:8000/api/v1/health/ready

Hot-reload enabled:
  - Edit Python files in backend/app/
  - Changes sync automatically (~2 seconds)
  - uvicorn restarts automatically

Note: Ensure cluster is running with SPIRE, Vault, and PostgreSQL deployed!
""")
