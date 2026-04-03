# AKS Automatic Reference

> **Last updated:** 2026-04-02

## What is AKS Automatic

AKS Automatic is a fully managed Kubernetes experience where Azure handles node provisioning, scaling, OS patching, and Kubernetes upgrades for you. You deploy workloads and Azure figures out the right VM sizes, node counts, and infrastructure configuration. Think of it as "serverless-ish Kubernetes" — you still write K8s manifests, but you skip all the infrastructure knobs.

## Key Properties

| Property | Value |
|----------|-------|
| SKU name | `Automatic` |
| SKU tier | `Standard` |
| API version | `2025-03-01` |

## Gateway API (NOT Ingress)

AKS Automatic uses the **Kubernetes Gateway API** for traffic routing, NOT the traditional `Ingress` resource. The Gateway API is built in via an Istio-based service mesh that ships with the cluster.

### How Gateway API differs from Ingress

- `Ingress` is a single resource that combines listener config and routing rules. Gateway API splits these into separate resources: `Gateway` (ports, TLS, listeners) and `HTTPRoute` (path matching, backend refs).
- Gateway API supports more advanced traffic patterns (header-based routing, traffic splitting, cross-namespace references) without annotations or custom CRDs.
- The `gatewayClassName` for AKS Automatic is `istio`.

### Gateway and HTTPRoute YAML

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
- Do NOT create `Ingress` resources — AKS Automatic does not use an ingress controller in the traditional sense.

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

The identity chain flows: **Managed Identity → Federated Credential → Kubernetes ServiceAccount → Pod**. ACR pull access is granted by assigning the `AcrPull` role to the cluster's kubelet identity (see `templates/bicep/acr.bicep` for the role assignment template).

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
- **Ingress controller installation:** Gateway API via Istio is built in.

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
- No ingress addon configuration — Gateway API via Istio is included automatically.
- `nodeResourceGroupProfile.restrictionLevel: 'ReadOnly'` prevents manual modification of the managed node resource group.

## Limitations

- **No custom node pools.** You cannot create user node pools or pin workloads to specific VM SKUs.
- **No Windows containers.** As of 2025, AKS Automatic only supports Linux node pools.
- **Limited addon flexibility.** You cannot install arbitrary addons that require node-level configuration (e.g., custom CSI drivers, specific CNI plugins).
- **No GPU nodes.** NAP does not currently auto-provision GPU-equipped VMs in Automatic SKU.
- **No Ingress resource support.** You must use Gateway API (`Gateway` + `HTTPRoute`). Traditional `Ingress` resources are ignored.
- **Deployment Safeguards cannot be disabled.** If your existing manifests are non-compliant, you must fix them before deploying.
