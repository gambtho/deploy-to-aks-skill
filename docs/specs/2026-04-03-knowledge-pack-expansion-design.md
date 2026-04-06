# Knowledge Pack Expansion Design

**Date:** 2026-04-03
**Status:** Draft
**Scope:** Add 8 framework knowledge packs (Tiers 1 & 2) + update README and phase references

---

## Problem

The README lists Node.js, Python, Java, Go, .NET, and Rust as "supported frameworks," but only Spring Boot has a knowledge pack providing deep framework-specific AKS deployment guidance. The Dockerfile templates cover all 6 languages at a generic level, but the knowledge packs — which provide health endpoint configuration, database profiles, writable path requirements, and AKS-specific troubleshooting — only exist for Spring Boot. This creates a misleading impression that all frameworks receive the same depth of support.

## Solution

Create 8 new framework-specific knowledge packs following the established `spring-boot.md` pattern, covering the most common startup frameworks. Update the README to clarify the two tiers of support, and update phase references to list all available packs.

## Framework Selection

### Tier 1 (most common startup stacks)

| Framework | File Name | Language | Trigger Signal |
|-----------|-----------|----------|---------------|
| Express/Fastify | `express.md` | Node.js | `package.json` with `express` or `fastify` dependency |
| Next.js | `nextjs.md` | Node.js | `package.json` with `next` dependency |
| FastAPI | `fastapi.md` | Python | `requirements.txt`/`pyproject.toml` with `fastapi` |
| Django | `django.md` | Python | `requirements.txt`/`pyproject.toml` with `django`, or `manage.py` present |

### Tier 2 (common, less startup-dominant)

| Framework | File Name | Language | Trigger Signal |
|-----------|-----------|----------|---------------|
| NestJS | `nestjs.md` | Node.js | `package.json` with `@nestjs/core` dependency |
| ASP.NET Core | `aspnet-core.md` | .NET | `*.csproj` with `Microsoft.AspNetCore` SDK |
| Go (Gin/Echo/Fiber) | `go.md` | Go | `go.mod` with `gin-gonic`, `labstack/echo`, or `gofiber` |
| Flask | `flask.md` | Python | `requirements.txt`/`pyproject.toml` with `flask` |

### Already exists

| Framework | File Name | Language |
|-----------|-----------|----------|
| Spring Boot | `spring-boot.md` | Java |

## Knowledge Pack Structure

Every pack follows the same 7-section structure as `spring-boot.md`:

### 1. Header

```markdown
# <Framework> Knowledge Pack

> **Applies to:** Projects detected with <trigger signal description>
```

### 2. Dockerfile Patterns

Framework-specific multi-stage build with optimization notes. This section complements (not replaces) the generic Dockerfile template — it provides framework-aware improvements the agent should apply on top of the base template.

Content per framework:

