# Knowledge Pack Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 8 framework-specific knowledge packs (Express, Next.js, FastAPI, Django, NestJS, ASP.NET Core, Go, Flask) and update references in SKILL.md, Phase 01, and README.

**Architecture:** Each knowledge pack is a standalone markdown file in `skills/deploy-to-aks/knowledge-packs/frameworks/` following the same 7-section structure as `spring-boot.md`. The loading mechanism already exists in Phase 01 (path-based lookup). We add the files, then update the reference lists.

**Tech Stack:** Markdown content files, no code dependencies.

---

### Task 1: Create Express/Fastify Knowledge Pack

**Files:**
- Create: `skills/deploy-to-aks/knowledge-packs/frameworks/express.md`
- Reference: `skills/deploy-to-aks/knowledge-packs/frameworks/spring-boot.md` (pattern to follow)

- [ ] **Step 1: Create `express.md`**

Write the following content to `skills/deploy-to-aks/knowledge-packs/frameworks/express.md`:

```markdown
# Express / Fastify Knowledge Pack

> **Applies to:** Projects detected with `package.json` containing `express` or `fastify` as a dependency

---

## Dockerfile Patterns

### Multi-stage build with signal handling

Node.js does not handle SIGTERM gracefully when running as PID 1 inside a container. Use `dumb-init` to proxy signals:

```dockerfile
# Build stage
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build --if-present
RUN npm prune --omit=dev

# Runtime stage
FROM node:22-alpine
RUN apk add --no-cache dumb-init
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/package.json ./
USER node
EXPOSE 3000
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/index.js"]
```

### Key points

- **`dumb-init`** ensures SIGTERM reaches the Node process — without it, `kubectl rollout restart` can leave zombie processes and force a `SIGKILL` after the termination grace period
- **`npm prune --omit=dev`** removes dev dependencies after build, shrinking the image by 30-60%
- **`USER node`** — the `node` user (uid 1000) is built into `node:*-alpine` images, satisfying DS004
- **Alpine variant** keeps the image under 200MB for a typical Express app
- **Fastify note:** Fastify listens on `127.0.0.1` by default — you must pass `{ host: '0.0.0.0' }` to `fastify.listen()` or set `FASTIFY_ADDRESS=0.0.0.0`, otherwise the container will not accept traffic

### Package manager variants

| Manager | Install command | Lockfile |
|---------|----------------|----------|
| npm | `npm ci` | `package-lock.json` |
| yarn | `yarn install --frozen-lockfile` | `yarn.lock` |
| pnpm | `corepack enable && pnpm install --frozen-lockfile` | `pnpm-lock.yaml` |

---

## Health Endpoints

Express and Fastify do not provide health endpoints out of the box. Add a dedicated route:

### Express

```javascript
app.get('/healthz', (req, res) => {
  res.status(200).json({ status: 'ok' });
});
```

### Fastify

```javascript
fastify.get('/healthz', async () => {
  return { status: 'ok' };
});
```

For deeper checks (database connectivity, downstream services), consider adding a `/ready` endpoint that verifies dependencies are reachable.

### Probe configuration in Deployment manifest

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /healthz
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
```

**Note:** Node.js apps start fast (1-3 seconds). Low `initialDelaySeconds` values are appropriate.

---

## Database Profiles

Express/Fastify apps commonly use one of several database libraries:

| Library | Config Pattern | Connection String Env Var |
|---------|---------------|--------------------------|
| `pg` (node-postgres) | `new Pool({ connectionString })` | `DATABASE_URL` |
| Prisma | `datasource db { url = env("DATABASE_URL") }` in `schema.prisma` | `DATABASE_URL` |
| Sequelize | `new Sequelize(process.env.DATABASE_URL)` | `DATABASE_URL` |
| Knex | `connection: process.env.DATABASE_URL` in `knexfile` | `DATABASE_URL` |

### Environment variables for PostgreSQL on AKS

```yaml
env:
  - name: DATABASE_URL
    value: "postgresql://{{IDENTITY_NAME}}@{{PG_SERVER_NAME}}.postgres.database.azure.com:5432/{{DB_NAME}}?sslmode=require"
  - name: NODE_ENV
    value: "production"
```

For Workload Identity with passwordless auth, use the `@azure/identity` package with `DefaultAzureCredential` to acquire tokens, then pass them to `pg` via a custom authentication handler.

### ConfigMap pattern

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{APP_NAME}}-config
data:
  NODE_ENV: "production"
  PORT: "3000"
```

---

## Writable Paths (DS012 Compliance)

When `readOnlyRootFilesystem: true` is set, Express/Fastify apps typically only need `/tmp`:

- **Multer** (file upload middleware) writes to `/tmp` by default
- **Express session** with file-based storage writes to `/tmp` (use Redis in production instead)

### Required volume mount

```yaml
volumes:
  - name: tmp
    emptyDir: {}
containers:
  - name: app
    volumeMounts:
      - name: tmp
        mountPath: /tmp
```

---

## Port Configuration

- **Default port:** 3000
- **Env var override:** `PORT` (convention — most Express/Fastify apps read `process.env.PORT`)
- **Fastify caveat:** Must bind to `0.0.0.0`, not `127.0.0.1` (the default)

---

## Build Commands

| Scenario | Build Command | Output |
|----------|--------------|--------|
| TypeScript project | `npm run build` | `dist/` directory |
| JavaScript project | None (no build step) | Source files directly |
| With bundler (esbuild, tsup) | `npm run build` | `dist/` or `build/` |

After build, run `npm prune --omit=dev` to remove dev dependencies from `node_modules`.

---

## Common Issues on AKS

| Issue | Symptom | Fix |
|-------|---------|-----|
| SIGTERM not handled | Pod takes 30s to terminate, `SIGKILL` in logs | Use `dumb-init` (see Dockerfile Patterns) and add graceful shutdown: `process.on('SIGTERM', () => server.close())` |
| `ECONNRESET` under load | Intermittent connection resets during rolling update | Implement graceful shutdown — stop accepting new connections, drain existing ones, then exit |
| Fastify binds to localhost | `Connection refused` from K8s probes | Pass `{ host: '0.0.0.0' }` to `fastify.listen()` |
| `node_modules` in image bloat | Image > 500MB | Ensure `npm prune --omit=dev` runs after build; add `node_modules` to `.dockerignore` |
| Memory leak in production | Pod OOMKilled after hours/days | Set `--max-old-space-size` via `NODE_OPTIONS` env var; match to container memory limit (use ~75% of limit) |
```

- [ ] **Step 2: Verify structure matches spring-boot.md pattern**

Confirm the file has all 7 sections in order:
1. Header with "Applies to" trigger
2. Dockerfile Patterns (with full Dockerfile, key points)
3. Health Endpoints (with code snippets, probe YAML)
4. Database Profiles (with env var table, ConfigMap YAML)
5. Writable Paths (with volume mount YAML)
6. Port Configuration
7. Build Commands
8. Common Issues on AKS (table with 4+ entries)

- [ ] **Step 3: Commit**

```bash
git add skills/deploy-to-aks/knowledge-packs/frameworks/express.md
git commit -m "feat: add Express/Fastify knowledge pack"
```

---

