# Deploy-to-AKS Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete OpenCode skill that guides developers through deploying web apps/APIs to AKS via a 6-phase conversational workflow with visual companion integration.

**Architecture:** Phased coordinator skill (`SKILL.md`) that loads phase-specific instruction files on demand. Reference documents provide AKS domain knowledge. Templates provide per-framework Dockerfile, K8s manifest, Bicep, and CI/CD starting points. Visual HTML templates render architecture diagrams, decision cards, and deployment summaries in the browser companion.

**Tech Stack:** Markdown (skill files), HTML/CSS (visual companion templates), Bicep (IaC templates), YAML (K8s manifest templates), YAML (GitHub Actions workflow templates)

---

## File Map

### Skill Core (coordinator + phases)
| Action | File | Responsibility |
|--------|------|---------------|
| Create | `skills/deploy-to-aks/SKILL.md` | Coordinator: checklist, phase transitions, state tracking, visual companion setup |
| Create | `skills/deploy-to-aks/phases/01-discover.md` | Phase 1: project scanning, framework detection, clarifying questions |
| Create | `skills/deploy-to-aks/phases/02-architect.md` | Phase 2: infrastructure planning, architecture diagram, cost estimation |
| Create | `skills/deploy-to-aks/phases/03-containerize.md` | Phase 3: Dockerfile generation/validation, .dockerignore |
| Create | `skills/deploy-to-aks/phases/04-scaffold.md` | Phase 4: K8s manifests, Bicep modules, Deployment Safeguard validation |
| Create | `skills/deploy-to-aks/phases/05-pipeline.md` | Phase 5: GitHub Actions workflow, OIDC federation, secrets setup |
| Create | `skills/deploy-to-aks/phases/06-deploy.md` | Phase 6: Azure resource creation, image push, go-live, summary |

### Reference Documents
| Action | File | Responsibility |
|--------|------|---------------|
| Create | `skills/deploy-to-aks/reference/aks-automatic.md` | AKS Automatic specifics: SKU, Gateway API, Safeguards, Workload Identity |
| Create | `skills/deploy-to-aks/reference/aks-standard.md` | AKS Standard differences: node pools, ingress, networking |
| Create | `skills/deploy-to-aks/reference/safeguards.md` | 13 Deployment Safeguard rules with detection + fix instructions |
| Create | `skills/deploy-to-aks/reference/workload-identity.md` | Workload Identity patterns per backing service |
| Create | `skills/deploy-to-aks/reference/cost-reference.md` | Azure pricing data for cost estimation |

### Templates — Dockerfiles
| Action | File | Responsibility |
|--------|------|---------------|
| Create | `skills/deploy-to-aks/templates/dockerfiles/node.Dockerfile` | Multi-stage Node.js Dockerfile (npm/yarn/pnpm) |
| Create | `skills/deploy-to-aks/templates/dockerfiles/python.Dockerfile` | Multi-stage Python Dockerfile (pip/poetry) |
| Create | `skills/deploy-to-aks/templates/dockerfiles/java.Dockerfile` | Multi-stage Java Dockerfile (Maven/Gradle) |
| Create | `skills/deploy-to-aks/templates/dockerfiles/go.Dockerfile` | Multi-stage Go Dockerfile (scratch final) |
| Create | `skills/deploy-to-aks/templates/dockerfiles/dotnet.Dockerfile` | Multi-stage .NET Dockerfile |
| Create | `skills/deploy-to-aks/templates/dockerfiles/rust.Dockerfile` | Multi-stage Rust Dockerfile (scratch final) |

### Templates — Kubernetes Manifests
| Action | File | Responsibility |
|--------|------|---------------|
| Create | `skills/deploy-to-aks/templates/k8s/deployment.yaml` | Deployment with resource limits, probes, security context |
| Create | `skills/deploy-to-aks/templates/k8s/service.yaml` | ClusterIP Service |
| Create | `skills/deploy-to-aks/templates/k8s/gateway.yaml` | Gateway API Gateway resource (AKS Automatic) |
| Create | `skills/deploy-to-aks/templates/k8s/httproute.yaml` | Gateway API HTTPRoute |
| Create | `skills/deploy-to-aks/templates/k8s/ingress.yaml` | Ingress resource (AKS Standard alternative) |
| Create | `skills/deploy-to-aks/templates/k8s/hpa.yaml` | HorizontalPodAutoscaler |
| Create | `skills/deploy-to-aks/templates/k8s/pdb.yaml` | PodDisruptionBudget |
| Create | `skills/deploy-to-aks/templates/k8s/serviceaccount.yaml` | ServiceAccount with Workload Identity annotations |

### Templates — Bicep Modules
| Action | File | Responsibility |
|--------|------|---------------|
| Create | `skills/deploy-to-aks/templates/bicep/main.bicep` | Orchestrator with parameters, module composition |
| Create | `skills/deploy-to-aks/templates/bicep/aks.bicep` | AKS cluster (Automatic + Standard variants) |
| Create | `skills/deploy-to-aks/templates/bicep/acr.bicep` | Container Registry + AcrPull role assignment |
| Create | `skills/deploy-to-aks/templates/bicep/identity.bicep` | Managed Identity + Federated Credential |
| Create | `skills/deploy-to-aks/templates/bicep/postgresql.bicep` | PostgreSQL Flexible Server |
| Create | `skills/deploy-to-aks/templates/bicep/redis.bicep` | Redis Cache |
| Create | `skills/deploy-to-aks/templates/bicep/keyvault.bicep` | Key Vault |

### Templates — GitHub Actions
| Action | File | Responsibility |
|--------|------|---------------|
| Create | `skills/deploy-to-aks/templates/github-actions/deploy.yml` | Build, push to ACR, deploy to AKS with OIDC |

### Visual Companion Templates
| Action | File | Responsibility |
|--------|------|---------------|
| Create | `skills/deploy-to-aks/visuals/architecture-diagram.html` | Architecture diagram with Azure service boxes, AKS internals, cost |
| Create | `skills/deploy-to-aks/visuals/decision-card.html` | Side-by-side comparison cards (e.g., AKS Automatic vs Standard) |
| Create | `skills/deploy-to-aks/visuals/summary-dashboard.html` | Post-deployment summary: resources, files, URLs, cost, next steps |

