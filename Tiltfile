# Tiltfile for SPIRE-Vault-99 Backend Development
# Enables hot-reload development with real SPIRE, Vault, and PostgreSQL

# Note: K8s manifests will be added in Phase 8
# For now, this Tiltfile is prepared but won't be used until deployment

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

# Kubernetes manifests will be loaded in Phase 8:
# k8s_yaml('backend/k8s/serviceaccount.yaml')
# k8s_yaml('backend/k8s/deployment.yaml')
# k8s_yaml('backend/k8s/service.yaml')

# Configure backend resource (will be uncommented in Phase 8)
# k8s_resource(
#     'backend',
#     port_forwards=[
#         '8000:8000',  # API
#     ],
#     labels=['app'],
# )

# Display startup message
print("""
🚀 SPIRE-Vault-99 Backend Development

Tiltfile configured!

Note: This Tiltfile is ready but cannot be used until Phase 8
when Kubernetes manifests are created.

For now, test locally:
  cd backend
  pip install -r requirements-dev.txt
  uvicorn app.main:app --reload

Then test:
  curl http://localhost:8000/api/v1/health

You'll be able to use 'tilt up' starting in Phase 8!
""")
