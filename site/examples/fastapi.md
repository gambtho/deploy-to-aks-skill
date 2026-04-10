# FastAPI Example

**Scenario:** Python FastAPI application with Redis cache, deployed to AKS Standard.

**Generated for:** `sample-fastapi-app` (fictional project)

---

## Dockerfile

Multi-stage build with Poetry, non-root user, Python 3.12:

```dockerfile
# Build stage
FROM python:3.12-slim AS build
WORKDIR /app
RUN pip install poetry
COPY pyproject.toml poetry.lock ./
RUN poetry export -f requirements.txt --output requirements.txt --without-hashes

# Runtime stage
FROM python:3.12-slim
RUN addgroup --system app && adduser --system --group app
USER app:app
WORKDIR /app
COPY --from=build /app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY --chown=app:app . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Key features:**
- Multi-stage build (Poetry only in build stage)
- Non-root user for security
- Requirements.txt for faster rebuilds
- Slim Python image for smaller footprint

---

## Kubernetes Manifests

### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-fastapi-app
  namespace: sample-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: sample-fastapi-app
  template:
    metadata:
      labels:
        app: sample-fastapi-app
    spec:
      serviceAccountName: sample-fastapi-app
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: app
        image: <acr-name>.azurecr.io/sample-fastapi-app:latest
        ports:
        - containerPort: 8000
        env:
        - name: REDIS_HOST
          value: sample-app-redis.redis.cache.windows.net
        - name: REDIS_PORT
          value: "6380"
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-credentials
              key: password
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: tmp
        emptyDir: {}
```

### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: sample-fastapi-app
  namespace: sample-app
spec:
  type: ClusterIP
  selector:
    app: sample-fastapi-app
  ports:
  - port: 80
    targetPort: 8000
    protocol: TCP
```

### Ingress (AKS Standard)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sample-fastapi-app
  namespace: sample-app
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: sample-fastapi-app
            port:
              number: 80
```

---

## Bicep Infrastructure

### Main Module

```bicep
targetScope = 'resourceGroup'

param location string = resourceGroup().location
param appName string = 'sample-fastapi-app'
param environment string = 'dev'

module aks 'aks.bicep' = {
  name: 'aks-deployment'
  params: {
    location: location
    clusterName: '${appName}-${environment}-aks'
    nodeCount: 3
    sku: 'Standard'
  }
}

module acr 'acr.bicep' = {
  name: 'acr-deployment'
  params: {
    location: location
    registryName: replace('${appName}${environment}acr', '-', '')
  }
}

module redis 'redis.bicep' = {
  name: 'redis-deployment'
  params: {
    location: location
    redisCacheName: '${appName}-${environment}-redis'
    sku: 'Basic'
    family: 'C'
    capacity: 0
  }
}

module identity 'identity.bicep' = {
  name: 'identity-deployment'
  params: {
    location: location
    identityName: '${appName}-${environment}-identity'
    aksOidcIssuer: aks.outputs.oidcIssuer
    namespace: 'sample-app'
    serviceAccountName: appName
  }
}

output aksClusterName string = aks.outputs.clusterName
output acrLoginServer string = acr.outputs.loginServer
output redisCacheName string = redis.outputs.cacheName
```

---

## GitHub Actions Workflow

```yaml
name: Deploy to AKS

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  ACR_NAME: samplefastapiappdevacr
  IMAGE_NAME: sample-fastapi-app
  AKS_CLUSTER: sample-fastapi-app-dev-aks
  AKS_RESOURCE_GROUP: sample-app-rg
  NAMESPACE: sample-app

permissions:
  id-token: write
  contents: read

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Set up Python 3.12
      uses: actions/setup-python@v5
      with:
        python-version: '3.12'
        cache: 'pip'
    
    - name: Install dependencies
      run: |
        pip install poetry
        poetry export -f requirements.txt --output requirements.txt --without-hashes
    
    - name: Azure Login (OIDC)
      uses: azure/login@v2
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    
    - name: Build and push Docker image
      run: |
        az acr build --registry ${{ env.ACR_NAME }} \
          --image ${{ env.IMAGE_NAME }}:${{ github.sha }} \
          --image ${{ env.IMAGE_NAME }}:latest \
          --file Dockerfile .
    
    - name: Get AKS credentials
      run: |
        az aks get-credentials \
          --resource-group ${{ env.AKS_RESOURCE_GROUP }} \
          --name ${{ env.AKS_CLUSTER }}
    
    - name: Deploy to AKS
      run: |
        kubectl set image deployment/${{ env.IMAGE_NAME }} \
          app=${{ env.ACR_NAME }}.azurecr.io/${{ env.IMAGE_NAME }}:${{ github.sha }} \
          -n ${{ env.NAMESPACE }}
        kubectl rollout status deployment/${{ env.IMAGE_NAME }} -n ${{ env.NAMESPACE }}
```

**Key features:**
- OIDC authentication (no stored secrets)
- Poetry dependency export for Docker build
- Python 3.12 with pip caching
- ACR build (no local Docker daemon needed)
- Automatic rollout verification

---

## Safeguards Compliance

All manifests pass AKS Deployment Safeguards:

- ✅ **DS001** - Container image provenance (ACR registry)
- ✅ **DS002** - Resource requests defined (100m CPU, 256Mi memory)
- ✅ **DS003** - Resource limits defined (500m CPU, 512Mi memory)
- ✅ **DS004** - Liveness probe configured
- ✅ **DS005** - Readiness probe configured
- ✅ **DS006** - Security context set (runAsNonRoot, seccomp)
- ✅ **DS012** - Non-root user (UID 1000)
- ✅ **DS013** - Capabilities dropped (ALL)

**Additional FastAPI-specific highlights:**
- Read-only root filesystem (`readOnlyRootFilesystem: true`) with writable `/tmp` volume
- Health endpoint at `/health` for both liveness and readiness probes
- Redis connection via Azure Cache for Redis with TLS (port 6380)

[Learn more about Deployment Safeguards](https://learn.microsoft.com/en-us/azure/aks/deployment-safeguards)

---

## Next Steps

- [View all examples](/examples/)
- [Deploy your own app](/guide/phases)