- **Express/Fastify:** `dumb-init` for proper signal handling (Node doesn't handle SIGTERM as PID 1), `npm prune --omit=dev` for slim production image, lockfile-first layer caching
- **Next.js:** `output: 'standalone'` in `next.config.js` (critical — reduces image from ~1GB to ~100MB), copy `.next/standalone` + `.next/static` + `public/` to runtime, `sharp` package explicit install for image optimization
- **FastAPI:** Virtual environment copy pattern (`python -m venv` in build, copy `/app/venv` to runtime), `--no-cache-dir` for pip
- **Django:** Same venv pattern as FastAPI, plus `collectstatic --noinput` build step, `DJANGO_SETTINGS_MODULE` env var
- **NestJS:** TypeScript compilation produces `dist/` directory, copy `dist/` + `node_modules` to runtime, `dumb-init`
- **ASP.NET Core:** `dotnet publish` with `--self-contained` option documented, project-file-first restore for layer caching
- **Go:** `CGO_ENABLED=0` for static binary, `gcr.io/distroless/static-debian12` runtime, `-ldflags="-s -w"` to strip debug info
- **Flask:** Same venv pattern as FastAPI/Django, simpler (no collectstatic equivalent)

### 3. Health Endpoints

Native health check mechanisms + Kubernetes probe YAML snippets.

| Framework | Health Mechanism | Liveness Path | Readiness Path |
|-----------|-----------------|---------------|----------------|
| Express/Fastify | Custom `/healthz` route (manual) | `/healthz` | `/healthz` or `/ready` |
| Next.js | Custom API route at `/api/health` | `/api/health` | `/api/health` |
| FastAPI | Custom route or `fastapi-health` package | `/health` | `/health` |
| Django | `django-health-check` package | `/health/` | `/health/` |
| NestJS | `@nestjs/terminus` health module | `/health` | `/health` |
| ASP.NET Core | `Microsoft.Extensions.Diagnostics.HealthChecks` | `/healthz` | `/ready` |
| Go | Custom `/healthz` handler (manual) | `/healthz` | `/ready` |
| Flask | Custom `/health` route (manual) | `/health` | `/health` |

Each pack includes:
- Required package/dependency installation (if applicable)
- Code snippet showing how to add the health endpoint
- Kubernetes `livenessProbe` and `readinessProbe` YAML with recommended `initialDelaySeconds`, `periodSeconds`, `timeoutSeconds`, `failureThreshold`
- `startupProbe` recommendation where startup is slow (Django with migrations, Next.js with build cache warming)

### 4. Database Profiles

How the framework manages database connections, with env var patterns for Azure services.

| Framework | DB Config Mechanism | Azure PostgreSQL Pattern |
|-----------|-------------------|------------------------|
| Express/Fastify | `pg` pool, Prisma, Sequelize, Knex | `DATABASE_URL` connection string |
| Next.js | Prisma (most common), direct pg | `DATABASE_URL` connection string |
| FastAPI | SQLAlchemy async + `asyncpg`, or Tortoise ORM | `DATABASE_URL` connection string |
| Django | `DATABASES` dict in settings, `dj-database-url` | `DATABASE_URL` parsed by `dj-database-url` |
| NestJS | TypeORM, Prisma, or MikroORM | `DATABASE_URL` or individual `DB_HOST`/`DB_PORT`/etc. |
| ASP.NET Core | Entity Framework Core, connection string in config | `ConnectionStrings__DefaultConnection` env var |
| Go | `database/sql` + driver, GORM, sqlx | `DATABASE_URL` or individual env vars |
| Flask | SQLAlchemy via Flask-SQLAlchemy | `DATABASE_URL` or `SQLALCHEMY_DATABASE_URI` |

Each pack includes:
- ConfigMap YAML template for the framework's env vars
- Azure PostgreSQL Flexible Server connection pattern (with and without Workload Identity)
- Common backing service env var patterns (Redis, Key Vault, Storage)

### 5. Writable Paths (DS012 Compliance)

Which directories need `emptyDir` volume mounts when `readOnlyRootFilesystem: true`.

| Framework | Writable Paths | Reason |
|-----------|---------------|--------|
| Express/Fastify | `/tmp` | Multer uploads, temp files |
| Next.js | `/tmp`, `/app/.next/cache` | ISR cache, image optimization cache |
| FastAPI | `/tmp` | Temp file uploads |
| Django | `/tmp`, `/app/staticfiles` (if serving static) | Temp files, collectstatic output (if runtime) |
| NestJS | `/tmp` | Temp files |
| ASP.NET Core | `/tmp` | Data protection keys, temp files |
| Go | (typically none) | Static binary, no writable paths needed |
| Flask | `/tmp` | Temp file uploads |

Each pack includes the volume mount YAML snippet.

### 6. Port Configuration

| Framework | Default Port | Config Override |
|-----------|-------------|----------------|
| Express/Fastify | 3000 | `PORT` env var (convention) |
| Next.js | 3000 | `PORT` env var or `-p` flag |
| FastAPI | 8000 | `--port` flag to uvicorn, or `PORT` env var |
| Django | 8000 | `--bind 0.0.0.0:8000` to gunicorn |
| NestJS | 3000 | `PORT` env var (from `main.ts`) |
| ASP.NET Core | 8080 | `ASPNETCORE_URLS` or `ASPNETCORE_HTTP_PORTS` env var |
| Go | 8080 | `PORT` env var (convention) |
| Flask | 5000 (dev), 8000 (gunicorn) | `--bind 0.0.0.0:8000` to gunicorn; Flask dev server uses 5000 but should never be used in production |

### 7. Build Commands

| Framework | Build Command | Output |
|-----------|--------------|--------|
| Express/Fastify | `npm run build` (if TypeScript) or none | `dist/` or source directly |
| Next.js | `npm run build` | `.next/` directory, `.next/standalone/` with standalone |
| FastAPI | None (interpreted) | Source directly |
| Django | `python manage.py collectstatic --noinput` | `staticfiles/` |
| NestJS | `npm run build` (TypeScript) | `dist/` |
| ASP.NET Core | `dotnet publish -c Release` | `publish/` directory |
| Go | `go build -ldflags="-s -w" -o /bin/app` | Single binary |
| Flask | None (interpreted) | Source directly |

### 8. Common Issues on AKS

Each pack includes a troubleshooting table with 4-6 entries in the format:

| Issue | Symptom | Fix |
|-------|---------|-----|
| (framework-specific) | (observable behavior) | (concrete fix) |

Key issues per framework:
- **Express/Fastify:** SIGTERM not handled (zombie processes), `ECONNRESET` under load
- **Next.js:** Image too large without standalone, ISR fails with read-only filesystem, `sharp` missing
- **FastAPI:** Uvicorn workers misconfigured, async DB pool exhaustion
- **Django:** `collectstatic` not run, `ALLOWED_HOSTS` not set, migrations not applied
- **NestJS:** Same signal handling issues as Express, TypeORM connection pool leak
- **ASP.NET Core:** Kestrel port binding on 80 instead of 8080, data protection keys lost on restart
- **Go:** Binary not statically linked (fails on distroless), DNS resolution issues with musl
- **Flask:** Running dev server in production, `SECRET_KEY` not set

## Files to Update

### 1. `phases/01-discover.md`

Update the "Currently available knowledge packs" list (around line 245) from:

```
Currently available knowledge packs:
- `spring-boot` -- Spring Boot (Java)
```

To include all 9 packs.

### 2. `SKILL.md`

Update the Knowledge Packs section (around line 57-59) to list all available packs instead of just referencing `spring-boot.md` as the example.

### 3. `README.md`

Rewrite the "Supported frameworks" section (around line 170-172) to distinguish two tiers:
- **Full support (knowledge pack):** Frameworks with dedicated knowledge packs providing Dockerfile optimizations, health endpoint config, database profiles, DS012 writable paths, and AKS troubleshooting
- **Base support (Dockerfile template):** Languages with multi-stage Dockerfile templates but no framework-specific knowledge pack

## File Inventory

New files (8):
```
skills/deploy-to-aks/knowledge-packs/frameworks/express.md
skills/deploy-to-aks/knowledge-packs/frameworks/nextjs.md
skills/deploy-to-aks/knowledge-packs/frameworks/fastapi.md
skills/deploy-to-aks/knowledge-packs/frameworks/django.md
skills/deploy-to-aks/knowledge-packs/frameworks/nestjs.md
skills/deploy-to-aks/knowledge-packs/frameworks/aspnet-core.md
skills/deploy-to-aks/knowledge-packs/frameworks/go.md
skills/deploy-to-aks/knowledge-packs/frameworks/flask.md
```

Modified files (3):
```
skills/deploy-to-aks/phases/01-discover.md
skills/deploy-to-aks/SKILL.md
README.md
```

Unchanged files (1):
```
skills/deploy-to-aks/knowledge-packs/frameworks/spring-boot.md
```

## Out of Scope

- Tier 3 frameworks (Quarkus, Rust/Actix/Axum) -- can be added later following the same pattern
- Changes to Dockerfile templates -- the existing 6 templates are sufficient; knowledge packs provide framework-specific guidance layered on top
- Changes to Phase 03 (containerize) or Phase 04 (scaffold) logic -- the knowledge pack loading mechanism in Phase 01 already feeds into these phases
- Changes to K8s manifest templates, Bicep templates, or GitHub Actions workflow
