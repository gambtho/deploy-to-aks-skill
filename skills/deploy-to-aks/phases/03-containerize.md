# Phase 3: Containerize

## Goal

Ensure the project has a **production-ready Dockerfile** and `.dockerignore` that comply with AKS Deployment Safeguards and container best practices. By the end of this phase the application can be built into an OCI image suitable for deployment to Azure Kubernetes Service.

---

## Step 1 — Check for an Existing Dockerfile

Search the repository root for `Dockerfile`, `Dockerfile.*`, or `*.Dockerfile`.

### If a Dockerfile already exists

Validate it against the **Best-Practices Checklist** below. For every item that fails, note the specific line and the recommended fix. Present all findings to the user before making changes.

Also check for `.dockerignore` at the repository root. If it is missing, flag it — even if the Dockerfile passes all other checks, a missing `.dockerignore` means build context will include unnecessary files (`.git/`, `node_modules/`, etc.), slowing builds and potentially leaking secrets into the image. Proceed to Step 3 to generate it.

### If no Dockerfile exists

Generate one from the appropriate template in `templates/dockerfiles/` based on the framework detected in **Phase 1** (discovery). Proceed to Step 2.

---

## Best-Practices Checklist

Every production Dockerfile MUST satisfy these requirements. Each item explains **why** it matters.

| # | Practice | Why |
|---|----------|-----|
| 1 | **Multi-stage build** (separate `build` and `runtime` stages) | Reduces final image size by 60-80% by excluding compilers, build tools, and intermediate artifacts. Smaller images pull faster and have a smaller attack surface. |
| 2 | **Non-root `USER`** | AKS Deployment Safeguards policy **DS004** blocks containers that run as root. Running as a non-root user limits the blast radius of a container escape. |
| 3 | **Pinned base-image tags** (no `:latest`) | AKS Deployment Safeguards policy **DS009** warns on `:latest` tags because they are mutable — a rebuild can silently pull a breaking change. Pin to a specific version (e.g. `node:22-alpine`, `python:3.12-slim`). |
| 4 | **Layer caching — lockfile before source** | Copy the dependency lockfile (`package-lock.json`, `requirements.txt`, `go.sum`, etc.) and install dependencies *before* copying the rest of the source. This lets Docker cache the expensive install layer and only re-run it when dependencies actually change, cutting CI/CD build times significantly. |
| 5 | **`HEALTHCHECK` instruction** (or documented omission) | Kubernetes liveness and readiness probes need an endpoint or command to check. A Dockerfile `HEALTHCHECK` provides a sensible default and documents the contract for operators. If the base image lacks curl/wget (e.g., distroless, JRE Alpine, ASP.NET runtime), omit the `HEALTHCHECK` and add a comment explaining that Kubernetes probes handle health checking in AKS. |
| 6 | **`.dockerignore`** | Prevents `node_modules/`, `venv/`, `.git/`, build artifacts, and secrets from being sent to the build context. This speeds up builds and avoids accidentally baking credentials or bloat into the image. |

---

## Step 2 — Generate or Improve the Dockerfile

### Knowledge pack check

Before selecting a template, check if a knowledge pack was loaded in Phase 1 (`knowledge-packs/frameworks/<framework>.md`). If one exists, read its **Dockerfile patterns** and **health endpoint configuration** sections first — prefer the pack's framework-specific guidance over the generic template. The pack may specify a different base image, build command, or health check approach that is more appropriate for the framework.

### Template selection

Choose the template that matches the primary framework detected in Phase 1:

| Framework / Language | Template |
|----------------------|----------|
| Node.js (Express, Next.js, Fastify, etc.) | `templates/dockerfiles/node.Dockerfile` |
| Python (Flask, Django, FastAPI, etc.) | `templates/dockerfiles/python.Dockerfile` |
| Java (Spring Boot, Quarkus, etc.) | `templates/dockerfiles/java.Dockerfile` |
| Go (net/http, Gin, Echo, etc.) | `templates/dockerfiles/go.Dockerfile` |
| .NET (ASP.NET Core, Minimal API) | `templates/dockerfiles/dotnet.Dockerfile` |
| Rust (Actix, Axum, Rocket, etc.) | `templates/dockerfiles/rust.Dockerfile` |

### Customization

Replace **all** template placeholders with actual values from Phase 1 discovery:

- `{{APP_NAME}}` — the application/binary name
- `{{PORT}}` — the port the application listens on
- `{{ENTRY_POINT}}` — the main file, module, or binary to run
- `{{BUILD_CMD}}` — the project-specific build command
- `{{LOCKFILE}}` — the dependency lockfile name

If the existing Dockerfile already exists but fails checklist items, apply targeted fixes rather than replacing the entire file. Explain each change.

---

## Step 3 — Generate `.dockerignore`

Create or update `.dockerignore` at the repository root. Start with the universal entries, then add framework-specific ones.

### Universal entries (always include)

```
.git
.gitignore
.github
.vscode
.idea
*.md
LICENSE
docker-compose*.yml
.env
.env.*
**/*.log
```

### Framework-specific entries

| Framework | Additional entries |
|-----------|--------------------|
| **Node.js** | `node_modules`, `npm-debug.log*`, `coverage`, `.next`, `dist` (if rebuilding in container) |
| **Python** | `__pycache__`, `*.pyc`, `*.pyo`, `venv`, `.venv`, `.pytest_cache`, `*.egg-info` |
| **Java** | `target`, `.gradle`, `build`, `*.class`, `*.jar` (source JARs — the build stage creates the final one) |
| **Go** | `vendor` (if using module mode), `*.test`, `*.exe` |
| **.NET** | `bin`, `obj`, `*.user`, `*.suo`, `packages` |
| **Rust** | `target`, `*.pdb` |

---

## Step 4 — Optional Local Build Test

After the Dockerfile and `.dockerignore` are in place, **ask the user** if they want to verify the build locally.

> Would you like me to run a local Docker build to verify the image builds successfully?
> This will execute: `docker build -t {{APP_NAME}}:local .`

### Confirmation gate

**Do not run the build without explicit user approval.** The build may take several minutes and consume bandwidth pulling base images.

### If the user approves

```bash
docker build -t {{APP_NAME}}:local .
```

### On success

Report the image size (`docker images {{APP_NAME}}:local --format "{{.Size}}"`) and confirm the image is ready. Optionally offer to run a quick smoke test:

```bash
docker run --rm -p {{PORT}}:{{PORT}} {{APP_NAME}}:local
```

### On failure

Read the build output, identify the failing step, and propose a fix. Common issues:

- Missing build dependency in the build stage
- Incorrect `COPY` path or working directory
- Permission errors from the non-root user (ensure writable dirs are `chown`-ed before switching `USER`)

---

## Completion Criteria

Phase 3 is complete when:

- [ ] A Dockerfile exists and passes all six best-practices checklist items
- [ ] A `.dockerignore` exists with universal + framework-specific entries
- [ ] (Optional) A local `docker build` succeeds and produces a reasonably sized image

Proceed to **Phase 4 — Scaffold** to generate Kubernetes manifests and Bicep infrastructure.
