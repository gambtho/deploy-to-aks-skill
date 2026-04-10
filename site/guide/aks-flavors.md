# AKS Automatic vs Standard

The skill supports both AKS Automatic and AKS Standard. Each has different management models, feature sets, and when to choose which.

## Quick Comparison

| Feature | AKS Automatic | AKS Standard |
|---------|--------------|--------------|
| **Node management** | Fully managed | You manage node pools |
| **Ingress** | Gateway API (built-in) | You install (nginx, etc.) |
| **Deployment Safeguards** | Enforced by default | Optional |
| **Networking** | Simplified (auto-configured) | Full control |
| **Monitoring** | Pre-configured | You configure |
| **Cost** | Slightly higher (managed) | Lower (you optimize) |
| **Best for** | Fast iteration, less ops | Full control, custom needs |

## AKS Automatic

**What it is:**
- Fully managed Kubernetes with opinionated defaults
- Microsoft handles node management, upgrades, security patches
- Gateway API for ingress (no need to install nginx/traefik)
- Deployment Safeguards enforced (can't deploy non-compliant manifests)

**When to choose:**
- You want to focus on app code, not cluster ops
- You're new to Kubernetes
- You prefer opinionated, secure defaults
- You value fast iteration over full control

**What the skill generates:**
- Gateway API resources (Gateway + HTTPRoute) instead of Ingress
- Manifests that comply with Deployment Safeguards
- Bicep with `sku: 'Automatic'` and safeguards enabled

**Example Gateway API manifest:**

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-app-gateway
spec:
  gatewayClassName: azure-alb
  listeners:
  - name: http
    protocol: HTTP
    port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app-route
spec:
  parentRefs:
  - name: my-app-gateway
  rules:
  - backendRefs:
    - name: my-app-service
      port: 80
```

## AKS Standard

**What it is:**
- Traditional AKS with full control over configuration
- You manage node pools, scaling, upgrades
- You choose and install ingress controller
- Deployment Safeguards are optional (can enable via policy)

**When to choose:**
- You need custom node pool configurations
- You have specific ingress controller requirements
- You want to optimize costs by tuning node sizes
- You have existing AKS Standard clusters

**What the skill generates:**
- Ingress resources (nginx by default, configurable)
- Manifests that pass Safeguards validation (but not enforced)
- Bicep with `sku: 'Standard'` and manual node pool config

**Example Ingress manifest:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app-service
            port:
              number: 80
```

## How the Skill Adapts

During Phase 2 (Architect), the skill asks:

> "Choose AKS flavor: (A) Automatic (recommended) or (S) Standard?"

Based on your choice, it generates appropriate manifests and Bicep.

**Automatic mode:**
- Uses Gateway API
- Enforces Deployment Safeguards
- Simpler Bicep (fewer config options)

**Standard mode:**
- Uses Ingress
- Validates against Safeguards (warns if non-compliant, but doesn't block)
- Full Bicep with node pool, networking config

## Migration Between Flavors

Can you switch later?

**Automatic → Standard:** No direct migration path. You'd recreate the cluster.

**Standard → Automatic:** Also requires new cluster, but you can reuse manifests (swap Ingress for Gateway API).

The skill's generated manifests are portable - Dockerfiles and most K8s resources work on both flavors.

## Deployment Safeguards

Both flavors benefit from Safeguard validation, but enforcement differs:

- **Automatic:** Safeguards enforced by Azure. Non-compliant manifests are rejected at deploy time.
- **Standard:** Safeguards are optional. The skill validates and warns, but Azure doesn't block deployment.

[Learn more about Deployment Safeguards →](https://learn.microsoft.com/en-us/azure/aks/deployment-safeguards)

## Choosing Your Flavor

**Pick AKS Automatic if:**
- ✅ You want opinionated, secure defaults
- ✅ You prefer managed node pools
- ✅ You like Gateway API (Kubernetes standard, future-proof)
- ✅ You value fast iteration over manual optimization

**Pick AKS Standard if:**
- ✅ You need custom node pool configurations
- ✅ You have existing ingress controller preferences
- ✅ You want to optimize costs by tuning resources
- ✅ You have advanced networking requirements

**Not sure?** Start with Automatic. It's faster to get running and you can always recreate as Standard later if you need more control.

## Learn More

- [6-phase deployment workflow](/guide/phases)
- [AKS Automatic documentation](https://learn.microsoft.com/en-us/azure/aks/intro-aks-automatic)
- [Gateway API vs Ingress](https://gateway-api.sigs.k8s.io/)
