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

[Similar Bicep and GitHub Actions content as Spring Boot example, adapted for FastAPI/Python]

---

## Next Steps

- [View all examples](/examples/)
- [Read framework guides](/guide/frameworks)
- [Deploy your own app](/guide/phases)