### Task 2: Create Next.js Knowledge Pack

**Files:**
- Create: `skills/deploy-to-aks/knowledge-packs/frameworks/nextjs.md`

- [ ] **Step 1: Create `nextjs.md`**

Write the following content to `skills/deploy-to-aks/knowledge-packs/frameworks/nextjs.md`:

```markdown
# Next.js Knowledge Pack

> **Applies to:** Projects detected with `package.json` containing `next` as a dependency

---

## Dockerfile Patterns

### Standalone output mode (critical)

Next.js `output: 'standalone'` mode is essential for Docker deployments. Without it, the image includes the full `node_modules` directory and is typically 800MB-1.2GB. With standalone mode, it drops to 80-150MB.

Add to `next.config.js` (or `next.config.mjs` / `next.config.ts`):

```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
};
module.exports = nextConfig;
```

### Multi-stage Dockerfile

```dockerfile
# Build stage
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# Runtime stage
FROM node:22-alpine
WORKDIR /app

# Next.js collects anonymous telemetry — disable in production
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production

# Copy standalone server and static assets
COPY --from=build /app/.next/standalone ./
COPY --from=build /app/.next/static ./.next/static
COPY --from=build /app/public ./public

USER node
EXPOSE 3000

CMD ["node", "server.js"]
```

### Key points

- **`output: 'standalone'`** is non-negotiable for Docker — without it, `node_modules` is copied wholesale
- **Static assets** (`.next/static` and `public/`) must be copied separately — the standalone build does not include them
- **`NEXT_TELEMETRY_DISABLED=1`** prevents outbound telemetry calls from the container
- **No `dumb-init` needed** — the standalone `server.js` handles signals correctly
- **`sharp`** — if the app uses `next/image` for image optimization, `sharp` must be installed explicitly: `npm install sharp`. The standalone build tree-shakes it out otherwise.

---

## Health Endpoints

Next.js does not provide a built-in health endpoint. Create an API route:

### App Router (Next.js 13+)

Create `app/api/health/route.ts`:

```typescript
export async function GET() {
  return Response.json({ status: 'ok' });
}
```

### Pages Router

Create `pages/api/health.ts`:

```typescript
import type { NextApiRequest, NextApiResponse } from 'next';

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  res.status(200).json({ status: 'ok' });
}
```

### Probe configuration in Deployment manifest

```yaml
livenessProbe:
  httpGet:
    path: /api/health
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 15
  timeoutSeconds: 3
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /api/health
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
```

**Note:** Next.js standalone server starts in 2-5 seconds. `initialDelaySeconds: 10` provides safe margin.

---

## Database Profiles

Next.js apps typically access databases through API routes or Server Components:

| Library | Config Pattern | Connection String Env Var |
|---------|---------------|--------------------------|
| Prisma | `datasource db { url = env("DATABASE_URL") }` in `schema.prisma` | `DATABASE_URL` |
| Drizzle | `drizzle(process.env.DATABASE_URL)` | `DATABASE_URL` |
| `pg` (direct) | `new Pool({ connectionString })` | `DATABASE_URL` |

### Environment variables for PostgreSQL on AKS

```yaml
env:
  - name: DATABASE_URL
    value: "postgresql://{{IDENTITY_NAME}}@{{PG_SERVER_NAME}}.postgres.database.azure.com:5432/{{DB_NAME}}?sslmode=require"
  - name: NODE_ENV
    value: "production"
  - name: NEXT_TELEMETRY_DISABLED
    value: "1"
```

### ConfigMap pattern

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{APP_NAME}}-config
data:
  NODE_ENV: "production"
  NEXT_TELEMETRY_DISABLED: "1"
```

---

## Writable Paths (DS012 Compliance)

When `readOnlyRootFilesystem: true` is set, Next.js needs:

- **`/tmp`** — general temporary files
- **`/app/.next/cache`** — ISR (Incremental Static Regeneration) cache and image optimization cache. Without this writable, ISR pages cannot be revalidated and `next/image` optimization will fail at runtime.

### Required volume mounts

```yaml
volumes:
  - name: tmp
    emptyDir: {}
  - name: next-cache
    emptyDir: {}
containers:
  - name: app
    volumeMounts:
      - name: tmp
        mountPath: /tmp
      - name: next-cache
        mountPath: /app/.next/cache
```

---

## Port Configuration

- **Default port:** 3000
- **Env var override:** `PORT` (the standalone `server.js` reads `process.env.PORT`)
- **CLI override:** `next start -p 8080` (not used in Docker — use `PORT` env var instead)

---

## Build Commands

| Scenario | Build Command | Output |
|----------|--------------|--------|
| Standard build | `npm run build` | `.next/` directory |
| Standalone (Docker) | `npm run build` (with `output: 'standalone'` in config) | `.next/standalone/` + `.next/static/` |

The standalone output creates a self-contained `server.js` with only the required `node_modules` files inlined. This is what gets copied to the runtime image.

---

## Common Issues on AKS

| Issue | Symptom | Fix |
|-------|---------|-----|
| Image too large (>800MB) | Slow pulls, high ACR cost | Add `output: 'standalone'` to `next.config.js` — reduces image to ~100MB |
| Static assets 404 | CSS/JS/images not loading | Copy `.next/static` and `public/` separately in Dockerfile (standalone excludes them) |
| ISR fails at runtime | Stale pages, `EROFS` errors in logs | Mount `/app/.next/cache` as writable `emptyDir` volume (see Writable Paths) |
| `next/image` optimization fails | Broken images, 500 errors on `/_next/image` | Install `sharp` explicitly: `npm install sharp`; mount cache directory as writable |
| Environment variables undefined | `process.env.X` is `undefined` at runtime | Use `NEXT_PUBLIC_` prefix for client-side vars (baked at build time), or use server-side env vars in API routes/Server Components |
| Telemetry calls from pod | Unexpected outbound traffic | Set `NEXT_TELEMETRY_DISABLED=1` env var |
```

- [ ] **Step 2: Verify structure matches spring-boot.md pattern**

- [ ] **Step 3: Commit**

```bash
git add skills/deploy-to-aks/knowledge-packs/frameworks/nextjs.md
git commit -m "feat: add Next.js knowledge pack"
```

---

### Task 3: Create FastAPI Knowledge Pack

**Files:**
- Create: `skills/deploy-to-aks/knowledge-packs/frameworks/fastapi.md`

- [ ] **Step 1: Create `fastapi.md`**

Write the following content to `skills/deploy-to-aks/knowledge-packs/frameworks/fastapi.md`:

```markdown
# FastAPI Knowledge Pack

> **Applies to:** Projects detected with `requirements.txt`, `pyproject.toml`, or `Pipfile` containing `fastapi`

---

## Dockerfile Patterns

### Multi-stage build with virtual environment

