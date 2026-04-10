# Quick Phase 1: Scan & Plan

Detect the application framework and Azure infrastructure, then present a deployment plan for approval.

## Goal

Build a complete deployment plan through automated scanning — of both the project and the live Azure environment — with zero or at most one clarifying question. Present the plan in a structured format and get a single approval before execution.

---

## Step 1: Project Scan (Silent)

Scan the project root in a single pass. Collect all categories before presenting anything to the developer.

### 1.1 Framework Detection

Scan for signal files at the project root (and one level deep for monorepos). Map each signal to a framework:

| Signal File | Framework | Sub-framework Detection |
|---|---|---|
| `package.json` | Node.js | Inspect `dependencies` for: **Express** (`express`), **Fastify** (`fastify`), **NestJS** (`@nestjs/core`), **Next.js** (`next`), **Remix** (`@remix-run/node`), **Hono** (`hono`), **Koa** (`koa`) |
| `requirements.txt` | Python | Scan for: **FastAPI** (`fastapi`), **Django** (`django`), **Flask** (`flask`), **Starlette** (`starlette`) |
| `pyproject.toml` | Python | Parse `[project.dependencies]` or `[tool.poetry.dependencies]` for the same libraries |
| `Pipfile` | Python | Parse `[packages]` section |
| `pom.xml` | Java | Search for `spring-boot-starter-web` → **Spring Boot**; `quarkus-resteasy` → **Quarkus** |
| `build.gradle` / `build.gradle.kts` | Java / Kotlin | Search for `org.springframework.boot` → **Spring Boot** |
| `go.mod` | Go | Parse `require` for: `gin-gonic/gin` → **Gin**; `labstack/echo` → **Echo**; `gofiber/fiber` → **Fiber** |
| `*.csproj` | .NET | Search for `Microsoft.AspNetCore.*` → **ASP.NET Core** |
| `Cargo.toml` | Rust | Parse `[dependencies]` for: `actix-web` → **Actix**; `axum` → **Axum** |

### 1.2 Port Detection

Check sources in priority order (first match wins):

| Source | What to Look For |
|---|---|
| `Dockerfile` | `EXPOSE <port>` |
| `.env` / `.env.example` | `PORT=<number>` |
| Source code | `app.listen(<number>)`, `server.port=<number>` |
| Framework defaults | Express: 3000, FastAPI: 8000, Spring Boot: 8080, ASP.NET: 5000/8080, Gin: 8080 |

### 1.3 Health Endpoint Detection

Grep source tree for route registrations matching:

`/health`, `/healthz`, `/ready`, `/readiness`, `/liveness`, `/startup`, `/ping`, `/api/health`, `/api/healthz`

Record the path. If none found, note it — Phase 2 will use `/health` as default in probes.

### 1.4 Existing Artifact Detection

| Pattern | What It Indicates |
|---|---|
| `Dockerfile` | Container build already defined |
| `k8s/`, `manifests/`, `deploy/` | Kubernetes manifests exist |

Record boolean `existing_dockerfile` and `existing_k8s_manifests`.

---

## Step 2: Azure Infrastructure Detection (Silent)

Query the live Azure environment to discover existing resources. Run these commands silently.

### 2.1 Cluster Detection

```bash
# Get current kubectl context
kubectl config current-context

# Get API server URL to identify cluster
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
```

Parse the API server URL to extract cluster and resource group information. For AKS-managed contexts, the URL format is `<cluster>-<rg>-<hash>.<region>.azmk8s.io`. Alternatively, use `az aks list` and match the API server.

Then query full cluster details:

```bash
az aks show -g <rg> -n <cluster> -o json
```

Extract:
- `aks_cluster_name` — cluster name
- `aks_flavor` — check `nodeProvisioningProfile.mode`: if `"Auto"` → AKS Automatic, otherwise → AKS Standard
- `aks_oidc_issuer` — `oidcIssuerProfile.issuerUrl`
- `resource_group` — the resource group name
- `location` — the Azure region

**For AKS Standard clusters**, verify the Web App Routing addon is enabled:

```bash
az aks show -g <rg> -n <cluster> --query 'ingressProfile.webAppRouting.enabled' -o tsv
```

If the result is not `true`, **stop immediately** with a clear error:

```text
✗ AKS Standard cluster missing required addon

  The cluster is AKS Standard but the Web App Routing addon is not enabled.
  The generated Ingress resource requires this addon to function.

  To enable it:
    az aks approuting enable -g <rg> -n <cluster>

  Or provision a new cluster with the addon:
    ./scripts/setup-aks-prerequisites.sh --name <name> --location eastus --flavor standard
```

### 2.2 ACR Detection

```bash
az acr list -g <rg> -o json
```

Extract `acr_name` and `acr_login_server` from the first result. If multiple ACRs exist, this is a disambiguation question (see Step 4).

### 2.3 Identity Detection

```bash
az identity list -g <rg> -o json
```

Extract `identity_name` and `identity_client_id`. If multiple identities with federated credentials exist, this is a disambiguation question (see Step 4).

### 2.4 Namespace Check

```bash
kubectl get namespace -o name
```

List existing namespaces. Default namespace for the app is the app name (derived from the project directory name or package name).

### Failure Handling

If any Azure or kubectl command fails, **stop immediately** with a clear error:

```text
✗ Azure infrastructure detection failed

  Command:  az aks show -g my-rg -n my-aks
  Error:    <actual error message>

  Possible causes:
  ├─ Not logged in to Azure     → Run: az login
  ├─ Wrong subscription         → Run: az account set -s <id>
  ├─ Cluster doesn't exist      → Run: az aks list -o table
  └─ No kubectl context         → Run: az aks get-credentials -g <rg> -n <cluster>

  To provision test infrastructure:
    ./scripts/setup-aks-prerequisites.sh --name <name> --location eastus
```

Do **not** fall back to a question loop. The user must fix their environment.

---

## Step 3: Knowledge Pack Loading

After detecting the framework, check `knowledge-packs/frameworks/` for a matching pack:

| Pack | Trigger |
|------|---------|
| `spring-boot` | `pom.xml` with `spring-boot-starter-web` |
| `express` | `package.json` with `express` or `fastify` |
| `nextjs` | `package.json` with `next` |
| `fastapi` | `requirements.txt`/`pyproject.toml` with `fastapi` |
| `django` | `requirements.txt`/`pyproject.toml` with `django` |
| `nestjs` | `package.json` with `@nestjs/core` |
| `aspnet-core` | `*.csproj` with `Microsoft.NET.Sdk.Web` |
| `go` | `go.mod` with `gin-gonic`, `labstack/echo`, or `gofiber` |
| `flask` | `requirements.txt`/`pyproject.toml` with `flask` |

If a pack exists, read it. It influences Dockerfile optimization, probe configuration, and writable path requirements in Quick Phase 2.

If no pack exists, continue with generic templates.

---

## Step 4: Disambiguation (Maximum One Question)

Ask a question **only** for genuine ambiguity that cannot be auto-resolved:

- Multiple Dockerfiles in the project → "Which Dockerfile should I use?"
- Multiple ACRs in the resource group → "Which container registry?"
- Multiple managed identities with federated credentials → "Which identity?"
- Ambiguous entry point (multiple `main.*` files) → "Which is the entry point?"

Present as multiple-choice. If there is no ambiguity, skip directly to Step 5 with **zero questions**.

---

## Step 5: Plan Presentation

Present the deployment plan using Unicode box-drawing and tree formatting. Render inside a code block:

```text
╭──────────────────────────────────────────────────╮
│  ⚡ Quick Deploy Plan                             │
╰──────────────────────────────────────────────────╯

  Application
  ├─ Framework:    <framework> <version>
  ├─ Entry point:  <entry_point>
  ├─ Port:         <port>
  └─ Health:       <health_endpoint or "none detected — will use /health">

  Target Infrastructure
  ├─ AKS Cluster:  <aks_cluster_name> (<aks_flavor>)
  ├─ ACR:          <acr_login_server>
  ├─ Identity:     <identity_name>
  └─ Namespace:    <namespace>

  Files to Generate
  ├─ Dockerfile           (from <language> template)
  ├─ .dockerignore
  ├─ k8s/namespace.yaml
  ├─ k8s/deployment.yaml
  ├─ k8s/service.yaml
  ├─ k8s/serviceaccount.yaml
  ├─ k8s/gateway.yaml     (AKS Automatic)    ← or ingress.yaml for Standard
  ├─ k8s/httproute.yaml                       ← only for Automatic
  ├─ k8s/hpa.yaml
  └─ k8s/pdb.yaml

  Deployment Steps
  ├─ [1/4] Generate artifacts
  ├─ [2/4] Build & push image → <acr>/<app>:<git-sha>
  ├─ [3/4] Deploy to AKS
  └─ [4/4] Verify & dashboard
```

Adapt the plan based on scan results:
- If existing Dockerfile found: show "Dockerfile (validate existing)" instead of "(from <language> template)"
- If existing K8s manifests found: show "k8s/* (validate & update existing)"
- If AKS Standard: show `ingress.yaml` instead of `gateway.yaml` + `httproute.yaml`
- If configmap is needed: include `k8s/configmap.yaml` in the file list

---

## Step 6: Approval Gate

Ask:

> Ready to deploy? (y/n)

- **If approved:** Proceed to Quick Phase 2.
- **If rejected:** Ask "What would you like to change?" — adjust the plan and re-present.
- This is a lightweight gate — no HARD GATE iteration loop.

---

## Data Points Collected

All of these must be known before proceeding to Quick Phase 2:

| Data Point | Source | Required |
|-----------|--------|----------|
| `framework` | Project scan | Yes |
| `sub_framework` | Dependency files | If detectable |
| `language_version` | Dependency files | If detectable |
| `entry_point` | Project scan | Yes |
| `port` | Dockerfile/env/source/defaults | Yes |
| `health_endpoints` | Source code grep | If detectable |
| `aks_cluster_name` | `az aks show` | Yes |
| `aks_flavor` | `az aks show` (node provisioning mode) | Yes |
| `web_app_routing_enabled` | `az aks show` (ingress profile) | Yes (for Standard only) |
| `aks_oidc_issuer` | `az aks show` | Yes |
| `acr_name` | `az acr list` | Yes |
| `acr_login_server` | `az acr list` | Yes |
| `identity_name` | `az identity list` | Yes |
| `identity_client_id` | `az identity list` | Yes |
| `resource_group` | `az aks show` / kubeconfig | Yes |
| `namespace` | Default: app name | Yes |
| `existing_dockerfile` | File scan | Yes (boolean) |
| `existing_k8s_manifests` | Directory scan | Yes (boolean) |
