# Deploy-to-AKS OpenCode Skill — Design Spec

**Date:** 2026-04-02
**Status:** Approved
**Author:** Brainstormed collaboratively via OpenCode

---

## 1. Overview

### Problem

Developers want to deploy their applications to Azure Kubernetes Service (AKS) without needing to learn Kubernetes. Existing solutions either require Kubernetes knowledge or are standalone web apps disconnected from the developer's actual codebase and workflow.

### Solution

An OpenCode skill that guides developers through deploying their applications to AKS via a conversational, phased workflow. The skill runs in the developer's terminal, reads their actual project, generates production-ready artifacts (Dockerfile, K8s manifests, Bicep IaC, CI/CD pipelines), and optionally executes deployment commands — all without requiring Kubernetes expertise.

### Inspiration

Inspired by the [`adaptive-ui-try-aks`](https://github.com/sabbour/adaptive-ui-try-aks) web app and the [`adaptive-ui-framework`](https://github.com/sabbour/adaptive-ui-framework) (by sabbour), which demonstrate the conversational deployment concept via a browser-based chat UI built on a custom Adaptive UI framework. This skill brings the same mission to the terminal with added advantages.

### Key Differentiators from the Web App

| Capability | Web App | OpenCode Skill |
|------------|---------|----------------|
| Codebase awareness | None — generates from scratch based on conversation | Reads actual project files, detects stack, adapts |
| CLI execution | ARM API calls via browser | Runs `az`, `docker`, `kubectl`, `gh` directly |
| File management | In-browser editor, exported via GitHub PR | Writes directly into the project |
| Setup required | Standalone React app + API backend | Zero — invoke the skill if you have OpenCode |
| Existing infrastructure | Ignores — always generates new | Detects and validates/extends what exists |

---

## 2. Target Users

**Primary:** Developer with a working application (web app or API) in a git repo who wants to get it running on AKS. May or may not have a Dockerfile, CI/CD, or any Azure resources yet.

**Secondary:**

- Greenfield projects (idea/framework preference but no code yet)
- Partially deployed applications (some Azure infra exists, need help finishing)

---

## 3. Scope

### In Scope (v1)

- Web applications and APIs (Node.js, Python, Java, Go, .NET, Rust)
- AKS Automatic (default) and AKS Standard
- Bicep for infrastructure-as-code
- GitHub Actions for CI/CD
- Visual companion for architecture diagrams, decision cards, deployment summary
- Generate artifacts + optional execution with confirmation gates

### Out of Scope (v1)

- AI Agent track (KAITO, Azure OpenAI, RAG) — deferred to v2
- Terraform support
- Azure DevOps pipelines (GitHub Actions only for v1)
- Multi-cluster / multi-environment (staging + production)
- Helm chart generation (detect and warn, but don't generate)

---

## 4. Skill Architecture

### Delivery Model

OpenCode Skill (phased coordinator with sub-skills), using the visual companion for rich content at key touchpoints.

### File Structure

```
skills/deploy-to-aks/
  SKILL.md                        # Coordinator (~200-300 lines)
  phases/
    01-discover.md                # Project scanning, framework detection, questions
    02-architect.md               # Infrastructure planning, architecture diagram, cost
    03-containerize.md            # Dockerfile generation/validation, .dockerignore
    04-scaffold.md                # K8s manifests, Bicep files, safeguard validation
    05-pipeline.md                # GitHub Actions, OIDC federation, secrets
    06-deploy.md                  # Azure resource creation, image push, go-live
  reference/
    aks-automatic.md              # AKS Automatic specifics
    aks-standard.md               # AKS Standard differences
    safeguards.md                 # 13 Deployment Safeguard rules with fix instructions
    workload-identity.md          # Workload Identity setup patterns
    cost-reference.md             # Azure pricing for cost estimation
  templates/
    dockerfiles/                  # Per-framework Dockerfile templates
    k8s/                          # K8s manifest templates
    bicep/                        # Bicep module templates
    github-actions/               # CI/CD workflow templates
  visuals/
    architecture-diagram.html     # HTML template for architecture diagrams
    decision-card.html            # Comparison card template
    summary-dashboard.html        # Final deployment summary
```

### How It Works

1. Developer invokes the skill (via `/deploy-to-aks` or asking "help me deploy to AKS")
2. `SKILL.md` loads — contains the coordinator: overall checklist, phase transitions, state tracking
3. At each phase, the coordinator reads the appropriate `phases/XX-*.md` for detailed instructions
4. Phase files reference `reference/` docs and `templates/` as needed
5. Visual companion is used at key moments (Phases 2, 4, 6)
6. State is tracked via the coordinator's checklist and todo items

### Design Principle

The coordinator SKILL.md is concise. It defines the *flow*, not the *domain knowledge*. Domain knowledge lives in reference docs and phase files. The LLM isn't overloaded with Bicep syntax when it's still in the discovery phase.

---

## 5. Phase Details

### Phase 1: Discover (2-4 turns, terminal only)

**What the skill does:**

- Dispatches an `explore` subagent to scan the project
- Detects framework/language from signal files (package.json, requirements.txt, pom.xml, go.mod, *.csproj, Cargo.toml)
- Checks for existing infrastructure artifacts (Dockerfile, k8s/, *.bicep, Helm, .github/workflows/)
- Identifies environment variables, database connections, external service dependencies
- Scans for health endpoints (/health, /healthz, /ready routes)

**Questions asked (only what can't be auto-detected):**

- Confirm detected stack: "I see this is a FastAPI app with PostgreSQL. Is that right?"
- Exposure type: "Does this need to be publicly accessible, or is it an internal API?"
- Backing services: "I see environment vars for REDIS_URL — do you need a Redis cache?"
- AKS flavor: "Any preference on AKS Automatic (managed) vs Standard (more control)?"

**Output:** Project profile — framework, language, dependencies, services needed, exposure type.

### Phase 2: Architect (1-2 turns, visual companion)

**What the skill does:**

- Based on discovery, selects Azure services (AKS, ACR, PostgreSQL, Redis, Key Vault, etc.)
- Generates an architecture diagram shown in the visual companion
- Computes a monthly cost estimate
- Presents the plan for developer confirmation

**Visual companion content:**

- Architecture diagram with Azure service icons, AKS internals, traffic flow
- Cost breakdown table (AKS control plane + compute + backing services)
- Decision comparison cards when choices arise (e.g., AKS Automatic vs Standard)

**Developer experience:**

- Sees the full architecture in the browser before any files are generated
- Can iterate: "skip Redis", "use Cosmos DB instead" — diagram and cost update
- Must explicitly approve before proceeding

**Output:** Approved architecture plan + diagram + cost estimate. Blueprint for Phases 3-6.

### Phase 3: Containerize (1-2 turns, terminal)

**What the skill does:**

- IF Dockerfile exists: validates for best practices, suggests improvements
- IF no Dockerfile: generates from framework-specific template
- Generates/updates .dockerignore
- Optionally offers to run `docker build` to test locally

**Best practices enforced:**

- Multi-stage builds (separate build/runtime stages)
- Non-root user
- Pinned base image tags (no :latest)
- Layer caching optimization
- Health check instruction

**Output:** Production-ready Dockerfile + .dockerignore written to project.

### Phase 4: Scaffold (2-3 turns, terminal + visual)

**Kubernetes manifests generated:**

- `deployment.yaml` — with resource limits, probes, security context
- `service.yaml` — ClusterIP
- `gateway.yaml` + `httproute.yaml` — Gateway API (Automatic) or Ingress (Standard)
- `hpa.yaml` — Horizontal Pod Autoscaler
- `pdb.yaml` — Pod Disruption Budget
- `serviceaccount.yaml` — with Workload Identity annotations

**Bicep files generated:**

- `main.bicep` — orchestrator with parameters
- `aks.bicep` — AKS cluster (Automatic or Standard)
- `acr.bicep` — Container Registry + AcrPull role
- `identity.bicep` — Managed Identity + Federated Credential
- Backing service modules as needed (PostgreSQL, Redis, Key Vault, etc.)

**Validation:**

- All 13 AKS Deployment Safeguard rules checked after generation
- Auto-fixable violations fixed with explanation ("Adding resource limits because AKS Deployment Safeguards require them")
- Non-fixable violations reported for developer action
- Architecture diagram updated in visual companion with actual resource/file names

**Output:** `k8s/` directory with manifests + `infra/` directory with Bicep modules. All Safeguard-compliant.

### Phase 5: Pipeline (1-2 turns, terminal)

**What gets created:**

- `.github/workflows/deploy.yml` — Build, push to ACR, deploy to AKS
- OIDC authentication (no stored passwords/secrets)
- Triggered on push to main + manual dispatch

**Optional execution (with confirmation):**

- `az ad app create` — App Registration
- `az ad sp create` — Service Principal
- Federated Identity Credential for GitHub Actions
- `gh secret set` — AZURE_CLIENT_ID, TENANT_ID, SUBSCRIPTION_ID

**Output:** GitHub Actions workflow file. Optionally: Azure AD app + federated credential + GitHub secrets configured.

### Phase 6: Deploy (2-4 turns, terminal + visual)

**Execution steps (each with confirmation gate):**

1. `az login` — authenticate to Azure
2. `az group create` — resource group
3. `az deployment group create` — deploy Bicep
4. `az acr build` — build + push image
5. `az aks get-credentials` + `kubectl apply` — deploy to cluster
6. Verify: `kubectl get pods`, `kubectl get gateway`, check endpoint

**Visual companion — Summary Dashboard:**

- Final architecture diagram with live resource names
- Resource list with Azure Portal links
- Application URL / endpoint
- Monthly cost summary
- Git commit summary of all files created/modified
- Next steps checklist (custom domain, monitoring, scaling, staging)

**Output:** Application running on AKS. Summary dashboard in browser.

---

## 6. Visual Companion Integration

Three specific touchpoints, not every phase:

| Touchpoint | Phase | Content |
|------------|-------|---------|
| Architecture diagram + cost | 2 (Architect) | Azure resources, AKS internals, traffic flow, cost breakdown |
| Updated diagram + safeguard report | 4 (Scaffold) | Diagram with actual names, safeguard validation status |
| Deployment summary dashboard | 6 (Deploy) | Resources, files, URLs, cost, portal links, next steps |

Additionally, decision comparison cards appear when the developer faces visual choices (AKS Automatic vs Standard, database selection, etc.).

The architecture diagram is the signature visual — the developer sees their infrastructure before it's created, and again after deployment with real resource names and links.

---

## 7. AKS Domain Knowledge

Encoded in focused reference documents, loaded only when relevant.

### reference/aks-automatic.md

- SKU: `Automatic/Standard`, API version `2025-03-01`
- Gateway API via `approuting-istio`
- Hosted system node pools, auto node provisioning
- Deployment Safeguards enforced at cluster level
- Workload Identity mandatory

### reference/aks-standard.md

- User-managed node pools with VM SKU selection
- Ingress controller choices (NGINX, Contour, application routing)
- Network plugin choices
- Deployment Safeguards optional but recommended

### reference/safeguards.md

13 Deployment Safeguard rules adapted from the web app's k8s-validator.ts:

| Rule | Check | Severity | Auto-fixable |
|------|-------|----------|-------------|
| DS001 | Resource requests/limits | Error | Yes (100m/128Mi req, 500m/256Mi limits) |
| DS002 | livenessProbe | Warning | Yes (httpGet /healthz) |
| DS003 | readinessProbe | Warning | Yes (httpGet /ready) |
| DS004 | runAsNonRoot | Error | Yes |
| DS005 | No hostNetwork | Error | Yes |
| DS006 | No hostPID | Error | Yes |
| DS007 | No hostIPC | Error | Yes |
| DS008 | No privileged | Error | Yes |
| DS009 | No :latest tags | Warning | No (needs developer input) |
| DS010 | replicas >= 2 | Warning | Yes |
| DS011 | allowPrivilegeEscalation: false | Error | Yes |
| DS012 | readOnlyRootFilesystem | Warning | Yes |
| DS013 | automountServiceAccountToken | Warning | Yes |

Unlike the web app (which auto-fixes silently), the skill shows the developer what it's fixing and why — a teaching moment.

### reference/workload-identity.md

- Managed Identity + Federated Credential pattern
- ServiceAccount annotations and pod labels
- Per-service wiring (PostgreSQL, Key Vault, Storage, etc.)

### reference/cost-reference.md

- AKS control plane: $116.80/mo (Automatic), $73/mo (Standard)
- Compute per-vCPU surcharge
- ACR, PostgreSQL, Redis, Key Vault pricing tiers

---

## 8. Codebase Intelligence

### Framework Detection Matrix

| Signal File | Detected As | Dockerfile Template |
|------------|-------------|---------------------|
| `package.json` | Node.js (Express/Fastify/Next.js/Nest) | Node multi-stage |
| `requirements.txt` / `pyproject.toml` | Python (Flask/FastAPI/Django) | Python multi-stage |
| `pom.xml` / `build.gradle` | Java (Spring Boot/Quarkus) | Java multi-stage |
| `go.mod` | Go (Gin/Echo/Fiber) | Go scratch |
| `*.csproj` | .NET (ASP.NET) | .NET multi-stage |
| `Cargo.toml` | Rust | Rust scratch |

### Existing Infrastructure Detection

| Signal | Skill Behavior |
|--------|---------------|
| Dockerfile exists | Phase 3 validates instead of generating |
| docker-compose.yml | Extract backing services from compose |
| k8s/ or manifests/ | Phase 4 validates/extends instead of generating |
| *.bicep files | Phase 4 extends existing modules |
| Helm Chart.yaml | Offer Helm values overlay vs raw manifests |
| .github/workflows/ | Phase 5 extends or adds deploy workflow |
| terraform/*.tf | Warn: skill uses Bicep; offer to add alongside |

### Adaptive Behavior Principle

**Detect before create, validate before replace.** Each phase checks what exists before deciding whether to generate or improve.

### Error Handling

| Situation | Response |
|-----------|----------|
| Unknown framework | Ask developer directly |
| Conflicting signals (monorepo) | Ask which app to deploy |
| Existing Terraform | Warn, offer Bicep alongside |
| Empty project | Switch to greenfield flow |
| Existing Helm charts | Offer values overlay option |

---

## 9. Execution Model

**Generate + optional execution with confirmation gates.**

All artifact generation (Dockerfiles, manifests, Bicep, workflows) happens automatically. All CLI execution (`az`, `docker`, `kubectl`, `gh`) requires explicit opt-in at each step.

Confirmation gate pattern:

```
"I've generated your Bicep files in infra/. Want me to deploy them to Azure?
This will run: az deployment group create -g <rg> -f infra/main.bicep
[Yes / No, I'll do it myself]"
```

---

## 10. Future Work (v2+)

- **AI Agent track** — KAITO, Azure OpenAI, RAG, model hosting
- **Multi-environment** — staging + production with promotion workflows
- **Azure DevOps pipelines** — as alternative to GitHub Actions
- **Helm chart generation** — for teams that prefer Helm
- **Monitoring setup** — Prometheus, Grafana, Azure Monitor integration
- **Custom domain + TLS** — automated cert-manager/Let's Encrypt setup
