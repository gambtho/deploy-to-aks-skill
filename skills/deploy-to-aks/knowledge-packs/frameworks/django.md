# Django Knowledge Pack

> **Applies to:** Projects detected with `requirements.txt`, `pyproject.toml`, or `Pipfile` containing `django`, or presence of `manage.py`

---

## Dockerfile Patterns

### Multi-stage build with virtual environment and collectstatic

Django requires a build stage that installs dependencies **and** collects static assets before the runtime stage:

```dockerfile
# Build stage
FROM python:3.12-slim AS build
WORKDIR /app
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN SECRET_KEY=build-placeholder python manage.py collectstatic --noinput
```

The `SECRET_KEY=build-placeholder` is necessary because `collectstatic` imports Django settings, which require a `SECRET_KEY` — but the real secret is never baked into the image.

```dockerfile
# Runtime stage
FROM python:3.12-slim AS runtime
WORKDIR /app
RUN addgroup --system app && adduser --system --ingroup app app
COPY --from=build /opt/venv /opt/venv
COPY --from=build /app .
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
USER app:app
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health/')" || exit 1
ENTRYPOINT ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]
```

### Key points

- **Base image:** `python:3.12-slim` over Alpine — Alpine uses musl libc which causes build failures with many Python C extensions (psycopg2, Pillow, cryptography)
- **`PYTHONDONTWRITEBYTECODE=1`** prevents `.pyc` files from bloating the image
- **`PYTHONUNBUFFERED=1`** ensures logs appear immediately in `kubectl logs` without buffering
- **`--no-cache-dir`** for pip avoids caching wheel files in the image layer
- **Non-root user** (`app`) satisfies DS004
- **`gunicorn`** is the production WSGI server — never use `manage.py runserver` in production (it is single-threaded, unoptimized, and not designed for production traffic)
- **Workers formula:** `2 * CPU_CORES + 1` — for a 1-vCPU container, use `--workers 3`
- **WSGI module path** varies by project scaffold: `config.wsgi:application`, `myproject.wsgi:application`, or `app.wsgi:application` — check `wsgi.py` location

### Poetry variant

```dockerfile
# Build stage
FROM python:3.12-slim AS build
WORKDIR /app
RUN pip install --no-cache-dir poetry
COPY pyproject.toml poetry.lock ./
RUN python -m venv /opt/venv && \
    . /opt/venv/bin/activate && \
    poetry install --only main --no-interaction --no-ansi
COPY . .
RUN SECRET_KEY=build-placeholder /opt/venv/bin/python manage.py collectstatic --noinput

# Runtime stage — same as above
```

---

## Health Endpoints

Django does not provide health endpoints out of the box. Use the `django-health-check` package:

### Installation

```bash
pip install django-health-check
```

### Configuration in `settings.py`

```python
INSTALLED_APPS = [
    # ...existing apps...
    "health_check",
    "health_check.db",
    "health_check.cache",
    "health_check.storage",
    "health_check.contrib.migrations",
]
```

### URL configuration in `urls.py`

```python
from django.urls import include, path

urlpatterns = [
    # ...existing urls...
    path("health/", include("health_check.urls")),
]
```

The `/health/` endpoint returns HTTP 200 when all checks pass and HTTP 500 with details when any check fails.

### Probe configuration in Deployment manifest

```yaml
livenessProbe:
  httpGet:
    path: /health/
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 15
  timeoutSeconds: 3
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /health/
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
```

**Note:** `initialDelaySeconds: 10` is sufficient for most Django apps. If the app runs database migrations on startup via an init container, add a `startupProbe` with a higher `failureThreshold` to avoid premature restarts during migration:

```yaml
startupProbe:
  httpGet:
    path: /health/
    port: 8000
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 30
```

---

## Database Profiles

Django does not have a built-in profile system like Spring Boot. Database configuration is driven by `settings.py` with environment variables:

| Pattern | How it works | Example |
|---------|-------------|---------|
| Direct config | Hardcoded in `settings.py` — dev only | `DATABASES = {"default": {"ENGINE": "django.db.backends.postgresql", ...}}` |
| `dj-database-url` | Parses a single `DATABASE_URL` env var | `DATABASES = {"default": dj_database_url.config(default="sqlite:///db.sqlite3")}` |
| Env-split | Individual env vars for each field | `HOST`, `PORT`, `NAME`, `USER` read via `os.environ` |

**Recommended:** Use `dj-database-url` for AKS deployments — it is the standard pattern for 12-factor Django apps and works cleanly with Kubernetes env vars.

### Environment variables for PostgreSQL on AKS