---

## Task Breakdown

### Task 1: Coordinator SKILL.md

**Files:**
- Create: `skills/deploy-to-aks/SKILL.md`

This is the entry point — loaded when the skill is invoked. It must follow superpowers conventions (YAML frontmatter, checklist, flowchart, concise).

- [ ] **Step 1: Write the coordinator SKILL.md**

```markdown
---
name: deploy-to-aks
description: Use when deploying a web application or API to Azure Kubernetes Service, containerizing an app for AKS, or generating Kubernetes manifests and Bicep infrastructure for Azure
---

# Deploy to AKS

Guide developers through deploying applications to Azure Kubernetes Service (AKS) without requiring Kubernetes expertise. Reads the actual project, detects the framework, generates production-ready artifacts, and optionally executes the deployment.

## Checklist

You MUST create a todo for each of these items and complete them in order:

1. **Discover** — scan the project, detect framework/language/dependencies, ask clarifying questions
2. **Architect** — plan infrastructure, show architecture diagram + cost in visual companion, get approval
3. **Containerize** — generate or validate Dockerfile + .dockerignore
4. **Scaffold** — generate K8s manifests + Bicep IaC, validate against Deployment Safeguards
5. **Pipeline** — generate GitHub Actions CI/CD workflow, optionally configure OIDC
6. **Deploy** — execute deployment with confirmation gates, show summary dashboard

## Process Flow

​```dot
digraph deploy_flow {
    rankdir=LR;
    node [shape=box, style=rounded];

    discover [label="1. Discover\n(terminal)"];
    architect [label="2. Architect\n(visual)"];
    containerize [label="3. Containerize\n(terminal)"];
    scaffold [label="4. Scaffold\n(visual)"];
    pipeline [label="5. Pipeline\n(terminal)"];
    deploy [label="6. Deploy\n(visual)"];

    discover -> architect;
    architect -> containerize [label="approved"];
    architect -> architect [label="iterate"];
    containerize -> scaffold;
    scaffold -> pipeline;
    pipeline -> deploy;
}
​```

## Phase Instructions

At each phase, read the corresponding instruction file for detailed guidance:

| Phase | Read | Also load |
|-------|------|-----------|
| 1. Discover | `phases/01-discover.md` | — |
| 2. Architect | `phases/02-architect.md` | `reference/cost-reference.md` |
| 3. Containerize | `phases/03-containerize.md` | — |
| 4. Scaffold | `phases/04-scaffold.md` | `reference/safeguards.md`, `reference/workload-identity.md` |
| 5. Pipeline | `phases/05-pipeline.md` | — |
| 6. Deploy | `phases/06-deploy.md` | — |

Load `reference/aks-automatic.md` or `reference/aks-standard.md` based on the developer's AKS flavor choice (detected in Phase 1).

## Visual Companion

This skill uses the visual companion at three touchpoints:
- **Phase 2:** Architecture diagram + cost estimate (use `visuals/architecture-diagram.html` as template)
- **Phase 4:** Updated architecture diagram with actual resource names
- **Phase 6:** Deployment summary dashboard (use `visuals/summary-dashboard.html` as template)

Start the visual companion server at Phase 2 using the brainstorming skill's server:
​```bash
scripts/start-server.sh --project-dir <developer-project-root>
​```

Decision comparison cards (`visuals/decision-card.html`) can be used at any phase when the developer faces a visual choice.

## Execution Model

- **Generate artifacts automatically** — Dockerfiles, manifests, Bicep, workflows
- **Execute CLI commands only with confirmation** — `az`, `docker`, `kubectl`, `gh`
- Show the exact command that will run and ask for explicit opt-in

## Adaptive Behavior

- **Detect before create** — check for existing Dockerfiles, manifests, Bicep, CI/CD
- **Validate before replace** — improve what exists rather than overwriting
- **Ask only what can't be auto-detected** — minimize questions, maximize intelligence
- **Teach while fixing** — when auto-fixing Safeguard violations, explain why

## Key Principles

- ONE concept per turn — never overload the developer
- Progressive discovery — ask incrementally, confirm as you go
- Sensible defaults — AKS Automatic, Gateway API, Workload Identity, 2 replicas
- No Kubernetes jargon until Phase 4 — frame AKS as a "scalable app platform"
```

- [ ] **Step 2: Verify SKILL.md structure**

Read the file back and confirm:
- YAML frontmatter has `name` and `description`
- Description starts with "Use when..."
- Checklist section with numbered items
- Graphviz flowchart
- Phase instruction table
- Under 300 lines

- [ ] **Step 3: Commit**

```bash
git add skills/deploy-to-aks/SKILL.md
git commit -m "feat: add coordinator SKILL.md with phase flow and checklist"
```

---

### Task 2: Phase 1 — Discover

**Files:**
- Create: `skills/deploy-to-aks/phases/01-discover.md`

- [ ] **Step 1: Write the discover phase file**

