# Phase 6: Deploy

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

For **AKS Automatic** (Gateway API):

```bash
kubectl get gateway
kubectl get httproute
# The external IP or hostname is on the Gateway resource
EXTERNAL_IP=$(kubectl get gateway myapp-gateway -o jsonpath='{.status.addresses[0].value}' 2>/dev/null)
```

For **AKS Standard** (Ingress):

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

Render a deployment summary in the terminal using the `templates/mermaid/summary-dashboard.md` template.

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
