# Quick Phase 2: Execute

Generate artifacts, build the container image, deploy to AKS, and verify — in a single continuous flow.

## Goal

Execute the approved deployment plan from Quick Phase 1 with structured progress output, automatic error recovery, and a polished summary dashboard. No intermediate confirmation gates — the plan approval in Phase 1 covers the entire execution.

## Presentation Style

Keep the developer engaged throughout:

- **Use emoji strategically** for key milestones (📦 build, 🚀 deploy, ✅ verify)
- **Stream command output** for long-running operations (don't go silent during 2-minute builds)
- **Show real progress** with incremental updates, not just "done" at the end
- **Provide context** for what's happening and why (1-line explanations)
- **Celebrate successes** with visual flair in the summary dashboard

The developer should feel like they're watching a professional deployment pipeline in action, not waiting in silence.

---

## Execution Model

Four steps executed sequentially. Each step has a progress indicator:

- `◻` — pending
- `▸` — active (currently executing)
- `✓` — completed successfully
- `✗` — failed

**CRITICAL:** Output the progress indicator block at the START of each step and again AFTER each step completes. This creates a dynamic, engaging experience:

**Before Step 1:**
```text
  ▸ [1/4] 📦 Generate artifacts
  ◻ [2/4] 🔨 Build & push image
  ◻ [3/4] 🚀 Deploy to AKS
  ◻ [4/4] ✅ Verify & dashboard
```

**After Step 1 completes:**
```text
  ✓ [1/4] 📦 Generate artifacts     10 files written
  ▸ [2/4] 🔨 Build & push image
  ◻ [3/4] 🚀 Deploy to AKS
  ◻ [4/4] ✅ Verify & dashboard
```

**After Step 2 completes:**
```text
  ✓ [1/4] 📦 Generate artifacts     10 files written
  ✓ [2/4] 🔨 Build & push image     Image pushed to ACR
  ▸ [3/4] 🚀 Deploy to AKS
  ◻ [4/4] ✅ Verify & dashboard
```

And so on. Always show the full 4-line block with updated checkmarks

**Error recovery:** Each step can fail and retry independently. One retry per step. On second failure, stop with full diagnostics. Never restart from Step 1 on a later step failure.

### Permission Strategy (CRITICAL)

To provide a smooth, interruption-free experience, request command permissions upfront using glob patterns:

1. **File writes (Step 1)**: Batch all Write tool calls in a single agent turn
2. **Bash commands (Steps 2-4)**: Request glob permissions at the start of each step:
   - `git --version` → approves all `git *` commands
   - `az version` → approves all `az *` commands  
   - `kubectl version --client` → approves all `kubectl *` commands
   - `curl --version` → approves all `curl *` commands (if needed)

After these placeholder commands are approved, all subsequent commands with the same prefix execute without prompts. This reduces ~15 permission prompts to ~4.

---

## Step 1: Generate Artifacts

### File Generation Strategy

**CRITICAL:** All file writes in Step 1 must be batched. Present the list of files to generate, then write ALL files in parallel using multiple Write tool calls in a single agent response. This enables batch approval and eliminates repeated permission prompts.

### Dockerfile

**If existing Dockerfile detected:** Validate against the best-practices checklist:

| # | Practice | Safeguard |
|---|----------|-----------|
| 1 | Multi-stage build | — |
| 2 | Non-root `USER` | DS004 |
| 3 | Pinned base-image tags (no `:latest`) | DS009 |
| 4 | Layer caching — lockfile before source | — |
| 5 | `HEALTHCHECK` or documented omission | — |
| 6 | `.dockerignore` exists | — |

Apply targeted fixes for any failures. Do not replace the entire Dockerfile — fix specific items and explain each change.

**If no Dockerfile:** Generate from the appropriate template in `templates/dockerfiles/`:

| Framework / Language | Template |
|----------------------|----------|
| Node.js | `templates/dockerfiles/node.Dockerfile` |
| Python | `templates/dockerfiles/python.Dockerfile` |
| Java | `templates/dockerfiles/java.Dockerfile` |
| Go | `templates/dockerfiles/go.Dockerfile` |
| .NET | `templates/dockerfiles/dotnet.Dockerfile` |
| Rust | `templates/dockerfiles/rust.Dockerfile` |

Apply knowledge pack optimizations if a pack was loaded in Quick Phase 1.

### .dockerignore

Generate if missing. Universal entries:

```text
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

Add framework-specific entries:

| Framework | Additional entries |
|-----------|--------------------|
| **Node.js** | `node_modules`, `npm-debug.log*`, `coverage`, `.next`, `dist` |
| **Python** | `__pycache__`, `*.pyc`, `*.pyo`, `venv`, `.venv`, `.pytest_cache`, `*.egg-info` |
| **Java** | `target`, `.gradle`, `build`, `*.class`, `*.jar` |
| **Go** | `vendor`, `*.test`, `*.exe` |
| **.NET** | `bin`, `obj`, `*.user`, `*.suo`, `packages` |
| **Rust** | `target`, `*.pdb` |

### Kubernetes Manifests

Generate from `templates/k8s/` templates. Replace all `<angle-bracket>` placeholders with actual values from Quick Phase 1 scan data.

**IMPORTANT:** Announce ALL files to be generated first, then write them all in a single batch using parallel tool calls. This triggers a single batch approval dialog instead of prompting for each file individually.

**Generation order:**

1. `k8s/namespace.yaml` — from `templates/k8s/namespace.yaml`
2. `k8s/serviceaccount.yaml` — from `templates/k8s/serviceaccount.yaml` (with Workload Identity annotation using `identity_client_id`)
3. `k8s/deployment.yaml` — from `templates/k8s/deployment.yaml` (image set to `<acr_login_server>/<app-name>:<IMAGE_TAG>` — placeholder resolved in Step 2)
4. `k8s/service.yaml` — from `templates/k8s/service.yaml`
5. AKS Automatic: `k8s/gateway.yaml` from `templates/k8s/gateway.yaml` + `k8s/httproute.yaml` from `templates/k8s/httproute.yaml`
   AKS Standard: `k8s/ingress.yaml` from `templates/k8s/ingress.yaml`
6. `k8s/hpa.yaml` — from `templates/k8s/hpa.yaml` (min: 2, max: 10)
7. `k8s/pdb.yaml` — from `templates/k8s/pdb.yaml` (minAvailable: 1)
8. `k8s/configmap.yaml` — from `templates/k8s/configmap.yaml` (only if app needs environment-specific config)

### Safeguards Validation

Load `reference/safeguards.md`. Validate all generated manifests against DS001–DS013. Auto-fix all fixable violations (12 of 13 are auto-fixable). DS009 (no `:latest` tag) is resolved automatically since we tag with git SHA in Step 2.

**AKS flavor handling:**
- **AKS Automatic:** Safeguards are always enforced. Validation failures must be fixed before deployment.
- **AKS Standard:** Safeguards may be off, in Warning mode, or in Enforcement mode. Check the cluster's `safeguardsProfile.level`:
  ```bash
  az aks show -g <rg> -n <cluster> --query 'safeguardsProfile.level' -o tsv
  ```
  - If `Enforcement`: same as Automatic — fix all violations
  - If `Warning` or `Off`: validate manifests but don't block on violations. Mention any issues as warnings, not errors.

Do NOT present a full safeguards table — the quick mode user doesn't need it. If all rules pass (expected), mention it in one line. If any required manual fixes, list only those.

### Output

Present a compact file summary (not full file contents):

```text
  ✓ [1/4] 📦 Generate artifacts     <N> files

    Created:
    ├─ Dockerfile               <base-image> multi-stage
    ├─ .dockerignore             <N> patterns
    ├─ k8s/namespace.yaml
    ├─ k8s/deployment.yaml       DS001-DS013 validated
    ├─ k8s/service.yaml          ClusterIP :<port>
    ├─ k8s/serviceaccount.yaml   Workload Identity linked
    ├─ k8s/gateway.yaml          Istio gateway           ← or ingress.yaml
    ├─ k8s/httproute.yaml        / → <app>:<port>        ← only for Automatic
    ├─ k8s/hpa.yaml              2-10 replicas
    └─ k8s/pdb.yaml              minAvailable: 1
```

If existing Dockerfile was validated instead of generated, show "Dockerfile (validated, N fixes applied)" or "Dockerfile (validated, all checks pass)".

---

## Step 2: Build & Push Image

### Permission Strategy

Request permissions upfront for git and az commands:

```bash
# Request git permissions
git --version

# Request az permissions (if not already approved in Step 3 prep)
az version
```

### Get the image tag

```bash
IMAGE_TAG=$(git rev-parse --short HEAD)
```

If not in a git repo, use a timestamp: `IMAGE_TAG=$(date +%Y%m%d%H%M%S)`.

### Update deployment manifest

Replace the `<image>` placeholder in `k8s/deployment.yaml` with the full image reference:

```text
<acr_login_server>/<app-name>:$IMAGE_TAG
```

### Build and push

```text
🔨 Building and pushing container image to ACR...
```

```bash
az acr build --registry <acr_name> --image <app-name>:$IMAGE_TAG --file Dockerfile . >/dev/null 2>&1
```
- "Sending build context to ACR..."
- "Building layer 4/8..."
- "Pushing image... 60% complete"

This keeps the developer engaged during the 1-3 minute build process.

### On success

```text
  ✓ [2/4] 🔨 Build & push image     <acr>/<app>:<tag> (<size>)
```

### On failure

Read the build output and identify the error. Common failures:

| Error Pattern | Likely Cause | Fix |
|---|---|---|
| `COPY failed` | Wrong path in Dockerfile | Fix COPY source path |
| `npm ERR!` / `pip install failed` | Dependency installation error | Fix dependency spec |
| `permission denied` | Non-root user can't write | Add `chown` before `USER` switch |
| `unauthorized` | ACR auth issue | Run `az acr login --name <acr>` |

Apply the fix to the Dockerfile and retry once:

```bash
az acr build \
    --registry <acr_name> \
    --image <app-name>:$IMAGE_TAG \
    --file Dockerfile \
    .
```

If the retry also fails, stop:

```text
  ✗ [2/4] Build & push image     FAILED (2 attempts)

    Last error:
    <relevant error lines from build output>

    The Dockerfile needs manual fixes. Check the build output above.
```

---

## Step 3: Deploy to AKS

### Permission Strategy

**CRITICAL:** To avoid repeated bash permission prompts, request glob permissions upfront by running placeholder commands:

```bash
# Request kubectl permissions (will be approved once for all kubectl commands)
kubectl version --client

# Request az permissions (will be approved once for all az commands)
az version
```

After these are approved, all subsequent `kubectl` and `az` commands in Steps 3-4 will execute without additional prompts.

Four sub-commands executed sequentially:

### 3a. Ensure kubectl context

```bash
az aks get-credentials -g <resource_group> -n <aks_cluster_name> --overwrite-existing >/dev/null 2>&1
```

### 3b. Verify Gateway API CRDs (AKS Automatic only)

```bash
kubectl get crd gateways.gateway.networking.k8s.io httproutes.gateway.networking.k8s.io >/dev/null 2>&1
```

If missing, install Gateway API:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml >/dev/null 2>&1
```

### 3c. Apply manifests

```text
🚀 Deploying to AKS cluster...
```

**CRITICAL:** Namespace creation must succeed before proceeding. If it fails, STOP immediately - do NOT continue with other manifests.

```bash
kubectl apply -f k8s/namespace.yaml >/dev/null 2>&1
```

**Verify namespace exists:**

```bash
kubectl get namespace <namespace> -o name >/dev/null 2>&1
```

If this verification fails, STOP. Do NOT proceed to apply other manifests. The namespace check in Phase 1 should have caught permission issues, but if it didn't, this is a hard stop.

**After namespace is verified to exist:**

```bash
kubectl apply -f k8s/ --recursive >/dev/null 2>&1
```

### 3d. Wait for rollout

```bash
kubectl rollout status deployment/<app-name> -n <namespace> --timeout=300s
```

Show a clean message while waiting:
```text
⏳ Waiting for pods to start (up to 5 minutes)...
```

### On success

```text
  ✓ [3/4] 🚀 Deploy to AKS          2/2 pods running
```

### On failure

Diagnose the issue:

```bash
kubectl get pods -n <namespace>
kubectl describe pod <failing-pod> -n <namespace>
kubectl logs <failing-pod> -n <namespace>
```

**CRITICAL:** If these commands fail because the namespace doesn't exist, it means Step 3c's namespace creation was bypassed or failed silently. This is a critical error - resources may have been created in the default namespace. STOP and instruct the user to:

```bash
# Check if resources ended up in default namespace
kubectl get all -n default | grep <app-name>

# Clean up if found
kubectl delete all -l app=<app-name> -n default

# Fix namespace permissions and retry deployment from Step 3
```

Common diagnoses:

| Pod Status | Likely Cause | Fix |
|---|---|---|
| `CrashLoopBackOff` | Application error on startup | Check logs, fix app code or config |
| `ImagePullBackOff` | ACR authentication or image not found | Verify AcrPull role, check image tag |
| `Pending` | Resource constraints (no nodes) | Wait for node auto-provisioning, or reduce resource requests |
| `OOMKilled` | Memory limit too low | Increase memory limit in deployment.yaml |

Propose a fix, apply it, and retry **only the failed sub-step** (not the entire Step 3):

- If 3b failed: fix manifests, re-run `kubectl apply -f k8s/`
- If 3c failed (pods not starting): fix the issue, wait for rollout again

If retry also fails, stop with full diagnostics.

---

## Step 4: Verify & Dashboard

All verification is read-only. No confirmation gates needed. kubectl permissions were already approved in Step 3. If health check uses curl, request curl permission when needed.

### 4a. Pod Status

Run quietly and report the summary:
```bash
kubectl get pods -n <namespace> -l app=<app-name> -o json
```

Parse the JSON and show: `✅ 2/2 pods running` or identify issues.

### 4b. Service Status

Run quietly:
```bash
kubectl get svc -n <namespace> -o json
```

Report: `✅ Service exposed on port <port>`

### 4c. Endpoint Discovery

**AKS Automatic:**

```bash
IP=$(kubectl get gateway -n <namespace> -o jsonpath='{.items[0].status.addresses[0].value}' 2>/dev/null)
```

If the IP is pending, wait up to 3 minutes with a clean progress message:
```text
⏳ Waiting for external IP (load balancer provisioning)...
```

**AKS Standard:**

```bash
IP=$(kubectl get ingress -n <namespace> -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null)
```

Same waiting logic if pending.

### 4d. Health Check

If a health endpoint was detected or `/health` is the default:

```bash
curl -sf http://<external-ip><health-path> >/dev/null 2>&1
```

Report: `✅ Health check passed` or `⚠️ Health check failed (non-blocking)`

### 4e. Log Scan

```bash
kubectl logs deployment/<app-name> -n <namespace> --tail=20 2>/dev/null
```

Scan for `ERROR`, `FATAL`, `Exception`, `panic` patterns. Report any findings as warnings. Don't show all logs to the user.

### Summary Dashboard

First, show the final progress block with all steps completed:

```text
  ✓ [1/4] 📦 Generate artifacts     10 files written
  ✓ [2/4] 🔨 Build & push image     Image pushed to ACR
  ✓ [3/4] 🚀 Deploy to AKS           2/2 pods running
  ✓ [4/4] ✅ Verify & dashboard      All checks passed
```

Then render the celebration banner and summary dashboard:

```text
╭─────────────────────────────────────────────────────────╮
│                                                         │
│     🎉  Deployment Successful!  🎉                      │
│                                                         │
│     Your app is live at:                                │
│     🌐  http://<external-ip>                            │
│                                                         │
╰─────────────────────────────────────────────────────────╯

  ☸️  Kubernetes Resources
  ├─ Namespace:    <namespace>
  ├─ Deployment:   2/2 pods running
  ├─ Service:      ClusterIP on port <port>
  └─ Gateway/Ingress: http://<external-ip>

  ☁️  Azure Resources
  ├─ AKS Cluster:  <aks_cluster_name>
  ├─ ACR:          <acr_name>
  └─ Identity:     <identity_name>

  📄 Files Created
  ├─ Dockerfile
  ├─ .dockerignore
  └─ k8s/  (<N> manifests)

  🚀 Next Steps
  ├─ Configure custom domain & TLS
  ├─ Set up GitHub Actions CI/CD
  ├─ Enable monitoring & alerts
  └─ Clean up: az group delete -n <resource_group> --yes --no-wait
```

### Completion

After the dashboard, offer to commit the generated files:

> Want me to commit the generated files? I'll use:
> `git add Dockerfile .dockerignore k8s/ && git commit -m "feat: add AKS deployment artifacts"`

This is a lightweight offer, not a gate. If the user doesn't respond, move on.

---

## Progress Output Reference

The full progress display at each step boundary:

**After Step 1:**
```text
  ✓ [1/4] 📦 Generate artifacts     <N> files
  ▸ [2/4] 🔨 Build & push image     az acr build...
  ◻ [3/4] 🚀 Deploy to AKS
  ◻ [4/4] ✅ Verify & dashboard
```

**After Step 2:**
```text
  ✓ [1/4] 📦 Generate artifacts     <N> files
  ✓ [2/4] 🔨 Build & push image     <acr>/<app>:<tag>
  ▸ [3/4] 🚀 Deploy to AKS          kubectl apply...
  ◻ [4/4] ✅ Verify & dashboard
```

**After Step 3:**
```text
  ✓ [1/4] 📦 Generate artifacts     <N> files
  ✓ [2/4] 🔨 Build & push image     <acr>/<app>:<tag>
  ✓ [3/4] 🚀 Deploy to AKS          2/2 pods running
  ▸ [4/4] ✅ Verify & dashboard
```

**After Step 4 (final):**
```text
  ✓ [1/4] 📦 Generate artifacts     <N> files
  ✓ [2/4] 🔨 Build & push image     <acr>/<app>:<tag>
  ✓ [3/4] 🚀 Deploy to AKS          2/2 pods running
  ✓ [4/4] ✅ Verify & dashboard     all checks passed
```

---