```dockerfile
# Build stage
FROM python:3.12-slim AS build
WORKDIR /app
RUN python -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH"
COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt
COPY . .

# Runtime stage
FROM python:3.12-slim
WORKDIR /app
RUN groupadd --gid 1000 appuser \
    && useradd --uid 1000 --gid appuser --shell /bin/sh --create-home appuser
COPY --from=build --chown=appuser:appuser /app /app
ENV PATH="/app/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
USER appuser
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Key points

- **Virtual environment** is created in the build stage and copied to runtime — this avoids installing build tools (gcc, etc.) in the final image
- **`PYTHONDONTWRITEBYTECODE=1`** prevents `.pyc` file generation (unnecessary in containers, reduces image noise)
- **`PYTHONUNBUFFERED=1`** ensures logs appear immediately in `kubectl logs` without buffering
- **`--no-cache-dir`** on pip prevents caching downloaded packages in the image layer
- **`python:3.12-slim`** over `python:3.12-alpine` — Alpine uses musl libc which causes issues with some Python packages (numpy, pandas, psycopg2)

### Poetry variant

If the project uses Poetry, replace the requirements.txt steps:

```dockerfile
COPY pyproject.toml poetry.lock ./
RUN pip install poetry \
    && poetry export -f requirements.txt -o requirements.txt --without-hashes \
    && pip install --no-cache-dir -r requirements.txt
```

### uv variant

If the project uses uv:

```dockerfile
COPY pyproject.toml uv.lock ./
RUN pip install uv \
    && uv pip install --system --no-cache -r pyproject.toml
```

---

## Health Endpoints

FastAPI makes health endpoints trivial:

```python
@app.get("/health")
async def health():
    return {"status": "ok"}
```

For deeper checks with database connectivity:

```python
@app.get("/health")
async def health():
    return {"status": "ok"}

@app.get("/ready")
async def ready(db: AsyncSession = Depends(get_db)):
    try:
        await db.execute(text("SELECT 1"))
        return {"status": "ready"}
    except Exception:
        raise HTTPException(status_code=503, detail="Database not ready")
```

### Probe configuration in Deployment manifest

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /ready
    port: 8000
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
```

**Note:** FastAPI with uvicorn starts in 1-3 seconds. Low `initialDelaySeconds` values are appropriate.

---

## Database Profiles

FastAPI apps commonly use async database drivers:

| Library | Config Pattern | Connection String Env Var |
|---------|---------------|--------------------------|
| SQLAlchemy (async) | `create_async_engine(url)` with `asyncpg` | `DATABASE_URL` |
| Tortoise ORM | `TORTOISE_ORM` config dict | `DATABASE_URL` |
| SQLModel | `create_engine(url)` | `DATABASE_URL` |
| `asyncpg` (direct) | `asyncpg.connect(dsn)` | `DATABASE_URL` |

### Environment variables for PostgreSQL on AKS

```yaml
env:
  - name: DATABASE_URL
    value: "postgresql+asyncpg://{{IDENTITY_NAME}}@{{PG_SERVER_NAME}}.postgres.database.azure.com:5432/{{DB_NAME}}?ssl=require"
```

**Note:** The `+asyncpg` suffix in the connection string tells SQLAlchemy to use the async driver. If using synchronous SQLAlchemy, use `postgresql://` instead.

### ConfigMap pattern

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{APP_NAME}}-config
data:
  PYTHONDONTWRITEBYTECODE: "1"
  PYTHONUNBUFFERED: "1"
```

---

## Writable Paths (DS012 Compliance)

When `readOnlyRootFilesystem: true` is set, FastAPI typically only needs `/tmp`:

- **Temp file uploads** — FastAPI's `UploadFile` writes to `/tmp` by default
- **No other writable paths** are typically needed for a production FastAPI app

### Required volume mount

```yaml
volumes:
  - name: tmp
    emptyDir: {}
containers:
  - name: app
    volumeMounts:
      - name: tmp
        mountPath: /tmp
```

---

## Port Configuration

- **Default port:** 8000
- **Config override:** `--port` flag to uvicorn: `uvicorn app.main:app --port 8000`
- **Env var override:** `PORT` (if the app reads `os.environ.get("PORT", "8000")`)

---

## Build Commands

| Scenario | Build Command | Output |
|----------|--------------|--------|
| Standard (pip) | None — Python is interpreted | Source files + installed packages in venv |
| Poetry | `poetry export -f requirements.txt` | `requirements.txt` for Docker |
| uv | `uv pip compile` | Resolved dependencies |

No compilation step. The Docker build handles dependency installation.

---

## Common Issues on AKS

| Issue | Symptom | Fix |
|-------|---------|-----|
| Uvicorn workers misconfigured | High latency under load, only 1 request at a time | Use `--workers N` where N = 2 * CPU cores + 1, or let `WEB_CONCURRENCY` env var control it |
| Async DB pool exhaustion | `asyncpg.exceptions.TooManyConnectionsError` | Set `pool_size` and `max_overflow` on `create_async_engine()`; match to PostgreSQL `max_connections` |
| Alpine image build fails | `pip install` fails with C extension errors (numpy, psycopg2) | Use `python:3.12-slim` (Debian-based) instead of `python:3.12-alpine` |
| Uvicorn binds to localhost | `Connection refused` from K8s probes | Pass `--host 0.0.0.0` to uvicorn |
| Missing `uvicorn` in production | `ModuleNotFoundError: No module named 'uvicorn'` | Ensure `uvicorn[standard]` is in `requirements.txt` (not just a dev dependency) |
```

- [ ] **Step 2: Verify structure matches spring-boot.md pattern**

- [ ] **Step 3: Commit**

```bash
git add skills/deploy-to-aks/knowledge-packs/frameworks/fastapi.md
git commit -m "feat: add FastAPI knowledge pack"
```

---

### Task 4: Create Django Knowledge Pack

**Files:**
- Create: `skills/deploy-to-aks/knowledge-packs/frameworks/django.md`

- [ ] **Step 1: Create `django.md`**

Write the following content to `skills/deploy-to-aks/knowledge-packs/frameworks/django.md`:

```markdown
# Django Knowledge Pack

> **Applies to:** Projects detected with `requirements.txt`, `pyproject.toml`, or `Pipfile` containing `django`, or presence of `manage.py`

---

## Dockerfile Patterns

### Multi-stage build with collectstatic

```dockerfile
# Build stage
FROM python:3.12-slim AS build
WORKDIR /app
RUN python -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH"
COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt
COPY . .
RUN DJANGO_SETTINGS_MODULE=myproject.settings \
    SECRET_KEY=build-placeholder \
    python manage.py collectstatic --noinput

# Runtime stage
FROM python:3.12-slim
WORKDIR /app
RUN groupadd --gid 1000 appuser \
    && useradd --uid 1000 --gid appuser --shell /bin/sh --create-home appuser
