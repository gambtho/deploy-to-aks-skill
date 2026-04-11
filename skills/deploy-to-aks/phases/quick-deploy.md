# Quick Deploy

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

```bash
az acr list -g <rg> -o json
az identity list -g <rg> -o json
```

**AKS Standard only** — verify Web App Routing addon:

```bash
az aks show -g <rg> -n <cluster> --query 'ingressProfile.webAppRouting.enabled' -o tsv
```

If not `true`, stop with error and provide the enable command: `az aks approuting enable -g <rg> -n <cluster>`

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
| Node.js | `templates/dockerfiles/node.Dockerfile` |
| Python | `templates/dockerfiles/python.Dockerfile` |
| Java | `templates/dockerfiles/java.Dockerfile` |
| Go | `templates/dockerfiles/go.Dockerfile` |
| .NET | `templates/dockerfiles/dotnet.Dockerfile` |
| Rust | `templates/dockerfiles/rust.Dockerfile` |

Generate `.dockerignore` if missing.

### Kubernetes Manifests

Generate from `templates/k8s/` templates. Replace `<angle-bracket>` placeholders with detected values.

| Manifest | Template | Notes |
|----------|----------|-------|
| `k8s/namespace.yaml` | `templates/k8s/namespace.yaml` | |
| `k8s/serviceaccount.yaml` | `templates/k8s/serviceaccount.yaml` | Workload Identity annotation |
| `k8s/deployment.yaml` | `templates/k8s/deployment.yaml` | Image placeholder resolved at deploy time |
| `k8s/service.yaml` | `templates/k8s/service.yaml` | |
| `k8s/gateway.yaml` | `templates/k8s/gateway.yaml` | AKS Automatic only |
| `k8s/httproute.yaml` | `templates/k8s/httproute.yaml` | AKS Automatic only |
| `k8s/ingress.yaml` | `templates/k8s/ingress.yaml` | AKS Standard only |
| `k8s/hpa.yaml` | `templates/k8s/hpa.yaml` | min: 2, max: 10 |
| `k8s/pdb.yaml` | `templates/k8s/pdb.yaml` | minAvailable: 1 |
| `k8s/configmap.yaml` | `templates/k8s/configmap.yaml` | Only if app needs environment-specific config |

---

## Section 3: Safeguards Validation

Before deploying, validate all generated manifests against AKS Deployment Safeguards DS001-DS013. Reference `reference/safeguards.md` for the full checklist.

- 12 of 13 rules are auto-fixable. DS009 (no `:latest` tag) is resolved by tagging with git SHA.
- Apply framework-specific writable path requirements from the knowledge pack (e.g., Spring Boot needs `/tmp`, Next.js needs `/app/.next/cache`).
- Reference `reference/workload-identity.md` for Workload Identity configuration.

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

### Verify Gateway API CRDs (AKS Automatic only)

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
kubectl get gateway -n <namespace> -o jsonpath='{.items[0].status.addresses[0].value}'  # AKS Automatic
kubectl get ingress -n <namespace> -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}'  # AKS Standard
```

Wait up to 3 minutes for external IP. Once available, curl the health endpoint.