```yaml
env:
  - name: DATABASE_URL
    value: "postgres://{{IDENTITY_NAME}}@{{PG_SERVER_NAME}}.postgres.database.azure.com:5432/{{DB_NAME}}?sslmode=require"
  - name: SECRET_KEY
    valueFrom:
      secretKeyRef:
        name: {{APP_NAME}}-secrets
        key: secret-key
```

**Important:** `SECRET_KEY` must never be in a ConfigMap or hardcoded. Always store it in a Kubernetes Secret (or Key Vault via Workload Identity).

### ConfigMap pattern

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{APP_NAME}}-config
data:
  DJANGO_SETTINGS_MODULE: "config.settings.production"
  DJANGO_ALLOWED_HOSTS: "{{INGRESS_HOSTNAME}}"
  DATABASE_URL: "postgres://{{IDENTITY_NAME}}@{{PG_SERVER_NAME}}.postgres.database.azure.com:5432/{{DB_NAME}}?sslmode=require"
```

---

## Writable Paths (DS012 Compliance)

When `readOnlyRootFilesystem: true` is set, Django apps need `/tmp` writable and optionally `/app/staticfiles`:

- **`/tmp`** — required for file uploads (`FILE_UPLOAD_TEMP_DIR` defaults to `/tmp`), session data when using file-based sessions, and temporary processing
- **`/app/staticfiles`** — optional, only needed if serving collected static files at runtime from the local filesystem (when not using WhiteNoise or a CDN)

### Volume mount configuration

```yaml
volumes:
  - name: tmp
    emptyDir: {}
  - name: staticfiles
    emptyDir: {}
containers:
  - name: app
    volumeMounts:
      - name: tmp
        mountPath: /tmp
      - name: staticfiles
        mountPath: /app/staticfiles
```

If static files are baked into the image at build time via `collectstatic` and served by WhiteNoise, the `staticfiles` volume can be omitted — only `/tmp` is required.

---

## Port Configuration

- **Default port:** 8000
- **CLI flag:** `--bind 0.0.0.0:8000` passed to `gunicorn`
- **Env var override:** `PORT` (read via `gunicorn --bind 0.0.0.0:$PORT` or `int(os.environ.get("PORT", 8000))`)

Gunicorn logs the port on startup: `Listening at: http://0.0.0.0:8000`

---

## Build Commands

| Command | Purpose | When to run |
|---------|---------|-------------|
| `python manage.py collectstatic --noinput` | Gathers static files into `STATIC_ROOT` | In Dockerfile build stage (with `SECRET_KEY=build-placeholder`) |
| `python manage.py migrate --noinput` | Applies database migrations | As a Kubernetes init container — **never in the Dockerfile** |

**Important:** Database migrations must run as an init container, not during the Docker build. The build stage has no access to the production database, and running migrations in the entrypoint creates race conditions when multiple replicas start simultaneously.

### Init container for migrations

```yaml
initContainers:
  - name: migrate
    image: {{ACR_NAME}}.azurecr.io/{{APP_NAME}}:{{TAG}}
    command: ["python", "manage.py", "migrate", "--noinput"]
    envFrom:
      - configMapRef:
          name: {{APP_NAME}}-config
      - secretRef:
          name: {{APP_NAME}}-secrets
```

---

## Common Issues on AKS

| Issue | Symptom | Fix |
|-------|---------|-----|
| `collectstatic` not run | Static files return 404, admin panel has no CSS | Run `python manage.py collectstatic --noinput` in the Dockerfile build stage with `SECRET_KEY=build-placeholder` |
| `ALLOWED_HOSTS` not set | `DisallowedHost` error, HTTP 400 on every request | Set `DJANGO_ALLOWED_HOSTS` env var and read it in settings: `ALLOWED_HOSTS = os.environ.get("DJANGO_ALLOWED_HOSTS", "").split(",")` |
| Dev server in production | `manage.py runserver` used in container — single-threaded, no security | Replace with `gunicorn` as the ENTRYPOINT — `runserver` is for local development only |
| Migrations not applied | `ProgrammingError: relation "..." does not exist` | Run `manage.py migrate` as an init container, not in the Dockerfile or entrypoint |
| `SECRET_KEY` not set | `ImproperlyConfigured` error on startup | Store `SECRET_KEY` in a Kubernetes Secret and inject via `secretKeyRef` — never hardcode or commit it |
| Static files 404 in production | CSS/JS/images not loading, broken admin panel | Use WhiteNoise (`whitenoise.middleware.WhiteNoiseMiddleware`) to serve static files from the app, or configure a CDN with `STATIC_URL` pointing to external storage |