```markdown
# Phase 1: Discover

Scan the developer's project to understand what they're building, what already exists, and what's needed for AKS deployment.

## Goal

Build a project profile without asking unnecessary questions. Auto-detect everything possible, then confirm and fill gaps.

## Step 1: Scan the Project

Dispatch an explore subagent to scan the project root. Look for these signal files:

### Framework Detection

| Signal File | Framework | Sub-framework (check dependencies) |
|------------|-----------|--------------------------------------|
| `package.json` | Node.js | Express, Fastify, Next.js, Nest.js, Hono (check `dependencies`) |
| `requirements.txt` or `pyproject.toml` or `Pipfile` | Python | Flask, FastAPI, Django, Starlette (check file contents or `[project.dependencies]`) |
| `pom.xml` or `build.gradle` or `build.gradle.kts` | Java | Spring Boot, Quarkus, Micronaut (check `<dependencies>` or `dependencies {}`) |
| `go.mod` | Go | Gin, Echo, Fiber, Chi (check `require` block) |
| `*.csproj` or `*.sln` | .NET | ASP.NET Core, Blazor (check `<PackageReference>` and SDK) |
| `Cargo.toml` | Rust | Actix, Axum, Rocket (check `[dependencies]`) |

### Existing Infrastructure Detection

| Look for | What it means |
|----------|--------------|
| `Dockerfile` | Already containerized — Phase 3 will validate instead of generate |
| `docker-compose.yml` or `docker-compose.yaml` | Has service dependencies — extract backing service names |
| `k8s/` or `manifests/` or `deploy/` directory | Has K8s manifests — Phase 4 will validate/extend |
| `*.bicep` files | Has Bicep IaC — Phase 4 will extend |
| `helm/` or `Chart.yaml` | Uses Helm — warn that this skill generates plain manifests; offer Helm values overlay |
| `.github/workflows/` | Has CI/CD — Phase 5 will add deploy workflow alongside |
| `terraform/` or `*.tf` | Has Terraform — warn that this skill uses Bicep; offer to add alongside |

### Environment & Dependency Detection

Scan these locations for backing service signals:

| Check | Signal | Backing service |
|-------|--------|----------------|
| `.env`, `.env.example`, `.env.template` | `DATABASE_URL`, `POSTGRES_*`, `PG_*` | PostgreSQL |
| `.env`, `.env.example`, `.env.template` | `MONGO_*`, `MONGODB_*` | Cosmos DB (Mongo API) |
| `.env`, `.env.example`, `.env.template` | `REDIS_URL`, `REDIS_*` | Redis Cache |
| `.env`, `.env.example`, `.env.template` | `AZURE_STORAGE_*`, `BLOB_*` | Storage Account |
| `.env`, `.env.example`, `.env.template` | `AZURE_OPENAI_*`, `OPENAI_*` | Azure OpenAI (out of v1 scope — note for future) |
| Source code imports | `azure-keyvault`, `@azure/keyvault-*`, `azure.keyvault` | Key Vault |
| `docker-compose.yml` | Service definitions (postgres, redis, mongo) | Corresponding Azure services |

### Port & Health Endpoint Detection

| Check | How |
|-------|-----|
| Port | Look for `PORT` env var, `EXPOSE` in Dockerfile, `listen(` calls, `server.port` in config |
| Health endpoints | Grep for `/health`, `/healthz`, `/ready`, `/readiness`, `/liveness` in route definitions |
| Entry point | `main` field in package.json, `CMD` in Dockerfile, `main.py`, `main.go`, `Program.cs` |

## Step 2: Present Discovery Summary

After scanning, present what you found in a concise summary:

```
Here's what I found in your project:

**Framework:** FastAPI (Python 3.11)
**Entry point:** src/main.py
**Port:** 8000
**Existing infrastructure:**
  - Dockerfile: Yes (will validate in Phase 3)
  - K8s manifests: None
  - CI/CD: GitHub Actions (build + test workflow exists)
**Backing services detected:**
  - PostgreSQL (from DATABASE_URL in .env.example)
  - Redis (from REDIS_URL in .env.example)
**Health endpoints:** /health (detected in routes)
```

## Step 3: Ask Clarifying Questions

Only ask what you couldn't auto-detect. Use multiple-choice where possible. One question at a time.

**Required questions (if not already known):**

1. **Confirm stack:** "I detected [framework] with [backing services]. Is that right, or did I miss anything?"

2. **Exposure type:** "Should this be publicly accessible (external API/web app) or internal only (cluster-internal service)?"

3. **AKS flavor** (use a decision card if visual companion is available):
   - AKS Automatic (recommended) — fully managed, Gateway API, Deployment Safeguards
   - AKS Standard — more control over node pools, ingress, networking

**Conditional questions (only if relevant):**

4. **Monorepo:** If multiple frameworks detected: "I see both [X] and [Y] config files. Is this a monorepo? Which application should we deploy?"

5. **Existing Terraform:** If *.tf files found: "You have Terraform files. This skill generates Bicep — I can add Bicep alongside your Terraform. OK?"

6. **Existing Helm:** If Chart.yaml found: "You have Helm charts. Want me to generate a Helm values overlay for AKS, or create plain K8s manifests?"

## Step 4: Handle Edge Cases

| Situation | Action |
|-----------|--------|
| Empty project (no source code) | Switch to greenfield flow: "Looks like a fresh project. What framework would you like to use? I can scaffold a starter app." |
| Unknown framework | Ask directly: "I can't auto-detect your framework. What language/framework is this?" |
| No env files or config | Ask about backing services: "Does your app need a database, cache, or other services?" |

## Output

By the end of this phase, you should know:
- Framework and language
- Entry point and port
- Existing infrastructure artifacts (Dockerfile, manifests, CI/CD, IaC)
- Backing services needed
- Exposure type (public/internal)
- AKS flavor (Automatic/Standard)
- Health endpoint paths (or defaults: /healthz, /ready)

Proceed to **Phase 2: Architect**.
```

- [ ] **Step 2: Verify the file**

Read back and confirm it covers: framework detection, infra detection, env detection, health endpoints, summary presentation, clarifying questions, edge cases, output requirements.

- [ ] **Step 3: Commit**

```bash
git add skills/deploy-to-aks/phases/01-discover.md
git commit -m "feat: add Phase 1 Discover instructions"
```

---

### Task 3: Phase 2 — Architect

**Files:**
- Create: `skills/deploy-to-aks/phases/02-architect.md`
- Create: `skills/deploy-to-aks/reference/cost-reference.md`

- [ ] **Step 1: Write the architect phase file**

Write `skills/deploy-to-aks/phases/02-architect.md` with the following content covering:
- Azure service selection logic (based on discovery output)
- Architecture diagram generation instructions (using visual companion)
- Cost estimation rules (referencing `reference/cost-reference.md`)
- Approval gate (developer must confirm before proceeding)
- Iteration support (developer can change services, diagram updates)

Key sections:
- **Goal:** Present the full infrastructure plan visually before generating any files
- **Step 1: Select Azure Services** — decision matrix mapping backing service needs to Azure resources
- **Step 2: Generate Architecture Diagram** — instructions to write HTML to visual companion using `visuals/architecture-diagram.html` as a guide. Diagram must show: Users → Gateway API → Deployment(s) inside AKS cluster, backing Azure services as external boxes, ACR with push/pull connections
- **Step 3: Compute Cost Estimate** — read `reference/cost-reference.md`, sum up selected services
- **Step 4: Present to Developer** — show diagram in browser, summarize in terminal with cost breakdown
- **Step 5: Iterate** — if developer wants changes, update services, regenerate diagram + cost
- **Step 6: Get Approval** — explicit "Looks good, proceed" before moving to Phase 3

- [ ] **Step 2: Write the cost reference document**

Write `skills/deploy-to-aks/reference/cost-reference.md` with Azure pricing data:

```markdown
# Azure Cost Reference

Pricing estimates for cost estimation during Phase 2 (Architect). All prices are approximate USD/month, East US region, pay-as-you-go.

## AKS

| Component | Price | Notes |
|-----------|-------|-------|
| AKS Automatic control plane | $116.80/mo | Includes Automatic SKU surcharge |
| AKS Standard control plane | $73.00/mo | Free tier available for dev/test |
| Compute per vCPU (Automatic) | ~$24.00/mo/vCPU | Billed through node auto-provisioning |
| Compute per vCPU (Standard) | Varies by VM SKU | D2s v3 (~$70/mo), D4s v3 (~$140/mo) |

## Container Registry

| Tier | Price | Storage | Notes |
|------|-------|---------|-------|
| Basic | $5.00/mo | 10 GB | Dev/test |
| Standard | $20.00/mo | 100 GB | Production (recommended) |

## Database

| Service | Tier | Price | Notes |
|---------|------|-------|-------|
| PostgreSQL Flexible Server | Burstable B1ms | ~$13.00/mo | 1 vCore, 2 GB RAM, 32 GB storage |
| PostgreSQL Flexible Server | GP D2s v3 | ~$100.00/mo | 2 vCores, 8 GB RAM, 128 GB storage |
| Cosmos DB (NoSQL) | Serverless | ~$0.25/100K RU | Pay per request |
| Cosmos DB (NoSQL) | Provisioned 400 RU/s | ~$23.00/mo | Minimum provisioned |

## Cache

| Service | Tier | Price | Notes |
|---------|------|-------|-------|
| Redis Cache | Basic C0 (250 MB) | ~$16.00/mo | Dev/test |
| Redis Cache | Standard C1 (1 GB) | ~$40.00/mo | Production (recommended) |

## Security

| Service | Price | Notes |
|---------|-------|-------|
| Key Vault | ~$0.03/10K operations | Secrets, certs, keys |
| Managed Identity | Free | Always use — no extra cost |

## Monitoring (included by default)

| Service | Price | Notes |
|---------|-------|-------|
| Log Analytics | ~$2.76/GB ingested | First 5 GB/mo free |
| Application Insights | ~$2.76/GB ingested | Shares Log Analytics workspace |

## Networking

| Component | Price | Notes |
|-----------|-------|-------|
| Gateway API (Istio) | Included in AKS Automatic | No additional charge |
| Standard Load Balancer | ~$18.00/mo + rules | Included with AKS |
| Public IP | ~$3.60/mo | One per Gateway |

## Cost Estimation Rules

1. Always include: AKS control plane + compute (minimum 2 vCPU for 2 replicas) + ACR Standard
2. Add backing services based on discovery
3. Round to nearest dollar
4. Present as monthly estimate with breakdown
5. Show total prominently
6. Note: "Actual costs may vary. See Azure Pricing Calculator for precise estimates."
```

- [ ] **Step 3: Verify both files**

Read both files back and confirm cost-reference.md covers all services mentioned in the spec, and 02-architect.md references it correctly.

- [ ] **Step 4: Commit**

```bash
git add skills/deploy-to-aks/phases/02-architect.md skills/deploy-to-aks/reference/cost-reference.md
git commit -m "feat: add Phase 2 Architect instructions and cost reference"
```

---

### Task 4: Phase 3 — Containerize

**Files:**
- Create: `skills/deploy-to-aks/phases/03-containerize.md`
- Create: `skills/deploy-to-aks/templates/dockerfiles/node.Dockerfile`
- Create: `skills/deploy-to-aks/templates/dockerfiles/python.Dockerfile`
- Create: `skills/deploy-to-aks/templates/dockerfiles/java.Dockerfile`
- Create: `skills/deploy-to-aks/templates/dockerfiles/go.Dockerfile`
- Create: `skills/deploy-to-aks/templates/dockerfiles/dotnet.Dockerfile`
- Create: `skills/deploy-to-aks/templates/dockerfiles/rust.Dockerfile`

- [ ] **Step 1: Write the containerize phase file**

Write `skills/deploy-to-aks/phases/03-containerize.md` covering:
- **Goal:** Ensure the project has a production-ready Dockerfile + .dockerignore
- **Step 1: Check for existing Dockerfile** — if exists, validate against best practices checklist; if not, generate from template
- **Best practices checklist:** Multi-stage build, non-root USER, pinned base image tags (no :latest), layer caching (copy lockfile before source), HEALTHCHECK instruction, .dockerignore excludes node_modules/venv/.git/etc.
- **Step 2: Generate or improve Dockerfile** — reference the appropriate template from `templates/dockerfiles/`
- **Step 3: Generate .dockerignore** — standard entries per framework
- **Step 4: Optional local build test** — offer to run `docker build -t <app-name>:local .` with confirmation gate
- **Validation checklist** for existing Dockerfiles (each item should explain WHY):
  - Multi-stage: reduces image size by 60-80%
  - Non-root: required by AKS Deployment Safeguards (DS004)
  - Pinned tags: required by Deployment Safeguards (DS009)
  - Layer caching: faster CI/CD builds
  - HEALTHCHECK: used by K8s probes

- [ ] **Step 2: Write all 6 Dockerfile templates**

Each template must include:
- Comment header explaining what to customize
- Multi-stage build (build stage + runtime stage)
- Non-root user
- Pinned base image tags with `# TODO: pin to specific version` comments
- HEALTHCHECK instruction
- Layer caching optimization
- `EXPOSE` with a placeholder port

Write the following files with production-ready Dockerfile content:

**`templates/dockerfiles/node.Dockerfile`:**
- Build: `node:22-alpine AS build`, `npm ci`, `npm run build`
- Runtime: `node:22-alpine`, copy from build, `USER node`, `EXPOSE 3000`

**`templates/dockerfiles/python.Dockerfile`:**
- Build: `python:3.12-slim AS build`, pip install to /app
- Runtime: `python:3.12-slim`, copy venv, `USER appuser`, `EXPOSE 8000`

**`templates/dockerfiles/java.Dockerfile`:**
- Build: `eclipse-temurin:21-jdk-alpine AS build`, Maven wrapper or Gradle build
- Runtime: `eclipse-temurin:21-jre-alpine`, copy JAR, `USER appuser`, `EXPOSE 8080`

**`templates/dockerfiles/go.Dockerfile`:**
- Build: `golang:1.23-alpine AS build`, `CGO_ENABLED=0 go build`
- Runtime: `scratch` or `gcr.io/distroless/static`, copy binary, `USER 65534`, `EXPOSE 8080`

**`templates/dockerfiles/dotnet.Dockerfile`:**
- Build: `mcr.microsoft.com/dotnet/sdk:9.0 AS build`, `dotnet publish`
- Runtime: `mcr.microsoft.com/dotnet/aspnet:9.0`, copy publish output, `USER app`, `EXPOSE 8080`

**`templates/dockerfiles/rust.Dockerfile`:**
- Build: `rust:1.83-slim AS build`, `cargo build --release`
- Runtime: `gcr.io/distroless/cc-debian12` or `scratch`, copy binary, `USER 65534`, `EXPOSE 8080`

- [ ] **Step 3: Verify all templates**

Read back each Dockerfile and confirm:
- Multi-stage: yes
- Non-root user: yes
- Pinned tags: yes (no `:latest`)
- HEALTHCHECK: yes
- Layer caching: lockfile copied before source
- EXPOSE: yes

- [ ] **Step 4: Commit**

```bash
git add skills/deploy-to-aks/phases/03-containerize.md skills/deploy-to-aks/templates/dockerfiles/
git commit -m "feat: add Phase 3 Containerize instructions and 6 Dockerfile templates"
```

---

### Task 5: Phase 4 — Scaffold (K8s Manifests)

**Files:**
- Create: `skills/deploy-to-aks/phases/04-scaffold.md`
- Create: `skills/deploy-to-aks/reference/safeguards.md`
- Create: `skills/deploy-to-aks/reference/workload-identity.md`
- Create: `skills/deploy-to-aks/templates/k8s/deployment.yaml`
- Create: `skills/deploy-to-aks/templates/k8s/service.yaml`
- Create: `skills/deploy-to-aks/templates/k8s/gateway.yaml`
- Create: `skills/deploy-to-aks/templates/k8s/httproute.yaml`
- Create: `skills/deploy-to-aks/templates/k8s/ingress.yaml`
- Create: `skills/deploy-to-aks/templates/k8s/hpa.yaml`
- Create: `skills/deploy-to-aks/templates/k8s/pdb.yaml`
- Create: `skills/deploy-to-aks/templates/k8s/serviceaccount.yaml`

- [ ] **Step 1: Write the safeguards reference document**

Write `skills/deploy-to-aks/reference/safeguards.md` with all 13 rules. For each rule include:
- Rule ID (DS001-DS013)
- What it checks
- Severity (Error/Warning)
- Why it matters (1 sentence, developer-friendly)
- How to detect the violation in YAML
- How to fix it (exact YAML to add/change)
- Whether it can be auto-fixed

- [ ] **Step 2: Write the workload identity reference document**

Write `skills/deploy-to-aks/reference/workload-identity.md` covering:
- What Workload Identity is (1 paragraph, no jargon)
- Three components: Managed Identity, Federated Credential, ServiceAccount
- How they link together (AKS OIDC issuer)
- Per-service connection patterns:
  - PostgreSQL: `DefaultAzureCredential` + `AZURE_CLIENT_ID` env var
  - Key Vault: `SecretClient` with `DefaultAzureCredential`
  - Storage: `BlobServiceClient` with `DefaultAzureCredential`
  - Redis: Azure AD token-based auth
- Required pod labels and ServiceAccount annotations

- [ ] **Step 3: Write the scaffold phase file**

Write `skills/deploy-to-aks/phases/04-scaffold.md` covering:
- **Goal:** Generate K8s manifests and Bicep modules for the approved architecture
- **Step 1: Check for existing manifests** — scan for k8s/, manifests/, *.bicep
- **Step 2: Generate K8s manifests** — one file at a time, referencing templates from `templates/k8s/`. Replace placeholders with actual values from discovery + architecture phases
- **Step 3: Validate against Deployment Safeguards** — read `reference/safeguards.md`, check each manifest against all 13 rules. Auto-fix what's fixable, report what's not. ALWAYS explain what was fixed and why
- **Step 4: Generate Bicep modules** — one module at a time, referencing templates from `templates/bicep/`. Compose via main.bicep
- **Step 5: Update architecture diagram** — push updated diagram to visual companion showing actual resource names from Bicep + K8s manifests
- File output structure: `k8s/` directory for manifests, `infra/` directory for Bicep

- [ ] **Step 4: Write all K8s manifest templates**

Write the following YAML template files. Each must include:
- Comment header with placeholder markers (`# REPLACE: <app-name>`, etc.)
- All Deployment Safeguard rules pre-satisfied
- Workload Identity annotations where applicable

**`templates/k8s/deployment.yaml`:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <app-name>
  labels:
    app: <app-name>
spec:
  replicas: 2                        # DS010: minimum 2 replicas
  selector:
    matchLabels:
      app: <app-name>
  template:
    metadata:
      labels:
        app: <app-name>
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: <app-name>
      automountServiceAccountToken: false  # DS013
      containers:
        - name: <app-name>
          image: <acr-name>.azurecr.io/<app-name>:<tag>  # DS009: no :latest
          ports:
            - containerPort: <port>
          resources:                  # DS001: resource limits
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "256Mi"
          livenessProbe:              # DS002
            httpGet:
              path: <health-path>
              port: <port>
            initialDelaySeconds: 10
            periodSeconds: 15
          readinessProbe:             # DS003
            httpGet:
              path: <ready-path>
              port: <port>
            initialDelaySeconds: 5
            periodSeconds: 10
          securityContext:
            runAsNonRoot: true        # DS004
            allowPrivilegeEscalation: false  # DS011
            readOnlyRootFilesystem: true     # DS012
            capabilities:
              drop: ["ALL"]
      securityContext:
        runAsNonRoot: true            # DS004 (pod level)
        seccompProfile:
          type: RuntimeDefault
```

**Write similar templates for:** service.yaml (ClusterIP), gateway.yaml (Gateway API with `istio` gatewayClassName), httproute.yaml (routing to service), ingress.yaml (NGINX class for AKS Standard), hpa.yaml (min 2, max 10, CPU 70%), pdb.yaml (minAvailable 1), serviceaccount.yaml (with Workload Identity annotation).

- [ ] **Step 5: Verify all K8s templates pass Safeguard rules**

Read each template and check:
- DS001: resources.requests AND resources.limits present
- DS002: livenessProbe present
- DS003: readinessProbe present
- DS004: runAsNonRoot: true
- DS005-DS007: no hostNetwork/hostPID/hostIPC
- DS008: no privileged: true
- DS009: no :latest tag
- DS010: replicas >= 2
- DS011: allowPrivilegeEscalation: false
- DS012: readOnlyRootFilesystem: true
- DS013: automountServiceAccountToken: false

- [ ] **Step 6: Commit**

```bash
git add skills/deploy-to-aks/phases/04-scaffold.md skills/deploy-to-aks/reference/safeguards.md skills/deploy-to-aks/reference/workload-identity.md skills/deploy-to-aks/templates/k8s/
git commit -m "feat: add Phase 4 Scaffold instructions, safeguards reference, workload identity reference, and K8s manifest templates"
```

---

### Task 6: Bicep Templates

**Files:**
- Create: `skills/deploy-to-aks/templates/bicep/main.bicep`
- Create: `skills/deploy-to-aks/templates/bicep/aks.bicep`
- Create: `skills/deploy-to-aks/templates/bicep/acr.bicep`
- Create: `skills/deploy-to-aks/templates/bicep/identity.bicep`
- Create: `skills/deploy-to-aks/templates/bicep/postgresql.bicep`
- Create: `skills/deploy-to-aks/templates/bicep/redis.bicep`
- Create: `skills/deploy-to-aks/templates/bicep/keyvault.bicep`

- [ ] **Step 1: Write all Bicep module templates**

Each module must include:
- Comment header explaining what to customize
- `@description` decorators on parameters
- Parameterized with sensible defaults
- Output resource IDs for cross-references

**`templates/bicep/main.bicep`:**
- Parameters: `appName`, `location`, `aksType` (Automatic/Standard), `enablePostgresql` (bool), `enableRedis` (bool), `enableKeyvault` (bool)
- Module references for each sub-module
- Outputs: AKS cluster name, ACR login server, resource group name

**`templates/bicep/aks.bicep`:**
- AKS Automatic variant: SKU `Automatic/Standard`, API `2025-03-01`, system managed node pools, `approuting-istio` addon for Gateway API
- AKS Standard variant (conditional): user-managed node pool with D2s v3, NGINX ingress addon
- Common: Workload Identity enabled, OIDC issuer enabled, Managed Identity, monitoring addon

**`templates/bicep/acr.bicep`:**
- Standard tier ACR
- AcrPull role assignment from AKS kubelet identity to ACR

**`templates/bicep/identity.bicep`:**
- User-Assigned Managed Identity
- Federated Identity Credential linking K8s ServiceAccount to the identity via AKS OIDC issuer

**`templates/bicep/postgresql.bicep`:**
- PostgreSQL Flexible Server, Burstable B1ms, 32 GB storage
- Azure AD authentication enabled (for Workload Identity)
- Firewall rule allowing Azure services

**`templates/bicep/redis.bicep`:**
- Redis Cache Standard C1
- Azure AD authentication enabled

**`templates/bicep/keyvault.bicep`:**
- Key Vault with RBAC authorization
- Role assignment for the Managed Identity (Key Vault Secrets User)

- [ ] **Step 2: Verify all Bicep modules**

Read each module and confirm:
- Valid Bicep syntax (resource declarations, parameters, outputs)
- Cross-module references use outputs correctly
- AKS Automatic uses correct SKU and API version
- Workload Identity enabled on AKS
- Role assignments present where needed (AcrPull, Key Vault Secrets User)

- [ ] **Step 3: Commit**

```bash
git add skills/deploy-to-aks/templates/bicep/
git commit -m "feat: add Bicep module templates for AKS, ACR, Identity, PostgreSQL, Redis, Key Vault"
```

---

### Task 7: Phase 5 — Pipeline

**Files:**
- Create: `skills/deploy-to-aks/phases/05-pipeline.md`
- Create: `skills/deploy-to-aks/templates/github-actions/deploy.yml`

- [ ] **Step 1: Write the pipeline phase file**

Write `skills/deploy-to-aks/phases/05-pipeline.md` covering:
- **Goal:** Generate a GitHub Actions workflow for CI/CD and optionally configure OIDC federation
- **Step 1: Check for existing workflows** — scan `.github/workflows/`
- **Step 2: Generate deploy workflow** — reference `templates/github-actions/deploy.yml`, customize with actual ACR name, AKS cluster name, resource group, namespace
- **Step 3: Explain OIDC** — briefly explain why OIDC is better than stored secrets (no passwords to rotate, time-limited tokens, no secret sprawl)
- **Step 4: Optional OIDC setup** — with confirmation gates, run:
  1. `az ad app create --display-name <app-name>-github-deploy`
  2. `az ad sp create --id <app-id>`
  3. `az ad app federated-credential create` (for GitHub Actions from repo main branch)
  4. `az role assignment create --assignee <sp-id> --role Contributor --scope /subscriptions/<sub-id>`
  5. `gh secret set AZURE_CLIENT_ID --body <client-id>`
  6. `gh secret set AZURE_TENANT_ID --body <tenant-id>`
  7. `gh secret set AZURE_SUBSCRIPTION_ID --body <sub-id>`
- Each command shown to developer before execution

- [ ] **Step 2: Write the GitHub Actions workflow template**

Write `skills/deploy-to-aks/templates/github-actions/deploy.yml`:

```yaml
name: Deploy to AKS

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  id-token: write   # Required for OIDC
  contents: read

env:
  ACR_NAME: <acr-name>
  AKS_CLUSTER: <aks-cluster-name>
  RESOURCE_GROUP: <resource-group>
  APP_NAME: <app-name>
  NAMESPACE: default

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Build and push to ACR
        run: |
          az acr build \
            --registry ${{ env.ACR_NAME }} \
            --image ${{ env.APP_NAME }}:${{ github.sha }} \
            --image ${{ env.APP_NAME }}:latest \
            .

      - name: Set AKS context
        uses: azure/aks-set-context@v4
        with:
          resource-group: ${{ env.RESOURCE_GROUP }}
          cluster-name: ${{ env.AKS_CLUSTER }}

      - name: Deploy to AKS
        run: |
          # Update image tag in deployment
          kubectl set image deployment/${{ env.APP_NAME }} \
            ${{ env.APP_NAME }}=${{ env.ACR_NAME }}.azurecr.io/${{ env.APP_NAME }}:${{ github.sha }} \
            -n ${{ env.NAMESPACE }}

          # Wait for rollout
          kubectl rollout status deployment/${{ env.APP_NAME }} \
            -n ${{ env.NAMESPACE }} \
            --timeout=300s
```

- [ ] **Step 3: Verify the workflow**

Read back and confirm:
- OIDC permissions set (`id-token: write`)
- Uses `azure/login@v2` with OIDC (client-id, tenant-id, subscription-id from secrets)
- Builds with `az acr build` (no need for docker login)
- Tags with git SHA (not :latest only)
- Uses `azure/aks-set-context@v4` for cluster auth
- Deploys with `kubectl set image` + `kubectl rollout status`

- [ ] **Step 4: Commit**

```bash
git add skills/deploy-to-aks/phases/05-pipeline.md skills/deploy-to-aks/templates/github-actions/deploy.yml
git commit -m "feat: add Phase 5 Pipeline instructions and GitHub Actions workflow template"
```

---

### Task 8: Phase 6 — Deploy

**Files:**
- Create: `skills/deploy-to-aks/phases/06-deploy.md`

- [ ] **Step 1: Write the deploy phase file**

Write `skills/deploy-to-aks/phases/06-deploy.md` covering:
- **Goal:** Execute the deployment with confirmation gates at each step, then show summary dashboard
- **Step 1: Pre-flight checks** — verify `az` CLI installed and logged in, verify `kubectl` installed, verify `gh` CLI installed (if GitHub integration needed)
- **Step 2: Azure Login** — confirmation gate, run `az login`, verify with `az account show`
- **Step 3: Create Resource Group** — confirmation gate, run `az group create --name <rg> --location <location>`
- **Step 4: Deploy Bicep** — confirmation gate, run `az deployment group create --resource-group <rg> --template-file infra/main.bicep --parameters appName=<app-name>`. Show the command, explain what it creates, wait for confirmation
- **Step 5: Build and Push Image** — confirmation gate, run `az acr build --registry <acr-name> --image <app-name>:<tag> .`
- **Step 6: Deploy to AKS** — confirmation gate:
  1. `az aks get-credentials --resource-group <rg> --name <aks-name>`
  2. `kubectl apply -f k8s/` (all manifests at once)
  3. `kubectl rollout status deployment/<app-name> --timeout=300s`
- **Step 7: Verify** — run `kubectl get pods`, `kubectl get svc`, `kubectl get gateway` (or `kubectl get ingress`), extract external IP/hostname
- **Step 8: Summary Dashboard** — write deployment summary to visual companion using `visuals/summary-dashboard.html` template. Include: all Azure resources with portal links, application URL, files created/modified list, cost estimate, next steps
- **Step 9: Commit artifacts** — offer to commit all generated files: `git add . && git commit -m "feat: add AKS deployment configuration"`

Confirmation gate pattern for each step:
```
"Next I'll create the Azure resource group. This will run:
  az group create --name my-app-rg --location eastus
This creates a resource group in East US. Want me to proceed?
[Yes / No, I'll do it myself]"
```

- [ ] **Step 2: Verify the file**

Read back and confirm all 9 steps are present, each has a confirmation gate pattern, and the summary dashboard step references the visual template.

- [ ] **Step 3: Commit**

```bash
git add skills/deploy-to-aks/phases/06-deploy.md
git commit -m "feat: add Phase 6 Deploy instructions with confirmation gates"
```

---

### Task 9: AKS Reference Documents

**Files:**
- Create: `skills/deploy-to-aks/reference/aks-automatic.md`
- Create: `skills/deploy-to-aks/reference/aks-standard.md`

- [ ] **Step 1: Write the AKS Automatic reference**

Write `skills/deploy-to-aks/reference/aks-automatic.md` covering:
- What AKS Automatic is (2-3 sentences, developer-friendly)
- Key properties: SKU `Automatic/Standard`, API version `2025-03-01`
- Gateway API: built-in via `approuting-istio` addon. Use `Gateway` + `HTTPRoute` resources (not Ingress)
- Node management: fully managed, auto node provisioning, no user node pools to configure
- Deployment Safeguards: enforced at cluster level (reference `safeguards.md`)
- Workload Identity: mandatory — no connection strings, no imagePullSecrets
- Monitoring: built-in Container Insights + Prometheus metrics
- What developers DON'T need to worry about: node sizing, OS patching, upgrade scheduling, network plugins
- Bicep properties: exact `properties.sku` and addon configuration needed
- Gateway API usage: `gatewayClassName: istio`, sample Gateway and HTTPRoute

- [ ] **Step 2: Write the AKS Standard reference**

Write `skills/deploy-to-aks/reference/aks-standard.md` covering:
- What AKS Standard is (comparison to Automatic)
- Key differences: user-managed node pools, choose VM SKU, choose ingress controller
- Node pools: at least one system pool + optional user pools, explicit VM SKU (recommend D2s_v3 for small workloads)
- Ingress: NGINX via application routing addon (or BYO controller). Use `Ingress` resource (not Gateway API)
- Networking: Azure CNI Overlay recommended, network policy options
- Deployment Safeguards: optional but recommended — enable via `properties.safeguardsProfile`
- Workload Identity: recommended (same setup as Automatic)
- Bicep properties: different from Automatic — includes `agentPoolProfiles`, explicit VM sizes, ingress addon config

- [ ] **Step 3: Verify both files**

Read back and confirm:
- aks-automatic.md covers Gateway API, not Ingress
- aks-standard.md covers Ingress, not Gateway API (by default)
- Both reference Workload Identity
- Bicep property specifics are accurate

- [ ] **Step 4: Commit**

```bash
git add skills/deploy-to-aks/reference/aks-automatic.md skills/deploy-to-aks/reference/aks-standard.md
git commit -m "feat: add AKS Automatic and Standard reference documents"
```

---

### Task 10: Visual Companion Templates

**Files:**
- Create: `skills/deploy-to-aks/visuals/architecture-diagram.html`
- Create: `skills/deploy-to-aks/visuals/decision-card.html`
- Create: `skills/deploy-to-aks/visuals/summary-dashboard.html`

- [ ] **Step 1: Write the architecture diagram HTML template**

Write `skills/deploy-to-aks/visuals/architecture-diagram.html` — an HTML content fragment (no `<html>` wrapper, the visual companion server adds that) that renders:
- Title: "Your Application on Azure"
- Traffic flow: Users → Gateway API (or Ingress) → App Deployment inside AKS cluster box
- AKS cluster box containing: Gateway, Deployment (with replica count), HPA, PDB, Workload Identity
- External Azure services as boxes below: ACR, backing services (PostgreSQL, Redis, Key Vault, etc.)
- Cost estimate bar at the bottom with per-service breakdown and total
- Placeholder markers (`{{APP_NAME}}`, `{{ACR_NAME}}`, `{{AKS_TYPE}}`, etc.) with comments explaining what to replace

The skill will use this as a starting point and customize it with actual values from the project.

Style should match the mockups we created during brainstorming: clean, light background, blue accents for Azure services, green for AKS cluster box, pills/badges for K8s components.

- [ ] **Step 2: Write the decision card HTML template**

Write `skills/deploy-to-aks/visuals/decision-card.html` — a reusable template for side-by-side comparison cards:
- Two cards with title, description, feature list, and optional "RECOMMENDED" badge
- Uses `data-choice` and `onclick="toggleSelect(this)"` for browser selection
- Placeholder markers for titles, descriptions, features

- [ ] **Step 3: Write the summary dashboard HTML template**

Write `skills/deploy-to-aks/visuals/summary-dashboard.html` — a post-deployment summary:
- Success banner with application URL
- 2x2 grid: Azure Resources (with portal links), Files Created (git diff style), Monthly Cost, Next Steps
- Placeholder markers for all dynamic content
- Portal link pattern: `https://portal.azure.com/#@/resource/subscriptions/{{SUB_ID}}/resourceGroups/{{RG_NAME}}/providers/Microsoft.ContainerService/managedClusters/{{AKS_NAME}}`

- [ ] **Step 4: Verify all visual templates**

Read back each HTML file and confirm:
- Valid HTML fragments (no `<html>` wrapper)
- Placeholder markers are documented
- Interactive elements use `toggleSelect(this)` where applicable
- Styling is inline (no external CSS dependency beyond what the companion server provides)

- [ ] **Step 5: Commit**

```bash
git add skills/deploy-to-aks/visuals/
git commit -m "feat: add visual companion HTML templates for architecture diagram, decision cards, and summary dashboard"
```

---

### Task 11: Final Cleanup and Verification

**Files:**
- Modify: `skills/deploy-to-aks/SKILL.md` (if any adjustments needed after writing all content)
- Remove: all `.gitkeep` files from directories that now have content

- [ ] **Step 1: Remove .gitkeep files from populated directories**

```bash
find skills/deploy-to-aks -name '.gitkeep' -delete
```

- [ ] **Step 2: Verify complete file structure**

Run `find skills/deploy-to-aks -type f | sort` and confirm all expected files exist:
- SKILL.md
- phases/01-discover.md through 06-deploy.md
- reference/aks-automatic.md, aks-standard.md, safeguards.md, workload-identity.md, cost-reference.md
- templates/dockerfiles/{node,python,java,go,dotnet,rust}.Dockerfile
- templates/k8s/{deployment,service,gateway,httproute,ingress,hpa,pdb,serviceaccount}.yaml
- templates/bicep/{main,aks,acr,identity,postgresql,redis,keyvault}.bicep
- templates/github-actions/deploy.yml
- visuals/{architecture-diagram,decision-card,summary-dashboard}.html

- [ ] **Step 3: Read SKILL.md one final time**

Verify all phase file references match actual filenames, all reference document paths are correct, and the skill follows superpowers conventions (frontmatter, checklist, flowchart).

- [ ] **Step 4: Commit cleanup**

```bash
git add -A
git commit -m "chore: remove .gitkeep files, finalize project structure"
```

- [ ] **Step 5: Run word count on SKILL.md**

```bash
wc -w skills/deploy-to-aks/SKILL.md
```

Target: under 500 words (it's a coordinator, not a reference). If over, trim.
