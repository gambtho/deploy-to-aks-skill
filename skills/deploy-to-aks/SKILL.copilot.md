---
name: deploy-to-aks
description: Use when deploying a web application or API to Azure Kubernetes Service, containerizing an app for AKS, or generating Kubernetes manifests and Bicep infrastructure for Azure
---

# Deploy to AKS


Guide developers through deploying applications to Azure Kubernetes Service (AKS) without requiring Kubernetes expertise. Reads the actual project, detects the framework, generates production-ready artifacts, and optionally executes the deployment.

## Checklist

You MUST track each of these items as a checklist and complete them in order:

1. **Discover** -- scan the project, detect framework/language/dependencies, ask clarifying questions
2. **Architect** -- plan infrastructure, show architecture diagram + cost estimate, get approval
3. **Containerize** -- generate or validate Dockerfile + .dockerignore
4. **Scaffold** -- generate K8s manifests + Bicep IaC, validate against Deployment Safeguards
5. **Pipeline** -- generate GitHub Actions CI/CD workflow, optionally configure OIDC
6. **Deploy** -- execute deployment with confirmation gates, show summary dashboard

## Process Flow

```dot
digraph deploy_flow {
    rankdir=LR;
    node [shape=box, style=rounded];

    discover [label="1. Discover"];
    architect [label="2. Architect\n(mermaid)"];
    containerize [label="3. Containerize"];
    scaffold [label="4. Scaffold\n(mermaid)"];
    pipeline [label="5. Pipeline"];
    deploy [label="6. Deploy\n(mermaid)"];

    discover -> architect;
    architect -> containerize [label="approved"];
    architect -> architect [label="iterate"];
    containerize -> scaffold;
    scaffold -> pipeline;
    pipeline -> deploy;
}
```

## Quick Deploy Mode

For developers who already have AKS infrastructure in place, a fast-path mode skips architecture design and infrastructure provisioning, going directly to containerization, deployment, and verification.

### Detection

Before starting the 6-phase flow, check for pre-existing infrastructure:

1. The developer explicitly asks for quick deploy (e.g., "deploy my app to my existing cluster", "I already have AKS set up")
2. `kubectl config current-context` returns an AKS context
3. `az aks show` succeeds for the current context's cluster

If any signal indicates existing infrastructure, offer quick deploy mode:

> I detected an existing AKS cluster (<cluster-name>). Would you like to use **quick deploy** mode? It skips infrastructure setup and gets your app deployed in ~5 minutes.
>
> - (a) **Yes, quick deploy** — I already have AKS, ACR, and identity set up
> - (b) **No, full setup** — walk me through the complete 6-phase flow

**Mode routing is a suggestion, not a gate.** The developer can always choose either path.

### Quick Phase Instructions

