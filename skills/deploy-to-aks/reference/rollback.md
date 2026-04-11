# Rollback Guidance

Recovery procedures for deployment failures. Referenced from Phase 6 (Deploy).

---

## Bicep Deployment Failed (Step 4)

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

## Image Build Failed (Step 5)

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

## kubectl apply Failed (Step 6b)

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

## Pods Not Starting (Step 6c / Step 7)

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

## Nuclear Option: Tear Everything Down

If the developer wants to start over completely:

```bash
# This deletes ALL resources in the resource group — irreversible.
az group delete --name rg-myapp-dev --yes --no-wait
```

This is itself a destructive command. If the developer asks to tear down, use a confirmation gate for it.
