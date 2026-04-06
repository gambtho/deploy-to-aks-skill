# Phase 1: Discover

Scan the developer's project to understand what they're building, what already exists, and what's needed for AKS deployment.

## Goal

Build a project profile without asking unnecessary questions. Auto-detect everything possible, then confirm and fill gaps.

---

## Step 1: Scan the Project

Scan the project root thoroughly. Collect all of the following categories in a single pass.

### 1.1 Framework Detection

Scan for signal files at the project root (and one level deep for monorepos). Map each signal to a framework and, where possible, a sub-framework:

| Signal File | Framework | Sub-framework Detection |
|---|---|---|
| `package.json` | Node.js | Inspect `dependencies` for: **Express** (`express`), **Fastify** (`fastify`), **NestJS** (`@nestjs/core`), **Next.js** (`next`), **Remix** (`@remix-run/node`), **Hono** (`hono`), **Koa** (`koa`) |
| `requirements.txt` | Python | Scan for: **FastAPI** (`fastapi`), **Django** (`django`), **Flask** (`flask`), **Starlette** (`starlette`), **Gunicorn** (`gunicorn`) |
| `pyproject.toml` | Python | Parse `[project.dependencies]` or `[tool.poetry.dependencies]` for the same libraries as above |
| `Pipfile` | Python | Parse `[packages]` section for the same libraries as above |
| `pom.xml` | Java | Search for `<artifactId>spring-boot-starter-web</artifactId>` → **Spring Boot**; `<artifactId>quarkus-resteasy</artifactId>` → **Quarkus**; `<artifactId>micronaut-http-server-netty</artifactId>` → **Micronaut** |
| `build.gradle` / `build.gradle.kts` | Java / Kotlin | Search for `org.springframework.boot` → **Spring Boot**; `io.quarkus` → **Quarkus**; `io.micronaut` → **Micronaut** |
| `go.mod` | Go | Parse `require` block for: `github.com/gin-gonic/gin` → **Gin**; `github.com/labstack/echo` → **Echo**; `github.com/gofiber/fiber` → **Fiber**; `net/http` (stdlib) → **net/http** |
| `*.csproj` | .NET | Search for `<PackageReference Include="Microsoft.AspNetCore.*"` → **ASP.NET Core**; check `<TargetFramework>` for version (e.g. `net8.0`) |
| `Cargo.toml` | Rust | Parse `[dependencies]` for: `actix-web` → **Actix**; `axum` → **Axum**; `rocket` → **Rocket**; `warp` → **Warp** |

**If multiple signal files are found** (e.g. both `package.json` and `requirements.txt`), record all of them — this may indicate a monorepo or polyglot project. Flag for clarification in Step 3.

### 1.2 Existing Infrastructure Detection

Look for files and directories that indicate the project already has deployment artifacts:

| Pattern | What It Indicates | Notes |
|---|---|---|
| `Dockerfile` | Container build already defined | Record base image, EXPOSE port, CMD/ENTRYPOINT |
| `docker-compose.yml` / `docker-compose.yaml` | Local dev services defined | Parse `services:` keys — these reveal backing services (Postgres, Redis, Mongo, etc.) |
| `k8s/` directory | Raw Kubernetes manifests exist | Scan for `Deployment`, `Service`, `Ingress`, `ConfigMap`, `Secret` kinds |
| `manifests/` directory | Raw Kubernetes manifests exist (alternate convention) | Same scan as `k8s/` |
| `deploy/` directory | Deployment scripts or manifests | Inspect contents — could be shell scripts, manifests, or Helm |
| `*.bicep` files | Azure Bicep IaC exists | Record resource types defined (e.g. `Microsoft.ContainerService/managedClusters`) |
| `helm/Chart.yaml` or `charts/*/Chart.yaml` | Helm chart exists | Record chart name, version, and `values.yaml` contents |
| `.github/workflows/*.yml` | GitHub Actions CI/CD exists | Scan for AKS deploy steps, Docker build steps, `az` CLI usage |
| `.azure-pipelines.yml` or `azure-pipelines/` | Azure DevOps CI/CD exists | Same scan as GitHub Actions |
| `terraform/*.tf` or `*.tf` in root | Terraform IaC exists | Scan for `azurerm_kubernetes_cluster`, `azurerm_container_registry`, and other Azure resources |
| `skaffold.yaml` | Skaffold dev workflow exists | Record build/deploy configuration |
| `kustomization.yaml` | Kustomize overlays exist | Record base and overlay structure |