| Phase | Read | Also load |
|-------|------|-----------|
| Quick Deploy | [Quick Deploy](#quick-deploy-instructions) | the [<detected>](#knowledge-packs) section below (if exists), [Deployment Safeguards](#reference-deployment-safeguards), [Workload Identity](#reference-workload-identity) |

### To provision test infrastructure

Run `./scripts/setup-aks-prerequisites.sh` to create AKS Automatic + ACR + identity for testing. See `--help` for usage.

## Phase Instructions

At each phase, read the corresponding instruction file for detailed guidance:

| Phase | Read | Also load |
|-------|------|-----------|
| 1. Discover | [Phase 1: Discover](#phase-1-discover) | the [<detected>](#knowledge-packs) section below (if exists); [AKS Automatic](#reference-aks-automatic) or [AKS Standard](#reference-aks-standard) based on AKS flavor choice |
| 2. Architect | [Phase 2: Architect](#phase-2-architect) | [Cost Estimation](#reference-cost-estimation), [templates/mermaid/architecture-diagram.md](#templates-mermaid-diagrams) |
| 3. Containerize | [Phase 3: Containerize](#phase-3-containerize) | -- |
| 4. Scaffold | [Phase 4: Scaffold](#phase-4-scaffold) | [Deployment Safeguards](#reference-deployment-safeguards), [Workload Identity](#reference-workload-identity), [templates/mermaid/architecture-diagram.md](#templates-mermaid-diagrams) |
| 5. Pipeline | [Phase 5: Pipeline](#phase-5-pipeline) | -- |
| 6. Deploy | [Phase 6: Deploy](#phase-6-deploy) | [templates/mermaid/summary-dashboard.md](#templates-mermaid-diagrams) |

### Knowledge Packs

After detecting the framework in Phase 1, check `knowledge-packs/frameworks/` for a matching pack. Knowledge packs provide framework-specific guidance for Dockerfile patterns, health endpoints, database configuration, writable path requirements, and common deployment issues. If no pack exists for the detected framework, the skill continues with generic templates — packs enhance the output but are not required.

Available packs: `spring-boot`, `express`, `nextjs`, `fastapi`, `django`, `nestjs`, `aspnet-core`, `go`, `flask`

## Diagrams

This skill renders architecture diagrams as **mermaid code blocks** inline in the terminal — no browser or external dependencies required.

- **Phase 2:** Architecture diagram + cost estimate (template: [templates/mermaid/architecture-diagram.md](#templates-mermaid-diagrams))
- **Phase 4:** Re-render architecture diagram with actual resource names from generated Bicep/K8s files
- **Phase 6:** Deployment summary dashboard (template: [templates/mermaid/summary-dashboard.md](#templates-mermaid-diagrams))

Use terminal-native question prompts (not visual cards) when the developer faces a choice.

## Execution Model

- **Generate artifacts automatically** -- Dockerfiles, manifests, Bicep, workflows
- **Execute CLI commands only with confirmation** -- `az`, `docker`, `kubectl`, `gh`
- Show the exact command that will run and ask for explicit opt-in

## Adaptive Behavior

- **Detect before create** -- check for existing Dockerfiles, manifests, Bicep, CI/CD
- **Validate before replace** -- improve what exists rather than overwriting
- **Ask only what can't be auto-detected** -- minimize questions, maximize intelligence
- **Teach while fixing** -- when auto-fixing Safeguard violations, explain why

## Key Principles

- ONE concept per turn -- never overload the developer
- Progressive discovery -- ask incrementally, confirm as you go
- Sensible defaults -- AKS Automatic, Ingress (Web App Routing), Workload Identity, 2 replicas
- No Kubernetes jargon until Phase 4 -- frame AKS as a "scalable app platform"

## Housekeeping

At any point during execution, if the project has a `.gitignore`, check whether your agent working directory is excluded (e.g., `.claude/`, `.superpowers/`, `.opencode/`). If not, add it. These directories contain session-specific data and should never be committed to the repository.

## Quick Deploy Instructions

Deploy an application to an existing AKS cluster with production-grade artifacts.

## Goal

Detect the application framework and Azure infrastructure, generate production-ready deployment artifacts, validate against AKS Deployment Safeguards, deploy, and verify — with minimal questions.

---

## Section 1: Detection

Scan the project and Azure environment. Ask at most one clarifying question (only if genuinely ambiguous: multiple Dockerfiles, multiple ACRs, multiple identities).

### Framework Detection

Scan for signal files at the project root (and one level deep for monorepos):

| Signal File | Framework | Sub-framework Detection |
|---|---|---|
| `package.json` | Node.js | `express`, `fastify`, `@nestjs/core`, `next`, `@remix-run/node`, `hono`, `koa` |
| `requirements.txt` / `pyproject.toml` / `Pipfile` | Python | `fastapi`, `django`, `flask`, `starlette` |
| `pom.xml` / `build.gradle` / `build.gradle.kts` | Java | `spring-boot-starter-web`, `org.springframework.boot`, `quarkus-resteasy` |
| `go.mod` | Go | `gin-gonic/gin`, `labstack/echo`, `gofiber/fiber` |
| `*.csproj` | .NET | `Microsoft.AspNetCore.*` |
| `Cargo.toml` | Rust | `actix-web`, `axum` |

### Port Detection

Check in priority order (first match wins):

1. `Dockerfile` — `EXPOSE <port>`
2. `.env` / `.env.example` — `PORT=<number>`
3. Source code — `app.listen(<number>)`, `server.port=<number>`
4. Framework defaults — Express: 3000, FastAPI: 8000, Spring Boot: 8080, ASP.NET: 8080, Gin: 8080

### Health Endpoint Detection

Grep source tree for route registrations matching: `/health`, `/healthz`, `/ready`, `/readiness`, `/liveness`, `/startup`, `/ping`, `/api/health`, `/api/healthz`

If none found, use `/health` as default in probes.

### Existing Artifact Detection

Check for existing `Dockerfile` and `k8s/` (or `manifests/`, `deploy/`) directories.

### Azure Infrastructure Detection

```bash
kubectl config current-context
az aks show -g <rg> -n <cluster> -o json
```

Extract from cluster details:
- **AKS flavor**: `nodeProvisioningProfile.mode` — `"Auto"` = AKS Automatic, otherwise = AKS Standard
- **OIDC issuer**: `oidcIssuerProfile.issuerUrl`
- **Azure RBAC**: `aadProfile.enableAzureRBAC`

### Routing Detection

Determine whether the cluster uses Gateway API or Ingress — this applies to **both** AKS Automatic and Standard:

```bash
az aks show -g <rg> -n <cluster> --query 'ingressProfile.webAppRouting' -o json
```

- If `gatewayApiImplementations.appRoutingIstio.mode` is `"Enabled"` → use **Gateway API** (`gateway.yaml` + `httproute.yaml`, `gatewayClassName: istio`)
- Otherwise → use **Ingress** (`ingress.yaml`, `ingressClassName: webapprouting.kubernetes.azure.com`)

> **Note:** AKS Automatic defaults to NGINX/Ingress (same as Standard). Gateway API via Istio is an optional mode on both flavors.

If `ingressProfile.webAppRouting.enabled` is not `true`, stop with error and provide the enable command: `az aks approuting enable -g <rg> -n <cluster>`

```bash
az acr list -g <rg> -o json
az identity list -g <rg> -o json
```

**RBAC check** — if Azure RBAC is enabled:

```bash
kubectl auth can-i create namespaces
```

If `no`, stop with error. Offer alternatives: provision a cluster without Azure RBAC, have admin create the namespace, or deploy to an existing namespace.

If any Azure CLI or kubectl command fails during detection, stop with the error and suggest common fixes: `az login`, `az account set -s <subscription-id>`, `az aks get-credentials -g <rg> -n <cluster>`.

### Knowledge Pack

After framework detection, load the matching pack from `knowledge-packs/frameworks/` if available:

`spring-boot`, `express`, `nextjs`, `fastapi`, `django`, `nestjs`, `aspnet-core`, `go`, `flask`

Knowledge packs influence Dockerfile optimization, probe configuration, and writable path requirements.

---

## Section 2: File Generation

Write all files in a single response turn (batch file writes).

### Dockerfile

**If existing Dockerfile:** Validate against best practices (multi-stage build, non-root USER, pinned base tags, layer caching, .dockerignore). Apply targeted fixes for failures.

**If no Dockerfile:** Generate from the appropriate template:

| Language | Template |
|----------|----------|
| Node.js | [templates/dockerfiles/node.Dockerfile](#templates-dockerfiles) |
| Python | [templates/dockerfiles/python.Dockerfile](#templates-dockerfiles) |
| Java | [templates/dockerfiles/java.Dockerfile](#templates-dockerfiles) |
| Go | [templates/dockerfiles/go.Dockerfile](#templates-dockerfiles) |
| .NET | [templates/dockerfiles/dotnet.Dockerfile](#templates-dockerfiles) |
| Rust | [templates/dockerfiles/rust.Dockerfile](#templates-dockerfiles) |

Generate `.dockerignore` if missing.

### Kubernetes Manifests

Generate from `templates/k8s/` templates. Replace `<angle-bracket>` placeholders with detected values.

| Manifest | Template | Notes |
|----------|----------|-------|
| `k8s/namespace.yaml` | [templates/k8s/namespace.yaml](#templates-kubernetes-manifests) | |
| `k8s/serviceaccount.yaml` | [templates/k8s/serviceaccount.yaml](#templates-kubernetes-manifests) | Workload Identity annotation |
| `k8s/deployment.yaml` | [templates/k8s/deployment.yaml](#templates-kubernetes-manifests) | Image placeholder resolved at deploy time |
| `k8s/service.yaml` | [templates/k8s/service.yaml](#templates-kubernetes-manifests) | |
| `k8s/gateway.yaml` | [templates/k8s/gateway.yaml](#templates-kubernetes-manifests) | Only if Istio Gateway API detected |
| `k8s/httproute.yaml` | [templates/k8s/httproute.yaml](#templates-kubernetes-manifests) | Only if Istio Gateway API detected |
| `k8s/ingress.yaml` | [templates/k8s/ingress.yaml](#templates-kubernetes-manifests) | Only if using Ingress (default for both flavors) |
| `k8s/hpa.yaml` | [templates/k8s/hpa.yaml](#templates-kubernetes-manifests) | min: 2, max: 10 |
| `k8s/pdb.yaml` | [templates/k8s/pdb.yaml](#templates-kubernetes-manifests) | minAvailable: 1 |
| `k8s/configmap.yaml` | [templates/k8s/configmap.yaml](#templates-kubernetes-manifests) | Only if app needs environment-specific config |

---

## Section 3: Safeguards Validation

Before deploying, validate all generated manifests against AKS Deployment Safeguards DS001-DS013. Reference [Deployment Safeguards](#reference-deployment-safeguards) for the full checklist.

- 12 of 13 rules are auto-fixable. DS009 (no `:latest` tag) is resolved by tagging with git SHA.
- Apply framework-specific writable path requirements from the knowledge pack (e.g., Spring Boot needs `/tmp`, Next.js needs `/app/.next/cache`).
- Reference [Workload Identity](#reference-workload-identity) for Workload Identity configuration.

**AKS Automatic:** Safeguards are always enforced — all violations must be fixed.

**AKS Standard:** Check `safeguardsProfile.level`:
```bash
az aks show -g <rg> -n <cluster> --query 'safeguardsProfile.level' -o tsv
```
- `Enforcement`: fix all violations
- `Warning` or `Off`: mention issues as warnings, don't block

---

## Section 4: Deploy

### Ensure kubectl context

```bash
az aks get-credentials -g <resource_group> -n <aks_cluster_name> --overwrite-existing
```

### Verify Gateway API CRDs (only if Istio Gateway API detected)

```bash
kubectl get crd gateways.gateway.networking.k8s.io httproutes.gateway.networking.k8s.io 2>/dev/null
```

If missing: `kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml`

### Build and push

```bash
IMAGE_TAG=$(git rev-parse --short HEAD)   # fallback: date +%Y%m%d%H%M%S
az acr build --registry <acr_name> --image <app-name>:$IMAGE_TAG --file Dockerfile .
```

### Deploy to cluster

```bash
# 1. Create namespace (must succeed before proceeding)
kubectl apply -f k8s/namespace.yaml
kubectl get namespace <namespace> -o name   # verify

# 2. Apply remaining manifests
kubectl apply -f k8s/ --recursive

# 3. Wait for rollout
kubectl rollout status deployment/<app-name> -n <namespace> --timeout=300s
```

If any step fails, show the error and stop.

---

## Section 5: Verify

```bash
kubectl get pods -n <namespace> -l app=<app-name>
kubectl get gateway -n <namespace> -o jsonpath='{.items[0].status.addresses[0].value}'  # if Gateway API
kubectl get ingress -n <namespace> -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}'  # if Ingress
```

Wait up to 3 minutes for external IP. Once available, curl the health endpoint.

## Phase 1: Discover

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

## Phase 2: Architect

## Goal

Present the full infrastructure plan **visually** before generating any Bicep or workflow files. The developer must see exactly what will be provisioned, how services connect, and what it will cost — then explicitly approve before proceeding.

**No files are generated in this phase.** This phase produces only a visual diagram, a cost estimate, and developer approval.

---

## Step 1: Select Azure Services

Using the application profile collected in Phase 1 (backing services, app type, scale expectations), map each need to a concrete Azure resource. Use the decision matrix below.

### Service Decision Matrix

| Application Need | Azure Service | Dev Tier | Production Tier |
|---|---|---|---|
| App hosting | AKS | Automatic (simplest) or Standard (if developer chose) | Same — tier choice persists |
| Container registry | Azure Container Registry (ACR) | Basic | Standard |
| PostgreSQL database | Azure Database for PostgreSQL Flexible Server | Burstable B1ms (1 vCore, 2 GiB) | General Purpose D2s_v3 (2 vCores, 8 GiB) |
| MongoDB database | Azure Cosmos DB (MongoDB API) | Serverless | Provisioned (400+ RU/s) |
| Redis / caching | Azure Cache for Redis | Basic C0 (250 MB) | Standard C1 (1 GB, replicated) |
| Secrets / key management | Azure Key Vault | Standard | Standard |
| Blob / file storage | Azure Storage Account | Standard LRS | Standard ZRS |
| Monitoring (always included) | Log Analytics Workspace + Application Insights | Per-GB ingestion (5 GB free) | Per-GB ingestion (5 GB free) |
| Container identity | Managed Identity (User-Assigned) | Free | Free |

### Selection Rules

1. **AKS + ACR + Monitoring are always selected.** Every deployment gets these three.
2. **Managed Identity is always selected.** Workload Identity federation is the only supported auth pattern — no connection strings in environment variables.
3. **Key Vault is selected whenever the app has secrets** (API keys, third-party credentials, certificates). If the only secrets are Azure service connections, Workload Identity handles those and Key Vault can be omitted.
4. **Only select backing services the app actually uses.** Do not provision a PostgreSQL server for an app that has no database.
5. **Default to dev tiers.** Only use production tiers if the developer explicitly requests production-grade infrastructure or indicates high availability requirements.
6. **Document every selection.** Record each service, its tier, and the reason it was selected in a structured list that will feed into the cost estimate.

### Output: Selected Services List

After applying the matrix, produce a list in this format (store in memory for subsequent steps):

```
Selected Services:
- AKS Automatic (control plane + 2 vCPU compute) — app hosting
- ACR Basic — container image storage
- PostgreSQL Flexible Server Burstable B1ms — primary database (detected in Phase 1)
- Azure Cache for Redis Basic C0 — session store (detected in Phase 1)
- Key Vault Standard — app holds third-party API keys
- Managed Identity (User-Assigned) — workload identity for all service connections
- Log Analytics + Application Insights — monitoring (always included)
```

---

## Step 2: Generate Architecture Diagram

Generate a mermaid architecture diagram so the developer can see the full topology before any infrastructure code is written.

### 2a: Read the Template

Read the file [templates/mermaid/architecture-diagram.md](#templates-mermaid-diagrams) from the skill's directory. This template contains a mermaid flowchart with placeholder tokens.

### 2b: Replace Placeholders

Substitute every placeholder with actual values derived from Phase 1 discovery and Step 1 selections:

| Placeholder | Source | Example |
|---|---|---|
| `{{APP_NAME}}` | Application name from Phase 1 | `contoso-api` |
| `{{ACR_NAME}}` | Derived: app name sanitized for ACR (lowercase, no hyphens, 5-50 chars) | `contosoapiacr` |
| `{{AKS_TYPE}}` | Developer's AKS mode choice | `Automatic` or `Standard` |
| `{{AKS_CLUSTER_NAME}}` | Derived: `aks-{app-name}` | `aks-contoso-api` |
| `{{RESOURCE_GROUP}}` | Derived: `rg-{app-name}` | `rg-contoso-api` |
| `{{NAMESPACE}}` | Kubernetes namespace for the app | `contoso-api` |
| `{{BACKING_SERVICES}}` | Comma-separated list of Azure backing services | `PostgreSQL, Redis, Key Vault` |
| `{{INGRESS_TYPE}}` | `Gateway API` if Istio enabled, `Ingress Controller` otherwise (default) | `Ingress Controller` |
| `{{ENVIRONMENT}}` | `dev` or `production` | `dev` |

### 2c: Diagram Topology Requirements

The generated diagram **must** show:

1. **External users** on the left, with an arrow into the cluster boundary.
2. **Ingress layer** — labeled "Gateway API" (if Istio enabled) or "Ingress Controller / Load Balancer" (default for both flavors) — as the entry point inside the cluster boundary.
3. **AKS cluster boundary** — a visible box labeled with the cluster name and AKS type containing:
   - The ingress layer.
   - One or more **Deployment** boxes (one per container/service discovered in Phase 1).
   - A **Managed Identity** badge attached to the deployments.
4. **ACR** — positioned above or beside the cluster box, with:
   - A "push" arrow from GitHub Actions (CI/CD) to ACR.
   - A "pull" arrow from ACR into the AKS cluster.
5. **Backing Azure services** — each as a separate box outside the cluster boundary (PostgreSQL, Cosmos DB, Redis, Key Vault, Storage, etc.), connected to the relevant Deployment(s) via dashed arrows labeled "Workload Identity".
6. **Monitoring** — Log Analytics + Application Insights shown as a box receiving telemetry from the cluster and backing services.

### 2d: Render the Diagram

Output the fully-resolved mermaid diagram as a fenced code block in the terminal. The developer sees the architecture inline — no browser required.

If the diagram is complex (many backing services), also output a simplified text version as a fallback.

### 2e: Validate

After rendering, verify the mermaid syntax is valid by checking that all node references are consistent (no dangling edges to undefined nodes). If a backing service was removed from the architecture contract, ensure its node and edges are also removed from the diagram.

---

## Step 3: Compute Cost Estimate

### 3a: Load Pricing Reference

Read the file [Cost Estimation](#reference-cost-estimation) from the skill's directory. This contains per-service monthly cost estimates for dev and production tiers.

### 3b: Sum Selected Services

For each service selected in Step 1, look up its monthly cost from the reference. Apply these rules:

1. **Always include AKS control plane cost** (Automatic: ~$117/mo, Standard: ~$73/mo).
2. **Always include default compute** — assume 2 vCPU / 4 GiB baseline unless the developer specified otherwise. Use the per-vCPU cost from the reference.
3. **Always include ACR** at the selected tier.
4. **Always include monitoring** — assume 5 GB/month ingestion (within free tier) unless the developer expects higher volume.
5. **Add each backing service** at its selected tier.
6. **Round each line item to the nearest dollar.**
7. **Sum for a total monthly estimate.**

### 3c: Format the Estimate

Produce a cost breakdown in table format:

```
┌─────────────────────────────────────────────┬───────────┐
│ Service                                     │ Est. $/mo │
├─────────────────────────────────────────────┼───────────┤
│ AKS Automatic (control plane)               │      $117 │
│ Compute (2 vCPU / 4 GiB)                   │       $44 │
│ ACR Basic                                   │        $5 │
│ PostgreSQL Flexible Server (B1ms)           │       $13 │
│ Azure Cache for Redis (Basic C0)            │       $16 │
│ Key Vault (estimated ops)                   │        $1 │
│ Managed Identity                            │     Free  │
│ Log Analytics (≤5 GB free tier)             │     Free  │
│ Application Insights (≤5 GB free tier)      │     Free  │
├─────────────────────────────────────────────┼───────────┤
│ TOTAL (estimated)                           │     ~$196 │
└─────────────────────────────────────────────┴───────────┘
```

**Always append the disclaimer:** *Costs are estimates based on published Azure pricing. Actual costs depend on usage. Verify at [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/).*

---

## Step 4: Present to Developer

### 4a: Show the Diagram

The mermaid diagram was already rendered inline in Step 2d. Reference it here — do not re-render unless the developer requested changes in Step 5.

### 4b: Terminal Summary

Print a concise summary in the terminal covering:

1. **Selected services** — bulleted list with tier and purpose.
2. **Architecture highlights** — e.g., "Traffic enters via Gateway API, routed to 1 deployment in namespace `contoso-api`. PostgreSQL and Redis accessed via Workload Identity. Images pulled from ACR `contosoapiacr`."
3. **Cost estimate table** — the table from Step 3.
4. **Explicit prompt:** "Review the architecture diagram and cost estimate above. Do you want to make any changes, or shall I proceed to Phase 3 (Containerize)?"

---

## Step 5: Iterate

If the developer requests changes:

1. **Update the selected services list** — add, remove, or change tiers as requested.
2. **Regenerate the architecture diagram** — repeat Step 2 with the updated topology.
3. **Recompute the cost estimate** — repeat Step 3 with the updated services.
4. **Re-present** — repeat Step 4.

Common change requests:
- "Switch to AKS Standard" → update AKS type, adjust control plane cost. Ingress type stays the same unless Istio mode changes.
- "Drop Redis" → remove from services, diagram, and cost.
- "Add blob storage" → add Storage Account to services, diagram, and cost.
- "Use production tiers" → upgrade all tiers, recompute costs.
- "That's too expensive" → suggest dropping optional services or switching to cheaper tiers; recompute.

Loop through Steps 1-4 until the developer is satisfied. There is no limit on iterations.

---

## Step 6: Get Approval

### HARD GATE

**Do NOT proceed to Phase 3 until the developer gives explicit approval.**

Acceptable approval signals:
- "Looks good, proceed"
- "Approved"
- "Go ahead"
- "LGTM"
- "Yes, generate the files"
- Any clear affirmative that references proceeding or generating

**Not** acceptable:
- Silence (do not assume approval — ask again)
- "Maybe" or "I think so" (ask for a definitive yes/no)
- "Let me think about it" (wait)
- Asking an unrelated question (answer it, then re-prompt for approval)

### On Approval

When the developer approves:

1. Record the final selected services list, tiers, AKS type, and all derived names as the **Architecture Contract**. This contract is the single source of truth for Phase 3.
2. Confirm: "Architecture approved. Moving to Phase 3: Containerize."
3. Transition to Phase 3.

### On Rejection

If the developer says "stop", "cancel", or "start over":

1. Confirm whether they want to restart from Phase 1 or just redo Phase 2.
2. Act accordingly.

## Phase 3: Containerize

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

### Template selection

Choose the template that matches the primary framework detected in Phase 1:

| Framework / Language | Template |
|----------------------|----------|
| Node.js (Express, Next.js, Fastify, etc.) | [templates/dockerfiles/node.Dockerfile](#templates-dockerfiles) |
| Python (Flask, Django, FastAPI, etc.) | [templates/dockerfiles/python.Dockerfile](#templates-dockerfiles) |
| Java (Spring Boot, Quarkus, etc.) | [templates/dockerfiles/java.Dockerfile](#templates-dockerfiles) |
| Go (net/http, Gin, Echo, etc.) | [templates/dockerfiles/go.Dockerfile](#templates-dockerfiles) |
| .NET (ASP.NET Core, Minimal API) | [templates/dockerfiles/dotnet.Dockerfile](#templates-dockerfiles) |
| Rust (Actix, Axum, Rocket, etc.) | [templates/dockerfiles/rust.Dockerfile](#templates-dockerfiles) |

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

## Phase 4: Scaffold

## Goal

Generate production-ready Kubernetes manifests and Bicep infrastructure modules for the
architecture approved in Phase 2 (Architect). Every generated manifest must pass all 13 AKS
Deployment Safeguard rules. Every Bicep module must compose cleanly through a single
`main.bicep` entry point.

---

## Step 1 — Check for Existing Manifests

Before generating anything, scan the workspace for files that already exist.

**Search patterns:**
- `k8s/**/*.yaml` and `k8s/**/*.yml`
- `manifests/**/*.yaml` and `manifests/**/*.yml`
- `*.bicep` and `infra/**/*.bicep`
- `deploy/**/*`

**If existing files are found:**
1. List every discovered file with a one-line description of what it contains.
2. Ask the user: *"I found existing manifests. Should I (a) extend them, (b) replace
   them, or (c) generate new files alongside them?"*
3. Wait for confirmation before proceeding.

**If no files are found:**
- Continue to Step 2.

---

## Step 2 — Generate Kubernetes Manifests

Generate manifests **one file at a time** in the `k8s/` directory. After writing each
file, briefly explain what was generated and why.

### Generation order

1. `k8s/namespace.yaml` — if the target namespace is not `default`
   (reference: [templates/k8s/namespace.yaml](#templates-kubernetes-manifests))
2. `k8s/serviceaccount.yaml` — with Workload Identity annotation
   (reference: [templates/k8s/serviceaccount.yaml](#templates-kubernetes-manifests))
3. `k8s/deployment.yaml` — full Deployment
   (reference: [templates/k8s/deployment.yaml](#templates-kubernetes-manifests))
4. `k8s/service.yaml` — ClusterIP Service
   (reference: [templates/k8s/service.yaml](#templates-kubernetes-manifests))
5. `k8s/gateway.yaml` — Gateway resource (only if Istio Gateway API is enabled)
   OR `k8s/ingress.yaml` — Ingress resource (default for both AKS Automatic and Standard)
   (reference: [templates/k8s/gateway.yaml](#templates-kubernetes-manifests), [templates/k8s/httproute.yaml](#templates-kubernetes-manifests),
   or [templates/k8s/ingress.yaml](#templates-kubernetes-manifests))
6. `k8s/httproute.yaml` — HTTPRoute (only if Gateway was generated)
7. `k8s/hpa.yaml` — HorizontalPodAutoscaler
   (reference: [templates/k8s/hpa.yaml](#templates-kubernetes-manifests))
8. `k8s/pdb.yaml` — PodDisruptionBudget
   (reference: [templates/k8s/pdb.yaml](#templates-kubernetes-manifests))
9. `k8s/configmap.yaml` — ConfigMap for non-secret configuration (if the app requires
   environment-specific config values)
   (reference: [templates/k8s/configmap.yaml](#templates-kubernetes-manifests))

### Template usage

For each manifest:
1. Read the corresponding template from `templates/k8s/`.
2. Replace all `# REPLACE:` placeholders with actual values from the approved architecture.
3. Write the final manifest to `k8s/`.

---

## Step 3 — Validate Against Deployment Safeguards

After generating **all** Kubernetes manifests, validate every file against all 13
Deployment Safeguard rules.

### Procedure

1. Read [Deployment Safeguards](#reference-deployment-safeguards) to load all rules.
2. For each manifest file in `k8s/`:
   a. Check every applicable rule (DS001–DS013).
   b. Record any violations found.
3. For each violation:
   a. If auto-fixable (see safeguards reference): fix it in-place and note the fix.
   b. If not auto-fixable (DS009): flag it for the user with an explanation.
4. Present a summary table:

```
| File                  | Rule  | Status | Action Taken         |
|-----------------------|-------|--------|----------------------|
| k8s/deployment.yaml   | DS001 | PASS   | —                    |
| k8s/deployment.yaml   | DS009 | FLAG   | User must set image tag |
| ...                   | ...   | ...    | ...                  |
```

5. If any non-auto-fixable violations remain, ask the user to resolve them before
   continuing to Step 4.

### Rule applicability

Not every rule applies to every resource kind:

| Rule | Applies to |
|------|-----------|
| DS001–DS004, DS008, DS009, DS011, DS012 | Deployments, StatefulSets, DaemonSets, Jobs |
| DS005–DS007 | Deployments, StatefulSets, DaemonSets |
| DS010 | Deployments |
| DS013 | Deployments, StatefulSets, DaemonSets |

Skip rules that don't apply to the resource kind being checked.

---

## Step 4 — Generate Bicep Modules

Generate Bicep infrastructure modules **one file at a time** in the `infra/` directory.

### Output directory layout

The skill's Bicep templates are flat files in `templates/bicep/`. When generating the target project's infrastructure, reorganize them into a nested structure:

```
infra/
├── main.bicep              ← orchestrator (from templates/bicep/main.bicep)
├── main.bicepparam         ← parameter file with environment-specific values
└── modules/
    ├── aks.bicep           ← from templates/bicep/aks.bicep
    ├── acr.bicep           ← from templates/bicep/acr.bicep
    ├── identity.bicep      ← from templates/bicep/identity.bicep
    └── [backing-service].bicep  ← only modules for services in the architecture contract
```

`main.bicep` and `main.bicepparam` go in `infra/`. All other modules go in `infra/modules/`. The `main.bicep` references modules via relative paths (e.g., `'modules/aks.bicep'`).

### Generation order

1. `infra/main.bicep` — orchestrator that composes all modules
   (reference: [templates/bicep/main.bicep](#templates-bicep-modules))
2. `infra/main.bicepparam` — parameter file with environment-specific values
   (reference: [templates/bicep/main.bicepparam](#templates-bicep-modules))
3. `infra/modules/aks.bicep` — AKS cluster (reference: [templates/bicep/aks.bicep](#templates-bicep-modules))
4. `infra/modules/acr.bicep` — Azure Container Registry
   (reference: [templates/bicep/acr.bicep](#templates-bicep-modules))
5. `infra/modules/keyvault.bicep` — Key Vault (if architecture includes secrets)
   (reference: [templates/bicep/keyvault.bicep](#templates-bicep-modules))
6. `infra/modules/postgresql.bicep` — PostgreSQL Flexible Server (if architecture
   includes a database) (reference: [templates/bicep/postgresql.bicep](#templates-bicep-modules))
7. `infra/modules/identity.bicep` — Managed Identity + Federated Credential
   (reference: [templates/bicep/identity.bicep](#templates-bicep-modules))
8. `infra/modules/redis.bicep` — Azure Cache for Redis (if architecture includes caching)
   (reference: [templates/bicep/redis.bicep](#templates-bicep-modules))
9. Additional modules as required by the approved architecture.

### Module selection rule

**Only generate Bicep modules for services listed in the approved architecture contract from Phase 2.** If the architecture contract does not include a database, do not generate `postgres.bicep`. If it does not include secrets management, do not generate `keyvault.bicep`. If it does not include caching, do not generate `redis.bicep`.

When customizing `main.bicep` from the template, **remove conditional module blocks** for services that are not in the architecture contract. Do not leave dead `module` declarations with `if (false)` or commented-out blocks — remove them entirely so the Bicep is clean and readable.

### Template usage

Same process as Kubernetes manifests:
1. Read the corresponding template from `templates/bicep/`.
2. Replace placeholders with actual values.
3. Wire the module into `main.bicep` with correct parameter passing.
4. Write the final module to `infra/modules/`.

### Composition rule

`main.bicep` must be the **single entry point**. Every module is invoked from
`main.bicep` using `module` declarations with explicit parameter passing. No module
should reference another module directly — all cross-module dependencies flow through
`main.bicep` outputs/parameters.

---

## Step 5 — Update Architecture Diagram

Update the architecture diagram (from Phase 2) with actual resource
names now that manifests have been generated.

### What to update

- Replace placeholder names with actual resource names (e.g., `<app-name>` → `order-api`)
- Add Kubernetes resource types next to each component (e.g., `Deployment`, `Service`)
- Add Azure resource names (e.g., `rg-myapp-prod`, `aks-myapp-prod`)
- Annotate networking paths with actual port numbers and route paths

### Format

Re-render the mermaid architecture diagram (from [templates/mermaid/architecture-diagram.md](#templates-mermaid-diagrams)) with actual resource names so the developer
can see the updated topology inline.

---

## Output Structure

After this phase completes, the workspace should contain:

```
k8s/
├── namespace.yaml          (if non-default namespace)
├── serviceaccount.yaml
├── deployment.yaml
├── service.yaml
├── gateway.yaml            (if Istio Gateway API enabled)
│   └── httproute.yaml
│   OR
├── ingress.yaml            (default — both AKS Automatic and Standard)
├── hpa.yaml
└── pdb.yaml

infra/
├── main.bicep
├── main.bicepparam
└── modules/
    ├── aks.bicep
    ├── acr.bicep
    ├── identity.bicep
    ├── keyvault.bicep       (if needed)
    └── postgresql.bicep     (if needed)
```

---

## Completion Criteria

This phase is complete when:
- [ ] All Kubernetes manifests are generated and pass all 13 Deployment Safeguard rules
- [ ] All Bicep modules are generated and compose through `main.bicep`
- [ ] The architecture diagram is updated with actual resource names
- [ ] The user has confirmed the scaffold looks correct

## Phase 5: Pipeline

## Goal

Generate a GitHub Actions workflow for CI/CD and optionally configure OIDC federation for passwordless Azure authentication.

---

## Step 1: Check for existing workflows

Scan `.github/workflows/` for any existing workflow files.

- **If a deploy workflow already exists** — validate its structure, check for correctness against current infrastructure values, and extend it rather than replacing it.
- **If only a build/test workflow exists** — add a new deployment workflow alongside it. Do not modify the existing build/test workflow.
- **If no workflows exist** — create `.github/workflows/` directory and generate a fresh deploy workflow.

Search for existing workflow files matching `**/.github/workflows/*.yml` and `**/.github/workflows/*.yaml`. Read any matches and summarize what they do before proceeding.

---

## Step 2: Generate deploy workflow

Reference [templates/github-actions/deploy.yml](#templates-github-actions) from this skill.

Customize all placeholders with real values discovered in Phase 1 and scaffolded in Phase 4:

| Placeholder       | Source                                      |
| ----------------- | ------------------------------------------- |
| `__ACR_NAME__`    | ACR name from Phase 2 architecture contract |
| `__AKS_CLUSTER__` | AKS cluster name from Phase 2 architecture contract |
| `__RG_NAME__`     | Resource group from Phase 2 architecture contract |
| `__NAMESPACE__`   | Kubernetes namespace from Phase 4 scaffold  |
| `__APP_NAME__`    | Application name from Phase 1               |

### Workflow filename

Choose the filename based on what already exists in `.github/workflows/`:

- **No existing deploy workflow:** use `deploy.yml`
- **Existing workflow named `deploy.yml`:** use `deploy-aks-<flavor>.yml` (e.g., `deploy-aks-automatic.yml`)
- **Developer chose to create alongside existing workflows (Phase 1):** use `deploy-aks-<flavor>.yml` to avoid any naming collision

Write the customized workflow to `.github/workflows/<chosen-filename>`.

Show the developer the final workflow content and confirm before writing.

---

## Step 3: Explain OIDC

Before offering OIDC setup, explain why it is the recommended approach:

- **No passwords to rotate** — federated credentials use short-lived tokens issued by Azure AD, eliminating the need for client secrets with expiration dates.
- **Time-limited tokens** — each token is scoped to a single workflow run and expires automatically, reducing the blast radius of any compromise.
- **No secret sprawl** — only three non-sensitive IDs are stored in GitHub (client ID, tenant ID, subscription ID), none of which grant access on their own.
- **Azure AD-backed** — authentication flows through Azure AD's full policy engine, including conditional access and audit logging.

---

## Step 4: Optional OIDC setup

Ask the developer: *"Would you like to configure OIDC federation for passwordless Azure auth from GitHub Actions?"*

If yes, proceed through each command below with a **confirmation gate** — show the command, explain what it does, and wait for approval before executing. The developer can choose to run any command manually instead.

### 4a. Create Azure AD application

```bash
az ad app create --display-name "<app-name>-github-deploy"
```

Capture the `appId` from the output for subsequent steps.

### 4b. Create service principal

```bash
az ad sp create --id <app-id>
```

Capture the `id` (object ID) of the service principal from the output.

### 4c. Create federated credential

```bash
az ad app federated-credential create --id <app-id> --parameters '{
  "name": "github-actions-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<org>/<repo>:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"],
  "description": "GitHub Actions deploy from main branch"
}'
```

Replace `<org>/<repo>` with the actual GitHub repository path detected from `git remote`.

### 4d. Assign Contributor role

```bash
az role assignment create \
  --assignee <sp-id> \
  --role Contributor \
  --scope /subscriptions/<sub-id>/resourceGroups/<rg-name>
```

This grants the service principal permission to manage resources within the target resource group.

### 4e. Store IDs in GitHub secrets

```bash
gh secret set AZURE_CLIENT_ID --body "<app-id>"
gh secret set AZURE_TENANT_ID --body "<tenant-id>"
gh secret set AZURE_SUBSCRIPTION_ID --body "<subscription-id>"
```

Verify secrets were set:

```bash
gh secret list
```

Confirm that `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` all appear in the output.

---

## Step 5: Verify

Offer to trigger a manual workflow run to validate the full pipeline end-to-end:

```bash
gh workflow run <workflow-filename>
```

Then monitor the run:

```bash
gh run watch
```

If the run fails, read the logs with `gh run view --log-failed` and work through the failure with the developer before marking this phase complete.

## Phase 6: Deploy

## Goal

Execute the deployment to Azure Kubernetes Service with **confirmation gates at every destructive step**. No Azure resource is created, no image is pushed, and no manifest is applied without the developer's explicit approval. After successful deployment, render a summary dashboard in the terminal showing the live application URL, Azure portal links, cost estimates, and next steps.

This is the only phase that mutates cloud state. Treat every command with the gravity it deserves.

---

## Confirmation Gate Pattern

Every destructive or billable action in this phase MUST use this exact pattern:

```
Next I'll [action in plain English]. This will run:

  [exact command, fully expanded — no unexplained variables]

[1-sentence explanation of what this creates, changes, or costs]

Want me to proceed? [Yes / No, I'll do it myself]
```

Rules:
- **Never** combine multiple destructive commands into a single gate. One gate per action.
- **Never** skip a gate because a previous gate was approved. Each gate stands alone.
- If the developer says "No, I'll do it myself," output the command cleanly so they can copy-paste it, then wait for them to confirm the step is complete before continuing.
- If the developer says "Yes to all" or similar, you may still show what each command does but proceed without waiting.

---

## Step 1: Pre-flight Checks

Before touching Azure, verify every required tool is installed and configured. Run these checks silently and report a summary:

```bash
# 1. Azure CLI
az version --output tsv 2>/dev/null
az account show --output json 2>/dev/null

# 2. kubectl
kubectl version --client --output=json 2>/dev/null

# 3. GitHub CLI (only if CI/CD pipeline was generated in Phase 5)
gh --version 2>/dev/null
gh auth status 2>/dev/null
```

Report a checklist to the developer:

```
Pre-flight checks:
  [pass/fail] az CLI installed (version X.Y.Z)
  [pass/fail] az CLI logged in (user: someone@example.com)
  [pass/fail] Active subscription: "My Subscription" (xxxxxxxx-xxxx-...)
  [pass/fail] kubectl installed (version X.Y)
  [pass/fail] gh CLI installed and authenticated (if needed)
```

If any check fails:
- `az` not installed → link to https://learn.microsoft.com/en-us/cli/azure/install-azure-cli
- `az` not logged in → prompt to run `az login` (this happens in Step 2)
- `kubectl` not installed → suggest `az aks install-cli`
- Wrong subscription → show `az account set --subscription <id>` before proceeding

Do **not** proceed to Step 2 until all checks pass.

---

## Step 2: Azure Login

**Confirmation gate.**

If the pre-flight check showed the developer is already logged in to the correct subscription, acknowledge it and skip to Step 3.

Otherwise:

```
Next I'll log you into Azure. This will run:

  az login

This opens a browser for Azure authentication. No resources are created.

Want me to proceed? [Yes / No, I'll do it myself]
```

After login completes, run:

```bash
az account show --output table
```

If multiple subscriptions exist, show them and ask which to use:

```bash
az account list --output table --query "[].{Name:name, ID:id, Default:isDefault}"
```

Then set the chosen subscription:

```bash
az account set --subscription "<subscription-id>"
```

Store the subscription ID — it's needed for portal links in the summary dashboard.

```bash
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
```

---

## Step 3: Create Resource Group

**Confirmation gate.**

```
Next I'll create the Azure Resource Group. This will run:

  az group create --name <rg-name> --location <location>

This creates a logical container for all the resources (AKS cluster, container
registry, database, etc.) in the <location> region. The resource group itself
is free — it's just a grouping mechanism. Deleting it later removes everything inside.

Want me to proceed? [Yes / No, I'll do it myself]
```

Values for `<rg-name>` and `<location>` come from the architecture decisions captured in Phase 2. Example:

```bash
az group create \
  --name rg-myapp-dev \
  --location eastus2 \
  --output json
```

Verify creation:

```bash
az group show --name rg-myapp-dev --query properties.provisioningState --output tsv
# Expected: "Succeeded"
```

---

## Step 4: Deploy Bicep Infrastructure

**Confirmation gate.** This is the most significant step — it creates billable Azure resources.

First, remind the developer what will be created. Pull this from the Phase 2 architecture decisions:

```
This Bicep deployment will create the following Azure resources:

  - Azure Kubernetes Service (<type>)           — runs your containers
  - Azure Container Registry (Basic tier)       — stores your container images
  - Managed Identity                            — secure access between AKS ↔ ACR
  [if PostgreSQL] - Azure Database for PostgreSQL (Flexible Server) — managed database
  [if Redis]      - Azure Cache for Redis (Basic tier)              — caching layer

  Estimated monthly cost: $XX–$YY (from Phase 2 analysis)
  Estimated provisioning time: 5–10 minutes (AKS cluster creation is the bottleneck)
```

Then the gate:

```
Next I'll deploy the Bicep infrastructure template. This will run:

  az deployment group create \
    --resource-group rg-myapp-dev \
    --template-file infra/main.bicep \
    --parameters \
      appName=myapp \
      aksType=automatic \
      enablePostgresql=true \
      enableRedis=false \
      location=eastus2

This provisions all Azure infrastructure. AKS cluster creation typically takes
5–10 minutes. You will start incurring costs once provisioning completes.

Want me to proceed? [Yes / No, I'll do it myself]
```

After the developer approves, run the command. While it runs, suggest the developer can monitor progress:

```bash
# In another terminal, poll deployment status:
az deployment group show \
  --resource-group rg-myapp-dev \
  --name main \
  --query properties.provisioningState \
  --output tsv
```

When complete, capture the deployment outputs — these are needed for subsequent steps:

```bash
# Extract outputs from the Bicep deployment
ACR_NAME=$(az deployment group show \
  --resource-group rg-myapp-dev \
  --name main \
  --query properties.outputs.acrName.value \
  --output tsv)

AKS_NAME=$(az deployment group show \
  --resource-group rg-myapp-dev \
  --name main \
  --query properties.outputs.aksClusterName.value \
  --output tsv)

echo "ACR: $ACR_NAME"
echo "AKS: $AKS_NAME"
```

If the deployment fails:
- Show the error: `az deployment group show --resource-group <rg> --name main --query properties.error`
- Common issues: quota limits, name conflicts, region availability
- See **Rollback Guidance** at the end of this file

---

## Step 5: Build and Push Container Image

**Confirmation gate.**

```
Next I'll build and push the container image using Azure Container Registry.
This will run:

  az acr build \
    --registry <acr-name> \
    --image <app-name>:<git-sha-short> \
    .

This builds the Docker image in the cloud using ACR Tasks — no local Docker
daemon is needed. The image is built on Azure's infrastructure and pushed
directly into the registry. The image is tagged with the short git SHA for
traceability (not :latest, per DS009).

Want me to proceed? [Yes / No, I'll do it myself]
```

Determine the tag from git:

```bash
GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "initial")
```

Full command:

```bash
az acr build \
  --registry "$ACR_NAME" \
  --image "myapp:$GIT_SHA" \
  .
```

This streams the build logs. Watch for:
- `Step N/M` progress lines — the Dockerfile layers building
- `Run ID: xxxx was successful` — confirms the build and push succeeded

If the build fails:
- Dockerfile syntax errors → fix and retry (no rollback needed; nothing was persisted)
- Authentication errors → `az acr login --name <acr-name>` then retry
- Context too large → check `.dockerignore` (generated in Phase 3)

---

## Step 6: Deploy to AKS

**Confirmation gate with three sub-steps.** Each sub-step gets its own gate.

### Sub-step 6a: Get AKS Credentials

```
Next I'll configure kubectl to connect to the AKS cluster. This will run:

  az aks get-credentials \
    --resource-group rg-myapp-dev \
    --name <aks-name> \
    --overwrite-existing

This downloads the cluster's kubeconfig and merges it into your local
~/.kube/config. It does not modify the cluster.

Want me to proceed? [Yes / No, I'll do it myself]
```

After approval:

```bash
az aks get-credentials \
  --resource-group rg-myapp-dev \
  --name "$AKS_NAME" \
  --overwrite-existing

# Verify connectivity
kubectl cluster-info
```

### Sub-step 6b: Apply Kubernetes Manifests

```
Next I'll apply all Kubernetes manifests to the cluster. This will run:

  kubectl apply -f k8s/

This creates/updates the following resources in the cluster:
  - Namespace (if defined)
  - Deployment (your application pods)
  - Service (internal load balancer)
  - Gateway/HTTPRoute or Ingress (external traffic routing)
  - ConfigMap / Secrets references (if any)
  - HorizontalPodAutoscaler (if defined)

Want me to proceed? [Yes / No, I'll do it myself]
```

After approval:

```bash
kubectl apply -f k8s/
```

Show the output (each resource and whether it was created or unchanged).

### Sub-step 6c: Wait for Rollout

```
Next I'll wait for the deployment to finish rolling out. This will run:

  kubectl rollout status deployment/<app-name> --timeout=300s

This watches the deployment until all pods are running or 5 minutes elapse.

Want me to proceed? [Yes / No, I'll do it myself]
```

After approval:

```bash
kubectl rollout status deployment/myapp --timeout=300s
```

Expected output: `deployment "myapp" successfully rolled out`

If the rollout times out or fails:
- Check pod status: `kubectl get pods -l app=myapp`
- Check events: `kubectl describe pod -l app=myapp`
- Check logs: `kubectl logs -l app=myapp --tail=50`
- See **Rollback Guidance** at the end of this file

---

## Step 7: Verify

Run all verification commands automatically (no confirmation gate — these are read-only):

### 7a: Pod Status

```bash
kubectl get pods -l app=myapp -o wide
```

Confirm all pods show `STATUS: Running` and `READY: 1/1` (or equivalent). If any pod is in `CrashLoopBackOff`, `ImagePullBackOff`, or `Error`, stop and diagnose before continuing.

### 7b: Service Status

```bash
kubectl get svc myapp
```

Confirm the service exists and has the correct port mapping.

### 7c: External Endpoint

For clusters with **Istio Gateway API enabled**:

```bash
kubectl get gateway
kubectl get httproute
# The external IP or hostname is on the Gateway resource
EXTERNAL_IP=$(kubectl get gateway myapp-gateway -o jsonpath='{.status.addresses[0].value}' 2>/dev/null)
```

For clusters using **Ingress** (default for both AKS Automatic and Standard):

```bash
kubectl get ingress
EXTERNAL_IP=$(kubectl get ingress myapp-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
```

If the external IP is `<pending>`, wait and retry — load balancer provisioning can take 1-2 minutes:

```bash
echo "Waiting for external IP..."
kubectl wait --for=jsonpath='{.status.addresses[0].value}' gateway/myapp-gateway --timeout=120s 2>/dev/null \
  || kubectl wait --for=jsonpath='{.status.loadBalancer.ingress[0].ip}' ingress/myapp-ingress --timeout=120s 2>/dev/null
```

### 7d: Application Logs

```bash
kubectl logs deployment/myapp --tail=20
```

Scan for startup errors, panic traces, or connection failures. The application should show healthy startup messages.

### 7e: Health Check

If an external IP or hostname is available, curl the health endpoint:

```bash
curl -sf "http://${EXTERNAL_IP}/health" && echo " ← healthy" \
  || curl -sf "http://${EXTERNAL_IP}/" && echo " ← root responded"
```

Report the final status to the developer:

```
Verification results:
  [pass/fail] Pods running: 2/2
  [pass/fail] Service exists with correct ports
  [pass/fail] External endpoint: http://<ip-or-hostname>
  [pass/fail] Logs show clean startup
  [pass/fail] Health endpoint responds 200 OK
```

---

## Step 8: Summary Dashboard

Render a deployment summary in the terminal using the [templates/mermaid/summary-dashboard.md](#templates-mermaid-diagrams) template.

### Content to render:

**Success Banner**
- Large green banner: "Deployment Successful"
- Application URL as a clickable link: `http://<EXTERNAL_IP>` or `http://<HOSTNAME>`
- Timestamp of deployment

**Azure Resources Table**

| Resource | Type | Name | Portal Link |
|----------|------|------|-------------|
| Resource Group | Microsoft.Resources/resourceGroups | `rg-myapp-dev` | `https://portal.azure.com/#@/resource/subscriptions/{{SUB_ID}}/resourceGroups/{{RG_NAME}}/overview` |
| AKS Cluster | Microsoft.ContainerService/managedClusters | `aks-myapp-dev` | `https://portal.azure.com/#@/resource/subscriptions/{{SUB_ID}}/resourceGroups/{{RG_NAME}}/providers/Microsoft.ContainerService/managedClusters/{{AKS_NAME}}/overview` |
| Container Registry | Microsoft.ContainerRegistry/registries | `acrmyappdev` | `https://portal.azure.com/#@/resource/subscriptions/{{SUB_ID}}/resourceGroups/{{RG_NAME}}/providers/Microsoft.ContainerRegistry/registries/{{ACR_NAME}}/overview` |
| PostgreSQL (if enabled) | Microsoft.DBforPostgreSQL/flexibleServers | `psql-myapp-dev` | `https://portal.azure.com/#@/resource/subscriptions/{{SUB_ID}}/resourceGroups/{{RG_NAME}}/providers/Microsoft.DBforPostgreSQL/flexibleServers/{{PSQL_NAME}}/overview` |
| Redis (if enabled) | Microsoft.Cache/redis | `redis-myapp-dev` | `https://portal.azure.com/#@/resource/subscriptions/{{SUB_ID}}/resourceGroups/{{RG_NAME}}/providers/Microsoft.Cache/redis/{{REDIS_NAME}}/overview` |

Replace `{{SUB_ID}}`, `{{RG_NAME}}`, and resource names with actual values from the deployment outputs.

**Files Created / Modified**

List all files generated across phases 3–5:

```
Created:
  Dockerfile
  .dockerignore
  k8s/deployment.yaml
  k8s/service.yaml
  k8s/gateway.yaml (or k8s/ingress.yaml)
  k8s/configmap.yaml (if applicable)
  k8s/hpa.yaml (if applicable)
  infra/main.bicep
  infra/modules/aks.bicep
  infra/modules/acr.bicep
  infra/modules/postgresql.bicep (if applicable)
  .github/workflows/deploy.yml
```

**Monthly Cost Estimate**

Pull the estimate from Phase 2 decisions. Display as a range:

```
Estimated monthly cost: $XX – $YY
  AKS (system nodes):      $XX
  AKS (user workload):     $XX
  Container Registry:      $XX
  PostgreSQL (if enabled):  $XX
  Egress / networking:     ~$X
```

Include a note: "Costs vary by usage. Use Azure Cost Management to track actual spend."

**Next Steps**

Present as an actionable checklist:

1. **Custom Domain** — Point a DNS record to the external IP and update the Gateway/Ingress
2. **TLS Certificate** — Enable HTTPS via cert-manager or Azure-managed TLS
3. **Monitoring Dashboard** — Set up Azure Monitor / Prometheus + Grafana for observability
4. **Scaling Configuration** — Tune HPA min/max replicas and resource requests/limits
5. **CI/CD Trigger** — Push a commit to the default branch to trigger the GitHub Actions pipeline
6. **Cleanup** — To tear everything down: `az group delete --name rg-myapp-dev --yes --no-wait`

---

## Step 9: Commit Artifacts

Offer to commit all generated files. This is **not** a confirmation gate — it's an offer.

```
I've generated the following files across this session:

  Dockerfile
  .dockerignore
  k8s/deployment.yaml
  k8s/service.yaml
  k8s/gateway.yaml
  infra/main.bicep
  infra/modules/aks.bicep
  infra/modules/acr.bicep
  .github/workflows/deploy.yml
  [... any others]

Would you like me to commit these to git?
  [Yes / No / Let me review first]
```

If yes:

```bash
git add \
  Dockerfile \
  .dockerignore \
  k8s/ \
  infra/ \
  .github/workflows/deploy.yml

git commit -m "Add AKS deployment infrastructure

- Dockerfile and .dockerignore for containerization
- Kubernetes manifests (deployment, service, gateway/ingress)
- Bicep infrastructure-as-code templates
- GitHub Actions CI/CD pipeline

Deployed to: <external-ip-or-hostname>
AKS cluster: <aks-name> in <rg-name>"
```

Do **not** push unless the developer explicitly asks. Mention that the CI/CD pipeline generated in Phase 5 will trigger on push.

---

## Rollback Guidance

If any step fails, use the guidance below. Do not proceed to the next step until the failure is resolved or the developer explicitly chooses to abort.

### Bicep Deployment Failed (Step 4)

```bash
# Check what went wrong
az deployment group show \
  --resource-group rg-myapp-dev \
  --name main \
  --query properties.error \
  --output json

# Cancel an in-progress deployment
az deployment group cancel \
  --resource-group rg-myapp-dev \
  --name main

# Common fixes:
# - Name conflict     → change appName parameter, redeploy
# - Quota exceeded    → request quota increase or change VM size / region
# - Region not available → change location parameter
# - Validation error  → fix the Bicep template, redeploy

# Fix and retry (idempotent — safe to re-run):
az deployment group create \
  --resource-group rg-myapp-dev \
  --template-file infra/main.bicep \
  --parameters appName=myapp ...
```

### Image Build Failed (Step 5)

```bash
# No cloud resources were persisted — nothing to roll back.
# Fix the issue and retry:

# Common fixes:
# - Dockerfile syntax error       → edit Dockerfile
# - Missing file in build context → check .dockerignore
# - Dependency install failure    → fix package.json / requirements.txt / go.mod

# Retry:
az acr build --registry <acr-name> --image <app-name>:<git-sha> .
```

### kubectl apply Failed (Step 6b)

```bash
# Remove the partially applied resources:
kubectl delete -f k8s/

# Common fixes:
# - YAML syntax error      → validate with: kubectl apply -f k8s/ --dry-run=client
# - Invalid resource field  → check API version matches cluster version
# - Image pull error        → verify ACR name in deployment.yaml matches actual ACR
# - Namespace doesn't exist → create it first or remove namespace from manifests

# Fix and retry:
kubectl apply -f k8s/
```

### Pods Not Starting (Step 6c / Step 7)

```bash
# Diagnose:
kubectl get pods -l app=myapp
kubectl describe pod -l app=myapp
kubectl logs -l app=myapp --tail=50

# Common error patterns:

# CrashLoopBackOff — app crashes on startup
#   → Check logs for the crash reason
#   → Usually: missing env var, bad database connection string, port mismatch

# ImagePullBackOff — can't pull the container image
#   → Verify image name: kubectl get deployment myapp -o jsonpath='{.spec.template.spec.containers[0].image}'
#   → Verify ACR access: az aks check-acr --resource-group <rg> --name <aks> --acr <acr>.azurecr.io

# Pending — pod can't be scheduled
#   → Check node status: kubectl get nodes
#   → Check resource requests vs available capacity: kubectl describe nodes

# OOMKilled — app exceeded memory limit
#   → Increase memory limit in k8s/deployment.yaml and re-apply

# After fixing, re-apply:
kubectl apply -f k8s/
kubectl rollout status deployment/myapp --timeout=300s
```

### Nuclear Option: Tear Everything Down

If the developer wants to start over completely:

```bash
# This deletes ALL resources in the resource group — irreversible.
az group delete --name rg-myapp-dev --yes --no-wait
```

This is itself a destructive command. If the developer asks to tear down, use a confirmation gate for it.

---

## Phase Completion Criteria

This phase is complete when ALL of the following are true:

- [ ] All pre-flight checks pass
- [ ] Azure infrastructure is provisioned (Bicep deployment succeeded)
- [ ] Container image is built and pushed to ACR
- [ ] Kubernetes manifests are applied to AKS
- [ ] All pods are in `Running` state
- [ ] External endpoint is reachable
- [ ] Summary dashboard is rendered in the terminal
- [ ] Developer has been offered the chance to commit artifacts

**The application is now live.** Congratulate the developer and point them to the Next Steps in the dashboard.

## Reference: Deployment Safeguards

> **Last updated:** 2026-04-02

AKS Deployment Safeguards enforce best practices on Kubernetes manifests at admission time.
When the cluster has safeguards enabled (Enforcement level: `Warning` or `Enforcement`),
non-compliant resources are either flagged or rejected.

This reference covers every rule the skill validates **before** deployment so you never
hit a surprise rejection at `kubectl apply` time.

---

## DS001 — Resource Limits Required

| Field | Value |
|-------|-------|
| **Checks** | Every container has `resources.requests` AND `resources.limits` for both `cpu` and `memory`. |
| **Severity** | Error |
| **Why it matters** | Without limits the scheduler cannot bin-pack pods and a single container can starve the node. |
| **Auto-fixable** | Yes |

### How to detect in YAML

Look for containers missing any of these four keys:

```yaml
resources:
  requests:
    cpu: ...
    memory: ...
  limits:
    cpu: ...
    memory: ...
```

If `resources` is absent, or any of the four sub-keys is missing, the rule is violated.

### How to fix

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "256Mi"
```

Adjust values to match your workload's actual needs.

---

## DS002 — Liveness Probe Required

| Field | Value |
|-------|-------|
| **Checks** | Every container has a `livenessProbe` defined. |
| **Severity** | Warning |
| **Why it matters** | Without a liveness probe, Kubernetes cannot restart a container that is deadlocked or hung. |
| **Auto-fixable** | Yes |

### How to detect in YAML

The container spec has no `livenessProbe` key.

### How to fix

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 15
  timeoutSeconds: 3
  failureThreshold: 3
```

Choose `httpGet`, `tcpSocket`, or `exec` depending on your app.

---

## DS003 — Readiness Probe Required

| Field | Value |
|-------|-------|
| **Checks** | Every container has a `readinessProbe` defined. |
| **Severity** | Warning |
| **Why it matters** | Without a readiness probe, traffic is sent to pods that aren't ready to serve, causing user-facing errors. |
| **Auto-fixable** | Yes |

### How to detect in YAML

The container spec has no `readinessProbe` key.

### How to fix

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
```

---

## DS004 — runAsNonRoot Required

| Field | Value |
|-------|-------|
| **Checks** | `securityContext.runAsNonRoot: true` is set at the **pod** level AND at each **container** level. |
| **Severity** | Error |
| **Why it matters** | Running as root inside a container dramatically increases the blast radius if the container is compromised. |
| **Auto-fixable** | Yes |

### How to detect in YAML

Check two locations:

1. `spec.template.spec.securityContext.runAsNonRoot` — must be `true`
2. Each `containers[*].securityContext.runAsNonRoot` — must be `true`

If either is missing or set to `false`, the rule is violated.

### How to fix

Pod-level:

```yaml
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
```

Container-level:

```yaml
securityContext:
  runAsNonRoot: true
```

---

## DS005 — No hostNetwork

| Field | Value |
|-------|-------|
| **Checks** | `spec.template.spec.hostNetwork` is not set to `true`. |
| **Severity** | Error |
| **Why it matters** | Host networking lets a pod see all network traffic on the node, breaking namespace isolation. |
| **Auto-fixable** | Yes |

### How to detect in YAML

```yaml
spec:
  template:
    spec:
      hostNetwork: true   # ← violation
```

### How to fix

Remove the field entirely or set it to `false`:

```yaml
spec:
  template:
    spec:
      hostNetwork: false
```

---

## DS006 — No hostPID

| Field | Value |
|-------|-------|
| **Checks** | `spec.template.spec.hostPID` is not set to `true`. |
| **Severity** | Error |
| **Why it matters** | Sharing the host PID namespace lets containers see and signal host processes, enabling container escapes. |
| **Auto-fixable** | Yes |

### How to detect in YAML

```yaml
spec:
  template:
    spec:
      hostPID: true   # ← violation
```

### How to fix

Remove the field entirely or set it to `false`:

```yaml
spec:
  template:
    spec:
      hostPID: false
```

---

## DS007 — No hostIPC

| Field | Value |
|-------|-------|
| **Checks** | `spec.template.spec.hostIPC` is not set to `true`. |
| **Severity** | Error |
| **Why it matters** | Sharing host IPC namespace allows containers to access shared memory of other host processes. |
| **Auto-fixable** | Yes |

### How to detect in YAML

```yaml
spec:
  template:
    spec:
      hostIPC: true   # ← violation
```

### How to fix

Remove the field entirely or set it to `false`:

```yaml
spec:
  template:
    spec:
      hostIPC: false
```

---

## DS008 — No Privileged Containers

| Field | Value |
|-------|-------|
| **Checks** | No container has `securityContext.privileged: true`. |
| **Severity** | Error |
| **Why it matters** | Privileged containers get full access to every host device and kernel capability — equivalent to root on the node. |
| **Auto-fixable** | Yes |

### How to detect in YAML

```yaml
containers:
  - name: app
    securityContext:
      privileged: true   # ← violation
```

### How to fix

Remove the field entirely or set it to `false`:

```yaml
securityContext:
  privileged: false
```

---

## DS009 — No :latest Image Tag

| Field | Value |
|-------|-------|
| **Checks** | Every container image reference includes an explicit tag or digest that is NOT `:latest`. |
| **Severity** | Error |
| **Why it matters** | `:latest` is mutable — the same tag can point to different images over time, making deployments non-reproducible. |
| **Auto-fixable** | No |

### How to detect in YAML

Check each `containers[*].image` value:

- `myregistry.azurecr.io/app:latest` — violation
- `myregistry.azurecr.io/app` (no tag) — violation (defaults to :latest)
- `myregistry.azurecr.io/app:v1.2.3` — compliant
- `myregistry.azurecr.io/app@sha256:abc...` — compliant

### How to fix

```yaml
image: myregistry.azurecr.io/app:v1.2.3
```

Use a semantic version, git SHA, or digest. Never omit the tag.

---

## DS010 — Minimum 2 Replicas for HA

| Field | Value |
|-------|-------|
| **Checks** | `spec.replicas` is at least `2` for Deployments. |
| **Severity** | Warning |
| **Why it matters** | A single replica means any pod disruption (node drain, OOM kill, crash) causes downtime. |
| **Auto-fixable** | Yes |

### How to detect in YAML

```yaml
spec:
  replicas: 1   # ← violation
```

Also violated if `replicas` is omitted (defaults to 1).

### How to fix

```yaml
spec:
  replicas: 2
```

Pair with a `PodDisruptionBudget` for controlled rollouts.

---

## DS011 — allowPrivilegeEscalation Must Be False

| Field | Value |
|-------|-------|
| **Checks** | Every container has `securityContext.allowPrivilegeEscalation: false`. |
| **Severity** | Error |
| **Why it matters** | Privilege escalation lets a process gain more privileges than its parent, which is the basis of most container breakout exploits. |
| **Auto-fixable** | Yes |

### How to detect in YAML

The field is either missing (defaults to `true`) or explicitly set to `true`:

```yaml
securityContext:
  allowPrivilegeEscalation: true   # ← violation
```

### How to fix

```yaml
securityContext:
  allowPrivilegeEscalation: false
```

---

## DS012 — readOnlyRootFilesystem Should Be True

| Field | Value |
|-------|-------|
| **Checks** | Every container has `securityContext.readOnlyRootFilesystem: true`. |
| **Severity** | Warning |
| **Why it matters** | A writable root filesystem lets attackers drop binaries or modify config inside the container at runtime. |
| **Auto-fixable** | Yes |

### How to detect in YAML

The field is missing or set to `false`:

```yaml
securityContext:
  readOnlyRootFilesystem: false   # ← violation
```

### How to fix

```yaml
securityContext:
  readOnlyRootFilesystem: true
```

If the app needs to write to specific paths, mount `emptyDir` volumes at those paths
rather than making the entire root filesystem writable.

### Common frameworks requiring writable paths

Many popular frameworks write temporary files at runtime. When `readOnlyRootFilesystem: true`
is set, these frameworks will fail unless you mount `emptyDir` volumes at the required paths.

| Framework | Path | Why |
|-----------|------|-----|
| **Spring Boot** (Java) | `/tmp` | Tomcat writes session data, multipart uploads, and compiled JSPs to `/tmp` |
| **ASP.NET Core** (.NET) | `/tmp` | Data protection keys, temp file uploads |
| **Django** (Python) | `/tmp` | File upload handlers use temp directory |
| **Express/Node.js** | `/tmp` | `multer` and other middleware write temp files |
| **Ruby on Rails** | `/tmp` | Cache store, session files, PID files |
| **Go** (various) | `/tmp` | `os.CreateTemp` default directory |

Add the corresponding volume and volumeMount to the Deployment manifest:

```yaml
spec:
  template:
    spec:
      volumes:
        - name: tmp
          emptyDir: {}
      containers:
        - name: app
          volumeMounts:
            - name: tmp
              mountPath: /tmp
```

If the framework's knowledge pack (see `knowledge-packs/frameworks/`) specifies additional
writable paths, mount those as well.

---

## DS013 — automountServiceAccountToken Should Be False

| Field | Value |
|-------|-------|
| **Checks** | `spec.template.spec.automountServiceAccountToken` is `false`. |
| **Severity** | Warning |
| **Why it matters** | Auto-mounted SA tokens let any compromised container call the Kubernetes API; most workloads don't need this. |
| **Auto-fixable** | Yes |

### How to detect in YAML

The field is missing (defaults to `true`) or explicitly set to `true`:

```yaml
spec:
  template:
    spec:
      automountServiceAccountToken: true   # ← violation
```

### How to fix

```yaml
spec:
  template:
    spec:
      automountServiceAccountToken: false
```

If your app genuinely needs to call the K8s API, set this to `true` on only that
specific ServiceAccount and use RBAC to scope permissions tightly.

---

## Quick Reference Table

| Rule | What | Severity | Auto-Fix |
|------|------|----------|----------|
| DS001 | Resource limits (cpu + memory requests & limits) | Error | Yes |
| DS002 | Liveness probe | Warning | Yes |
| DS003 | Readiness probe | Warning | Yes |
| DS004 | runAsNonRoot (pod + container) | Error | Yes |
| DS005 | No hostNetwork | Error | Yes |
| DS006 | No hostPID | Error | Yes |
| DS007 | No hostIPC | Error | Yes |
| DS008 | No privileged containers | Error | Yes |
| DS009 | No :latest image tag | Error | No |
| DS010 | Minimum 2 replicas | Warning | Yes |
| DS011 | allowPrivilegeEscalation: false | Error | Yes |
| DS012 | readOnlyRootFilesystem: true | Warning | Yes |
| DS013 | automountServiceAccountToken: false | Warning | Yes |

## Reference: Workload Identity

> **Last updated:** 2026-04-02

## What Is Workload Identity?

Workload Identity lets pods in AKS authenticate to Azure services (Key Vault, Storage,
PostgreSQL, etc.) without storing any secrets. Instead of injecting connection strings or
passwords, your pod proves its identity through a short-lived token issued by the
cluster's OIDC provider, which Azure AD trusts because you've set up a federation
between the cluster and a Managed Identity. The pod gets a token automatically — your
app code just uses the standard Azure SDK credential chain.

---

## Three Components

### 1. User-Assigned Managed Identity

A Managed Identity in Azure that has RBAC role assignments on the target resources
(e.g., `Key Vault Secrets User`, `Storage Blob Data Contributor`).

```
Managed Identity
  ├── Client ID: <AZURE_CLIENT_ID>
  ├── Tenant ID: <AZURE_TENANT_ID>
  └── Role assignments:
       ├── Key Vault Secrets User  → /subscriptions/.../vaults/my-kv
       ├── Storage Blob Data Contributor → /subscriptions/.../storageAccounts/my-sa
       └── ...
```

### 2. Federated Identity Credential

A trust relationship that says: "When the AKS cluster's OIDC issuer presents a token
for ServiceAccount `<namespace>/<sa-name>`, treat it as this Managed Identity."

```
Federated Credential
  ├── Issuer:  https://oidc.prod-aks.azure.com/<tenant-id>/<cluster-id>
  ├── Subject: system:serviceaccount:<namespace>:<sa-name>
  └── Audience: api://AzureADTokenExchange
```

### 3. Kubernetes ServiceAccount

A standard K8s ServiceAccount annotated with the Managed Identity's client ID.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: <app-name>
  namespace: <namespace>
  annotations:
    azure.workload.identity/client-id: "<AZURE_CLIENT_ID>"
```

---

## How They Link Together

```
Pod (with label azure.workload.identity/use: "true")
  │
  ├── References ServiceAccount (annotated with client-id)
  │
  ▼
AKS OIDC Issuer issues a projected service account token
  │
  ├── Issuer URL matches the Federated Credential's issuer
  ├── Subject (system:serviceaccount:ns:sa) matches the Federated Credential's subject
  │
  ▼
Azure AD validates the federation and issues an Azure AD token
  │
  ▼
Azure SDK (DefaultAzureCredential) uses the token to access Azure resources
```

The Workload Identity webhook in AKS automatically:
- Projects the service account token into the pod at a well-known path
- Sets the `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_FEDERATED_TOKEN_FILE`
  environment variables in the container

Your app code does **not** need to know about any of this — `DefaultAzureCredential`
picks it up automatically.

---

## Per-Service Patterns

### PostgreSQL (Flexible Server with Azure AD Auth)

The Managed Identity needs the `<db-name> Admin` or a custom PostgreSQL role.

```python
# Python — psycopg2 + DefaultAzureCredential
from azure.identity import DefaultAzureCredential

credential = DefaultAzureCredential()
token = credential.get_token("https://ossrdbms-aad.database.windows.net/.default")

conn = psycopg2.connect(
    host="<server>.postgres.database.azure.com",
    dbname="<database>",
    user="<managed-identity-name>",
    password=token.token,
    sslmode="require",
)
```

```csharp
// C# — Npgsql + Azure.Identity
var credential = new DefaultAzureCredential();
var token = await credential.GetTokenAsync(
    new TokenRequestContext(new[] { "https://ossrdbms-aad.database.windows.net/.default" }));

var connString = $"Host=<server>.postgres.database.azure.com;Database=<database>;"
               + $"Username=<managed-identity-name>;Password={token.Token};SSL Mode=Require";
await using var conn = new NpgsqlConnection(connString);
```

**Required env vars** (injected by Workload Identity webhook):
- `AZURE_CLIENT_ID` — used by `DefaultAzureCredential`

### Key Vault

Role assignment: `Key Vault Secrets User` (or `Key Vault Crypto User` for keys).

```python
# Python
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

credential = DefaultAzureCredential()
client = SecretClient(vault_url="https://<vault-name>.vault.azure.net", credential=credential)
secret = client.get_secret("my-secret")
```

```csharp
// C#
var credential = new DefaultAzureCredential();
var client = new SecretClient(new Uri("https://<vault-name>.vault.azure.net"), credential);
KeyVaultSecret secret = await client.GetSecretAsync("my-secret");
```

### Azure Blob Storage

Role assignment: `Storage Blob Data Contributor` (or `Reader` for read-only).

```python
# Python
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient

credential = DefaultAzureCredential()
client = BlobServiceClient(
    account_url="https://<account>.blob.core.windows.net",
    credential=credential,
)
```

```csharp
// C#
var credential = new DefaultAzureCredential();
var client = new BlobServiceClient(
    new Uri("https://<account>.blob.core.windows.net"), credential);
```

### Azure Cache for Redis (Azure AD Token Auth)

Role assignment: `Redis Cache Contributor` or custom data-plane role.

```python
# Python — redis-py with Azure AD token
from azure.identity import DefaultAzureCredential
import redis

credential = DefaultAzureCredential()
token = credential.get_token("https://redis.azure.com/.default")

r = redis.Redis(
    host="<cache-name>.redis.cache.windows.net",
    port=6380,
    ssl=True,
    username=os.environ["AZURE_CLIENT_ID"],
    password=token.token,
)
```

```csharp
// C#
var credential = new DefaultAzureCredential();
var token = await credential.GetTokenAsync(
    new TokenRequestContext(new[] { "https://redis.azure.com/.default" }));

var muxer = await ConnectionMultiplexer.ConnectAsync(new ConfigurationOptions
{
    EndPoints = { "<cache-name>.redis.cache.windows.net:6380" },
    Ssl = true,
    User = Environment.GetEnvironmentVariable("AZURE_CLIENT_ID"),
    Password = token.Token,
});
```

---

## Required Pod Labels and ServiceAccount Annotations

### Pod Label (on the Deployment's `spec.template.metadata.labels`)

```yaml
labels:
  azure.workload.identity/use: "true"
```

This label tells the Workload Identity webhook to inject the projected token volume
and environment variables into the pod.

### ServiceAccount Annotation

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: <app-name>
  annotations:
    azure.workload.identity/client-id: "<AZURE_CLIENT_ID>"
```

This annotation tells the webhook which Managed Identity to federate with.

### Complete Deployment Snippet

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <app-name>
spec:
  template:
    metadata:
      labels:
        app: <app-name>
        azure.workload.identity/use: "true"     # ← required label
    spec:
      serviceAccountName: <app-name>            # ← references annotated SA
      automountServiceAccountToken: false        # ← DS013 (Workload Identity uses projected volume, not SA token)
      containers:
        - name: <app-name>
          # AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_FEDERATED_TOKEN_FILE
          # are injected automatically by the webhook
```

> **Note:** `automountServiceAccountToken: false` disables the *default* SA token mount.
> Workload Identity uses a separate projected volume that the webhook manages independently,
> so both can coexist without conflict.

## Reference: Cost Estimation

> **Last updated:** 2025-06  
> **Region basis:** East US (prices vary by region — East US is used as the baseline)  
> **Currency:** USD  
> **Billing period:** Monthly estimates (730 hours/month)

This document provides estimated monthly costs for Azure services commonly provisioned by the deploy-to-AKS skill. Use these figures for Phase 2 cost estimation. Always direct developers to the [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) for precise, up-to-date quotes.

---

## AKS (Azure Kubernetes Service)

### Control Plane

| Mode | Monthly Cost | Notes |
|---|---|---|
| AKS Automatic | ~$116.80/mo | Includes managed node provisioning, Gateway API, managed Prometheus & Grafana |
| AKS Standard (Free tier) | $0/mo | No SLA, no uptime guarantee — suitable for dev/test only |
| AKS Standard (Standard tier) | ~$73/mo | Includes uptime SLA (99.95% with availability zones), recommended for production |
| AKS Standard (Premium tier) | ~$146/mo | Includes long-term support, advanced networking features |

### Compute (Node Pool)

Costs depend on the VM SKU backing the node pool. For AKS Automatic, Azure selects VMs automatically but the per-vCPU cost still applies.

| SKU | vCPUs | Memory (GiB) | Monthly Cost | Per-vCPU/mo |
|---|---|---|---|---|
| Standard_B2s | 2 | 4 | ~$30.37/mo | ~$15.19 |
| Standard_B2ms | 2 | 8 | ~$60.74/mo | ~$30.37 |
| Standard_D2s_v5 | 2 | 8 | ~$70.08/mo | ~$35.04 |
| Standard_D4s_v5 | 4 | 16 | ~$140.16/mo | ~$35.04 |
| Standard_D2as_v5 | 2 | 8 | ~$62.78/mo | ~$31.39 |
| Standard_D4as_v5 | 4 | 16 | ~$125.56/mo | ~$31.39 |

**Default assumption for cost estimates:** 2 vCPU / 4 GiB node (Standard_B2s) at ~$30/mo for dev; 2 vCPU / 8 GiB node (Standard_D2s_v5) at ~$70/mo for production.

---

## Container Registry (ACR)

| Tier | Monthly Cost | Included Storage | Notes |
|---|---|---|---|
| Basic | ~$5/mo | 10 GiB | Suitable for dev/test, limited throughput |
| Standard | ~$20/mo | 100 GiB | Recommended for production, geo-replication not included |
| Premium | ~$50/mo | 500 GiB | Geo-replication, content trust, private link |

**Default:** Basic for dev, Standard for production.

---

## Database — PostgreSQL

### Azure Database for PostgreSQL Flexible Server

| Tier / SKU | vCores | Memory (GiB) | Monthly Cost | Notes |
|---|---|---|---|---|
| Burstable B1ms | 1 | 2 | ~$13/mo | Dev/test workloads, variable CPU |
| Burstable B2s | 2 | 4 | ~$26/mo | Small production workloads |
| General Purpose D2s_v3 | 2 | 8 | ~$100/mo | Production, consistent performance |
| General Purpose D4s_v3 | 4 | 16 | ~$200/mo | Larger production workloads |
| Memory Optimized E2s_v3 | 2 | 16 | ~$130/mo | Memory-heavy queries, analytics |

**Storage:** ~$0.115/GiB/mo (provisioned). Minimum 32 GiB (~$3.68/mo).

**Backup:** Locally redundant backup included. Geo-redundant backup adds ~$0.10/GiB/mo.

**Default:** Burstable B1ms + 32 GiB storage (~$17/mo) for dev; GP D2s_v3 + 64 GiB (~$107/mo) for production.

---

## Database — MongoDB (Cosmos DB)

### Azure Cosmos DB for MongoDB (vCore-based or RU-based)

#### Serverless (RU-based)

| Metric | Cost | Notes |
|---|---|---|
| Request Units | ~$0.25 per 1 million RU | Pay only for consumed throughput |
| Storage | ~$0.25/GiB/mo | Per GiB of data stored |

**Typical dev cost:** $1-5/mo depending on usage. Ideal for low-traffic, bursty workloads.

#### Provisioned Throughput (RU-based)

| Provisioned RU/s | Monthly Cost | Notes |
|---|---|---|
| 400 RU/s (minimum) | ~$23/mo | Single region, manual throughput |
| 1,000 RU/s | ~$58/mo | Single region |
| 4,000 RU/s (autoscale max) | ~$87/mo | Autoscale bills at 10% of max when idle |

**Storage:** ~$0.25/GiB/mo.

#### vCore-based

| Tier | vCores | Memory (GiB) | Monthly Cost | Notes |
|---|---|---|---|---|
| M25 (Burstable) | Shared | 2 | ~$14/mo | Dev/test |
| M30 | 2 | 8 | ~$109/mo | Small production |
| M40 | 4 | 16 | ~$218/mo | Production |

**Default:** Serverless for dev; Provisioned 400 RU/s or vCore M25 for production (developer choice).

---

## Cache — Azure Cache for Redis

| Tier / SKU | Size | Monthly Cost | Notes |
|---|---|---|---|
| Basic C0 | 250 MB | ~$16/mo | No SLA, no replication — dev/test only |
| Basic C1 | 1 GB | ~$34/mo | No SLA, no replication |
| Standard C0 | 250 MB | ~$40/mo | Replicated, 99.9% SLA |
| Standard C1 | 1 GB | ~$68/mo | Replicated, 99.9% SLA |
| Premium P1 | 6 GB | ~$225/mo | Clustering, persistence, VNet |

**Default:** Basic C0 (~$16/mo) for dev; Standard C1 (~$68/mo) for production.

---

## Security

### Azure Key Vault

| Operation | Cost | Notes |
|---|---|---|
| Secrets operations | ~$0.03 per 10,000 operations | Standard tier |
| Key operations (RSA 2048) | ~$0.03 per 10,000 operations | Software-protected |
| Key operations (HSM) | ~$1.00 per 10,000 operations | HSM-protected |
| Certificate operations | ~$3.00 per renewal | Auto-renewal |
| Storage | Included | Up to 25,000 objects per vault |

**Typical monthly cost:** $0.30 - $3.00/mo for most applications (well under 100K ops/mo).

**Default estimate:** ~$1/mo for cost planning purposes.

### Managed Identity

| Component | Cost |
|---|---|
| User-Assigned Managed Identity | **Free** |
| System-Assigned Managed Identity | **Free** |
| Workload Identity Federation | **Free** |
| Token requests | **Free** |

Managed Identity has **zero cost**. Always include it, never charge for it.

---

## Monitoring

### Log Analytics Workspace

| Tier | Cost | Notes |
|---|---|---|
| Per-GB ingestion | ~$2.76/GiB | First 5 GiB/mo free per billing account |
| Data retention (31 days) | Included | Default 31-day retention, no extra charge |
| Data retention (90 days) | ~$0.10/GiB/mo | Extended retention beyond 31 days |
| Data retention (180+ days) | ~$0.20/GiB/mo | Long-term retention |

### Application Insights

| Component | Cost | Notes |
|---|---|---|
| Data ingestion | ~$2.76/GiB | Shares the 5 GiB free allowance with Log Analytics |
| Multi-step web tests | ~$10/test/mo | Optional, not included by default |
| Continuous export | ~$0.25/GiB | Optional, not included by default |

**Default estimate for dev:** Free (assuming <=5 GiB/mo ingestion across Log Analytics + App Insights).

**Default estimate for production:** ~$14/mo (assuming ~10 GiB/mo ingestion, minus 5 GiB free = 5 GiB * $2.76).

---

## Networking

### AKS Automatic

| Component | Cost | Notes |
|---|---|---|
| Gateway API (managed) | Included | Part of AKS Automatic, no extra charge |
| Managed public IP | Included | Provisioned automatically |
| Egress (first 5 GB/mo) | Free | Outbound data transfer |
| Egress (5-10 TB/mo) | ~$0.087/GiB | Standard inter-region pricing |

### AKS Standard

| Component | Monthly Cost | Notes |
|---|---|---|
| Standard Load Balancer | ~$18/mo | Base charge ($0.025/hr) |
| Load Balancer rules (first 5) | Included | Additional rules ~$7.30/mo each |
| Public IP (Standard SKU) | ~$3.60/mo | $0.005/hr static IP |
| Egress (first 5 GB/mo) | Free | Outbound data transfer |
| Egress (5-10 TB/mo) | ~$0.087/GiB | Standard inter-region pricing |

**Default for AKS Automatic:** $0 additional networking cost (included in control plane).

**Default for AKS Standard:** ~$22/mo (Load Balancer + 1 Public IP).

---

## Storage — Azure Storage Account

| Tier | Redundancy | Cost per GiB/mo | Transaction Cost (per 10K ops) | Notes |
|---|---|---|---|---|
| Hot | LRS | ~$0.018/GiB | ~$0.05 (write), ~$0.004 (read) | Frequently accessed data |
| Hot | ZRS | ~$0.023/GiB | ~$0.05 (write), ~$0.004 (read) | Zone-redundant for production |
| Cool | LRS | ~$0.01/GiB | ~$0.10 (write), ~$0.01 (read) | Infrequently accessed |
| Archive | LRS | ~$0.002/GiB | ~$0.10 (write), ~$5.00 (read) | Rarely accessed, high retrieval cost |

**Default estimate:** ~$1-2/mo for dev (small storage, Hot LRS); scales with data volume in production.

---

## Cost Estimation Rules

When computing cost estimates in Phase 2, follow these rules:

### Always Include (Every Deployment)

1. **AKS control plane** — Automatic (~$117) or Standard ($0 free tier / ~$73 standard tier)
2. **Compute** — At least one node; default to Standard_B2s (~$30/mo) for dev
3. **ACR** — Basic ($5) for dev, Standard ($20) for production
4. **Monitoring** — Log Analytics + App Insights (Free if <=5 GiB/mo, otherwise ~$2.76/GiB)
5. **Managed Identity** — Free (always list it, always show $0)

### Add If Selected

6. **Backing databases** — PostgreSQL, Cosmos DB, etc. at appropriate tier
7. **Cache** — Redis at appropriate tier
8. **Key Vault** — ~$1/mo estimate
9. **Storage Account** — Per estimated volume
10. **Networking** — Only for AKS Standard (LB + Public IP ~$22/mo)

### Formatting Rules

- **Round each line item to the nearest dollar** for the summary table.
- **Always show monthly estimates** — not hourly, not annual.
- **Show "Free" explicitly** for zero-cost services (Managed Identity, monitoring within free tier). Do not omit them.
- **Total line uses "~" prefix** to indicate approximation: `~$196`.
- **Always append the disclaimer:** *"Costs are estimates based on published Azure pricing for East US region as of 2025-06. Actual costs vary by region, usage, and reserved instance discounts. Verify with the [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/)."*

### Quick Reference: Common Stacks

| Stack | Dev Estimate | Production Estimate |
|---|---|---|
| AKS Automatic + ACR + PostgreSQL | ~$165/mo | ~$310/mo |
| AKS Automatic + ACR + Cosmos DB (Serverless) | ~$155/mo | ~$280/mo |
| AKS Automatic + ACR + PostgreSQL + Redis | ~$180/mo | ~$380/mo |
| AKS Standard + ACR + PostgreSQL | ~$70/mo | ~$285/mo |
| AKS Standard (Free tier) + ACR + PostgreSQL | ~$50/mo | N/A (no SLA) |
| AKS Automatic + ACR only (no backing services) | ~$150/mo | ~$210/mo |

## Reference: AKS Automatic

> **Last updated:** 2026-04-10

## What is AKS Automatic

AKS Automatic is a fully managed Kubernetes experience where Azure handles node provisioning, scaling, OS patching, and Kubernetes upgrades for you. You deploy workloads and Azure figures out the right VM sizes, node counts, and infrastructure configuration. Think of it as "serverless-ish Kubernetes" — you still write K8s manifests, but you skip all the infrastructure knobs.

## Key Properties

| Property | Value |
|----------|-------|
| SKU name | `Automatic` |
| SKU tier | `Standard` |
| API version | `2025-03-01` |

## Routing: Ingress (Default) or Gateway API (Optional)

AKS Automatic uses the **Web App Routing addon (NGINX)** by default — the same as AKS Standard. The Kubernetes Gateway API with Istio is available as an **optional mode** that must be explicitly enabled.

### Detecting the Active Routing Mode

```bash
az aks show -g <rg> -n <cluster> --query 'ingressProfile.webAppRouting' -o json
```

Check `gatewayApiImplementations.appRoutingIstio.mode`:
- `"Enabled"` → Gateway API with Istio is active → use `Gateway` + `HTTPRoute` resources with `gatewayClassName: istio`
- `"Disabled"` (default) → NGINX Ingress is active → use `Ingress` resources with `ingressClassName: webapprouting.kubernetes.azure.com`

### Default: Ingress (NGINX via Web App Routing)

When Istio is not enabled (the default), AKS Automatic behaves identically to AKS Standard for routing:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  namespace: app-namespace
spec:
  ingressClassName: webapprouting.kubernetes.azure.com
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-service
                port:
                  number: 8080
```

### Optional: Gateway API (Istio)

When `appRoutingIstio.mode` is `"Enabled"`, the cluster has an Istio-based service mesh that provides Gateway API support.

#### How Gateway API differs from Ingress

- `Ingress` is a single resource that combines listener config and routing rules. Gateway API splits these into separate resources: `Gateway` (ports, TLS, listeners) and `HTTPRoute` (path matching, backend refs).
- Gateway API supports more advanced traffic patterns (header-based routing, traffic splitting, cross-namespace references) without annotations or custom CRDs.
- The `gatewayClassName` for AKS with Istio enabled is `istio`.

### Gateway and HTTPRoute YAML (only when Istio is enabled)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: app-gateway
  namespace: app-namespace
  annotations:
    # Request a public Azure Load Balancer IP
    service.beta.kubernetes.io/azure-load-balancer-resource-group: "<node-resource-group>"
spec:
  gatewayClassName: istio
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: Same
    - name: https
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        certificateRefs:
          - name: app-tls-secret
            kind: Secret
      allowedRoutes:
        namespaces:
          from: Same
```

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-route
  namespace: app-namespace
spec:
  parentRefs:
    - name: app-gateway
      sectionName: http
  hostnames:
    - "myapp.example.com"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api
      backendRefs:
        - name: api-service
          port: 8080
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: frontend-service
          port: 3000
```

**Key points:**
- `parentRefs` links the HTTPRoute to a specific Gateway and listener.
- Multiple HTTPRoutes can reference the same Gateway.
- Only use `Gateway`/`HTTPRoute` resources when Istio Gateway API is enabled. If Istio is disabled (the default), use `Ingress` resources with `ingressClassName: webapprouting.kubernetes.azure.com`.

## Node Management

Nodes are **fully managed** via Node Auto-Provisioning (NAP). There is no concept of user-defined node pools.

- Azure automatically selects optimal VM SKUs based on your workload resource requests (`resources.requests` in pod specs).
- Nodes are provisioned, scaled, and deprovisioned without user intervention.
- OS patches are applied automatically.
- Kubernetes version upgrades are automatic.
- If you don't set resource requests on your pods, NAP cannot make good decisions. **Always set `resources.requests` and `resources.limits`.**

There is nothing to configure for node management. No VM SKU selection, no node pool definitions, no manual scaling.

## Deployment Safeguards

Deployment Safeguards are **enforced at the cluster level** in AKS Automatic. They are not optional.

- The cluster operates in either **Warning** mode (logs violations but allows deployment) or **Enforcement** mode (rejects non-compliant manifests outright).
- Non-compliant manifests will be rejected by the admission controller if Enforcement is active. This means your YAML must comply before `kubectl apply` will succeed.
- Safeguards cover: resource requests/limits, pod disruption budgets, readiness/liveness probes, restricted pod security standards, and more.

**See `safeguards.md` for the full list of enforced rules and how to write compliant manifests.**

Common things that will be rejected in Enforcement mode:
- Pods without `resources.requests` and `resources.limits`
- Containers running as root or with privileged security context
- Missing readiness or liveness probes
- Pods without a `PodDisruptionBudget`
- Images referenced by mutable tags (e.g., `:latest`)

## Workload Identity

Workload Identity is the **mandatory** approach for authenticating pods to Azure services. Do not use connection strings, storage keys, or `imagePullSecrets` for ACR.

The identity chain flows: **Managed Identity → Federated Credential → Kubernetes ServiceAccount → Pod**. ACR pull access is granted by assigning the `AcrPull` role to the cluster's kubelet identity (see [templates/bicep/acr.bicep](#templates-bicep-modules) for the role assignment template).

**See `workload-identity.md` for the full setup guide, Bicep examples, and Kubernetes manifest examples.**

## Monitoring

AKS Automatic includes built-in observability. No addons to enable or configure.

- **Container Insights:** Log collection from stdout/stderr, pod metrics, node metrics — sent to a Log Analytics Workspace.
- **Prometheus metrics:** Managed Prometheus (Azure Monitor Workspace) is enabled by default.
- **Grafana dashboards:** Azure Managed Grafana connects to the Prometheus data source for pre-built K8s dashboards.

You do need to ensure the Log Analytics Workspace and Azure Monitor Workspace resources exist and are referenced in the cluster Bicep.

## What Developers DON'T Need to Worry About

- **Node sizing:** NAP picks VM SKUs automatically.
- **OS patching:** Applied automatically with no maintenance windows to schedule.
- **Kubernetes upgrades:** Rolled out automatically.
- **Network plugins:** Azure CNI Overlay with Cilium is configured automatically.
- **kube-proxy configuration:** Cilium replaces kube-proxy; no iptables tuning needed.
- **Ingress controller installation:** Web App Routing (NGINX) is built in. Gateway API via Istio is optionally available.

## Bicep Configuration

### Cluster Resource

```bicep
resource cluster 'Microsoft.ContainerService/managedClusters@2025-03-01' = {
  name: clusterName
  location: location
  sku: {
    name: 'Automatic'
    tier: 'Standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // DNS prefix for the cluster API server
    dnsPrefix: clusterName

    // Node resource group naming control
    nodeResourceGroup: '${clusterName}-nodes'
    nodeResourceGroupProfile: {
      restrictionLevel: 'ReadOnly' // Prevent manual changes to managed infrastructure
    }

    // Agent pool — Automatic uses a single system pool named 'systempool'
    // NAP manages all node provisioning beyond this
    agentPoolProfiles: [
      {
        name: 'systempool'
        mode: 'System'
        count: 3 // Initial count; NAP adjusts as needed
      }
    ]

    // OIDC issuer — required for Workload Identity federated credentials
    oidcIssuerProfile: {
      enabled: true
    }

    // Workload Identity — enables the mutating webhook for token injection
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }

    // Monitoring
    azureMonitorProfile: {
      metrics: {
        enabled: true
      }
      containerInsights: {
        enabled: true
        logAnalyticsWorkspaceResourceId: logAnalyticsWorkspace.id
      }
    }
  }
}
```

### Key Bicep Observations

- `agentPoolProfiles` must have a system pool, but you do NOT define user pools. NAP handles all workload node provisioning.
- No `vmSize` is specified in the pool — Automatic selects it.
- No `networkProfile` block is needed — networking is fully managed.
- No ingress addon configuration needed — Web App Routing (NGINX) is included by default. Gateway API via Istio can be enabled optionally.
- `nodeResourceGroupProfile.restrictionLevel: 'ReadOnly'` prevents manual modification of the managed node resource group.

## Limitations

- **No custom node pools.** You cannot create user node pools or pin workloads to specific VM SKUs.
- **No Windows containers.** As of 2025, AKS Automatic only supports Linux node pools.
- **Limited addon flexibility.** You cannot install arbitrary addons that require node-level configuration (e.g., custom CSI drivers, specific CNI plugins).
- **No GPU nodes.** NAP does not currently auto-provision GPU-equipped VMs in Automatic SKU.
- **No Ingress resource support when Istio is enabled.** If Istio Gateway API is enabled, you must use `Gateway` + `HTTPRoute`. If Istio is disabled (the default), use standard `Ingress` resources with `ingressClassName: webapprouting.kubernetes.azure.com`.
- **Deployment Safeguards cannot be disabled.** If your existing manifests are non-compliant, you must fix them before deploying.

## Reference: AKS Standard

> **Last updated:** 2026-04-10

## What is AKS Standard

AKS Standard is the traditional managed Kubernetes offering on Azure where you retain full control over node pools, VM sizes, networking, ingress, and upgrade scheduling. Compared to AKS Automatic, you get more flexibility and configuration options, but you also take on more responsibility — you choose the VM SKUs, configure autoscaling, pick your ingress controller, schedule maintenance windows, and manage OS patch cadence. If Automatic is "Azure decides," Standard is "you decide, Azure runs it."

## Key Differences from Automatic

| Aspect | Automatic | Standard |
|--------|-----------|----------|
| Node pools | Fully managed by NAP, no user pools | User-defined system + user pools with explicit VM SKU |
| Ingress | NGINX (web app routing addon) by default; Gateway API via Istio optionally | NGINX (web app routing addon) or BYO controller via `Ingress` |
| VM SKU selection | Azure picks automatically | You specify per node pool |
| K8s upgrades | Automatic | Manual or scheduled maintenance windows |
| OS patching | Automatic | Node image upgrades (manual, scheduled, or unattended) |
| Deployment Safeguards | Enforced, not optional | Optional, recommended |
| Network config | Fully managed (CNI Overlay + Cilium) | You choose: CNI Overlay, CNI + VNet, Kubenet |
| Windows containers | Not supported | Supported via Windows node pools |
| GPU workloads | Not supported | Supported via GPU VM SKUs |

## Node Pools

### System Pool (required)

Every AKS Standard cluster needs at least one system pool. System pools run core AKS components (CoreDNS, metrics-server, etc.). System pods have `CriticalAddonsOnly` toleration.

- Minimum 2 nodes recommended for production (availability during upgrades).
- Use a general-purpose VM SKU: `Standard_D2s_v3` (2 vCPU, 8 GiB) for small clusters, `Standard_D4s_v3` (4 vCPU, 16 GiB) for medium.

### User Pools (optional, recommended)

Run application workloads on dedicated user pools to isolate them from system components.

- You can create multiple user pools with different VM SKUs for different workload types.
- Use taints and tolerations or node selectors to schedule specific workloads on specific pools.

### VM SKU Recommendations

| Workload | Recommended SKU | vCPU | Memory |
|----------|----------------|------|--------|
| Small / dev-test | `Standard_D2s_v3` | 2 | 8 GiB |
| Medium / production | `Standard_D4s_v3` | 4 | 16 GiB |
| Memory-intensive | `Standard_E4s_v3` | 4 | 32 GiB |
| GPU (ML/AI) | `Standard_NC6s_v3` | 6 | 112 GiB + 1 V100 |
| Windows workloads | `Standard_D4s_v3` | 4 | 16 GiB |

### Node Pool Bicep Configuration

```bicep
agentPoolProfiles: [
  {
    name: 'system'
    mode: 'System'
    vmSize: 'Standard_D2s_v3'
    count: 2
    minCount: 2
    maxCount: 4
    enableAutoScaling: true
    osType: 'Linux'
    osSKU: 'AzureLinux'
    availabilityZones: ['1', '2', '3']
  }
  {
    name: 'apps'
    mode: 'User'
    vmSize: 'Standard_D4s_v3'
    count: 2
    minCount: 1
    maxCount: 10
    enableAutoScaling: true
    osType: 'Linux'
    osSKU: 'AzureLinux'
    availabilityZones: ['1', '2', '3']
    nodeTaints: [] // Add taints if you want workload isolation
    nodeLabels: {
      workload: 'app'
    }
  }
]
```

## Ingress

### Recommended: Web Application Routing Addon (NGINX-based)

The simplest path for ingress on AKS Standard is the **web application routing addon**. It deploys a managed NGINX ingress controller.

Enable it in Bicep:

```bicep
ingressProfile: {
  webAppRouting: {
    enabled: true
    dnsZoneResourceIds: [
      dnsZone.id // Optional: for automatic DNS record management
    ]
  }
}
```

### Ingress Resource YAML

Use the standard `Ingress` resource. Gateway API (`Gateway` / `HTTPRoute`) is only available when Istio is explicitly enabled via `appRoutingIstio.mode: Enabled` — this applies to both AKS Standard and Automatic.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  namespace: app-namespace
  annotations:
    # Use the web app routing ingress class
    spec.ingressClassName: webapprouting.kubernetes.azure.com
    # Optional: enable TLS via Key Vault integration
    # kubernetes.azure.com/tls-cert-keyvault-uri: "https://myvault.vault.azure.net/certificates/my-cert"
spec:
  ingressClassName: webapprouting.kubernetes.azure.com
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 8080
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend-service
                port:
                  number: 3000
  tls:
    - hosts:
        - myapp.example.com
      secretName: app-tls-secret
```

### BYO Ingress Controller

If you need more control, install your own ingress controller (e.g., NGINX community, Traefik, HAProxy) via Helm. In that case, do NOT enable the `webAppRouting` addon — use your controller's `ingressClassName` instead.

## Networking

### Recommended: Azure CNI Overlay

Azure CNI Overlay gives pods their own IP addresses from a private CIDR that overlays the VNet. This is simpler than traditional CNI (which consumes VNet IPs for every pod) and avoids IP exhaustion.

```bicep
networkProfile: {
  networkPlugin: 'azure'
  networkPluginMode: 'overlay'
  networkPolicy: 'azure' // Azure NPM; or use 'calico' for Calico
  podCidr: '10.244.0.0/16'
  serviceCidr: '10.0.0.0/16'
  dnsServiceIP: '10.0.0.10'
}
```

### Network Policy Options

| Policy Engine | Best For |
|--------------|----------|
| `azure` (Azure NPM) | Simple L3/L4 policies, native Azure integration |
| `calico` | Advanced policies, L7 rules, global network sets |

Choose one at cluster creation — it cannot be changed later.

## Deployment Safeguards

Deployment Safeguards are **optional** on AKS Standard but **strongly recommended**, especially for production clusters.

### Modes

- **Warning:** Violations are logged in Azure Policy / audit logs but deployments are allowed. Good for rolling out compliance incrementally.
- **Enforcement:** Non-compliant manifests are rejected by the admission controller. Same behavior as AKS Automatic.
- **Off:** No safeguards applied (default for Standard).

### Bicep Configuration

```bicep
properties: {
  safeguardsProfile: {
    level: 'Warning' // or 'Enforcement' or 'Off'
    excludedNamespaces: [
      'kube-system'
      'gatekeeper-system'
    ]
  }
}
```

**See `safeguards.md` for the full list of rules and how to write compliant manifests.** Even if you start with Warning mode, write manifests that pass Enforcement — it makes future tightening painless.

## Workload Identity

Workload Identity setup is the **same** as AKS Automatic: Managed Identity → Federated Credential → ServiceAccount → Pod. The difference is that it's recommended but not enforced — you could use connection strings or secrets, but you shouldn't.

Enable it by setting `oidcIssuerProfile.enabled: true` and `securityProfile.workloadIdentity.enabled: true` in the cluster Bicep (shown in the full cluster example below). ACR pull access uses the same `AcrPull` role assignment — see [templates/bicep/acr.bicep](#templates-bicep-modules) for the template.

**See `workload-identity.md` for the full setup guide, Bicep examples, and Kubernetes manifest examples.**

## Scaling

### Cluster Autoscaler (node-level)

Configured per node pool in `agentPoolProfiles`:

```bicep
{
  name: 'apps'
  mode: 'User'
  vmSize: 'Standard_D4s_v3'
  enableAutoScaling: true
  minCount: 1    // Scale down to 1 node during low usage
  maxCount: 10   // Scale up to 10 nodes under load
  count: 2       // Initial node count
}
```

The autoscaler adds nodes when pods are pending due to insufficient resources and removes nodes when utilization is low.

### Horizontal Pod Autoscaler (pod-level)

Scale pods based on CPU, memory, or custom metrics:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa
  namespace: app-namespace
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-deployment
  minReplicas: 2
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

### Manual Scaling

If autoscaling is disabled, set `count` in the node pool and scale with:

```sh
az aks nodepool scale --resource-group <rg> --cluster-name <cluster> --name apps --node-count 5
```

## Bicep Configuration — Full Cluster

```bicep
resource cluster 'Microsoft.ContainerService/managedClusters@2025-03-01' = {
  name: clusterName
  location: location
  sku: {
    name: 'Base'
    tier: 'Standard' // or 'Free' for dev/test (no SLA), 'Premium' for advanced features
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: clusterName

    nodeResourceGroup: '${clusterName}-nodes'

    agentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        vmSize: 'Standard_D2s_v3'
        count: 2
        minCount: 2
        maxCount: 4
        enableAutoScaling: true
        osType: 'Linux'
        osSKU: 'AzureLinux'
        availabilityZones: ['1', '2', '3']
      }
      {
        name: 'apps'
        mode: 'User'
        vmSize: 'Standard_D4s_v3'
        count: 2
        minCount: 1
        maxCount: 10
        enableAutoScaling: true
        osType: 'Linux'
        osSKU: 'AzureLinux'
        availabilityZones: ['1', '2', '3']
      }
    ]

    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkPolicy: 'azure'
      podCidr: '10.244.0.0/16'
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
    }

    oidcIssuerProfile: {
      enabled: true
    }

    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }

    safeguardsProfile: {
      level: 'Warning'
      excludedNamespaces: [
        'kube-system'
        'gatekeeper-system'
      ]
    }

    ingressProfile: {
      webAppRouting: {
        enabled: true
      }
    }

    azureMonitorProfile: {
      metrics: {
        enabled: true
      }
      containerInsights: {
        enabled: true
        logAnalyticsWorkspaceResourceId: logAnalyticsWorkspace.id
      }
    }
  }
}
```

### Contrast with Automatic Bicep

| Property | Standard | Automatic |
|----------|----------|-----------|
| `sku.name` | `'Base'` | `'Automatic'` |
| `agentPoolProfiles` | Explicit system + user pools with `vmSize` | Single system pool, no `vmSize`, NAP handles the rest |
| `networkProfile` | Required — you configure CNI, policy, CIDRs | Not needed — fully managed |
| `ingressProfile.webAppRouting` | Enabled for NGINX ingress | Enabled for NGINX ingress (same as Standard); Gateway API via Istio optionally available |
| `safeguardsProfile` | Optional, defaults to `Off` | Always active, cannot be disabled |
| `nodeResourceGroupProfile` | Optional | `restrictionLevel: 'ReadOnly'` enforced |

## When to Choose Standard

Choose AKS Standard over Automatic when you need:

- **Windows containers** — Automatic does not support Windows node pools.
- **Specific VM SKUs** — You need to pin workloads to exact VM families (e.g., memory-optimized E-series, compute-optimized F-series).
- **GPU nodes** — ML/AI workloads requiring NC, ND, or NV-series VMs.
- **Custom networking** — Specific VNet integration, custom route tables, or advanced network policy requirements (Calico).
- **Full control over upgrades** — You want to test K8s upgrades in staging before production, or maintain version pinning.
- **Full control over patching** — Scheduled node image upgrades during specific maintenance windows.
- **BYO ingress controller** — You need Traefik, HAProxy, or a specific NGINX configuration that the web app routing addon doesn't support.
- **Custom addons / extensions** — CSI drivers, service meshes, or policy engines that require node-level access.
- **Compliance requirements** — Regulations that mandate specific node configurations, disk encryption with customer-managed keys, or dedicated hosts.

If none of the above apply, AKS Automatic is simpler and reduces operational burden.

## Knowledge Packs


### Aspnet Core

> **Applies to:** Projects detected with `*.csproj` containing `Microsoft.NET.Sdk.Web` or referencing `Microsoft.AspNetCore.*` packages

---

## Dockerfile Patterns

### Multi-stage build with project-file-first NuGet restore

Copying only `*.csproj` and restoring before copying source ensures NuGet restore is cached unless dependencies change:

```dockerfile
# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS build
WORKDIR /app
COPY *.csproj ./
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS runtime
WORKDIR /app
ENV DOTNET_EnableDiagnostics=0 \
    DOTNET_RUNNING_IN_CONTAINER=true
COPY --from=build /app/publish .
USER app
EXPOSE 8080
ENTRYPOINT ["dotnet", "<app-name>.dll"]
```

### Key points

- **Base image:** `mcr.microsoft.com/dotnet/aspnet` is the official Microsoft runtime image — minimal and supported
- **Alpine variant** reduces image size by ~60% compared to the Debian-based tag
- **Project-file-first copy** (`COPY *.csproj`) means `dotnet restore` layer is cached until dependencies change
- **Non-root user** (`app`, uid 1654) is built into .NET 8+ images — no need to create one manually; satisfies DS004
- **`DOTNET_EnableDiagnostics=0`** disables diagnostic pipes that require writable paths not available in read-only filesystems
- **`DOTNET_RUNNING_IN_CONTAINER=true`** signals the runtime to optimize for container environments (GC, thread pool)

### Self-contained deployment variant

For environments where you want no dependency on the shared .NET runtime, publish as self-contained and use the smaller `runtime-deps` base image:

```dockerfile
# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS build
WORKDIR /app
COPY *.csproj ./
RUN dotnet restore --runtime linux-musl-x64
COPY . .
RUN dotnet publish -c Release -o /app/publish \
    --runtime linux-musl-x64 \
    --self-contained true \
    -p:PublishSingleFile=true \
    -p:PublishTrimmed=true

# Runtime stage — no .NET runtime needed
FROM mcr.microsoft.com/dotnet/runtime-deps:8.0-alpine AS runtime
WORKDIR /app
ENV DOTNET_EnableDiagnostics=0 \
    DOTNET_RUNNING_IN_CONTAINER=true
COPY --from=build /app/publish .
USER app
EXPOSE 8080
ENTRYPOINT ["./<app-name>"]
```

This produces a single native binary and yields the smallest possible image (~30-50MB). Use `linux-musl-x64` for Alpine or `linux-x64` for Debian-based images.

### Multi-project solutions

For solutions with multiple projects, copy all `.csproj` files preserving directory structure before restore:

```dockerfile
COPY ["src/MyApp.Api/MyApp.Api.csproj", "src/MyApp.Api/"]
COPY ["src/MyApp.Core/MyApp.Core.csproj", "src/MyApp.Core/"]
RUN dotnet restore "src/MyApp.Api/MyApp.Api.csproj"
COPY . .
RUN dotnet publish "src/MyApp.Api/MyApp.Api.csproj" -c Release -o /app/publish
```

---

## Health Endpoints

ASP.NET Core has built-in health check middleware via `Microsoft.Extensions.Diagnostics.HealthChecks`:

| Endpoint | Purpose | Probe Type |
|----------|---------|-----------|
| `/healthz` | Overall health | `livenessProbe` |
| `/ready` | Dependency readiness | `readinessProbe` |

### Required configuration

In `Program.cs`:

```csharp
var builder = WebApplication.CreateBuilder(args);

// Register health checks
builder.Services.AddHealthChecks()
    .AddNpgSql(builder.Configuration.GetConnectionString("DefaultConnection")!,
        name: "postgresql",
        tags: new[] { "ready" });

var app = builder.Build();

// Map health endpoints
app.MapHealthChecks("/healthz", new HealthCheckOptions
{
    Predicate = _ => false // No dependency checks for liveness
});

app.MapHealthChecks("/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready")
});
```

The `AspNetCore.HealthChecks.NpgSql` NuGet package provides the PostgreSQL health check. Install with:

```bash
dotnet add package AspNetCore.HealthChecks.NpgSql
```

### Probe configuration in Deployment manifest

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 15
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

**Note:** ASP.NET Core apps start significantly faster than JVM-based frameworks — `initialDelaySeconds: 5` is typically sufficient.

---

## Database Profiles

ASP.NET Core uses configuration providers and Entity Framework Core for database access:

| Configuration Source | Activation | Typical Usage |
|---------------------|------------|---------------|
| `appsettings.json` | Default | Local dev with SQLite or LocalDB |
| `appsettings.Production.json` | `ASPNETCORE_ENVIRONMENT=Production` | Production connection strings |
| Environment variables | Always override file config | AKS deployments |

### Environment variables for PostgreSQL on AKS

```yaml
env:
  - name: ASPNETCORE_ENVIRONMENT
    value: Production
  - name: ConnectionStrings__DefaultConnection
    value: "Host={{PG_SERVER_NAME}}.postgres.database.azure.com;Database={{DB_NAME}};Username={{IDENTITY_NAME}};Ssl Mode=Require"
```

The double-underscore (`__`) in `ConnectionStrings__DefaultConnection` maps to the `:` separator in .NET configuration — `ConnectionStrings:DefaultConnection`.

### Workload Identity with Azure.Identity

With Workload Identity, you can authenticate to PostgreSQL without storing passwords. Add the `Azure.Identity` and `Npgsql` packages:

```bash
dotnet add package Azure.Identity
dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL
```

Configure the `DbContext` to use Azure AD token authentication:

```csharp
builder.Services.AddDbContext<AppDbContext>(options =>
{
    var dataSource = new NpgsqlDataSourceBuilder(
        builder.Configuration.GetConnectionString("DefaultConnection"))
    {
        // Azure AD token provider for passwordless auth
    }.Build();
    options.UseNpgsql(dataSource);
});
```

### ConfigMap pattern

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{APP_NAME}}-config
data:
  ASPNETCORE_ENVIRONMENT: "Production"
  ConnectionStrings__DefaultConnection: "Host={{PG_SERVER_NAME}}.postgres.database.azure.com;Database={{DB_NAME}};Ssl Mode=Require"
  DOTNET_EnableDiagnostics: "0"
  DOTNET_RUNNING_IN_CONTAINER: "true"
```

---

## Writable Paths (DS012 Compliance)

When `readOnlyRootFilesystem: true` is set, ASP.NET Core needs `/tmp` writable:

- **Data Protection keys** are written to a local directory by default for key persistence
- **Temporary files** from multipart uploads and response buffering use `/tmp`
- **Entity Framework** compiled models may write to temp directories

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

### Data Protection key persistence

By default, ASP.NET Core Data Protection stores encryption keys in-memory when no persistent path is available, meaning keys are lost on pod restart. This breaks authentication cookies and anti-forgery tokens across pod restarts or in multi-replica deployments.

For production, persist keys to Azure Blob Storage:

```csharp
builder.Services.AddDataProtection()
    .PersistKeysToAzureBlobStorage("<connection-string>", "<container>", "<blob-name>")
    .ProtectKeysWithAzureKeyVault(new Uri("<key-vault-uri>"), new DefaultAzureCredential());
```

Alternatively, mount a PVC at a known path and configure:

```csharp
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/keys"));
```

---

## Port Configuration

- **Default port:** 8080 (since .NET 8; previously 80 in .NET 7 and earlier)
- **Env var override:** `ASPNETCORE_URLS=http://+:8080` or `ASPNETCORE_HTTP_PORTS=8080`
- **Code override:** `builder.WebHost.UseUrls("http://+:8080")` in `Program.cs`

The port change from 80 to 8080 in .NET 8 aligns with non-root container best practices — port 80 requires elevated privileges.

---

## Build Commands

| Variant | Build Command | Output |
|---------|---------------|--------|
| Framework-dependent | `dotnet publish -c Release -o ./publish` | `./publish/<app-name>.dll` — requires .NET runtime on target |
| Self-contained | `dotnet publish -c Release --self-contained -o ./publish` | `./publish/<app-name>` — includes .NET runtime |
| Single-file | `dotnet publish -c Release --self-contained -p:PublishSingleFile=true -o ./publish` | Single executable binary |

The `-c Release` flag enables compiler optimizations and disables debug symbols — always use it for production builds.

---

## Common Issues on AKS

| Issue | Symptom | Fix |
|-------|---------|-----|
| Kestrel bound to port 80 | `CrashLoopBackOff` — permission denied binding to port 80 as non-root | Set `ASPNETCORE_HTTP_PORTS=8080` or upgrade to .NET 8+ which defaults to 8080 |
| Data Protection keys lost on restart | Users logged out after pod restart, anti-forgery token validation failures | Persist keys to Azure Blob Storage or a PVC — do not rely on in-memory default |
| EF Core migrations not applied | `NpgsqlException: relation "..." does not exist` | Run `dotnet ef database update` as an init container or at startup with `Database.Migrate()` |
| Image too large (>500MB) | Slow pulls, high ACR storage | Use self-contained + trimmed publish with `runtime-deps` Alpine base image |
| HTTPS redirect loop behind gateway | Infinite 307/308 redirects, `ERR_TOO_MANY_REDIRECTS` | Disable HTTPS redirection in `Program.cs` when behind a TLS-terminating gateway — configure `ForwardedHeaders` middleware instead |

### Django

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

### Express

> **Applies to:** Projects detected with `package.json` containing `express` or `fastify` as a dependency

---

## Dockerfile Patterns

### Multi-stage build with dumb-init for signal handling

Node.js does not handle `SIGTERM` correctly when running as PID 1. Use `dumb-init` as the entrypoint to forward signals properly:

```dockerfile
# Build stage
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build --if-present

# Runtime stage
FROM node:22-alpine AS runtime
RUN apk add --no-cache dumb-init
WORKDIR /app
COPY --from=build /app/package.json /app/package-lock.json ./
RUN npm ci --omit=dev
COPY --from=build /app/dist ./dist
COPY --from=build /app/src ./src
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost:3000/healthz || exit 1
ENTRYPOINT ["dumb-init", "node", "dist/index.js"]
```

### Key points

- **Base image:** Official `node:22-alpine` — minimal footprint, receives LTS security patches
- **Alpine variant** reduces image size by ~70% compared to Debian-based `node:22`
- **`dumb-init`** ensures `SIGTERM` from Kubernetes is forwarded to the Node process so graceful shutdown works
- **`npm ci --omit=dev`** strips dev dependencies from the runtime image, cutting image size and attack surface
- **`USER node`** — the official Node Alpine image ships with a built-in `node` user (uid 1000), satisfying DS004 without creating a custom user

### Fastify listen caveat

Fastify defaults to listening on `127.0.0.1`, which is unreachable from outside the container. Bind to `0.0.0.0` explicitly:

```js
await fastify.listen({ port: 3000, host: '0.0.0.0' });
```

If the pod starts but health probes fail with `connection refused`, this is almost always the cause.

### Package manager variants

| Package Manager | Install (all) | Install (prod only) | Lock File |
|----------------|---------------|---------------------|-----------|
| npm | `npm ci` | `npm ci --omit=dev` | `package-lock.json` |
| yarn | `yarn install --frozen-lockfile` | `yarn install --frozen-lockfile --production` | `yarn.lock` |
| pnpm | `pnpm install --frozen-lockfile` | `pnpm install --frozen-lockfile --prod` | `pnpm-lock.yaml` |

Copy the correct lock file in the Dockerfile `COPY` step to match the project's package manager.

---

## Health Endpoints

Node.js frameworks do not provide health endpoints out of the box. Add a `/healthz` route manually.

### Express

```js
app.get('/healthz', (req, res) => {
  res.status(200).json({ status: 'UP' });
});
```

### Fastify

```js
fastify.get('/healthz', async () => {
  return { status: 'UP' };
});
```

For richer checks (database connectivity, downstream services), extend the handler to verify dependencies and return `503` when unhealthy.

### Probe configuration in Deployment manifest

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 15
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

**Note:** Node.js apps start in under a second, so `initialDelaySeconds: 5` is sufficient. No `startupProbe` is needed unless the app performs heavy initialization (e.g., loading ML models).

---

## Database Profiles

Node.js projects use a variety of database libraries. The standard pattern is a `DATABASE_URL` connection string injected via environment variable:

| Library | Connection Pattern | Config Property |
|---------|-------------------|-----------------|
| `pg` (node-postgres) | `new Pool({ connectionString: process.env.DATABASE_URL })` | `DATABASE_URL` |
| Prisma | `datasource db { url = env("DATABASE_URL") }` in `schema.prisma` | `DATABASE_URL` |
| Sequelize | `new Sequelize(process.env.DATABASE_URL)` | `DATABASE_URL` |
| Knex | `connection: process.env.DATABASE_URL` in `knexfile.js` | `DATABASE_URL` |

### Environment variables for PostgreSQL on AKS

```yaml
env:
  - name: DATABASE_URL
    value: "postgresql://{{IDENTITY_NAME}}@{{PG_SERVER_NAME}}.postgres.database.azure.com:5432/{{DB_NAME}}?sslmode=require"
  - name: PGHOST
    value: "{{PG_SERVER_NAME}}.postgres.database.azure.com"
  - name: PGDATABASE
    value: "{{DB_NAME}}"
  - name: PGUSER
    value: "{{IDENTITY_NAME}}"
  - name: PGPORT
    value: "5432"
  - name: PGSSLMODE
    value: "require"
```

For Workload Identity with passwordless authentication, use the `@azure/identity` package with `pg` to obtain Azure AD tokens instead of passwords.

### ConfigMap pattern

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{APP_NAME}}-config
data:
  NODE_ENV: "production"
  PGHOST: "{{PG_SERVER_NAME}}.postgres.database.azure.com"
  PGDATABASE: "{{DB_NAME}}"
  PGPORT: "5432"
  PGSSLMODE: "require"
```

---

## Writable Paths (DS012 Compliance)

When `readOnlyRootFilesystem: true` is set, Node.js apps need only `/tmp` writable:

- **Multipart uploads** (e.g., `multer`, `@fastify/multipart`) stage files to `/tmp`
- **Logging libraries** that buffer to disk use `/tmp`
- **No other writable paths** are typically needed — `node_modules` is read-only at runtime

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

No other writable paths are typically needed for production Node.js apps.

---

## Port Configuration

- **Default port:** 3000
- **Env var override:** `PORT=3000`
- **Code pattern:** `app.listen(process.env.PORT || 3000)`

Express binds to `0.0.0.0` by default, so it is reachable from outside the container without additional configuration.

Fastify binds to `127.0.0.1` by default — **you must pass `host: '0.0.0.0'`** in the `listen()` call or the pod will start but all probes and traffic will fail with `connection refused`.

---

## Build Commands

| Scenario | Build Command | Output | Entrypoint |
|----------|---------------|--------|------------|
| TypeScript | `npm run build` (invokes `tsc`) | `dist/` | `node dist/index.js` |
| JavaScript (no build) | None | `src/` | `node src/index.js` |
| Bundler (esbuild/webpack) | `npm run build` | `dist/bundle.js` | `node dist/bundle.js` |

For TypeScript projects, ensure `tsconfig.json` has `"outDir": "dist"` and the Dockerfile copies the `dist/` folder to the runtime stage. Do **not** install `typescript` or `ts-node` in the production image.

---

## Common Issues on AKS

| Issue | Symptom | Fix |
|-------|---------|-----|
| No SIGTERM handling | Pod takes 30s to terminate (killed by `SIGKILL` after grace period) | Use `dumb-init` as entrypoint, or add explicit `process.on('SIGTERM', ...)` handler to close the server gracefully |
| ECONNRESET on PostgreSQL | `Error: Connection terminated unexpectedly` | Configure pool `idleTimeoutMillis` and `connectionTimeoutMillis`; Azure PG Flexible Server closes idle connections after ~5 min |
| Fastify localhost binding | Health probes fail with `connection refused` despite app running | Pass `host: '0.0.0.0'` to `fastify.listen()` — Fastify defaults to `127.0.0.1` |
| node_modules bloat | Image > 500MB, slow pulls from ACR | Run `npm ci --omit=dev` in a separate stage; consider esbuild bundling for single-file output |
| Memory leak under load | Pod `OOMKilled` after hours of traffic | Set `--max-old-space-size` to ~75% of container memory limit (e.g., `--max-old-space-size=384` for 512Mi limit); profile with `--inspect` locally |

### Fastapi

> **Applies to:** Projects detected with `requirements.txt`, `pyproject.toml`, or `Pipfile` containing `fastapi`

---

## Dockerfile Patterns

### Multi-stage build with virtual environment

Using a virtual environment in a multi-stage build keeps the final image lean by copying only installed packages:

```dockerfile
# Build stage
FROM python:3.12-slim AS build
WORKDIR /app
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .

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
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1
ENTRYPOINT ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Key points

- **Base image:** `python:3.12-slim` over Alpine — Alpine uses musl libc which causes build failures with many Python C extensions (numpy, psycopg2, cryptography)
- **`PYTHONDONTWRITEBYTECODE=1`** prevents `.pyc` files from bloating the image
- **`PYTHONUNBUFFERED=1`** ensures logs appear immediately in `kubectl logs` without buffering
- **`--no-cache-dir`** for pip avoids caching wheel files in the image layer
- **Non-root user** (`app`) satisfies DS004
- **Virtual environment copy** (`/opt/venv`) cleanly separates dependencies from build tools

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

# Runtime stage — same as above
```

### uv variant

```dockerfile
# Build stage
FROM python:3.12-slim AS build
WORKDIR /app
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
COPY pyproject.toml uv.lock ./
RUN uv venv /opt/venv && \
    . /opt/venv/bin/activate && \
    uv sync --frozen --no-dev
COPY . .

# Runtime stage — same as above
```

---

## Health Endpoints

FastAPI health endpoints must be defined explicitly in application code:

### Minimal health route

```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/health")
async def health():
    return {"status": "ok"}
```

### Readiness route with database check

```python
from fastapi import FastAPI, status
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

@app.get("/ready")
async def ready(db: AsyncSession = Depends(get_db)):
    try:
        await db.execute(text("SELECT 1"))
        return {"status": "ready"}
    except Exception:
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"status": "not ready"},
        )
```

### Probe configuration in Deployment manifest

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 5
  periodSeconds: 15
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

**Note:** FastAPI apps start quickly (typically <2s), so `initialDelaySeconds: 5` is sufficient — much lower than JVM-based frameworks.

---

## Database Profiles

FastAPI does not have a built-in profile system. Database configuration is typically driven by environment variables:

| ORM / Driver | Package(s) | Connection String Format |
|-------------|-----------|--------------------------|
| SQLAlchemy async + asyncpg | `sqlalchemy[asyncio]`, `asyncpg` | `postgresql+asyncpg://user:pass@host:5432/db` |
| Tortoise ORM | `tortoise-orm`, `asyncpg` | `postgres://user:pass@host:5432/db` |
| SQLModel | `sqlmodel`, `asyncpg` | `postgresql+asyncpg://user:pass@host:5432/db` |
| asyncpg direct | `asyncpg` | `postgresql://user:pass@host:5432/db` |

**Important:** SQLAlchemy async requires the `+asyncpg` suffix in the connection URL scheme (`postgresql+asyncpg://`). Omitting it will default to the synchronous `psycopg2` driver, which blocks the event loop.

### Environment variables for PostgreSQL on AKS

```yaml
env:
  - name: DATABASE_URL
    value: "postgresql+asyncpg://{{IDENTITY_NAME}}@{{PG_SERVER_NAME}}.postgres.database.azure.com:5432/{{DB_NAME}}?sslmode=require"
```

### ConfigMap pattern

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{APP_NAME}}-config
data:
  DATABASE_URL: "postgresql+asyncpg://{{IDENTITY_NAME}}@{{PG_SERVER_NAME}}.postgres.database.azure.com:5432/{{DB_NAME}}?sslmode=require"
  UVICORN_WORKERS: "1"
```

### Workload Identity with azure-identity

With Workload Identity, you can authenticate to Azure PostgreSQL without storing passwords. Install `azure-identity`:

```bash
pip install azure-identity
```

Use `DefaultAzureCredential` to obtain an Azure AD token and pass it as the password when creating the async engine:

```python
from azure.identity import DefaultAzureCredential

credential = DefaultAzureCredential()
token = credential.get_token("https://ossrdbms-aad.database.windows.net/.default")

# Pass token as password in the connection URL or via connect_args
engine = create_async_engine(
    DATABASE_URL,
    connect_args={"password": token.token},
)
```

**Note:** Azure AD tokens expire (typically after 1 hour). For long-running apps, refresh the token in a `pool_events.connect` listener or use a connection pool that supports token refresh callbacks.

---

## Writable Paths (DS012 Compliance)

When `readOnlyRootFilesystem: true` is set, FastAPI apps typically only need `/tmp` writable:

- **Uploaded files** use `/tmp` as the default staging directory for `UploadFile`
- **Temporary processing** may write intermediate results to `/tmp`

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

No other writable paths are typically needed for production FastAPI apps.

---

## Port Configuration

- **Default port:** 8000
- **CLI flag:** `--port 8000` passed to `uvicorn`
- **Env var override:** `PORT` (read via `uvicorn --port $PORT` or `int(os.environ.get("PORT", 8000))`)

Uvicorn logs the port on startup: `Uvicorn running on http://0.0.0.0:8000`

---

## Build Commands

| Tool | Install Command | Output |
|------|----------------|--------|
| pip | `pip install --no-cache-dir -r requirements.txt` | Packages in site-packages |
| Poetry | `poetry install --only main --no-interaction` | Packages in virtualenv |
| uv | `uv sync --frozen --no-dev` | Packages in virtualenv |

The `--no-cache-dir` flag (pip) and `--no-interaction` flag (Poetry) suppress interactive prompts — important for CI/CD and Docker builds.

---

## Common Issues on AKS

| Issue | Symptom | Fix |
|-------|---------|-----|
| Uvicorn workers misconfigured | High latency under load, single-core CPU usage | Set `--workers` to `2 * CPU_CORES + 1` for sync code, or `1` when using async handlers (async code uses a single event loop) |
| Async DB pool exhaustion | `asyncpg.exceptions.TooManyConnectionsError` | Configure pool size with `create_async_engine(pool_size=5, max_overflow=10)` and match PostgreSQL `max_connections` |
| Alpine build fails | `gcc` errors installing `cryptography`, `psycopg2`, `numpy` | Use `python:3.12-slim` (Debian-based) instead of `python:3.12-alpine` |
| Uvicorn binds to localhost | Connection refused from Kubernetes probes | Set `--host 0.0.0.0` — uvicorn defaults to `127.0.0.1` which is unreachable from outside the container |
| Missing uvicorn in production | `ModuleNotFoundError: No module named 'uvicorn'` | Ensure `uvicorn[standard]` is in `requirements.txt` — it is often only in dev dependencies |

### Flask

> **Applies to:** Projects detected with `requirements.txt`, `pyproject.toml`, or `Pipfile` containing `flask`

---

## Dockerfile Patterns

### Multi-stage build with virtual environment

Flask requires a production WSGI server — never use `flask run` or `app.run()` in production. Gunicorn is the standard choice:

```dockerfile
# Build stage
FROM python:3.12-slim AS build
WORKDIR /app
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .

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
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1
ENTRYPOINT ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "3", "app:app"]
```

### Key points

- **Base image:** `python:3.12-slim` over Alpine — Alpine uses musl libc which causes build failures with many Python C extensions (psycopg2, cryptography)
- **`PYTHONDONTWRITEBYTECODE=1`** prevents `.pyc` files from bloating the image
- **`PYTHONUNBUFFERED=1`** ensures logs appear immediately in `kubectl logs` without buffering
- **`--no-cache-dir`** for pip avoids caching wheel files in the image layer
- **Non-root user** (`app`) satisfies DS004
- **Virtual environment copy** (`/opt/venv`) cleanly separates dependencies from build tools
- **Never use `flask run` or `app.run()` in production** — these start the Werkzeug development server which is single-threaded, not hardened, and not suitable for production traffic

### Entry point variants

- **Module-level `app` object:** `gunicorn "app:app"` — the most common pattern where `app = Flask(__name__)` is defined at module level
- **Application factory pattern:** `gunicorn "myapp:create_app()"` — when the app is created via a factory function like `def create_app(): app = Flask(__name__); return app`

### Workers formula

Set gunicorn workers to `2 * CPU_CORES + 1`. For a container with a 1-core CPU limit, use `--workers 3`. Adjust via the `WEB_CONCURRENCY` env var at runtime:

```dockerfile
ENTRYPOINT ["gunicorn", "--bind", "0.0.0.0:8000", "app:app"]
```

```yaml
env:
  - name: WEB_CONCURRENCY
    value: "3"
```

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

# Runtime stage — same as above
```

---

## Health Endpoints

Flask does not include health check endpoints — they must be defined explicitly in application code:

### Minimal health route

```python
from flask import Flask, jsonify

app = Flask(__name__)

@app.route("/health")
def health():
    return jsonify(status="ok"), 200
```

### Readiness route with database check

```python
from flask import jsonify
from sqlalchemy import text

@app.route("/ready")
def ready():
    try:
        db.session.execute(text("SELECT 1"))
        return jsonify(status="ready"), 200
    except Exception:
        return jsonify(status="not ready"), 503
```

### Probe configuration in Deployment manifest

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 5
  periodSeconds: 15
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

**Note:** Flask apps behind gunicorn start quickly (typically <3s), so `initialDelaySeconds: 5` is sufficient — much lower than JVM-based frameworks.

---

## Database Profiles

Flask does not have a built-in profile system. Database configuration is typically driven by environment variables:

| ORM / Driver | Package(s) | Connection String Env Var |
|-------------|-----------|--------------------------|
| Flask-SQLAlchemy | `flask-sqlalchemy`, `psycopg2-binary` | `SQLALCHEMY_DATABASE_URI` |
| SQLAlchemy direct | `sqlalchemy`, `psycopg2-binary` | `DATABASE_URL` |
| psycopg2 direct | `psycopg2-binary` | `DATABASE_URL` |

**Important:** Flask-SQLAlchemy reads the connection string from `app.config["SQLALCHEMY_DATABASE_URI"]`, which is typically set via `os.environ.get("SQLALCHEMY_DATABASE_URI")` or `os.environ.get("DATABASE_URL")`. Ensure the env var name matches what the app expects.

### Environment variables for PostgreSQL on AKS

```yaml
env:
  - name: SQLALCHEMY_DATABASE_URI
    value: "postgresql://{{IDENTITY_NAME}}@{{PG_SERVER_NAME}}.postgres.database.azure.com:5432/{{DB_NAME}}?sslmode=require"
  - name: SECRET_KEY
    valueFrom:
      secretKeyRef:
        name: {{APP_NAME}}-secrets
        key: secret-key
```

### Secret for SECRET_KEY

Flask requires `SECRET_KEY` for session signing, CSRF tokens, and any use of `flask.session`. Never hardcode it — store it in a Kubernetes Secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{APP_NAME}}-secrets
type: Opaque
stringData:
  secret-key: "<generate-a-random-string>"
```

### ConfigMap pattern

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{APP_NAME}}-config
data:
  SQLALCHEMY_DATABASE_URI: "postgresql://{{IDENTITY_NAME}}@{{PG_SERVER_NAME}}.postgres.database.azure.com:5432/{{DB_NAME}}?sslmode=require"
```

### Workload Identity with azure-identity

With Workload Identity, you can authenticate to Azure PostgreSQL without storing passwords. Install `azure-identity`:

```bash
pip install azure-identity
```

Use `DefaultAzureCredential` to obtain an Azure AD token and pass it as the password when creating the SQLAlchemy engine:

```python
from azure.identity import DefaultAzureCredential

credential = DefaultAzureCredential()
token = credential.get_token("https://ossrdbms-aad.database.windows.net/.default")

# Pass token as password via create_engine connect_args
engine = create_engine(
    SQLALCHEMY_DATABASE_URI,
    connect_args={"password": token.token},
)
```

**Note:** Azure AD tokens expire (typically after 1 hour). For long-running apps, refresh the token periodically using SQLAlchemy's `pool_events.connect` listener.

---

## Writable Paths (DS012 Compliance)

When `readOnlyRootFilesystem: true` is set, Flask apps typically only need `/tmp` writable:

- **Uploaded files** use `/tmp` as the default staging directory for `request.files`
- **Temporary processing** may write intermediate results to `/tmp`

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

No other writable paths are typically needed for production Flask apps.

---

## Port Configuration

- **Development port:** 5000 (`flask run` default — do not use in production)
- **Production port:** 8000 (gunicorn convention)
- **CLI flag:** `--bind 0.0.0.0:8000` passed to `gunicorn`
- **Env var override:** `PORT` (read via `gunicorn --bind 0.0.0.0:$PORT` or in app code `int(os.environ.get("PORT", 8000))`)

Gunicorn logs the port on startup: `Listening at: http://0.0.0.0:8000`

---

## Build Commands

| Tool | Install Command | Output |
|------|----------------|--------|
| pip | `pip install --no-cache-dir -r requirements.txt` | Packages in site-packages |
| Poetry | `poetry install --only main --no-interaction` | Packages in virtualenv |

The `--no-cache-dir` flag (pip) and `--no-interaction` flag (Poetry) suppress interactive prompts — important for CI/CD and Docker builds.

Ensure `gunicorn` is listed in `requirements.txt` or `pyproject.toml` production dependencies — it is not included with Flask.

---

## Common Issues on AKS

| Issue | Symptom | Fix |
|-------|---------|-----|
| Running dev server in production | Single-threaded, poor performance, `WARNING: This is a development server` in logs | Use `gunicorn` as the ENTRYPOINT — never use `flask run` or `app.run()` in production containers |
| `SECRET_KEY` not set | `RuntimeError: The session is unavailable because no secret key was set`, CSRF failures | Set `SECRET_KEY` via a Kubernetes Secret and reference it as an env var in the Deployment manifest |
| Flask binds to localhost | Connection refused from Kubernetes probes | Pass `--bind 0.0.0.0:8000` to gunicorn — the Flask dev server defaults to `127.0.0.1` which is unreachable from outside the container |
| Gunicorn not installed | `ModuleNotFoundError: No module named 'gunicorn'` | Ensure `gunicorn` is in `requirements.txt` or `pyproject.toml` main dependencies — it is often only in dev dependencies or missing entirely |
| DB connections not closed | `sqlalchemy.exc.TimeoutError: QueuePool limit`, PostgreSQL `max_connections` exhaustion | Configure pool size with `SQLALCHEMY_ENGINE_OPTIONS = {"pool_size": 5, "max_overflow": 10, "pool_recycle": 300}` and match PostgreSQL `max_connections` |

### Go

> **Applies to:** Projects detected with `go.mod` containing `github.com/gin-gonic/gin`, `github.com/labstack/echo`, `github.com/gofiber/fiber`, or any Go project using the standard library `net/http` for HTTP serving

---

## Dockerfile Patterns

### Static binary with distroless runtime

Go compiles to a single static binary, producing some of the smallest production images possible:

```dockerfile
# Build stage
FROM golang:1.23-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o /app/server ./cmd/server

# Runtime stage
FROM gcr.io/distroless/static-debian12 AS runtime
COPY --from=build /app/server /server
USER 65534
EXPOSE 8080
ENTRYPOINT ["/server"]
```

### Key points

- **`CGO_ENABLED=0`** produces a fully static binary with no libc dependency — required for `distroless/static`
- **`-ldflags="-s -w"`** strips debug symbols and DWARF info, reducing binary size by ~30%
- **`distroless/static-debian12`** is ~2MB — no shell, no package manager, minimal attack surface
- **`USER 65534`** is the `nobody` user in distroless, satisfying DS004

### CGO variant

If your app requires CGO (e.g., for SQLite, certain crypto libraries):

```dockerfile
FROM gcr.io/distroless/cc-debian12 AS runtime
COPY --from=build /app/server /server
USER 65534
EXPOSE 8080
ENTRYPOINT ["/server"]
```

The `distroless/cc` image includes glibc — use it only when `CGO_ENABLED=1` is required.

### Build cache mount optimization

For faster rebuilds in CI/CD, use Docker BuildKit cache mounts:

```dockerfile
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o /app/server ./cmd/server
```

This caches the module download and compilation artifacts across builds.

---

## Health Endpoints

Go does not provide health check endpoints out of the box — you must implement them manually.

### Gin

```go
r.GET("/healthz", func(c *gin.Context) {
    c.JSON(200, gin.H{"status": "ok"})
})
r.GET("/ready", func(c *gin.Context) {
    // Check database, external dependencies
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
e.GET("/ready", func(c echo.Context) error {
    if err := db.Ping(); err != nil {
        return c.JSON(503, map[string]string{"status": "not ready"})
    }
    return c.JSON(200, map[string]string{"status": "ready"})
})
```

### Fiber

```go
app.Get("/healthz", func(c *fiber.Ctx) error {
    return c.JSON(fiber.Map{"status": "ok"})
})
app.Get("/ready", func(c *fiber.Ctx) error {
    if err := db.Ping(); err != nil {
        return c.Status(503).JSON(fiber.Map{"status": "not ready"})
    }
    return c.JSON(fiber.Map{"status": "ready"})
})
```

### Standard library (net/http)

```go
http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusOK)
    w.Write([]byte(`{"status":"ok"}`))
})
http.HandleFunc("/ready", func(w http.ResponseWriter, r *http.Request) {
    if err := db.Ping(); err != nil {
        w.WriteHeader(http.StatusServiceUnavailable)
        w.Write([]byte(`{"status":"not ready"}`))
        return
    }
    w.WriteHeader(http.StatusOK)
    w.Write([]byte(`{"status":"ready"}`))
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

**Note:** Go binaries start in milliseconds — `initialDelaySeconds: 3` is generous. No JVM warmup or interpreter startup to wait for.

---

## Database Profiles

Go does not have a built-in profile system. Database configuration is typically driven by environment variables:

| Library | Driver | Connection Env Var |
|---------|--------|--------------------|
| `database/sql` + `pgx` | `github.com/jackc/pgx/v5/stdlib` | `DATABASE_URL` |
| GORM | `gorm.io/driver/postgres` | `DATABASE_URL` |
| sqlx | `github.com/jmoiron/sqlx` + `pgx` | `DATABASE_URL` |
| pgx direct | `github.com/jackc/pgx/v5` | `DATABASE_URL` |

### Environment variables for PostgreSQL on AKS

```yaml
env:
  - name: DATABASE_URL
    value: "host={{PG_SERVER_NAME}}.postgres.database.azure.com port=5432 dbname={{DB_NAME}} user={{IDENTITY_NAME}} sslmode=require"
```

### Workload Identity with pgx

Use `azidentity` to obtain Azure AD tokens and inject them via pgx's `BeforeConnect` hook — no password stored:

```go
import (
    "github.com/Azure/azure-sdk-for-go/sdk/azidentity"
    "github.com/jackc/pgx/v5"
)

cred, _ := azidentity.NewDefaultAzureCredential(nil)

config, _ := pgx.ParseConfig(os.Getenv("DATABASE_URL"))
config.BeforeConnect = func(ctx context.Context, cfg *pgx.ConnConfig) error {
    token, err := cred.GetToken(ctx, policy.TokenRequestOptions{
        Scopes: []string{"https://ossrdbms-aad.database.windows.net/.default"},
    })
    if err != nil {
        return err
    }
    cfg.Password = token.Token
    return nil
}
```

### ConfigMap pattern

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{APP_NAME}}-config
data:
  DATABASE_URL: "host={{PG_SERVER_NAME}}.postgres.database.azure.com port=5432 dbname={{DB_NAME}} user={{IDENTITY_NAME}} sslmode=require"
```

---

## Writable Paths (DS012 Compliance)

When `readOnlyRootFilesystem: true` is set, Go apps typically need **no writable paths**:

- Go compiles to a static binary — no temp files, no interpreted bytecode, no session storage
- The `distroless/static` base image has no shell or package manager that writes to disk

### Optional `/tmp` mount

If your application explicitly writes temporary files (e.g., file uploads, report generation):

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

Most Go web APIs do not need this.

---

## Port Configuration

- **Default port:** 8080 (Go convention, not enforced by any framework)
- **Env var override:** `PORT` (commonly used pattern)

### Code pattern

```go
port := os.Getenv("PORT")
if port == "" {
    port = "8080"
}
log.Printf("Listening on :%s", port)
log.Fatal(http.ListenAndServe(":"+port, router))
```

All major Go frameworks (Gin, Echo, Fiber) accept the listen address as a string — no special configuration property needed.

---

## Build Commands

| Variant | Command | Notes |
|---------|---------|-------|
| Standard | `CGO_ENABLED=0 go build -ldflags="-s -w" -o server ./cmd/server` | Production binary, stripped |
| Race detector (test only) | `go build -race -o server ./cmd/server` | Do **not** use in production — 10x overhead |
| Multiple binaries | `CGO_ENABLED=0 go build -ldflags="-s -w" -o migrate ./cmd/migrate` | Build each binary target separately |

The `./cmd/server` path is conventional for Go projects using the [Standard Go Project Layout](https://github.com/golang-standards/project-layout). Adjust to match the actual `main` package location.

---

## Common Issues on AKS

| Issue | Symptom | Fix |
|-------|---------|-----|
| Binary not statically linked | `exec format error` or `not found` in distroless | Ensure `CGO_ENABLED=0` is set during build; if CGO is required, use `distroless/cc` instead of `distroless/static` |
| DNS resolution issues with Alpine | `dial tcp: lookup ... no such host` during build | Use `golang:1.23-alpine` with `RUN apk add --no-cache ca-certificates` or switch to `golang:1.23` (Debian-based) for the build stage |
| Graceful shutdown not implemented | Connections dropped during rolling update, 502 errors | Implement `signal.NotifyContext` with `srv.Shutdown(ctx)` — give in-flight requests time to complete before exit |
| Binary name mismatch | `exec /server: no such file or directory` | Verify the `-o` flag in `go build` matches the `ENTRYPOINT` path in the Dockerfile |
| Port < 1024 with non-root user | `bind: permission denied` | Use port 8080 (or any port >= 1024); never bind to 80 or 443 inside the container |

### Nestjs

> **Applies to:** Projects detected with `package.json` containing `@nestjs/core` as a dependency

---

## Dockerfile Patterns

### Multi-stage build with TypeScript compilation

NestJS compiles TypeScript to JavaScript via `nest build`, outputting to `dist/`. Use `dumb-init` for proper signal handling:

```dockerfile
# Build stage
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# Runtime stage
FROM node:22-alpine AS runtime
RUN apk add --no-cache dumb-init
WORKDIR /app
COPY --from=build /app/package.json /app/package-lock.json ./
RUN npm ci --omit=dev
COPY --from=build /app/dist ./dist
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1
ENTRYPOINT ["dumb-init", "node", "dist/main.js"]
```

### Key points

- **Base image:** Official `node:22-alpine` — minimal footprint, receives LTS security patches
- **Alpine variant** reduces image size by ~70% compared to Debian-based `node:22`
- **`dumb-init`** ensures `SIGTERM` from Kubernetes is forwarded to the Node process so graceful shutdown works
- **`npm ci --omit=dev`** strips dev dependencies (including `typescript`, `@nestjs/cli`, `@nestjs/schematics`) from the runtime image
- **`USER node`** — the official Node Alpine image ships with a built-in `node` user (uid 1000), satisfying DS004 without creating a custom user
- **`dist/main.js`** is the default entrypoint — NestJS compiles `src/main.ts` to `dist/main.js`

### Monorepo projects

NestJS monorepos (created with `nest generate app`) compile each app separately:

```dockerfile
# Build a specific app in a monorepo
RUN npx nest build <app-name>
```

The output goes to `dist/apps/<app-name>/main.js`. Adjust the `ENTRYPOINT` accordingly:

```dockerfile
ENTRYPOINT ["dumb-init", "node", "dist/apps/<app-name>/main.js"]
```

### Package manager variants

| Package Manager | Install (all) | Install (prod only) | Lock File |
|----------------|---------------|---------------------|-----------|
| npm | `npm ci` | `npm ci --omit=dev` | `package-lock.json` |
| yarn | `yarn install --frozen-lockfile` | `yarn install --frozen-lockfile --production` | `yarn.lock` |
| pnpm | `pnpm install --frozen-lockfile` | `pnpm install --frozen-lockfile --prod` | `pnpm-lock.yaml` |

Copy the correct lock file in the Dockerfile `COPY` step to match the project's package manager.

---

## Health Endpoints

NestJS provides health checks via the `@nestjs/terminus` package.

### Installation

```bash
npm install @nestjs/terminus
```

### HealthModule

```typescript
import { Module } from '@nestjs/common';
import { TerminusModule } from '@nestjs/terminus';
import { HealthController } from './health.controller';

@Module({
  imports: [TerminusModule],
  controllers: [HealthController],
})
export class HealthModule {}
```

Register `HealthModule` in `AppModule` imports.

### HealthController with database check

```typescript
import { Controller, Get } from '@nestjs/common';
import {
  HealthCheck,
  HealthCheckService,
  TypeOrmHealthIndicator,
} from '@nestjs/terminus';

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

For Prisma, use `PrismaHealthIndicator`; for MikroORM, use `MikroOrmHealthIndicator`. If no database is used, omit the indicator and return a simple status check.

### Probe configuration in Deployment manifest

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 15
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

**Note:** NestJS apps start quickly (typically under 2 seconds), so `initialDelaySeconds: 5` is sufficient. If the app performs heavy initialization (e.g., loading large config, running migrations), increase to 10-15s or add a `startupProbe`.

---

## Database Profiles

NestJS supports multiple ORM libraries. The standard pattern is a connection string or individual env vars injected via environment variables:

| ORM | Connection Pattern | Config Property |
|-----|-------------------|-----------------|
| TypeORM | `TypeOrmModule.forRoot({ url: process.env.DATABASE_URL })` | `DATABASE_URL` |
| Prisma | `datasource db { url = env("DATABASE_URL") }` in `schema.prisma` | `DATABASE_URL` |
| MikroORM | `MikroOrmModule.forRoot({ clientUrl: process.env.DATABASE_URL })` | `DATABASE_URL` |
| Sequelize | `SequelizeModule.forRoot({ uri: process.env.DATABASE_URL })` | `DATABASE_URL` |

### Environment variables for PostgreSQL on AKS

```yaml
env:
  - name: DATABASE_URL
    value: "postgresql://{{IDENTITY_NAME}}@{{PG_SERVER_NAME}}.postgres.database.azure.com:5432/{{DB_NAME}}?sslmode=require"
  - name: PGHOST
    value: "{{PG_SERVER_NAME}}.postgres.database.azure.com"
  - name: PGDATABASE
    value: "{{DB_NAME}}"
  - name: PGUSER
    value: "{{IDENTITY_NAME}}"
  - name: PGPORT
    value: "5432"
  - name: PGSSLMODE
    value: "require"
```

For Workload Identity with passwordless authentication, use the `@azure/identity` package with `pg` to obtain Azure AD tokens instead of passwords.

### ConfigMap pattern

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{APP_NAME}}-config
data:
  NODE_ENV: "production"
  PGHOST: "{{PG_SERVER_NAME}}.postgres.database.azure.com"
  PGDATABASE: "{{DB_NAME}}"
  PGPORT: "5432"
  PGSSLMODE: "require"
```

---

## Writable Paths (DS012 Compliance)

When `readOnlyRootFilesystem: true` is set, NestJS apps need only `/tmp` writable:

- **Multipart uploads** (e.g., `@nestjs/platform-express` with `multer`) stage files to `/tmp`
- **Logging libraries** that buffer to disk use `/tmp`
- **No other writable paths** are typically needed — `node_modules` and `dist/` are read-only at runtime

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

No other writable paths are typically needed for production NestJS apps.

---

## Port Configuration

- **Default port:** 3000
- **Env var override:** `PORT=3000`
- **Code pattern:** `await app.listen(process.env.PORT || 3000)` in `main.ts`

NestJS (via Express adapter) binds to `0.0.0.0` by default, so it is reachable from outside the container without additional configuration.

If using the Fastify adapter (`@nestjs/platform-fastify`), you must pass `'0.0.0.0'` explicitly:

```typescript
await app.listen(process.env.PORT || 3000, '0.0.0.0');
```

Without this, the pod will start but all probes and traffic will fail with `connection refused`.

---

## Build Commands

| Scenario | Build Command | Output | Entrypoint |
|----------|---------------|--------|------------|
| Standard | `npm run build` (invokes `nest build`) | `dist/` | `node dist/main.js` |
| Monorepo | `npx nest build <app-name>` | `dist/apps/<app-name>/` | `node dist/apps/<app-name>/main.js` |
| SWC compiler | `nest build --builder swc` | `dist/` | `node dist/main.js` |

The **SWC compiler** is ~20x faster than the default TypeScript compiler for large projects. Enable it by installing `@swc/cli @swc/core` and passing `--builder swc` or setting `"builder": "swc"` in `nest-cli.json`. SWC does not perform type checking — run `tsc --noEmit` separately in CI if type safety is required.

---

## Common Issues on AKS

| Issue | Symptom | Fix |
|-------|---------|-----|
| SIGTERM not handled | Pod takes 30s to terminate (killed by `SIGKILL` after grace period) | Call `app.enableShutdownHooks()` in `main.ts` so NestJS lifecycle events (`OnModuleDestroy`, `BeforeApplicationShutdown`) fire on `SIGTERM`; also use `dumb-init` as the container entrypoint |
| TypeORM connection pool exhaustion | `Error: Connection pool exhausted` or `ETIMEDOUT` under load | Set `extra: { max: 10 }` in TypeORM config to limit pool size; Azure PG Flexible Server has a connection limit based on SKU — monitor with `pg_stat_activity` |
| Circular dependency | `Error: Nest cannot create the ... instance` at startup | Use `forwardRef(() => Module)` in module imports; refactor shared logic into a dedicated module to break the cycle |
| dist/ not included in image | `Error: Cannot find module '/app/dist/main.js'` at container start | Ensure `COPY --from=build /app/dist ./dist` is present in the Dockerfile runtime stage; verify `nest build` runs successfully in the build stage |
| Global prefix breaks probes | Health probes return `404` after setting `app.setGlobalPrefix('api')` | The health endpoint moves to `/api/health` — update probe paths in the Deployment manifest, or exclude the health controller from the global prefix using `app.setGlobalPrefix('api', { exclude: ['health'] })` |

### Nextjs

> **Applies to:** Projects detected with `package.json` containing `next` as a dependency

---

## Dockerfile Patterns

### Multi-stage build with standalone output

Next.js standalone output mode is critical for containerized deployments — it reduces the image from ~1GB to ~100MB by bundling only the files needed to run the server:

```dockerfile
# Build stage
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# Runtime stage
FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup -S nextjs && adduser -S nextjs -G nextjs

COPY --from=build /app/public ./public
COPY --from=build --chown=nextjs:nextjs /app/.next/standalone ./
COPY --from=build --chown=nextjs:nextjs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"
CMD ["node", "server.js"]
```

### Key points

- **Standalone output** requires `output: 'standalone'` in `next.config.js` — without this, the build copies all of `node_modules` into the image
- **No `dumb-init` needed** — the standalone `server.js` handles `SIGTERM` signals correctly as PID 1
- **`NEXT_TELEMETRY_DISABLED=1`** prevents Next.js from sending anonymous telemetry from the build and runtime containers
- **Three COPY steps** are required: `public/` for static assets, `.next/standalone` for the server, `.next/static` for client-side JS/CSS bundles
- **`USER nextjs`** satisfies DS004 — create a dedicated non-root user since the official Node Alpine `node` user also works
- **`HOSTNAME="0.0.0.0"`** is required in Next.js 14+ (replaces the older `-H 0.0.0.0` CLI flag) to listen on all interfaces

### Enabling standalone output

In `next.config.js` (or `next.config.mjs` / `next.config.ts`):

```js
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
};

module.exports = nextConfig;
```

### sharp for next/image optimization

If the app uses `next/image`, the standalone build may not include the `sharp` image processing library. Install it explicitly:

```dockerfile
# In the build stage, before npm run build:
RUN npm ci
# Ensure sharp is available for image optimization in production:
RUN npm install sharp
```

Without `sharp`, Next.js falls back to the slower `squoosh` library, which may cause timeout errors under load.

### Package manager variants

| Package Manager | Install Command | Lock File | Standalone COPY |
|----------------|----------------|-----------|-----------------|
| npm | `npm ci` | `package-lock.json` | Same for all |
| yarn | `yarn install --frozen-lockfile` | `yarn.lock` | Same for all |
| pnpm | `pnpm install --frozen-lockfile` | `pnpm-lock.yaml` | Same for all |

Copy the correct lock file in the Dockerfile `COPY` step to match the project's package manager.

---

## Health Endpoints

Next.js does not provide health endpoints out of the box. Add a custom API route — the implementation depends on whether the project uses App Router or Pages Router.

### App Router (Next.js 13.4+)

Create `app/api/health/route.ts`:

```ts
import { NextResponse } from 'next/server';

export async function GET() {
  return NextResponse.json({ status: 'UP' });
}

export const dynamic = 'force-dynamic';
```

The `force-dynamic` export prevents Next.js from statically caching the health response at build time.

### Pages Router

Create `pages/api/health.ts`:

```ts
import type { NextApiRequest, NextApiResponse } from 'next';

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  res.status(200).json({ status: 'UP' });
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

**Note:** Next.js standalone server starts in 1–3 seconds, but `initialDelaySeconds: 10` provides a safe margin for cold starts and environment variable resolution. No `startupProbe` is needed unless the app performs heavy server-side initialization.

---

## Database Profiles

Next.js apps commonly use Prisma, Drizzle, or `pg` (node-postgres) for database access. All follow the `DATABASE_URL` connection string pattern:

| Library | Connection Pattern | Config Property |
|---------|-------------------|-----------------|
| Prisma | `datasource db { url = env("DATABASE_URL") }` in `schema.prisma` | `DATABASE_URL` |
| Drizzle | `postgres(process.env.DATABASE_URL!)` or `drizzle(process.env.DATABASE_URL!)` | `DATABASE_URL` |
| `pg` (node-postgres) | `new Pool({ connectionString: process.env.DATABASE_URL })` | `DATABASE_URL` |

### Environment variables for PostgreSQL on AKS

```yaml
env:
  - name: DATABASE_URL
    value: "postgresql://{{IDENTITY_NAME}}@{{PG_SERVER_NAME}}.postgres.database.azure.com:5432/{{DB_NAME}}?sslmode=require"
  - name: PGHOST
    value: "{{PG_SERVER_NAME}}.postgres.database.azure.com"
  - name: PGDATABASE
    value: "{{DB_NAME}}"
  - name: PGUSER
    value: "{{IDENTITY_NAME}}"
  - name: PGPORT
    value: "5432"
  - name: PGSSLMODE
    value: "require"
```

For Prisma with Workload Identity (passwordless authentication), use `@prisma/adapter-pg` with `@azure/identity` to obtain Azure AD tokens instead of passwords.

### ConfigMap pattern

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{APP_NAME}}-config
data:
  NODE_ENV: "production"
  NEXT_TELEMETRY_DISABLED: "1"
  PGHOST: "{{PG_SERVER_NAME}}.postgres.database.azure.com"
  PGDATABASE: "{{DB_NAME}}"
  PGPORT: "5432"
  PGSSLMODE: "require"
```

---

## Writable Paths (DS012 Compliance)

When `readOnlyRootFilesystem: true` is set, Next.js needs **two** writable paths:

- **`/tmp`** — general-purpose temporary file storage
- **`/app/.next/cache`** — ISR (Incremental Static Regeneration) page cache and `next/image` optimization cache; without this, ISR and image optimization fail with `EROFS: read-only file system` errors

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

Both mounts are required. Missing the cache mount is the most common cause of ISR failures on AKS.

---

## Port Configuration

- **Default port:** 3000
- **Env var override:** `PORT=3000`
- **Hostname binding:** `HOSTNAME="0.0.0.0"` (Next.js 14+) or `-H 0.0.0.0` CLI flag (Next.js 13)

The standalone `server.js` reads the `PORT` and `HOSTNAME` environment variables automatically. No code changes are needed to customize the port.

---

## Build Commands

| Scenario | Build Command | Output | Entrypoint |
|----------|---------------|--------|------------|
| Standard build | `npm run build` | `.next/` (full) | `next start` |
| Standalone build (recommended) | `npm run build` with `output: 'standalone'` | `.next/standalone/server.js` | `node server.js` |

The `output: 'standalone'` setting in `next.config.js` changes what `npm run build` produces — no separate command is needed. The standalone `server.js` includes a built-in HTTP server and does not require the `next` CLI at runtime.

**Important:** Always use the standalone build for container deployments. The standard build requires the full `node_modules` directory at runtime, resulting in images 5-10x larger.

---

## Common Issues on AKS

| Issue | Symptom | Fix |
|-------|---------|-----|
| Image too large without standalone | Image > 1GB, slow pulls from ACR | Set `output: 'standalone'` in `next.config.js` — reduces image to ~100MB |
| Static assets 404 | CSS/JS files return 404 after deployment | Ensure `.next/static` is copied to `.next/static` in the runtime stage (not into `standalone/.next/static`) |
| ISR fails with read-only filesystem | `EROFS: read-only file system` when revalidating pages | Mount `emptyDir` volume at `/app/.next/cache` — ISR writes regenerated pages to the cache directory |
| next/image optimization fails | Images return 500 or timeout under load | Install `sharp` explicitly (`npm install sharp`); the standalone build may not include it automatically |
| Env vars undefined (`NEXT_PUBLIC_` prefix) | Client-side code sees `undefined` for environment variables | `NEXT_PUBLIC_` vars are inlined at **build time**, not runtime; set them as build args in the Dockerfile or use runtime config via `publicRuntimeConfig` |
| Telemetry calls from container | Unexpected outbound network requests to `telemetry.nextjs.org` | Set `NEXT_TELEMETRY_DISABLED=1` in both the build stage and runtime stage of the Dockerfile |

### Spring Boot

> **Applies to:** Projects detected with `pom.xml` containing `spring-boot-starter-web` or `build.gradle`/`build.gradle.kts` containing `org.springframework.boot`

---

## Dockerfile Patterns

### Multi-stage build with layered JAR extraction

Spring Boot 2.3+ supports layered JARs for optimized Docker layer caching:

```dockerfile
# Build stage
FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /app
COPY pom.xml mvnw ./
COPY .mvn .mvn
RUN ./mvnw dependency:go-offline -B
COPY src src
RUN ./mvnw package -DskipTests -B

# Extract layers for caching
FROM eclipse-temurin:21-jdk-alpine AS extract
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
RUN java -Djarmode=layertools -jar app.jar extract

# Runtime stage
FROM eclipse-temurin:21-jre-alpine AS runtime
WORKDIR /app
RUN addgroup -S spring && adduser -S spring -G spring
COPY --from=extract /app/dependencies/ ./
COPY --from=extract /app/spring-boot-loader/ ./
COPY --from=extract /app/snapshot-dependencies/ ./
COPY --from=extract /app/application/ ./
USER spring:spring
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.LaunchedClassPathJarLauncher"]
```

### Key points

- **Base image:** Eclipse Temurin (Adoptium) is the recommended OpenJDK distribution for production
- **Alpine variant** reduces image size by ~60% compared to Debian-based
- **Layered JAR extraction** means only changed layers are rebuilt/pushed — dependencies rarely change
- **Non-root user** (`spring`) satisfies DS004

### ACR-compatible flattening

If the layered extraction fails (older Spring Boot versions), flatten the layers:

```dockerfile
COPY --from=extract /app/dependencies/ ./
COPY --from=extract /app/spring-boot-loader/ ./
COPY --from=extract /app/snapshot-dependencies/ ./
COPY --from=extract /app/application/ ./
```

This is compatible with ACR's layer deduplication.

---

## Health Endpoints

Spring Boot Actuator provides health endpoints out of the box:

| Endpoint | Purpose | Probe Type |
|----------|---------|-----------|
| `/actuator/health` | Overall health | General |
| `/actuator/health/liveness` | Liveness group | `livenessProbe` |
| `/actuator/health/readiness` | Readiness group | `readinessProbe` |

### Required configuration

In `application.properties` or `application.yml`:

```properties
management.endpoints.web.exposure.include=health
management.endpoint.health.probes.enabled=true
management.endpoint.health.show-details=always
```

The probes are automatically enabled when running in Kubernetes (detected via the `KUBERNETES_SERVICE_HOST` env var), but it's best practice to enable them explicitly.

### Probe configuration in Deployment manifest

```yaml
livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 15
  timeoutSeconds: 3
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: 8080
  initialDelaySeconds: 15
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
```

**Note:** Spring Boot apps typically need longer `initialDelaySeconds` (15-60s) due to JVM warmup and Spring context initialization.

---

## Database Profiles

Spring Boot uses Spring Profiles to switch database configurations:

| Profile | Activation | Typical Config File |
|---------|------------|-------------------|
| `default` | No profile set | `application.properties` — usually H2 in-memory |
| `mysql` | `SPRING_PROFILES_ACTIVE=mysql` | `application-mysql.properties` |
| `postgres` | `SPRING_PROFILES_ACTIVE=postgres` | `application-postgres.properties` |

### Environment variables for PostgreSQL on AKS

```yaml
env:
  - name: SPRING_PROFILES_ACTIVE
    value: postgres
  - name: POSTGRES_URL
    value: "jdbc:postgresql://{{PG_SERVER_NAME}}.postgres.database.azure.com:5432/{{DB_NAME}}"
  - name: POSTGRES_USER
    value: "{{IDENTITY_NAME}}"
  - name: SPRING_DATASOURCE_AZURE_PASSWORDLESS_ENABLED
    value: "true"
```

With Workload Identity and the `spring-cloud-azure-starter-jdbc-postgresql` dependency, Spring Boot can authenticate to PostgreSQL without a password using Azure AD tokens.

### ConfigMap pattern

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{APP_NAME}}-config
data:
  SPRING_PROFILES_ACTIVE: "postgres"
  MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE: "health"
  MANAGEMENT_ENDPOINT_HEALTH_PROBES_ENABLED: "true"
```

---

## Writable Paths (DS012 Compliance)

When `readOnlyRootFilesystem: true` is set, Spring Boot needs `/tmp` writable:

- **Tomcat** writes session data and compiled JSPs to `/tmp`
- **Multipart file uploads** use `/tmp` as the staging directory
- **Spring Boot DevTools** (if accidentally included) writes to `/tmp`

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

No other writable paths are typically needed for production Spring Boot apps.

---

## Port Configuration

- **Default port:** 8080
- **Config property:** `server.port` in `application.properties`
- **Env var override:** `SERVER_PORT=8080`

Spring Boot always logs the port on startup: `Tomcat started on port(s): 8080 (http)`

---

## Build Commands

| Build Tool | Build Command | Output |
|-----------|---------------|--------|
| Maven | `./mvnw package -DskipTests -B` | `target/*.jar` |
| Gradle | `./gradlew bootJar` | `build/libs/*.jar` |

The `-B` flag (batch mode) suppresses interactive Maven output — important for CI/CD and Docker builds.

---

## Common Issues on AKS

| Issue | Symptom | Fix |
|-------|---------|-----|
| JVM OOM in container | `OOMKilled` pod status | Set `-XX:MaxRAMPercentage=75.0` in `JAVA_OPTS` and ensure memory limit >= 256Mi |
| Slow startup | Readiness probe fails, pod restarted | Increase `initialDelaySeconds` to 45-60s, or add a `startupProbe` with higher `failureThreshold` |
| H2 in-memory on AKS | Data lost on pod restart | Switch to PostgreSQL profile — H2 is for local dev only |
| Connection refused to PostgreSQL | `PSQLException: Connection refused` | Verify firewall rules on PostgreSQL Flexible Server allow AKS subnet |
| Image too large (>500MB) | Slow pulls, high ACR storage | Use Alpine base image + layered JAR extraction |

## Templates: Kubernetes Manifests


### `templates/k8s/configmap.yaml`

```yaml
# =============================================================================
# Kubernetes ConfigMap Template — AKS Deploy Skill
# =============================================================================
# Stores non-sensitive configuration data as key-value pairs. Values are
# injected into pods as environment variables via envFrom or env/valueFrom.
#
# Do NOT store secrets here — use Azure Key Vault + Workload Identity instead.
#
# REPLACE: <app-name>   — your application name (e.g., order-api)
# REPLACE: <namespace>  — target namespace (e.g., production)
# =============================================================================
apiVersion: v1
kind: ConfigMap
metadata:
  name: <app-name>-config
  namespace: <namespace>
  labels:
    app: <app-name>
data: {}
  # Add application configuration as key-value pairs.
  # Example:
  #   LOG_LEVEL: "info"
  #   ASPNETCORE_ENVIRONMENT: "Production"
  #   SPRING_PROFILES_ACTIVE: "prod"
```

### `templates/k8s/deployment.yaml`

```yaml
# Kubernetes Deployment Template — AKS Deploy Skill
# Satisfies Deployment Safeguard rules DS001–DS013. Replace <placeholder> values per Phase 4.
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <app-name>
  namespace: <namespace>
  labels:
    app: <app-name>
spec:
  # DS010: Minimum 2 replicas for high availability
  replicas: 2
  selector:
    matchLabels:
      app: <app-name>
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: <app-name>
        # Workload Identity: enables the mutating webhook to inject
        # AZURE_CLIENT_ID, AZURE_TENANT_ID, and AZURE_FEDERATED_TOKEN_FILE
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: <app-name>

      # DS013: Do not auto-mount the default ServiceAccount token.
      # Workload Identity uses a separate projected volume managed by its webhook.
      automountServiceAccountToken: false

      # DS004 (pod-level): Run as non-root
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault

      containers:
        - name: <app-name>
          # DS009: Always use an explicit tag — never :latest or bare image
          image: <image>
          ports:
            - name: http
              containerPort: <port>
              protocol: TCP

          # DS001: Resource requests AND limits for cpu and memory
          resources:
            requests:
              cpu: "<cpu-request>"
              memory: "<memory-request>"
            limits:
              cpu: "<cpu-limit>"
              memory: "<memory-limit>"

          # DS002: Liveness probe
          livenessProbe:
            httpGet:
              path: <health-path>
              port: <port>
            initialDelaySeconds: 10
            periodSeconds: 15
            timeoutSeconds: 3
            failureThreshold: 3

          # DS003: Readiness probe
          readinessProbe:
            httpGet:
              path: <ready-path>
              port: <port>
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 3

          # DS004, DS008, DS011, DS012
          securityContext:
            runAsNonRoot: true
            privileged: false
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL

          # If the app needs to write to specific paths (logs, tmp, cache),
          # mount emptyDir volumes below instead of disabling readOnlyRootFilesystem.
          volumeMounts:
            - name: tmp
              mountPath: /tmp

      volumes:
        - name: tmp
          emptyDir: {}
```

### `templates/k8s/gateway.yaml`

```yaml
# =============================================================================
# Gateway API — Gateway Resource Template — AKS Deploy Skill
# =============================================================================
# Use this template for AKS clusters with Istio Gateway API enabled
# (appRoutingIstio.mode: Enabled). This applies to both AKS Automatic and Standard.
#
# For clusters using the default NGINX-based Web App Routing, use ingress.yaml instead.
#
# REPLACE: <gateway-name> — name for the gateway (e.g., app-gateway)
# REPLACE: <namespace>    — target namespace (e.g., production)
# REPLACE: <hostname>     — FQDN for the listener (e.g., api.example.com)
# =============================================================================
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: <gateway-name>
  namespace: <namespace>
  labels:
    app: <gateway-name>
spec:
  # AKS Automatic provisions an Istio-based gateway controller
  gatewayClassName: istio
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      hostname: "<hostname>"
      allowedRoutes:
        namespaces:
          from: Same
    # Uncomment for TLS — requires a Secret with the certificate
    # - name: https
    #   protocol: HTTPS
    #   port: 443
    #   hostname: "<hostname>"
    #   tls:
    #     mode: Terminate
    #     certificateRefs:
    #       - kind: Secret
    #         name: <tls-secret-name>
    #   allowedRoutes:
    #     namespaces:
    #       from: Same
```

### `templates/k8s/hpa.yaml`

```yaml
# =============================================================================
# HorizontalPodAutoscaler Template — AKS Deploy Skill
# =============================================================================
# Scales the Deployment between min and max replicas based on CPU utilization.
# Minimum of 2 replicas ensures HA even at low load (aligns with DS010).
#
# REPLACE: <app-name>   — your application name (e.g., order-api)
# REPLACE: <namespace>  — target namespace (e.g., production)
# REPLACE: <min>        — minimum replicas (default: 2, must be >= 2 for DS010)
# REPLACE: <max>        — maximum replicas (e.g., 10)
# =============================================================================
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: <app-name>
  namespace: <namespace>
  labels:
    app: <app-name>
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: <app-name>
  minReplicas: <min>
  maxReplicas: <max>
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Pods
          value: 1
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Pods
          value: 2
          periodSeconds: 60
```

### `templates/k8s/httproute.yaml`

```yaml
# =============================================================================
# Gateway API — HTTPRoute Template — AKS Deploy Skill
# =============================================================================
# Routes HTTP traffic from a Gateway to a backend Service.
# Use this together with gateway.yaml on clusters with Istio Gateway API enabled.
#
# REPLACE: <app-name>      — your application name (e.g., order-api)
# REPLACE: <namespace>     — target namespace (e.g., production)
# REPLACE: <gateway-name>  — name of the Gateway resource (e.g., app-gateway)
# REPLACE: <hostname>      — FQDN matching the Gateway listener (e.g., api.example.com)
# REPLACE: <path-prefix>   — URL path prefix to match (e.g., /)
# REPLACE: <service-port>  — port on the backend Service (e.g., 80)
# =============================================================================
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: <app-name>
  namespace: <namespace>
  labels:
    app: <app-name>
spec:
  parentRefs:
    - name: <gateway-name>
      namespace: <namespace>
  hostnames:
    - "<hostname>"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: "<path-prefix>"
      backendRefs:
        - name: <app-name>
          port: <service-port>
          kind: Service
```

### `templates/k8s/ingress.yaml`

```yaml
# =============================================================================
# Kubernetes Ingress Template — AKS Deploy Skill
# =============================================================================
# Use this template for AKS clusters with the Web App Routing add-on (NGINX).
# This is the default for both AKS Automatic and AKS Standard.
# For clusters with Istio Gateway API enabled, use gateway.yaml + httproute.yaml instead.
#
# REPLACE: <app-name>    — your application name (e.g., order-api)
# REPLACE: <namespace>   — target namespace (e.g., production)
# REPLACE: <hostname>    — FQDN for the ingress rule (e.g., api.example.com)
# REPLACE: <path>        — URL path (e.g., /)
# REPLACE: <service-port> — port on the backend Service (e.g., 80)
# =============================================================================
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: <app-name>
  namespace: <namespace>
  labels:
    app: <app-name>
spec:
  ingressClassName: webapprouting.kubernetes.azure.com
  # Uncomment for TLS — requires a Secret with the certificate
  # tls:
  #   - hosts:
  #       - <hostname>
  #     secretName: <tls-secret-name>
  rules:
    - host: "<hostname>"
      http:
        paths:
          - path: "<path>"
            pathType: Prefix
            backend:
              service:
                name: <app-name>
                port:
                  number: <service-port>
```

### `templates/k8s/namespace.yaml`

```yaml
# =============================================================================
# Kubernetes Namespace Template — AKS Deploy Skill
# =============================================================================
# Creates an isolated namespace for the application workload. Using a dedicated
# namespace (rather than "default") improves resource organization, access
# control, and makes cleanup easier (delete the namespace to remove everything).
#
# REPLACE: <namespace> — target namespace (e.g., myapp, production)
# =============================================================================
apiVersion: v1
kind: Namespace
metadata:
  name: <namespace>
  labels:
    app.kubernetes.io/managed-by: deploy-to-aks-skill
```

### `templates/k8s/pdb.yaml`

```yaml
# =============================================================================
# PodDisruptionBudget Template — AKS Deploy Skill
# =============================================================================
# Ensures at least one pod remains available during voluntary disruptions
# (node drains, cluster upgrades, spot evictions).
#
# REPLACE: <app-name>   — your application name (e.g., order-api)
# REPLACE: <namespace>  — target namespace (e.g., production)
# =============================================================================
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: <app-name>
  namespace: <namespace>
  labels:
    app: <app-name>
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: <app-name>
```

### `templates/k8s/service.yaml`

```yaml
# =============================================================================
# Kubernetes Service Template — AKS Deploy Skill
# =============================================================================
# ClusterIP Service that routes traffic to application pods.
#
# REPLACE: <app-name>    — your application name (e.g., order-api)
# REPLACE: <namespace>   — target namespace (e.g., production)
# REPLACE: <port>        — service port (e.g., 80)
# REPLACE: <target-port> — container port (e.g., 8080)
# =============================================================================
apiVersion: v1
kind: Service
metadata:
  name: <app-name>
  namespace: <namespace>
  labels:
    app: <app-name>
spec:
  type: ClusterIP
  selector:
    app: <app-name>
  ports:
    - name: http
      port: <port>
      targetPort: <target-port>
      protocol: TCP
```

### `templates/k8s/serviceaccount.yaml`

```yaml
# =============================================================================
# ServiceAccount Template — AKS Deploy Skill
# =============================================================================
# Kubernetes ServiceAccount with Azure Workload Identity annotation.
# The annotation links this SA to an Azure Managed Identity via OIDC federation.
#
# Prerequisites:
#   1. A User-Assigned Managed Identity exists in Azure
#   2. A Federated Identity Credential is configured with:
#      - Issuer:  <AKS cluster OIDC issuer URL>
#      - Subject: system:serviceaccount:<namespace>:<app-name>
#      - Audience: api://AzureADTokenExchange
#
# REPLACE: <app-name>          — your application name (e.g., order-api)
# REPLACE: <namespace>         — target namespace (e.g., production)
# REPLACE: <azure-client-id>   — client ID of the Managed Identity
# =============================================================================
apiVersion: v1
kind: ServiceAccount
metadata:
  name: <app-name>
  namespace: <namespace>
  labels:
    app: <app-name>
  annotations:
    # Workload Identity: maps this ServiceAccount to an Azure Managed Identity.
    # The Workload Identity webhook reads this annotation and injects
    # AZURE_CLIENT_ID, AZURE_TENANT_ID, and AZURE_FEDERATED_TOKEN_FILE
    # into any pod that references this ServiceAccount AND has the label
    # azure.workload.identity/use: "true".
    azure.workload.identity/client-id: "<azure-client-id>"
```

## Templates: Dockerfiles


### `templates/dockerfiles/dotnet.Dockerfile`

```dockerfile
# =============================================================================
# .NET (ASP.NET Core) Production Dockerfile
# =============================================================================
# Customize the following before use:
#   - PROJECT_NAME: Replace "MyApp" with your .csproj name (without extension)
#   - PORT:         Change EXPOSE and HEALTHCHECK port if not 8080
#   - ASSEMBLY:     Adjust the DLL name in CMD if it differs from the project
#
# Notes:
#   - .NET 8+ defaults to port 8080 (ASPNETCORE_HTTP_PORTS), not 80
#   - The "app" user is built into the aspnet runtime image since .NET 8
#   - For self-contained deployment, add --self-contained to dotnet publish
#     and switch the runtime image to mcr.microsoft.com/dotnet/runtime-deps:9.0
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Build
# ---------------------------------------------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build

WORKDIR /src

# Layer caching: restore NuGet packages before copying the full source.
# Copy only project files first so the restore layer is cached independently.
COPY *.sln ./
COPY src/MyApp/*.csproj src/MyApp/

RUN dotnet restore src/MyApp/MyApp.csproj

# Copy everything and publish a Release build
COPY . .

RUN dotnet publish src/MyApp/MyApp.csproj \
    --configuration Release \
    --no-restore \
    --output /app/publish

# ---------------------------------------------------------------------------
# Stage 2: Runtime
# ---------------------------------------------------------------------------
FROM mcr.microsoft.com/dotnet/aspnet:9.0

WORKDIR /app

# Copy published output from the build stage
COPY --from=build /app/publish ./

# AKS Deployment Safeguards DS004: run as non-root.
# The "app" user is built into the aspnet image since .NET 8.
USER app

EXPOSE 8080

ENV ASPNETCORE_URLS="http://+:8080" \
    DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_EnableDiagnostics=0

# No HEALTHCHECK: the aspnet runtime image does not include curl or wget.
# Kubernetes liveness/readiness probes (configured in deployment.yaml) handle
# health checking in AKS. For local Docker usage, install wget or add
# app.MapHealthChecks("/healthz") and use a custom health check binary.

ENTRYPOINT ["dotnet", "MyApp.dll"]
```

### `templates/dockerfiles/go.Dockerfile`

```dockerfile
# =============================================================================
# Go Production Dockerfile
# =============================================================================
# Customize the following before use:
#   - APP_NAME:    Replace "app" in the binary name and CMD
#   - PORT:        Change EXPOSE port if not 8080
#   - MODULE_PATH: Ensure go.mod module path matches your project
#
# Notes:
#   - CGO_ENABLED=0 produces a fully static binary that runs on distroless
#   - The distroless runtime has no shell — use the exec form for CMD
#   - To debug, swap the runtime to gcr.io/distroless/static-debian12:debug
#     which includes busybox
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Build
# ---------------------------------------------------------------------------
FROM golang:1.23-alpine AS build

WORKDIR /src

# Layer caching: download module dependencies before copying source.
# This layer is only rebuilt when go.mod or go.sum changes.
COPY go.mod go.sum ./

RUN go mod download && go mod verify

# Copy source and compile a static binary
COPY . .

RUN CGO_ENABLED=0 GOOS=linux \
    go build -ldflags="-s -w" -o /bin/app ./cmd/app

# ---------------------------------------------------------------------------
# Stage 2: Runtime
# ---------------------------------------------------------------------------
FROM gcr.io/distroless/static-debian12

# Copy the compiled binary from the build stage
COPY --from=build /bin/app /app

# AKS Deployment Safeguards DS004: run as non-root.
# 65534 is the "nobody" user in distroless images.
USER 65534

EXPOSE 8080

# Distroless has no shell, curl, or wget. Kubernetes liveness/readiness probes
# (configured in deployment.yaml) handle health checking in AKS.
# For local Docker usage, consider adding a /healthz handler and using a
# statically-compiled health check binary, or swap to the :debug variant.

ENTRYPOINT ["/app"]
```

### `templates/dockerfiles/java.Dockerfile`

```dockerfile
# =============================================================================
# Java (Spring Boot / Maven) Production Dockerfile
# =============================================================================
# Customize the following before use:
#   - JAR_FILE:    Adjust the glob pattern if your build output differs
#   - PORT:        Change EXPOSE and HEALTHCHECK port if not 8080
#   - JVM_OPTS:    Tune -Xmx, -Xms, GC flags, etc. via JAVA_OPTS env var
#
# Gradle users:
#   Replace the Maven wrapper commands in the build stage with:
#     COPY gradlew build.gradle.kts settings.gradle.kts ./
#     COPY gradle ./gradle
#     RUN ./gradlew dependencies --no-daemon
#     COPY . .
#     RUN ./gradlew bootJar --no-daemon
#   And adjust the JAR_FILE path to "build/libs/*.jar"
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Build
# ---------------------------------------------------------------------------
FROM eclipse-temurin:21-jdk-alpine AS build

WORKDIR /app

# Layer caching: copy Maven wrapper and POM first so dependency resolution is
# cached independently of source changes.
COPY mvnw pom.xml ./
COPY .mvn .mvn

# Download dependencies (offline-friendly layer)
RUN chmod +x mvnw \
    && ./mvnw dependency:go-offline -B

# Copy source and build the fat JAR
COPY src ./src

RUN ./mvnw package -DskipTests -B \
    && cp target/*.jar app.jar

# ---------------------------------------------------------------------------
# Stage 2: Runtime
# ---------------------------------------------------------------------------
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

# AKS Deployment Safeguards DS004: create and switch to a non-root user
RUN addgroup -S appuser && adduser -S appuser -G appuser

# Copy only the built JAR from the build stage
COPY --from=build --chown=appuser:appuser /app/app.jar ./app.jar

# Spring Boot Layered JARs: if using layered JARs, replace the COPY above
# with the extract + copy approach for even better layer caching:
#   RUN java -Djarmode=layertools -jar app.jar extract
#   COPY --from=build /app/dependencies/ ./
#   COPY --from=build /app/spring-boot-loader/ ./
#   COPY --from=build /app/snapshot-dependencies/ ./
#   COPY --from=build /app/application/ ./

USER appuser

EXPOSE 8080

# MaxRAMPercentage caps heap relative to the container memory limit
# (container-aware by default in JDK 21).
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:+UseG1GC"

# No HEALTHCHECK: the JRE Alpine image does not include wget or curl.
# Kubernetes liveness/readiness probes (configured in deployment.yaml) handle
# health checking in AKS.

ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]
```

### `templates/dockerfiles/node.Dockerfile`

```dockerfile
# =============================================================================
# Node.js Production Dockerfile
# =============================================================================
# Customize the following before use:
#   - APP_NAME:    Replace in comments as needed
#   - PORT:        Change EXPOSE port if not 3000
#   - ENTRY_POINT: Change the final CMD to your main file (e.g. dist/main.js)
#   - BUILD_CMD:   Adjust "npm run build" if your build script differs
#
# Package manager support:
#   - npm:  This file is configured for npm by default
#   - yarn: Replace "npm ci" with "yarn install --frozen-lockfile"
#           Replace "package-lock.json" with "yarn.lock"
#   - pnpm: Replace "npm ci" with "corepack enable && pnpm install --frozen-lockfile"
#           Replace "package-lock.json" with "pnpm-lock.yaml"
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Build
# ---------------------------------------------------------------------------
FROM node:22-alpine AS build

WORKDIR /app

# Layer caching: copy dependency manifests first so the install layer is
# only rebuilt when dependencies change, not on every source edit.
COPY package.json package-lock.json ./

RUN npm ci

# Copy the rest of the source and build
COPY . .

RUN npm run build

# Remove dev dependencies to slim down the production node_modules
RUN npm prune --omit=dev

# ---------------------------------------------------------------------------
# Stage 2: Runtime
# ---------------------------------------------------------------------------
FROM node:22-alpine

# Security: install dumb-init so Node runs as PID > 1 and signals propagate
# correctly — avoids zombie processes inside the container.
RUN apk add --no-cache dumb-init

WORKDIR /app

# Copy only production artifacts from the build stage
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/package.json ./

# AKS Deployment Safeguards DS004: never run as root.
# The "node" user (uid 1000) is built into the node-alpine image.
USER node

EXPOSE 3000

# HEALTHCHECK is omitted — Kubernetes liveness/readiness probes handle health
# checks in AKS. See deployment.yaml for probe configuration.

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/main.js"]
```

### `templates/dockerfiles/python.Dockerfile`

```dockerfile
# =============================================================================
# Python Production Dockerfile
# =============================================================================
# Customize the following before use:
#   - APP_MODULE:  Change the uvicorn target (e.g. "app.main:app" for FastAPI,
#                  "myproject.wsgi:application" for Django with gunicorn)
#   - PORT:        Change EXPOSE port if not 8000
#   - DEPS FILE:   If using Poetry, replace requirements.txt steps with
#                  "poetry export -f requirements.txt" in the build stage
#   - ENTRY_POINT: Adjust the final CMD for your framework (gunicorn, uvicorn,
#                  flask run, etc.)
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Build
# ---------------------------------------------------------------------------
FROM python:3.12-slim AS build

WORKDIR /app

# Create a virtual environment so we can copy it cleanly to the runtime stage
RUN python -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

# Layer caching: install dependencies before copying source
COPY requirements.txt ./

RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Copy application source
COPY . .

# If you have a build step (e.g. Django collectstatic), run it here:
# RUN python manage.py collectstatic --noinput

# ---------------------------------------------------------------------------
# Stage 2: Runtime
# ---------------------------------------------------------------------------
FROM python:3.12-slim

WORKDIR /app

# AKS Deployment Safeguards DS004: create and switch to a non-root user
RUN groupadd --gid 1000 appuser \
    && useradd --uid 1000 --gid appuser --shell /bin/sh --create-home appuser

# Copy the virtual environment and application source from the build stage
COPY --from=build --chown=appuser:appuser /app /app

ENV PATH="/app/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

USER appuser

EXPOSE 8000

# HEALTHCHECK is omitted — Kubernetes liveness/readiness probes handle health
# checks in AKS. Adding a Dockerfile HEALTHCHECK would require installing curl
# in the runtime image, increasing size and attack surface.

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### `templates/dockerfiles/rust.Dockerfile`

```dockerfile
# =============================================================================
# Rust Production Dockerfile
# =============================================================================
# Customize the following before use:
#   - APP_NAME:    Replace "app" with your binary name from Cargo.toml
#   - PORT:        Change EXPOSE port if not 8080
#
# Notes:
#   - The dependency-caching trick creates a dummy main.rs, builds
#     dependencies, then replaces it with real source — this avoids
#     rebuilding all deps on every source change
#   - The final image uses distroless/cc which includes libgcc/libstdc++
#     needed by the default Rust allocator; if you use musl
#     (--target x86_64-unknown-linux-musl) switch to distroless/static
#   - For workspace builds, copy the whole workspace in one shot and adjust
#     the binary path in the final COPY
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Build
# ---------------------------------------------------------------------------
FROM rust:1.83-slim AS build

WORKDIR /app

# Install build dependencies (if any native libs are needed, add them here)
RUN apt-get update \
    && apt-get install -y --no-install-recommends pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Layer caching: build dependencies separately from application code.
# 1. Copy only the manifests and create a dummy main to compile deps.
COPY Cargo.toml Cargo.lock ./

RUN mkdir src \
    && echo 'fn main() { println!("placeholder"); }' > src/main.rs \
    && cargo build --release \
    && rm -rf src target/release/deps/app* target/release/app*
    # ↑ Update "app*" if your Cargo.toml binary name differs

# 2. Copy real source and build the actual binary.
COPY src ./src

RUN cargo build --release

# ---------------------------------------------------------------------------
# Stage 2: Runtime
# ---------------------------------------------------------------------------
FROM gcr.io/distroless/cc-debian12

WORKDIR /app

# Copy the compiled binary from the build stage
COPY --from=build /app/target/release/app /app/app

# AKS Deployment Safeguards DS004: run as non-root.
# 65534 is the "nobody" user in distroless images.
USER 65534

EXPOSE 8080

# Distroless has no shell, curl, or wget. Kubernetes liveness/readiness probes
# (configured in deployment.yaml) handle health checking in AKS.
# For local Docker usage, consider adding a /healthz handler and using a
# statically-compiled health check binary.

ENTRYPOINT ["/app/app"]
```

## Templates: Bicep Modules


### `templates/bicep/acr.bicep`

```bicep
// ============================================================================
// Azure Container Registry Module
// ============================================================================
// Customize:
//   - acrSku: upgrade to 'Premium' if you need geo-replication or private endpoints
//   - kubeletIdentityObjectId: the AKS kubelet identity that needs AcrPull access
// ============================================================================

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Application name used as a prefix for the ACR resource.')
param appName string

@description('Azure region for the Container Registry.')
param location string

@description('SKU tier for the Container Registry.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acrSku string = 'Basic'

@description('Object ID of the AKS kubelet managed identity to grant AcrPull access.')
param kubeletIdentityObjectId string

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------

// ACR names must be globally unique, alphanumeric only, 5-50 chars.
var acrName = replace('${appName}acr', '-', '')

// Built-in role: AcrPull
var acrPullRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '7f951dda-4ed3-4680-a7ca-43fe172d538d'
)

// ---------------------------------------------------------------------------
// Container Registry
// ---------------------------------------------------------------------------

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: false
  }
}

// ---------------------------------------------------------------------------
// Role Assignment – AcrPull for AKS kubelet identity
// ---------------------------------------------------------------------------

resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, kubeletIdentityObjectId, acrPullRoleDefinitionId)
  scope: acr
  properties: {
    principalId: kubeletIdentityObjectId
    roleDefinitionId: acrPullRoleDefinitionId
    principalType: 'ServicePrincipal'
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('Login server URL for the Container Registry (e.g., myacr.azurecr.io).')
output acrLoginServer string = acr.properties.loginServer

@description('Name of the Container Registry resource.')
output acrName string = acr.name

@description('Resource ID of the Container Registry.')
output acrResourceId string = acr.id
```

### `templates/bicep/aks.bicep`

```bicep
// ============================================================================
// AKS Cluster Module
// ============================================================================
// Customize:
//   - aksType: 'Automatic' for node auto-provisioning, 'Standard' for user-managed pools
//   - vmSize / nodeCount: only used when aksType is 'Standard'
//   - kubernetesVersion: pin to a specific version if needed
//   - logAnalyticsWorkspaceId: supply an existing workspace or let the module create one
// ============================================================================

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Application name used as a prefix for the AKS cluster resource.')
param appName string

@description('Azure region for the AKS cluster.')
param location string

@description('AKS cluster type. "Automatic" uses node auto-provisioning; "Standard" uses user-managed node pools.')
@allowed([
  'Automatic'
  'Standard'
])
param aksType string = 'Automatic'

@description('Kubernetes version. Leave blank to use the latest stable version.')
param kubernetesVersion string = ''

@description('VM size for the default agent pool (Standard mode only).')
param vmSize string = 'Standard_D2s_v3'

@description('Number of nodes in the default agent pool (Standard mode only).')
param nodeCount int = 2

@description('Optional: existing Log Analytics workspace resource ID for Container Insights. When empty the module creates a new workspace.')
param logAnalyticsWorkspaceId string = ''

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------

var clusterName = '${appName}-aks'
var createWorkspace = empty(logAnalyticsWorkspaceId)
var workspaceId = createWorkspace ? logAnalytics.id : logAnalyticsWorkspaceId

// ---------------------------------------------------------------------------
// Log Analytics Workspace (created only when no external ID is provided)
// ---------------------------------------------------------------------------

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = if (createWorkspace) {
  name: '${appName}-law'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// ---------------------------------------------------------------------------
// AKS Cluster
// ---------------------------------------------------------------------------

resource aksCluster 'Microsoft.ContainerService/managedClusters@2025-03-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: aksType == 'Automatic' ? 'Automatic' : 'Base'
    tier: 'Standard'
  }
  properties: {
    // Kubernetes version — omit to let Azure pick the latest stable
    kubernetesVersion: empty(kubernetesVersion) ? json('null') : kubernetesVersion
    dnsPrefix: '${appName}-dns'

    // --- Agent pool profiles (Standard mode only) ---
    agentPoolProfiles: aksType == 'Standard'
      ? [
          {
            name: 'system'
            count: nodeCount
            vmSize: vmSize
            mode: 'System'
            osType: 'Linux'
            osSKU: 'AzureLinux'
            type: 'VirtualMachineScaleSets'
          }
        ]
      : [
          {
            name: 'systempool'
            mode: 'System'
            count: 3
          }
        ]

    // --- Network profile (Standard only; Automatic manages networking) ---
    networkProfile: aksType == 'Standard'
      ? {
          networkPlugin: 'azure'
          networkPluginMode: 'overlay'
          networkDataplane: 'cilium'
        }
      : null

    // --- OIDC & Workload Identity ---
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }

    // --- Add-ons ---
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: workspaceId
        }
      }
    }

    // Web app routing add-on for Standard clusters
    ingressProfile: aksType == 'Standard'
      ? {
          webAppRouting: {
            enabled: true
          }
        }
      : null

    // --- Node auto-provisioning for Automatic clusters ---
    nodeProvisioningProfile: aksType == 'Automatic'
      ? {
          mode: 'Auto'
        }
      : null
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('Name of the AKS cluster.')
output clusterName string = aksCluster.name

@description('OIDC issuer URL for federated identity credentials.')
output oidcIssuerUrl string = aksCluster.properties.oidcIssuerProfile.issuerURL

@description('Object ID of the kubelet managed identity (used for ACR pull role assignment).')
output kubeletIdentityObjectId string = aksCluster.properties.identityProfile.kubeletidentity.objectId

@description('Resource ID of the AKS cluster.')
output aksResourceId string = aksCluster.id
```

### `templates/bicep/identity.bicep`

```bicep
// ============================================================================
// Managed Identity Module – Workload Identity for AKS
// ============================================================================
// Customize:
//   - namespace / serviceAccountName: must match the K8s ServiceAccount your
//     workload uses so the federated credential trust chain is valid
//   - oidcIssuerUrl: the OIDC issuer URL from the AKS cluster
// ============================================================================

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Application name used as a prefix for the identity resources.')
param appName string

@description('Azure region for the managed identity.')
param location string

@description('OIDC issuer URL of the AKS cluster (from aks.bicep outputs).')
param oidcIssuerUrl string

@description('Kubernetes namespace where the workload ServiceAccount lives.')
param namespace string = 'default'

@description('Name of the Kubernetes ServiceAccount bound to this identity.')
param serviceAccountName string = '${appName}-sa'

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------

var identityName = '${appName}-workload-id'

// ---------------------------------------------------------------------------
// User-Assigned Managed Identity
// ---------------------------------------------------------------------------

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

// ---------------------------------------------------------------------------
// Federated Identity Credential
// Links the K8s ServiceAccount to the Azure Managed Identity via OIDC.
// ---------------------------------------------------------------------------

resource federatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  name: '${appName}-federated-cred'
  parent: managedIdentity
  properties: {
    issuer: oidcIssuerUrl
    subject: 'system:serviceaccount:${namespace}:${serviceAccountName}'
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('Client ID of the managed identity (set as azure.workload.identity/client-id annotation on the K8s ServiceAccount).')
output identityClientId string = managedIdentity.properties.clientId

@description('Principal (object) ID of the managed identity (used for Azure role assignments).')
output identityPrincipalId string = managedIdentity.properties.principalId

@description('Display name of the managed identity (used as the PostgreSQL AAD admin principal name).')
output identityName string = managedIdentity.name

@description('Full resource ID of the managed identity.')
output identityResourceId string = managedIdentity.id
```

### `templates/bicep/keyvault.bicep`

```bicep
// ============================================================================
// Azure Key Vault Module
// ============================================================================
// Customize:
//   - skuName: 'standard' or 'premium' (premium supports HSM-backed keys)
//   - identityPrincipalId: the managed identity that needs Key Vault Secrets User access
//   - softDeleteRetentionInDays: 7-90 days (default 90)
//   - enablePurgeProtection: set to true for production to prevent accidental purge
// ============================================================================

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Application name used as a prefix for the Key Vault resource.')
param appName string

@description('Azure region for the Key Vault.')
param location string

@description('SKU tier for the Key Vault.')
@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'

@description('Principal (object) ID of the managed identity to grant Key Vault Secrets User access.')
param identityPrincipalId string

@description('Number of days to retain soft-deleted vaults and secrets (7-90).')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90

@description('Enable purge protection to prevent permanent deletion during the retention period.')
param enablePurgeProtection bool = false

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------

// Key Vault names must be globally unique, 3-24 alphanumeric + hyphens.
var vaultName = '${appName}-kv'

// Built-in role: Key Vault Secrets User
var kvSecretsUserRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4633458b-17de-408a-b874-0445c86b69e6'
)

// ---------------------------------------------------------------------------
// Key Vault
// ---------------------------------------------------------------------------

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: vaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: skuName
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: enablePurgeProtection ? true : null
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// ---------------------------------------------------------------------------
// Role Assignment – Key Vault Secrets User for Workload Identity
// ---------------------------------------------------------------------------

resource kvSecretsUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, identityPrincipalId, kvSecretsUserRoleDefinitionId)
  scope: keyVault
  properties: {
    principalId: identityPrincipalId
    roleDefinitionId: kvSecretsUserRoleDefinitionId
    principalType: 'ServicePrincipal'
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('URI of the Key Vault (e.g., https://myapp-kv.vault.azure.net/).')
output vaultUri string = keyVault.properties.vaultUri

@description('Name of the Key Vault resource.')
output vaultName string = keyVault.name

@description('Resource ID of the Key Vault.')
output vaultResourceId string = keyVault.id
```

### `templates/bicep/main.bicep`

```bicep
// ============================================================================
// Main Orchestrator - Deploy to AKS
// ============================================================================
// Customize:
//   - appName: unique prefix for all resources
//   - aksType: 'Automatic' (node auto-provisioning) or 'Standard' (user-managed pools)
//   - enablePostgresql / enableRedis / enableKeyvault: toggle optional backing services
//   - workloadNamespace / workloadServiceAccount: K8s identifiers for federated credentials
// ============================================================================

targetScope = 'resourceGroup'

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Application name used as a prefix for all deployed resources.')
param appName string

@description('Azure region for all resources. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('AKS cluster type. "Automatic" uses node auto-provisioning; "Standard" uses user-managed node pools.')
@allowed([
  'Automatic'
  'Standard'
])
param aksType string = 'Automatic'

@description('Enable an Azure Database for PostgreSQL Flexible Server.')
param enablePostgresql bool = false

@description('Enable an Azure Cache for Redis instance.')
param enableRedis bool = false

@description('Enable an Azure Key Vault instance.')
param enableKeyvault bool = false

@description('Kubernetes namespace for the workload identity federated credential.')
param workloadNamespace string = 'default'

@description('Kubernetes ServiceAccount name for the workload identity federated credential.')
param workloadServiceAccount string = '${appName}-sa'

@description('PostgreSQL administrator login name (used only when enablePostgresql is true).')
param postgresAdminLogin string = '${appName}admin'

@description('PostgreSQL administrator password (used only when enablePostgresql is true). Must be at least 8 characters.')
@secure()
param postgresAdminPassword string = ''

// ---------------------------------------------------------------------------
// Modules – always deployed
// ---------------------------------------------------------------------------

module aks './aks.bicep' = {
  name: '${appName}-aks'
  params: {
    appName: appName
    location: location
    aksType: aksType
  }
}

module acr './acr.bicep' = {
  name: '${appName}-acr'
  params: {
    appName: appName
    location: location
    kubeletIdentityObjectId: aks.outputs.kubeletIdentityObjectId
  }
}

module identity './identity.bicep' = {
  name: '${appName}-identity'
  params: {
    appName: appName
    location: location
    oidcIssuerUrl: aks.outputs.oidcIssuerUrl
    namespace: workloadNamespace
    serviceAccountName: workloadServiceAccount
  }
}

// ---------------------------------------------------------------------------
// Modules – conditionally deployed
// ---------------------------------------------------------------------------

module postgresql './postgresql.bicep' = if (enablePostgresql) {
  name: '${appName}-postgresql'
  params: {
    appName: appName
    location: location
    administratorLogin: postgresAdminLogin
    administratorLoginPassword: postgresAdminPassword
    administratorPrincipalId: identity.outputs.identityPrincipalId
    administratorPrincipalName: identity.outputs.identityName
  }
}

module redis './redis.bicep' = if (enableRedis) {
  name: '${appName}-redis'
  params: {
    appName: appName
    location: location
    identityPrincipalId: identity.outputs.identityPrincipalId
  }
}

module keyvault './keyvault.bicep' = if (enableKeyvault) {
  name: '${appName}-keyvault'
  params: {
    appName: appName
    location: location
    identityPrincipalId: identity.outputs.identityPrincipalId
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('Name of the deployed AKS cluster.')
output aksClusterName string = aks.outputs.clusterName

@description('Login server URL for the Azure Container Registry.')
output acrLoginServer string = acr.outputs.acrLoginServer

@description('Name of the resource group containing all resources.')
output resourceGroupName string = resourceGroup().name

@description('OIDC issuer URL of the AKS cluster (used for workload identity federation).')
output aksOidcIssuerUrl string = aks.outputs.oidcIssuerUrl

@description('Client ID of the workload managed identity.')
output workloadIdentityClientId string = identity.outputs.identityClientId

@description('Name of the Azure Container Registry.')
output acrName string = acr.outputs.acrName
```

### `templates/bicep/main.bicepparam`

```bicep
// =============================================================================
// Bicep Parameter File Template — AKS Deploy Skill
// =============================================================================
// Environment-specific values for the main.bicep orchestrator.
//
// REPLACE: <app-name>  — your application name (e.g., myapp)
// REPLACE: <location>  — Azure region (e.g., eastus2)
//
// Toggle backing services based on the Phase 2 architecture contract.
// =============================================================================

using './main.bicep'

param appName = '<app-name>'
param location = '<location>'
param aksType = 'Automatic'

// Backing services — set to true only for services in the architecture contract
param enablePostgresql = false
param enableRedis = false
param enableKeyvault = false

// Workload Identity — match the namespace and ServiceAccount from k8s/ manifests
param workloadNamespace = '<app-name>'
param workloadServiceAccount = '<app-name>-sa'
```

### `templates/bicep/postgresql.bicep`

```bicep
// ============================================================================
// Azure Database for PostgreSQL Flexible Server Module
// ============================================================================
// Customize:
//   - skuName / skuTier: scale up for production workloads
//   - storageSizeGB: increase for larger datasets
//   - postgresVersion: pin to a specific major version
//   - databaseName: change to match your application schema
//   - administratorLogin: local admin credential (used alongside Entra ID auth)
//   - administratorPrincipalId / administratorPrincipalName: managed identity for Entra ID auth (required, no defaults)
// ============================================================================

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Application name used as a prefix for the PostgreSQL server.')
param appName string

@description('Azure region for the PostgreSQL Flexible Server.')
param location string

@description('SKU name for the PostgreSQL server.')
param skuName string = 'Standard_B1ms'

@description('SKU tier for the PostgreSQL server.')
@allowed([
  'Burstable'
  'GeneralPurpose'
  'MemoryOptimized'
])
param skuTier string = 'Burstable'

@description('Storage size in GB.')
param storageSizeGB int = 32

@description('PostgreSQL major version.')
@allowed([
  '14'
  '15'
  '16'
  '17'
])
param postgresVersion string = '16'

@description('Local administrator login name.')
param administratorLogin string

@description('Local administrator password. Must be at least 8 characters. Required when passwordAuth is Enabled.')
@secure()
param administratorLoginPassword string

@description('Principal (object) ID of the managed identity to set as Azure AD administrator.')
param administratorPrincipalId string

@description('Principal name (client ID) of the managed identity to set as Azure AD administrator.')
param administratorPrincipalName string

@description('Name of the default database to create.')
param databaseName string = '${appName}db'

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------

var serverName = '${appName}-pg'

// ---------------------------------------------------------------------------
// PostgreSQL Flexible Server
// ---------------------------------------------------------------------------

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: serverName
  location: location
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    version: postgresVersion
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    storage: {
      storageSizeGB: storageSizeGB
    }
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Enabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
  }
}

// ---------------------------------------------------------------------------
// Azure AD Administrator
// ---------------------------------------------------------------------------

resource aadAdmin 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2024-08-01' = {
  name: administratorPrincipalId
  parent: postgresServer
  properties: {
    principalType: 'ServicePrincipal'
    principalName: administratorPrincipalName
    tenantId: subscription().tenantId
  }
}

// ---------------------------------------------------------------------------
// Default Database
// ---------------------------------------------------------------------------

resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = {
  name: databaseName
  parent: postgresServer
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// ---------------------------------------------------------------------------
// Firewall Rule – Allow Azure Services
// ---------------------------------------------------------------------------

resource firewallAllowAzure 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-08-01' = {
  name: 'AllowAzureServices'
  parent: postgresServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('Fully qualified domain name of the PostgreSQL server.')
output fqdn string = postgresServer.properties.fullyQualifiedDomainName

@description('Name of the default database.')
output databaseName string = database.name

@description('Resource ID of the PostgreSQL Flexible Server.')
output serverResourceId string = postgresServer.id
```

### `templates/bicep/redis.bicep`

```bicep
// ============================================================================
// Azure Cache for Redis Module
// ============================================================================
// Customize:
//   - skuName / skuFamily / skuCapacity: scale up for production workloads
//     (e.g., Premium P1 for persistence, clustering, and VNet injection)
//   - minTlsVersion: keep at 1.2 or higher
// ============================================================================

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Application name used as a prefix for the Redis resource.')
param appName string

@description('Azure region for the Redis cache.')
param location string

@description('SKU name for the Redis cache.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Basic'

@description('SKU family. Use "C" for Basic/Standard, "P" for Premium.')
@allowed([
  'C'
  'P'
])
param skuFamily string = 'C'

@description('SKU capacity (cache size). For C family: 0-6; for P family: 1-5.')
@minValue(0)
@maxValue(6)
param skuCapacity int = 0

@description('Minimum TLS version required by clients.')
@allowed([
  '1.2'
  '1.3'
])
param minTlsVersion string = '1.2'

@description('Principal ID of the workload managed identity to grant Redis Cache Contributor role.')
param identityPrincipalId string

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------

var redisName = '${appName}-redis'

// Redis Cache Contributor role definition ID
var redisCacheContributorRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'e0f68234-74aa-48ed-b826-c38b57376e17'
)

// ---------------------------------------------------------------------------
// Redis Cache
// ---------------------------------------------------------------------------

resource redis 'Microsoft.Cache/redis@2024-11-01' = {
  name: redisName
  location: location
  properties: {
    sku: {
      name: skuName
      family: skuFamily
      capacity: skuCapacity
    }
    enableNonSslPort: false
    minimumTlsVersion: minTlsVersion
    redisConfiguration: {
      'maxmemory-policy': 'allkeys-lru'
    }
    publicNetworkAccess: 'Enabled'
  }
}

// ---------------------------------------------------------------------------
// Role Assignment – Redis Cache Contributor for Workload Identity
// ---------------------------------------------------------------------------

resource redisCacheContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(redis.id, identityPrincipalId, redisCacheContributorRoleDefinitionId)
  scope: redis
  properties: {
    principalId: identityPrincipalId
    roleDefinitionId: redisCacheContributorRoleDefinitionId
    principalType: 'ServicePrincipal'
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('Hostname of the Redis cache (e.g., myapp-redis.redis.cache.windows.net).')
output hostName string = redis.properties.hostName

@description('SSL port for the Redis cache (typically 6380).')
output sslPort int = redis.properties.sslPort

@description('Resource ID of the Redis cache.')
output redisResourceId string = redis.id
```

## Templates: GitHub Actions


### `templates/github-actions/deploy.yml`

```yaml
# GitHub Actions workflow: Deploy to AKS
#
# This workflow builds a container image, pushes it to Azure Container Registry,
# and deploys it to an Azure Kubernetes Service cluster.
#
# Authentication uses OIDC federation (workload identity) — no stored passwords.
# Required GitHub secrets: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID
#
# Placeholders to replace (uses __DOUBLE_UNDERSCORE__ style; K8s templates use angle-bracket style):
#   __ACR_NAME__    — Azure Container Registry name (e.g. myappacr)
#   __AKS_CLUSTER__ — AKS cluster name (e.g. myapp-aks)
#   __RG_NAME__     — Azure resource group containing ACR and AKS
#   __APP_NAME__    — Application / deployment name in Kubernetes
#   __NAMESPACE__   — Kubernetes namespace to deploy into

name: Deploy to AKS

on:
  # Trigger on push to main branch (app code changes only)
  push:
    branches:
      - main
    paths-ignore:
      - 'docs/**'
      - '*.md'
      - '.github/**'
      - '.vscode/**'

  # Allow manual trigger from the Actions tab
  workflow_dispatch:

# OIDC federation requires these permissions so GitHub can issue
# an ID token that Azure AD will accept.
permissions:
  id-token: write   # Required for requesting the JWT
  contents: read     # Required for actions/checkout

env:
  ACR_NAME: __ACR_NAME__
  AKS_CLUSTER: __AKS_CLUSTER__
  RESOURCE_GROUP: __RG_NAME__
  APP_NAME: __APP_NAME__
  NAMESPACE: __NAMESPACE__

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    steps:
      # -----------------------------------------------------------
      # 1. Checkout source code
      # -----------------------------------------------------------
      - name: Checkout repository
        uses: actions/checkout@v4

      # -----------------------------------------------------------
      # 2. Authenticate to Azure using OIDC (workload identity)
      #
      #    This exchanges the GitHub-issued OIDC token for an Azure
      #    access token — no client secret required.
      # -----------------------------------------------------------
      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      # -----------------------------------------------------------
      # 3. Build container image and push to ACR
      #
      #    `az acr build` runs the Docker build remotely on ACR,
      #    so no local Docker daemon is needed. The image is tagged
      #    with the commit SHA for traceability.
      # -----------------------------------------------------------
      - name: Build and push image to ACR
        run: |
          az acr build \
            --registry ${{ env.ACR_NAME }} \
            --image ${{ env.APP_NAME }}:${{ github.sha }} \
            .

      # -----------------------------------------------------------
      # 4. Set AKS context
      #
      #    Configures kubectl credentials for the target cluster
      #    so subsequent steps can interact with Kubernetes.
      # -----------------------------------------------------------
      - name: Set AKS context
        uses: azure/aks-set-context@v4
        with:
          resource-group: ${{ env.RESOURCE_GROUP }}
          cluster-name: ${{ env.AKS_CLUSTER }}

      # -----------------------------------------------------------
      # 5. Deploy to AKS
      #
      #    Substitutes the image tag in the deployment manifest,
      #    applies all K8s resources, then waits for the rollout.
      # -----------------------------------------------------------
      - name: Deploy to AKS
        env:
          IMAGE: ${{ env.ACR_NAME }}.azurecr.io/${{ env.APP_NAME }}:${{ github.sha }}
        run: |
          sed -i "s|image: <image>|image: ${IMAGE}|" k8s/deployment.yaml

          kubectl apply -f k8s/ --namespace ${{ env.NAMESPACE }}

          kubectl rollout status deployment/${{ env.APP_NAME }} \
            --namespace ${{ env.NAMESPACE }} \
            --timeout=300s
```

## Templates: Mermaid Diagrams


### `templates/mermaid/architecture-diagram.md`

# Architecture Diagram Template

Render this mermaid diagram in the terminal, replacing all `{{PLACEHOLDER}}` tokens with actual values from Phase 1 discovery and Phase 2 service selection.

## Diagram

~~~mermaid
flowchart LR
    Users([Users]) -->|HTTPS| GW

    subgraph AKS["AKS Cluster: {{AKS_CLUSTER_NAME}}"]
        direction LR
        GW[{{INGRESS_TYPE}}] --> SVC[Service\n{{APP_NAME}}:{{PORT}}]
        SVC --> DEP[Deployment\n{{REPLICA_COUNT}} replicas]
    end

    DEP -.->|Workload Identity| MI[Managed Identity\n{{IDENTITY_NAME}}]
    ACR[ACR\n{{ACR_NAME}}.azurecr.io] -->|pull| AKS
    CICD[GitHub Actions] -->|push| ACR

    %% Backing services — include only those in the architecture contract
    %% Delete lines for services not selected
    DEP -.->|Workload Identity| PG[(PostgreSQL\n{{PG_SERVER_NAME}})]
    DEP -.->|Workload Identity| REDIS[(Redis\n{{REDIS_NAME}})]
    DEP -.->|Workload Identity| KV[Key Vault\n{{KV_NAME}}]

    MON[Log Analytics\n{{LAW_NAME}}] -..- AKS

    style AKS fill:#e8f5e9,stroke:#107C10,stroke-width:2px
    style ACR fill:#e3f2fd,stroke:#0078D4
    style PG fill:#fff3e0,stroke:#f57c00
    style REDIS fill:#fce4ec,stroke:#c62828
    style KV fill:#f3e5f5,stroke:#7b1fa2
    style MON fill:#f5f5f5,stroke:#757575
~~~

## Rendering instructions

Output this diagram as a fenced mermaid code block in the terminal. The developer will see it rendered if their terminal/tool supports mermaid, or as readable text if not.

After the diagram, output the cost estimate table in plain text (using the format from Phase 2 Step 3).

### `templates/mermaid/summary-dashboard.md`

# Deployment Summary Template

After successful deployment, render this summary in the terminal.

## Template

```
╔══════════════════════════════════════════════════════╗
║  DEPLOYMENT SUCCESSFUL                               ║
║  {{APP_NAME}} is live at {{APP_URL}}                 ║
║  Deployed: {{DEPLOY_TIMESTAMP}}                      ║
╚══════════════════════════════════════════════════════╝
```

### Azure Resources

| Resource | Type | Name | Portal Link |
|----------|------|------|-------------|
| Resource Group | resourceGroups | {{RG_NAME}} | `https://portal.azure.com/...` |
| AKS Cluster | managedClusters | {{AKS_NAME}} | `https://portal.azure.com/...` |
| Container Registry | registries | {{ACR_NAME}} | `https://portal.azure.com/...` |
| {{BACKING_SERVICE}} | {{TYPE}} | {{NAME}} | `https://portal.azure.com/...` |

Replace each portal link with the full URL using the subscription ID, resource group, and resource name.

### Files Created / Modified

List all files generated across phases 3–5 with `+` for created and `~` for modified.

### Monthly Cost Estimate

Pull the estimate from Phase 2 decisions and display as a table.

### Next Steps

1. **Custom Domain** — Point DNS to external IP, update Gateway/Ingress
2. **TLS Certificate** — Enable HTTPS via cert-manager or Azure-managed TLS
3. **Monitoring Dashboard** — Set up Azure Monitor / Prometheus + Grafana
4. **Scaling** — Tune HPA min/max replicas and resource requests/limits
5. **CI/CD Trigger** — Push to default branch to trigger pipeline
6. **Cleanup** — `az group delete --name {{RG_NAME}} --yes --no-wait`