COPY --from=build --chown=appuser:appuser /app /app
ENV PATH="/app/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
USER appuser
EXPOSE 8000
CMD ["gunicorn", "myproject.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]
```

### Key points

- **`collectstatic`** runs in the build stage — a temporary `SECRET_KEY` is needed because Django settings are loaded during the command, but the real key is injected at runtime via env var
- **`gunicorn`** is the production WSGI server — never use `manage.py runserver` in production (single-threaded, no security features, debug mode)
- **`python:3.12-slim`** over Alpine — many Django dependencies (Pillow, psycopg2) need C extensions that are problematic on musl
- **Workers:** `--workers 3` is a good starting point for a 1-2 CPU container; general formula is `2 * CPU + 1`

### Poetry variant

Replace the requirements.txt steps:

```dockerfile
COPY pyproject.toml poetry.lock ./
RUN pip install poetry \
    && poetry export -f requirements.txt -o requirements.txt --without-hashes \
    && pip install --no-cache-dir -r requirements.txt
```

---

## Health Endpoints

Django does not provide health endpoints by default. Use the `django-health-check` package:

### Installation

```
pip install django-health-check
```

### Configuration in `settings.py`

```python
INSTALLED_APPS = [
    # ...
    'health_check',
    'health_check.db',
    'health_check.cache',
    'health_check.storage',
]
```

### URL configuration in `urls.py`

```python
from django.urls import path, include

urlpatterns = [
    # ...
    path('health/', include('health_check.urls')),
]
```

This provides `/health/` which checks database, cache, and storage backends.

### Probe configuration in Deployment manifest

```yaml
livenessProbe:
  httpGet:
    path: /health/
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 15
  timeoutSeconds: 5
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /health/
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

**Note:** Django with gunicorn starts in 3-8 seconds. `initialDelaySeconds: 10` provides safe margin. If running migrations on startup, consider a `startupProbe` with higher `failureThreshold`.

---

## Database Profiles

Django uses the `DATABASES` setting for database configuration:

| Pattern | Mechanism | Common Package |
|---------|-----------|---------------|
| Direct config | `DATABASES = { 'default': { 'ENGINE': '...', 'NAME': '...', ... } }` | Built-in |
| URL-based | `DATABASES = { 'default': dj_database_url.config() }` | `dj-database-url` |
| Environment-split | Individual env vars: `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` | Built-in |

### Environment variables for PostgreSQL on AKS

Using `dj-database-url` (recommended):

```yaml
env:
  - name: DATABASE_URL
    value: "postgresql://{{IDENTITY_NAME}}@{{PG_SERVER_NAME}}.postgres.database.azure.com:5432/{{DB_NAME}}?sslmode=require"
  - name: DJANGO_SETTINGS_MODULE
    value: "myproject.settings"
  - name: SECRET_KEY
    valueFrom:
      secretKeyRef:
        name: {{APP_NAME}}-secrets
        key: django-secret-key
```

### ConfigMap pattern

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{APP_NAME}}-config
data:
  DJANGO_SETTINGS_MODULE: "myproject.settings"
  DJANGO_ALLOWED_HOSTS: "*"
  PYTHONDONTWRITEBYTECODE: "1"
  PYTHONUNBUFFERED: "1"
```

---

## Writable Paths (DS012 Compliance)

When `readOnlyRootFilesystem: true` is set, Django needs:

- **`/tmp`** — temporary file uploads (Django's `FILE_UPLOAD_TEMP_DIR` defaults to `/tmp`)
- **`/app/staticfiles`** — only if `collectstatic` output is needed at runtime (typically handled at build time, but some setups require it writable)

### Required volume mounts

```yaml
volumes:
  - name: tmp
    emptyDir: {}
containers:
  - name: app
    volumeMounts:
      - name: tmp
        mountPath: /tmp
```

If static files are collected at runtime (not recommended), add:

```yaml
volumes:
  - name: staticfiles
    emptyDir: {}
containers:
  - name: app
    volumeMounts:
      - name: staticfiles
        mountPath: /app/staticfiles
```

---

## Port Configuration

- **Default port:** 8000
- **Config override:** `--bind 0.0.0.0:8000` flag to gunicorn
- **Env var override:** `PORT` (if using `gunicorn myproject.wsgi --bind 0.0.0.0:$PORT`)

---

## Build Commands

| Scenario | Build Command | Output |
|----------|--------------|--------|
| Collect static files | `python manage.py collectstatic --noinput` | `staticfiles/` directory |
| Run migrations | `python manage.py migrate --noinput` | Database schema changes (run as init container, not in Dockerfile) |

**Important:** Database migrations should run as a Kubernetes init container or a Job, not in the Dockerfile build. The build environment does not have access to the production database.

---

## Common Issues on AKS

| Issue | Symptom | Fix |
|-------|---------|-----|
| `collectstatic` not run | 404 on CSS/JS, unstyled admin panel | Add `collectstatic --noinput` to Dockerfile build stage with a placeholder `SECRET_KEY` |
| `ALLOWED_HOSTS` not set | `DisallowedHost` 400 error | Set `DJANGO_ALLOWED_HOSTS` env var; in production, use `["*"]` or the actual domain |
| Running dev server in prod | `CommandError: This is not safe for production` | Use `gunicorn myproject.wsgi` instead of `manage.py runserver` |
| Migrations not applied | `ProgrammingError: relation does not exist` | Run migrations as an init container: `python manage.py migrate --noinput` |
| `SECRET_KEY` not set | `ImproperlyConfigured` at startup | Inject via K8s Secret, never hardcode; generate with `django.core.management.utils.get_random_secret_key()` |
| Static files 404 in production | CSS/JS loads in dev but not in prod | Use WhiteNoise middleware or serve via Azure Blob Storage/CDN; Django's dev static serving is disabled when `DEBUG=False` |
```

- [ ] **Step 2: Verify structure matches spring-boot.md pattern**

- [ ] **Step 3: Commit**

```bash
git add skills/deploy-to-aks/knowledge-packs/frameworks/django.md
git commit -m "feat: add Django knowledge pack"
```

---

### Task 5: Create NestJS Knowledge Pack

**Files:**
- Create: `skills/deploy-to-aks/knowledge-packs/frameworks/nestjs.md`

- [ ] **Step 1: Create `nestjs.md`**

Write the following content to `skills/deploy-to-aks/knowledge-packs/frameworks/nestjs.md`:

```markdown
# NestJS Knowledge Pack

> **Applies to:** Projects detected with `package.json` containing `@nestjs/core` as a dependency

---

## Dockerfile Patterns

### Multi-stage build with TypeScript compilation

```dockerfile
# Build stage
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build
RUN npm prune --omit=dev

# Runtime stage
FROM node:22-alpine
RUN apk add --no-cache dumb-init
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/package.json ./
USER node
EXPOSE 3000
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/main.js"]
```

### Key points

- **`npm run build`** compiles TypeScript to `dist/` via the NestJS CLI (`nest build`), which uses `tsc` under the hood
- **`dumb-init`** is needed for the same signal-handling reasons as Express (Node as PID 1 doesn't forward SIGTERM)
- **`dist/main.js`** is the default entry point — the NestJS CLI generates this
- **`USER node`** satisfies DS004 using the built-in user from `node:22-alpine`
- **Monorepo note:** If using NestJS monorepo mode, adjust the build command to `nest build <app-name>` and the output path to `dist/apps/<app-name>/main.js`

---

## Health Endpoints

NestJS provides health checks via the `@nestjs/terminus` package:

### Installation

```bash
npm install @nestjs/terminus
```

### Health module

```typescript
// health.module.ts
import { Module } from '@nestjs/common';
import { TerminusModule } from '@nestjs/terminus';
import { HealthController } from './health.controller';

@Module({
  imports: [TerminusModule],
  controllers: [HealthController],
})
export class HealthModule {}
```

### Health controller

```typescript
// health.controller.ts
import { Controller, Get } from '@nestjs/common';
import { HealthCheck, HealthCheckService, TypeOrmHealthIndicator } from '@nestjs/terminus';