### 1.3 Environment & Dependency Detection

Scan environment files and source code to detect backing services and Azure SDK usage.

**Environment files to scan:** `.env`, `.env.example`, `.env.template`, `.env.sample`, `.env.local`

| Env Var Pattern | Backing Service Detected | Default Azure Equivalent |
|---|---|---|
| `DATABASE_URL`, `POSTGRES_*`, `PG_*` | PostgreSQL | Azure Database for PostgreSQL Flexible Server |
| `MONGO_*`, `MONGODB_URI`, `MONGO_URL` | MongoDB | Azure Cosmos DB (MongoDB API) |
| `REDIS_*`, `REDIS_URL` | Redis | Azure Cache for Redis |
| `AZURE_STORAGE_*`, `STORAGE_ACCOUNT_*` | Azure Blob Storage | Azure Storage Account |
| `AZURE_OPENAI_*`, `OPENAI_API_*` | Azure OpenAI / OpenAI | Azure OpenAI Service |
| `RABBITMQ_*`, `AMQP_*` | RabbitMQ | Azure Service Bus |
| `KAFKA_*`, `KAFKA_BOOTSTRAP_*` | Kafka | Azure Event Hubs (Kafka protocol) |
| `MYSQL_*`, `MYSQL_URL` | MySQL | Azure Database for MySQL Flexible Server |
| `SQL_SERVER_*`, `MSSQL_*` | SQL Server | Azure SQL Database |
| `AZURE_SERVICE_BUS_*` | Azure Service Bus | Azure Service Bus |
| `AZURE_KEYVAULT_*`, `KEY_VAULT_*` | Azure Key Vault | Azure Key Vault |
| `APPLICATIONINSIGHTS_*`, `APPINSIGHTS_*` | Application Insights | Azure Monitor / Application Insights |

**Source code imports to scan** (check `src/`, `app/`, `lib/`, and root-level source files):

| Import Pattern | SDK / Service |
|---|---|
| `@azure/storage-blob` | Azure Blob Storage SDK |
| `@azure/identity` | Azure Identity (managed identity / service principal) |
| `@azure/keyvault-secrets` | Azure Key Vault SDK |
| `@azure/service-bus` | Azure Service Bus SDK |
| `@azure/cosmos` | Azure Cosmos DB SDK |
| `azure-storage-blob` (Python) | Azure Blob Storage SDK |
| `azure-identity` (Python) | Azure Identity SDK |
| `azure-keyvault-secrets` (Python) | Azure Key Vault SDK |
| `com.azure:azure-*` (Java) | Azure SDK for Java |
| `Azure.Storage.Blobs` (.NET) | Azure Blob Storage SDK |
| `Azure.Identity` (.NET) | Azure Identity SDK |

**docker-compose.yml service definitions** — parse the `services:` block and map images to backing services:

| Image Pattern | Backing Service |
|---|---|
| `postgres:*`, `postgis/*` | PostgreSQL |
| `mongo:*` | MongoDB |
| `redis:*` | Redis |
| `rabbitmq:*` | RabbitMQ |
| `mysql:*`, `mariadb:*` | MySQL / MariaDB |
| `mcr.microsoft.com/mssql/*` | SQL Server |
| `confluentinc/cp-kafka:*` | Kafka |
| `elasticsearch:*`, `opensearchproject/*` | Elasticsearch / OpenSearch |
| `memcached:*` | Memcached |

### 1.4 Port & Health Endpoint Detection

Determine the application's listen port and any existing health check endpoints.

**Port detection** — check these sources in priority order (first match wins):

| Source | What to Look For | Example |
|---|---|---|
| `Dockerfile` | `EXPOSE <port>` directive | `EXPOSE 3000` |
| `.env` / `.env.example` | `PORT=<number>` | `PORT=8080` |
| `package.json` (`scripts.start`) | `--port <number>` or `-p <number>` | `next start --port 3000` |
| Source code | `app.listen(<number>)`, `.listen(<number>)`, `server.port=<number>` | `app.listen(3000)` |
| `application.properties` / `application.yml` (Java) | `server.port=<number>` | `server.port=8080` |
| `appsettings.json` (.NET) | `"Urls": "http://*:<number>"` | `"Urls": "http://*:5000"` |
| Framework defaults | Use known defaults if nothing explicit found | Express: 3000, FastAPI: 8000, Spring Boot: 8080, ASP.NET: 5000, Gin: 8080 |

