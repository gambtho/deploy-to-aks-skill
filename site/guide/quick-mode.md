# Quick Deploy Mode

If you already have an AKS cluster running, quick deploy mode gets you from "I have code" to "it's deployed" in ~5-7 minutes.

## When to Use Quick Mode

✅ **Use quick mode if:**
- You already have an AKS cluster (Automatic or Standard)
- You just want to containerize and deploy your app
- You're iterating on an existing deployment

❌ **Use full mode (6 phases) if:**
- You're starting from scratch (no AKS cluster yet)
- You need backing services (databases, caches, Key Vault)
- You want CI/CD pipeline setup
- You need infrastructure-as-code (Bicep)

## What Quick Mode Does

Quick mode runs as a single phase with 5 sections:

1. **Detection** — scans your project, detects framework and port, auto-discovers your AKS cluster and ACR, loads framework-specific knowledge
2. **File Generation** — generates Dockerfile, .dockerignore, and K8s manifests (namespace, deployment, service, gateway/ingress, HPA, PDB, service account)
3. **Safeguards Validation** — validates all manifests against AKS Deployment Safeguards (DS001-DS013) before deploying
4. **Deploy** — creates namespace, builds and pushes image via ACR, applies manifests, waits for rollout
5. **Verify** — waits for external IP, confirms health endpoint responds

## What Quick Mode Skips

Compared to full 6-phase mode:

- ❌ No architecture design or cost estimates
- ❌ No Bicep infrastructure provisioning
- ❌ No CI/CD pipeline setup
- ❌ No backing service creation (assumes you have them or don't need them)

## Prerequisites

Before using quick mode, you need:

- An existing AKS cluster (Automatic or Standard)
- An existing ACR (Azure Container Registry)
- kubectl configured to access your cluster
- Azure CLI logged in with push access to ACR

**Don't have these?** Use the setup script:

```bash
curl -fsSL https://raw.githubusercontent.com/gambtho/deploy-to-aks-skill/main/scripts/setup-aks-prerequisites.sh | bash
```

This provisions an AKS Automatic cluster, ACR, and configures access.

## How to Use Quick Mode

From your project directory, ask your AI agent:

```text
I have an existing AKS cluster - help me containerize and deploy this app quickly
```

The skill detects your context and routes to quick mode automatically.

## Example Timeline

| Time | Activity |
|------|----------|
| 0:00 | Skill scans project, detects framework and Azure infrastructure |
| 0:30 | Generates Dockerfile, K8s manifests, validates safeguards |
| 1:30 | Builds Docker image via `az acr build` |
| 3:00 | Deploys to AKS namespace |
| 4:00 | Waits for rollout complete |
| 5:00 | Verifies health checks pass, shows endpoint URL |
| 5:30 | ✅ Deployed and running |

## What You Get

Same production-ready artifacts as full mode:

- Multi-stage Dockerfile (non-root, optimized)
- Kubernetes manifests (passing all 13 Deployment Safeguards)
- HPA with scale-down stabilization and PodDisruptionBudget
- Gateway API (AKS Automatic) or Ingress (AKS Standard) routing
- Workload Identity integration
- Deployment verification and health checks

You just skip the infrastructure provisioning and CI/CD setup.

## Next Steps After Quick Deploy

Once deployed via quick mode, you can:

1. **Add CI/CD:** Run full mode Phase 5 separately to generate GitHub Actions workflow
2. **Add backing services:** Provision manually or run Bicep modules from examples
3. **Iterate:** Quick mode is fast for testing changes before setting up full automation

## Quick Mode vs Full Mode Comparison

| Feature | Quick Mode | Full Mode (6 Phases) |
|---------|-----------|---------------------|
| **Time** | ~5-7 min | ~30-40 min |
| **Prerequisites** | Existing AKS + ACR | Just Azure subscription |
| **Generates** | | |
| Dockerfile | ✅ | ✅ |
| K8s manifests | ✅ | ✅ |
| Bicep infrastructure | ❌ | ✅ |
| GitHub Actions | ❌ | ✅ |
| **Provisions** | | |
| AKS cluster | ❌ (uses existing) | ✅ |
| ACR | ❌ (uses existing) | ✅ |
| Backing services | ❌ | ✅ |
| **Interaction** | | |
| Clarifying questions | 0-1 (only if ambiguous) | Per-phase approval |
| Azure resource creation | N/A | Yes |

## Learn More

- [Full 6-phase workflow](/guide/phases)
- [Setup script for test infrastructure](https://github.com/gambtho/deploy-to-aks-skill/blob/main/scripts/setup-aks-prerequisites.sh)
- [AKS Deployment Safeguards](https://learn.microsoft.com/en-us/azure/aks/deployment-safeguards)