@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private db: TypeOrmHealthIndicator,
  ) {}

  @Get()
  @HealthCheck()
  check() {
    return this.health.check([
      () => this.db.pingCheck('database'),
    ]);
  }
}
```

### Probe configuration in Deployment manifest

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
```

---

## Database Profiles

NestJS supports multiple ORM/database libraries:

| Library | Config Pattern | Connection String Env Var |
|---------|---------------|--------------------------|
| TypeORM | `TypeOrmModule.forRoot({ url: process.env.DATABASE_URL })` | `DATABASE_URL` |
| Prisma | `datasource db { url = env("DATABASE_URL") }` in `schema.prisma` | `DATABASE_URL` |
| MikroORM | `MikroOrmModule.forRoot({ clientUrl: process.env.DATABASE_URL })` | `DATABASE_URL` |
| Sequelize | `SequelizeModule.forRoot({ uri: process.env.DATABASE_URL })` | `DATABASE_URL` |

### Environment variables for PostgreSQL on AKS

```yaml
env:
  - name: DATABASE_URL
    value: "postgresql://{{IDENTITY_NAME}}@{{PG_SERVER_NAME}}.postgres.database.azure.com:5432/{{DB_NAME}}?sslmode=require"
  - name: NODE_ENV
    value: "production"
```

### ConfigMap pattern

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{APP_NAME}}-config
data:
  NODE_ENV: "production"
  PORT: "3000"
```

---

## Writable Paths (DS012 Compliance)

When `readOnlyRootFilesystem: true` is set, NestJS typically only needs `/tmp`:

- **Temp files** — multer uploads (if using `@nestjs/platform-express`), temporary data
- No other writable paths are typically needed

### Required volume mount

```yaml
volumes:
  - name: tmp
    emptyDir: {}
containers:
  - name: app
    volumeMounts:
      - name: tmp
        mountPath: /tmp
```

---

## Port Configuration

- **Default port:** 3000
- **Config override:** `app.listen(process.env.PORT || 3000)` in `main.ts`
- **Env var override:** `PORT`

---

## Build Commands

| Scenario | Build Command | Output |
|----------|--------------|--------|
| Standard build | `npm run build` (runs `nest build`) | `dist/` directory |
| Monorepo app | `nest build <app-name>` | `dist/apps/<app-name>/` |
| With SWC compiler | `nest build --builder swc` | `dist/` (faster compilation) |

After build, run `npm prune --omit=dev` to remove dev dependencies.

---

## Common Issues on AKS

| Issue | Symptom | Fix |
|-------|---------|-----|
| SIGTERM not handled | Pod takes 30s to terminate | Use `dumb-init` and implement `app.enableShutdownHooks()` in `main.ts` |
| TypeORM connection pool exhaustion | `TypeORMError: Connection pool was destroyed` | Configure `extra: { max: 10 }` in TypeORM config; match to PostgreSQL `max_connections` / number of pods |
| Circular dependency | `Nest cannot create instance` error at startup | Check for circular module imports; use `forwardRef()` where needed |
| dist/ not included in image | `Cannot find module './dist/main.js'` | Ensure `npm run build` runs in build stage and `dist/` is copied to runtime |
| Global prefix breaks probes | Health endpoint at `/api/health` instead of `/health` | Exclude health from global prefix: `app.setGlobalPrefix('api', { exclude: ['health'] })` |
```

- [ ] **Step 2: Verify structure matches spring-boot.md pattern**

- [ ] **Step 3: Commit**

```bash
git add skills/deploy-to-aks/knowledge-packs/frameworks/nestjs.md
git commit -m "feat: add NestJS knowledge pack"
```

---

### Task 6: Create ASP.NET Core Knowledge Pack

**Files:**
- Create: `skills/deploy-to-aks/knowledge-packs/frameworks/aspnet-core.md`

- [ ] **Step 1: Create `aspnet-core.md`**

Write the following content to `skills/deploy-to-aks/knowledge-packs/frameworks/aspnet-core.md`:

```markdown
# ASP.NET Core Knowledge Pack

> **Applies to:** Projects detected with `*.csproj` containing `Microsoft.NET.Sdk.Web` or referencing `Microsoft.AspNetCore.*` packages

---

## Dockerfile Patterns

### Multi-stage build with project-file-first restore

```dockerfile
# Build stage
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY *.sln ./
COPY src/MyApp/*.csproj src/MyApp/
RUN dotnet restore src/MyApp/MyApp.csproj
COPY . .
RUN dotnet publish src/MyApp/MyApp.csproj \
    --configuration Release \
    --no-restore \
    --output /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
COPY --from=build /app/publish ./
USER app
EXPOSE 8080
ENV ASPNETCORE_URLS="http://+:8080" \
    DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_EnableDiagnostics=0
ENTRYPOINT ["dotnet", "MyApp.dll"]
```

### Key points

- **Project-file-first restore** — copying `.csproj` files before source enables NuGet restore layer caching
- **`USER app`** — since .NET 8, the `aspnet` runtime image includes a built-in `app` user (uid 1654). No need to create one manually. Satisfies DS004.
- **Port 8080** — .NET 8+ defaults to port 8080 via `ASPNETCORE_HTTP_PORTS`, not port 80 as in older versions
- **`DOTNET_EnableDiagnostics=0`** — disables diagnostic pipes in production (reduces attack surface)
- **`DOTNET_RUNNING_IN_CONTAINER=true`** — signals the runtime to adjust threading/GC for container environments

### Self-contained deployment

For smaller images without the ASP.NET runtime layer:

```dockerfile
RUN dotnet publish src/MyApp/MyApp.csproj \
    --configuration Release \
    --self-contained \
    --runtime linux-x64 \
    --output /app/publish
# Use runtime-deps instead of aspnet
FROM mcr.microsoft.com/dotnet/runtime-deps:9.0
```

---

## Health Endpoints

ASP.NET Core has built-in health check middleware:

### Configuration in `Program.cs`

```csharp
var builder = WebApplication.CreateBuilder(args);

// Add health checks
builder.Services.AddHealthChecks()
    .AddNpgSql(builder.Configuration.GetConnectionString("DefaultConnection")!); // optional DB check

var app = builder.Build();

app.MapHealthChecks("/healthz");
app.MapHealthChecks("/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready")
});
```

The NuGet package `AspNetCore.HealthChecks.NpgSql` provides PostgreSQL-specific health checks.

### Probe configuration in Deployment manifest

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
```

**Note:** ASP.NET Core apps start in 1-3 seconds. Low `initialDelaySeconds` values are appropriate.

---

## Database Profiles

ASP.NET Core uses Entity Framework Core for database access:

| Pattern | Mechanism | Configuration |
|---------|-----------|--------------|
| Connection string | `builder.Configuration.GetConnectionString("DefaultConnection")` | `ConnectionStrings__DefaultConnection` env var |
| DbContext config | `builder.Services.AddDbContext<AppDbContext>(...)` | In `Program.cs` |

### Environment variables for PostgreSQL on AKS

```yaml
env:
  - name: ConnectionStrings__DefaultConnection
    value: "Host={{PG_SERVER_NAME}}.postgres.database.azure.com;Database={{DB_NAME}};Username={{IDENTITY_NAME}};SSL Mode=Require"
  - name: ASPNETCORE_ENVIRONMENT
    value: "Production"
```

For Workload Identity with passwordless auth, use the `Azure.Identity` NuGet package with `DefaultAzureCredential` and the Npgsql Azure AD authentication plugin.

### ConfigMap pattern

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{APP_NAME}}-config
data:
  ASPNETCORE_ENVIRONMENT: "Production"
  ASPNETCORE_URLS: "http://+:8080"
  DOTNET_EnableDiagnostics: "0"
```

---

## Writable Paths (DS012 Compliance)

When `readOnlyRootFilesystem: true` is set, ASP.NET Core needs:

- **`/tmp`** — data protection keys (encryption key ring), temporary uploads
- ASP.NET Core's Data Protection system writes key material to the filesystem by default. In production on AKS, configure it to use Azure Blob Storage or a persistent volume instead.

### Required volume mount

```yaml
volumes:
  - name: tmp
    emptyDir: {}
containers:
  - name: app
    volumeMounts:
      - name: tmp
        mountPath: /tmp
```

---

## Port Configuration

- **Default port:** 8080 (since .NET 8; was 80 in .NET 7 and earlier)
- **Env var override:** `ASPNETCORE_URLS=http://+:8080` or `ASPNETCORE_HTTP_PORTS=8080`
- **Config override:** `builder.WebHost.UseUrls("http://+:8080")` in `Program.cs`

---

## Build Commands

| Scenario | Build Command | Output |
|----------|--------------|--------|
| Framework-dependent | `dotnet publish -c Release -o /app/publish` | `publish/` directory with DLL + deps |
| Self-contained | `dotnet publish -c Release --self-contained -r linux-x64 -o /app/publish` | `publish/` directory with runtime included |
| Single-file | `dotnet publish -c Release --self-contained -r linux-x64 -p:PublishSingleFile=true -o /app/publish` | Single executable |

---

## Common Issues on AKS

| Issue | Symptom | Fix |
|-------|---------|-----|
| Kestrel binds to port 80 | `Connection refused` on port 8080 | Set `ASPNETCORE_URLS=http://+:8080` or `ASPNETCORE_HTTP_PORTS=8080`; .NET 8+ defaults to 8080 but older apps may hardcode 80 |
| Data protection keys lost | `CryptographicException` after pod restart, auth cookies invalidated | Configure Data Protection to persist keys to Azure Blob Storage or a PersistentVolumeClaim |
| EF Core migrations not applied | `NpgsqlException: relation does not exist` | Run migrations as an init container: `dotnet ef database update` or via a startup Job |
| Image too large (>400MB) | Slow pulls | Use self-contained deployment with `runtime-deps` base image, or enable trimming: `-p:PublishTrimmed=true` |
| HTTPS redirect loop | Infinite redirects behind Gateway/Ingress | Disable HTTPS redirection in prod when TLS is terminated at the gateway: set `ASPNETCORE_FORWARDEDHEADERS_ENABLED=true` and configure `ForwardedHeadersOptions` |
```

- [ ] **Step 2: Verify structure matches spring-boot.md pattern**

- [ ] **Step 3: Commit**

```bash
git add skills/deploy-to-aks/knowledge-packs/frameworks/aspnet-core.md
git commit -m "feat: add ASP.NET Core knowledge pack"
```

---

### Task 7: Create Go Knowledge Pack

**Files:**
- Create: `skills/deploy-to-aks/knowledge-packs/frameworks/go.md`

- [ ] **Step 1: Create `go.md`**

Write the following content to `skills/deploy-to-aks/knowledge-packs/frameworks/go.md`:

```markdown
# Go Knowledge Pack

> **Applies to:** Projects detected with `go.mod` containing `github.com/gin-gonic/gin`, `github.com/labstack/echo`, or `github.com/gofiber/fiber`. Also applies to stdlib-based Go HTTP servers.

---

## Dockerfile Patterns

### Static binary with distroless runtime

```dockerfile
# Build stage
FROM golang:1.23-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download && go mod verify
COPY . .
RUN CGO_ENABLED=0 GOOS=linux \
    go build -ldflags="-s -w" -o /bin/app ./cmd/app

# Runtime stage
FROM gcr.io/distroless/static-debian12
COPY --from=build /bin/app /app
USER 65534
EXPOSE 8080
ENTRYPOINT ["/app"]
```

### Key points

- **`CGO_ENABLED=0`** produces a fully static binary — required for `distroless/static` which has no libc
- **`-ldflags="-s -w"`** strips debug info and symbol tables, reducing binary size by 20-30%
- **`gcr.io/distroless/static-debian12`** is the smallest possible runtime (~2MB) — no shell, no package manager, minimal attack surface
- **`USER 65534`** is the `nobody` user in distroless images, satisfying DS004
- **Entry point:** Adjust `./cmd/app` to match your project's main package location

### If CGO is required

Some packages (SQLite via `mattn/go-sqlite3`, certain crypto libraries) require CGO:

```dockerfile
# Use distroless/cc which includes libc
FROM gcr.io/distroless/cc-debian12
```

### Build cache optimization

For large projects, add a cache mount:

```dockerfile
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=0 go build -ldflags="-s -w" -o /bin/app ./cmd/app
```

---

## Health Endpoints

Go frameworks and the stdlib do not provide built-in health endpoints. Add them manually:

### Gin

```go
r.GET("/healthz", func(c *gin.Context) {
    c.JSON(200, gin.H{"status": "ok"})
})

r.GET("/ready", func(c *gin.Context) {
    if err := db.Ping(); err != nil {
        c.JSON(503, gin.H{"status": "not ready", "error": err.Error()})
        return
    }
    c.JSON(200, gin.H{"status": "ready"})
})
```

### Echo

```go
e.GET("/healthz", func(c echo.Context) error {
    return c.JSON(200, map[string]string{"status": "ok"})
})
```

### Fiber

```go
app.Get("/healthz", func(c *fiber.Ctx) error {
    return c.JSON(fiber.Map{"status": "ok"})
})
```

### stdlib (net/http)

```go
http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusOK)
    w.Write([]byte(`{"status":"ok"}`))
})
```

### Probe configuration in Deployment manifest

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 3
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 3
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
```

**Note:** Go binaries start nearly instantly (<1 second). Very low `initialDelaySeconds` is safe.

---

## Database Profiles

Go does not have a framework-level database abstraction. Connection is driver-specific:

| Library | Config Pattern | Connection String Env Var |
|---------|---------------|--------------------------|
| `database/sql` + `pgx` | `sql.Open("pgx", os.Getenv("DATABASE_URL"))` | `DATABASE_URL` |
| GORM | `gorm.Open(postgres.Open(os.Getenv("DATABASE_URL")))` | `DATABASE_URL` |
| sqlx | `sqlx.Connect("pgx", os.Getenv("DATABASE_URL"))` | `DATABASE_URL` |
| `pgx` (direct) | `pgx.Connect(ctx, os.Getenv("DATABASE_URL"))` | `DATABASE_URL` |

### Environment variables for PostgreSQL on AKS

```yaml
env:
  - name: DATABASE_URL
    value: "postgresql://{{IDENTITY_NAME}}@{{PG_SERVER_NAME}}.postgres.database.azure.com:5432/{{DB_NAME}}?sslmode=require"
```

For Workload Identity with passwordless auth, use the `azidentity` Go SDK to acquire tokens and pass them via the `pgx` `BeforeConnect` hook.

### ConfigMap pattern

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{APP_NAME}}-config
data:
  PORT: "8080"
```

---

## Writable Paths (DS012 Compliance)

Go binaries running on distroless typically need **no writable paths**:

- No temp directory access needed unless the application explicitly writes files
- No package cache, no interpreted runtime state

If your application writes temporary files, mount `/tmp`:

```yaml
volumes:
  - name: tmp
    emptyDir: {}
containers:
  - name: app
    volumeMounts:
      - name: tmp
        mountPath: /tmp
```

---

## Port Configuration

- **Default port:** 8080 (convention, not enforced by any framework)
- **Env var override:** `PORT` (convention — most Go apps read `os.Getenv("PORT")`)
- **Hardcoded fallback:** `:8080` is the most common default in Go web apps

Example pattern:

```go
port := os.Getenv("PORT")
if port == "" {
    port = "8080"
}
http.ListenAndServe(":"+port, router)
```

---

## Build Commands

| Scenario | Build Command | Output |
|----------|--------------|--------|
| Standard | `CGO_ENABLED=0 go build -ldflags="-s -w" -o /bin/app ./cmd/app` | Single static binary |
| With race detector (testing only) | `go build -race -o /bin/app ./cmd/app` | Binary with race detector (not for production) |
| Multiple binaries | `go build -o /bin/server ./cmd/server && go build -o /bin/worker ./cmd/worker` | Multiple binaries |

---

## Common Issues on AKS

| Issue | Symptom | Fix |
|-------|---------|-----|
| Binary not statically linked | `exec format error` or `not found` on distroless | Ensure `CGO_ENABLED=0` is set during build; if CGO is needed, use `distroless/cc` instead of `distroless/static` |
| DNS resolution issues with Alpine | Intermittent DNS failures during build | Add `RUN go env -w GOFLAGS="-mod=mod"` or use `golang:1.23` (Debian) instead of Alpine for the build stage |
| Graceful shutdown not implemented | `Connection reset` during rolling updates | Implement `signal.Notify(ctx, syscall.SIGTERM)` and use `http.Server.Shutdown(ctx)` with a timeout |
| Binary name mismatch | `exec /app: no such file or directory` | Ensure the `-o` flag in `go build` matches the `ENTRYPOINT` path in the Dockerfile |
| Port collision with distroless | Cannot bind to ports < 1024 | Use port 8080 (not 80); distroless runs as non-root (`USER 65534`) which cannot bind privileged ports |
```

- [ ] **Step 2: Verify structure matches spring-boot.md pattern**

- [ ] **Step 3: Commit**

```bash
git add skills/deploy-to-aks/knowledge-packs/frameworks/go.md
git commit -m "feat: add Go knowledge pack"
```

---

### Task 8: Create Flask Knowledge Pack

**Files:**
- Create: `skills/deploy-to-aks/knowledge-packs/frameworks/flask.md`

- [ ] **Step 1: Create `flask.md`**

Write the following content to `skills/deploy-to-aks/knowledge-packs/frameworks/flask.md`:

```markdown
# Flask Knowledge Pack

> **Applies to:** Projects detected with `requirements.txt`, `pyproject.toml`, or `Pipfile` containing `flask`

---

## Dockerfile Patterns

### Multi-stage build with gunicorn

```dockerfile
# Build stage
FROM python:3.12-slim AS build
WORKDIR /app
RUN python -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH"
COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt
COPY . .

# Runtime stage
FROM python:3.12-slim
WORKDIR /app
RUN groupadd --gid 1000 appuser \
    && useradd --uid 1000 --gid appuser --shell /bin/sh --create-home appuser
COPY --from=build --chown=appuser:appuser /app /app
ENV PATH="/app/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
USER appuser
EXPOSE 8000
CMD ["gunicorn", "app:app", "--bind", "0.0.0.0:8000", "--workers", "3"]
```

### Key points

- **`gunicorn`** is the production WSGI server — Flask's built-in `flask run` / `app.run()` is single-threaded and not suitable for production
- **`app:app`** tells gunicorn to import the `app` object from the `app` module — adjust to match your project structure (e.g., `myapp:create_app()` for app factory pattern)
- **Virtual environment** pattern same as FastAPI/Django — build in one stage, copy to runtime
- **`python:3.12-slim`** over Alpine — same rationale as other Python packs (musl libc issues with some packages)
- **Workers:** `--workers 3` is a good starting point; general formula is `2 * CPU + 1`

### App factory pattern

If using Flask's app factory pattern:

```dockerfile
CMD ["gunicorn", "myapp:create_app()", "--bind", "0.0.0.0:8000", "--workers", "3"]
```

---

## Health Endpoints

Flask does not provide health endpoints by default. Add a simple route:

```python
@app.route('/health')
def health():
    return {'status': 'ok'}, 200
```

For deeper checks with database connectivity:

```python
@app.route('/health')
def health():
    return {'status': 'ok'}, 200

@app.route('/ready')
def ready():
    try:
        db.session.execute(text('SELECT 1'))
        return {'status': 'ready'}, 200
    except Exception as e:
        return {'status': 'not ready', 'error': str(e)}, 503
```

### Probe configuration in Deployment manifest

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /ready
    port: 8000
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
```

**Note:** Flask with gunicorn starts in 2-4 seconds. Low `initialDelaySeconds` values are appropriate.

---

## Database Profiles

Flask apps commonly use SQLAlchemy via Flask-SQLAlchemy:

| Library | Config Pattern | Connection String Env Var |
|---------|---------------|--------------------------|
| Flask-SQLAlchemy | `app.config['SQLALCHEMY_DATABASE_URI'] = os.environ['DATABASE_URL']` | `DATABASE_URL` or `SQLALCHEMY_DATABASE_URI` |
| SQLAlchemy (direct) | `create_engine(os.environ['DATABASE_URL'])` | `DATABASE_URL` |
| `psycopg2` (direct) | `psycopg2.connect(os.environ['DATABASE_URL'])` | `DATABASE_URL` |

### Environment variables for PostgreSQL on AKS

```yaml
env:
  - name: DATABASE_URL
    value: "postgresql://{{IDENTITY_NAME}}@{{PG_SERVER_NAME}}.postgres.database.azure.com:5432/{{DB_NAME}}?sslmode=require"
  - name: FLASK_ENV
    value: "production"
  - name: SECRET_KEY
    valueFrom:
      secretKeyRef:
        name: {{APP_NAME}}-secrets
        key: flask-secret-key
```

### ConfigMap pattern

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{APP_NAME}}-config
data:
  FLASK_ENV: "production"
  PYTHONDONTWRITEBYTECODE: "1"
  PYTHONUNBUFFERED: "1"
```

---

## Writable Paths (DS012 Compliance)

When `readOnlyRootFilesystem: true` is set, Flask typically only needs `/tmp`:

- **Temp file uploads** — `request.files` saves to `/tmp` by default
- **Flask session** with filesystem storage writes to `/tmp` (use Redis in production instead)

### Required volume mount

```yaml
volumes:
  - name: tmp
    emptyDir: {}
containers:
  - name: app
    volumeMounts:
      - name: tmp
        mountPath: /tmp
```

---

## Port Configuration

- **Default port:** 5000 (Flask dev server), 8000 (gunicorn production convention)
- **Dev server:** `flask run --port 5000` (never use in production)
- **Gunicorn:** `gunicorn app:app --bind 0.0.0.0:8000`
- **Env var override:** `PORT` (if using `--bind 0.0.0.0:$PORT`)

---

## Build Commands

| Scenario | Build Command | Output |
|----------|--------------|--------|
| Standard (pip) | None — Python is interpreted | Source files + installed packages in venv |
| Poetry | `poetry export -f requirements.txt` | `requirements.txt` for Docker |

No compilation step. The Docker build handles dependency installation.

---

## Common Issues on AKS

| Issue | Symptom | Fix |
|-------|---------|-----|
| Running dev server in production | `WARNING: This is a development server.` in logs, poor performance | Use `gunicorn app:app --bind 0.0.0.0:8000` instead of `flask run` or `app.run()` |
| `SECRET_KEY` not set | `RuntimeError` on session access, CSRF failures | Inject via K8s Secret; generate with `python -c "import secrets; print(secrets.token_hex(32))"` |
| Flask binds to localhost | `Connection refused` from K8s probes | Use `--bind 0.0.0.0:8000` with gunicorn (Flask dev server also defaults to localhost) |
| `gunicorn` not installed | `ModuleNotFoundError: No module named 'gunicorn'` | Add `gunicorn` to `requirements.txt` (it's often missing when devs only test with `flask run`) |
| Database connection not closed | `OperationalError: too many connections` | Use Flask-SQLAlchemy's `SQLALCHEMY_POOL_SIZE` and `SQLALCHEMY_POOL_RECYCLE` settings; or call `db.session.remove()` in `@app.teardown_appcontext` |
```

- [ ] **Step 2: Verify structure matches spring-boot.md pattern**

- [ ] **Step 3: Commit**

```bash
git add skills/deploy-to-aks/knowledge-packs/frameworks/flask.md
git commit -m "feat: add Flask knowledge pack"
```

---

### Task 9: Update Phase 01 Knowledge Pack List

**Files:**
- Modify: `skills/deploy-to-aks/phases/01-discover.md:242-245`

- [ ] **Step 1: Update the knowledge pack list**

Replace lines 242-245 in `skills/deploy-to-aks/phases/01-discover.md`:

Old content:
```markdown
Currently available knowledge packs:
- `spring-boot` — Spring Boot (Java)

Additional packs can be added to `knowledge-packs/frameworks/` as needed.
```

New content:
```markdown
Currently available knowledge packs:

| Pack | Framework | Trigger |
|------|-----------|---------|
| `spring-boot` | Spring Boot (Java) | `pom.xml` with `spring-boot-starter-web` or `build.gradle` with `org.springframework.boot` |
| `express` | Express / Fastify (Node.js) | `package.json` with `express` or `fastify` |
| `nextjs` | Next.js (Node.js) | `package.json` with `next` |
| `fastapi` | FastAPI (Python) | `requirements.txt`/`pyproject.toml` with `fastapi` |
| `django` | Django (Python) | `requirements.txt`/`pyproject.toml` with `django`, or `manage.py` present |
| `nestjs` | NestJS (Node.js) | `package.json` with `@nestjs/core` |
| `aspnet-core` | ASP.NET Core (.NET) | `*.csproj` with `Microsoft.NET.Sdk.Web` |
| `go` | Go (Gin, Echo, Fiber, stdlib) | `go.mod` with `gin-gonic`, `labstack/echo`, or `gofiber` |
| `flask` | Flask (Python) | `requirements.txt`/`pyproject.toml` with `flask` |

If no pack exists for the detected framework, the skill continues with generic Dockerfile templates.
```

- [ ] **Step 2: Commit**

```bash
git add skills/deploy-to-aks/phases/01-discover.md
git commit -m "fix: update Phase 01 knowledge pack list with all 9 packs"
```

---

### Task 10: Update SKILL.md Knowledge Pack Section

**Files:**
- Modify: `skills/deploy-to-aks/SKILL.md:57-59`

- [ ] **Step 1: Update the Knowledge Packs section**

Replace lines 57-59 in `skills/deploy-to-aks/SKILL.md`:

Old content:
```markdown
### Knowledge Packs

After detecting the framework in Phase 1, check `knowledge-packs/frameworks/` for a matching pack (e.g., `spring-boot.md`). Knowledge packs provide framework-specific guidance for Dockerfile patterns, health endpoints, environment variables, writable path requirements, and common deployment issues. If no pack exists for the detected framework, the skill continues with generic templates — packs enhance the output but are not required.
```

New content:
```markdown
### Knowledge Packs

After detecting the framework in Phase 1, check `knowledge-packs/frameworks/` for a matching pack. Knowledge packs provide framework-specific guidance for Dockerfile patterns, health endpoints, database configuration, writable path requirements, and common deployment issues. If no pack exists for the detected framework, the skill continues with generic templates — packs enhance the output but are not required.

Available packs: `spring-boot`, `express`, `nextjs`, `fastapi`, `django`, `nestjs`, `aspnet-core`, `go`, `flask`
```

- [ ] **Step 2: Commit**

```bash
git add skills/deploy-to-aks/SKILL.md
git commit -m "fix: update SKILL.md knowledge pack list"
```

---

### Task 11: Update README Supported Frameworks Section

**Files:**
- Modify: `README.md:206-210`

- [ ] **Step 1: Update the Supported frameworks section**

Replace lines 206-210 in `README.md`:

Old content:
```markdown
## Supported frameworks

Node.js (Express, Fastify, Next.js, Nest) · Python (Flask, FastAPI, Django) · Java (Spring Boot, Quarkus) · Go (Gin, Echo, Fiber) · .NET (ASP.NET) · Rust

All frameworks get production-ready Dockerfile generation and deployment support. Frameworks with a [knowledge pack](skills/deploy-to-aks/knowledge-packs/frameworks/) (currently Spring Boot) get additional framework-specific guidance for health endpoints, environment configuration, and common deployment pitfalls.
```

New content:
```markdown
## Supported frameworks

All listed frameworks get production-ready multi-stage Dockerfile generation and full AKS deployment support. Frameworks with a **knowledge pack** get deeper guidance — optimized Dockerfiles, health endpoint setup, database configuration, DS012 writable-path handling, and AKS-specific troubleshooting.

| Language | Frameworks | Knowledge Pack |
|----------|-----------|---------------|
| Node.js | Express, Fastify, Next.js, NestJS | Yes |
| Python | FastAPI, Django, Flask | Yes |
| Java | Spring Boot, Quarkus | Spring Boot only |
| Go | Gin, Echo, Fiber, stdlib | Yes |
| .NET | ASP.NET Core | Yes |
| Rust | Actix, Axum | Dockerfile template only |
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: clarify supported frameworks and knowledge pack coverage in README"
```