**Health endpoint detection** — grep the entire source tree for route registrations matching these patterns:

| Pattern | Endpoint Type |
|---|---|
| `/health` | Generic health check |
| `/healthz` | Kubernetes-style health check |
| `/ready`, `/readiness` | Readiness probe |
| `/liveness` | Liveness probe |
| `/startup` | Startup probe |
| `/ping` | Simple ping (sometimes used as health) |
| `/status` | Status endpoint |
| `/api/health`, `/api/healthz` | Prefixed health check |

Record the **HTTP method** (GET/HEAD) and **expected response code** (200) for each detected endpoint. If no health endpoints are found, flag this — Phase 2 will generate them.

---

## Step 2: Present Discovery Summary

After scanning, display a concise summary to the developer. Use the following format:

```
## Project Discovery Summary

**Framework:** <framework> (<sub-framework>)
**Entry Point:** <main file path>
**Detected Port:** <port> (source: <where detected>)

### Existing Infrastructure
- Dockerfile: <yes/no> <brief details if yes>
- Kubernetes manifests: <yes/no> <location if yes>
- Helm chart: <yes/no> <chart name if yes>
- CI/CD pipeline: <yes/no> <platform if yes>
- IaC (Terraform/Bicep): <yes/no> <brief details if yes>

### Backing Services
- <service 1>: detected via <source>
- <service 2>: detected via <source>
- (none detected)

### Health Endpoints
- <endpoint 1>: <method> <path> → <status code>
- (none detected — will generate in Phase 2)

### Azure SDK Usage
- <sdk 1>: <import location>
- (none detected)
```

Keep it factual. No recommendations yet — those come in Phase 2.

---

## Step 3: Ask Clarifying Questions

Only ask what could **not** be auto-detected. Use **multiple-choice** format. Ask **one question at a time** and wait for the response before proceeding to the next.

### Required Questions (always ask)

**Q1: Confirm detected stack**
> I detected **[framework/sub-framework]** with **[backing services]**. Is this correct?
> - (a) Yes, that's correct
> - (b) Mostly — let me correct: ___
> - (c) No, this is actually a ___ project

**Q2: Exposure type**
> How should this application be exposed?
> - (a) **Public** — internet-facing with a public IP / domain (e.g., customer-facing API or website)
> - (b) **Internal** — accessible only within a VNet / private network (e.g., internal microservice)
> - (c) **Both** — public ingress for some routes, internal for others

**Q3: AKS flavor**
> Which AKS flavor do you want?
> - (a) **AKS Automatic** (recommended) — Microsoft manages node pools, scaling, and many operational settings. Less config, faster setup. Best for most workloads.
> - (b) **AKS Standard** — you manage node pools, scaling policies, and more operational details. Better if you need fine-grained control.
> - (c) **Not sure** — I'll go with the recommended option (Automatic)

### Conditional Questions (ask only when triggered)

| Trigger | Question |
|---|---|
| Multiple signal files detected (monorepo suspected) | "I found multiple project roots: `[list]`. Which one are we deploying?" with options listing each detected project and an "All of them" option |
| `terraform/*.tf` files found | "I found existing Terraform config. Should I (a) extend it with AKS resources, (b) ignore it and create fresh Bicep/Terraform, or (c) let me review what's there first?" |
| `helm/Chart.yaml` found | "I found an existing Helm chart (`<chart-name>`). Should I (a) use and extend it, (b) replace it with a new chart, or (c) let me review it first?" |
| Existing `Dockerfile` found | "I found an existing Dockerfile. Should I (a) use it as-is, (b) let me optimize it for AKS, or (c) replace it entirely?" |
| Existing CI/CD pipeline found | "I found an existing CI/CD pipeline on `<platform>`. Should I (a) extend it with AKS deployment steps, (b) create a separate deployment workflow, or (c) ignore it?" |
| No backing services detected | "I didn't detect any databases or caches. Does this app need any backing services? (a) No, it's self-contained (b) Yes: ___" |

---

## Step 4: Handle Edge Cases

When scanning produces unexpected results, handle them gracefully:

| Scenario | Detection Criteria | Behavior |
|---|---|---|
| **Empty project (greenfield)** | No signal files found at all; project root contains no source code or only a README | Announce: "This looks like a new project. I'll switch to **greenfield flow** — I'll scaffold the app structure alongside the AKS infrastructure." Ask for desired framework and language before proceeding. |
| **Unknown framework** | Signal files found but no sub-framework match (e.g., `package.json` exists but no known web framework in dependencies) | Announce: "I found a `<signal file>` but couldn't identify a specific web framework. What framework/library does this project use?" Offer common options for the detected language. |
| **No env files** | No `.env*` files found and no docker-compose.yml | Announce: "I didn't find any environment files or docker-compose config. I'll rely on source code scanning for dependency detection." Continue with whatever was found in source imports. |
| **Static site / SPA** | `package.json` has `build` script producing `dist/` or `build/`, no server-side framework detected | Announce: "This looks like a static site or SPA. AKS is likely overkill — consider Azure Static Web Apps instead. Want to proceed with AKS anyway?" |
| **Monorepo with many services** | More than 3 project roots detected | Announce: "This looks like a monorepo with `<N>` services. Let's pick one to start with and I'll create a reusable pattern for the others." |
| **Binary / compiled project** | Only compiled artifacts found (`.jar`, `.dll`, `.exe`) with no source | Announce: "I only found compiled artifacts. I'll need to know the runtime and port to containerize this. What runtime does this use?" |
| **Pre-existing AKS config** | Terraform/Bicep already defines `azurerm_kubernetes_cluster` or Kubernetes manifests reference an AKS cluster | Announce: "It looks like this project already targets AKS. Should I (a) audit and improve the existing setup, (b) start fresh, or (c) deploy to a new cluster alongside the existing one?" |

---

## Step 5: Load Framework Knowledge Pack

After confirming the framework in Step 3, check if a knowledge pack exists for the detected framework:

```
knowledge-packs/frameworks/<framework>.md
```

Where `<framework>` is the lowercase framework name (e.g., `spring-boot`, `django`, `express`, `aspnet-core`).

**If a knowledge pack exists:** Read it and use the framework-specific guidance throughout subsequent phases:
- Phase 3 (Containerize): Use the pack's Dockerfile patterns and health endpoint configuration
- Phase 4 (Scaffold): Use the pack's probe settings, writable path requirements, env var patterns, and ConfigMap structure
- Phase 6 (Deploy): Use the pack's common issues table for troubleshooting

**If no knowledge pack exists:** Continue with generic templates. The skill works without a knowledge pack — packs enhance the output with framework-specific best practices but are not required.

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

---

## Output

By the end of Phase 1, the following data points **must** be known (either auto-detected or confirmed by the developer). If any are missing, do **not** proceed to Phase 2 — loop back and ask.

| Data Point | Source | Required |
|---|---|---|
| `framework` | Auto-detected from signal files | Yes |
| `sub_framework` | Auto-detected from dependency analysis | Yes (or "none" for stdlib-based apps) |
| `language_version` | Parsed from signal files (e.g., `engines.node`, `python_requires`, `<TargetFramework>`) | Yes |
| `entry_point` | Auto-detected (e.g., `main` in package.json, `main.py`, `Main.java`) | Yes |
| `port` | Auto-detected or asked | Yes |
| `exposure_type` | Asked (public / internal / both) | Yes |
| `aks_flavor` | Asked (Automatic / Standard) | Yes |
| `backing_services[]` | Auto-detected from env files, docker-compose, source imports | Yes (can be empty array) |
| `health_endpoints[]` | Auto-detected from source code route scanning | No (will generate if missing) |
| `existing_dockerfile` | Auto-detected | Yes (boolean) |
| `existing_k8s_manifests` | Auto-detected | Yes (boolean) |
| `existing_helm_chart` | Auto-detected | Yes (boolean) |
| `existing_cicd` | Auto-detected | Yes (boolean + platform name) |
| `existing_iac` | Auto-detected | Yes (boolean + tool name) |
| `azure_sdk_usage[]` | Auto-detected from source imports | No (informational) |
| `monorepo` | Auto-detected | Yes (boolean; if true, `deploy_target` path is also required) |
| `deploy_target` | Asked if monorepo | Conditional |

Once all required data points are collected, write them to the project profile and announce:

> **Phase 1 complete.** Proceeding to Phase 2: Architect.
