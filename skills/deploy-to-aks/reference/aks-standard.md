# AKS Standard Reference

## What is AKS Standard

AKS Standard is the traditional managed Kubernetes offering on Azure where you retain full control over node pools, VM sizes, networking, ingress, and upgrade scheduling. Compared to AKS Automatic, you get more flexibility and configuration options, but you also take on more responsibility — you choose the VM SKUs, configure autoscaling, pick your ingress controller, schedule maintenance windows, and manage OS patch cadence. If Automatic is "Azure decides," Standard is "you decide, Azure runs it."

## Key Differences from Automatic

| Aspect | Automatic | Standard |
|--------|-----------|----------|
| Node pools | Fully managed by NAP, no user pools | User-defined system + user pools with explicit VM SKU |
| Ingress | Gateway API via built-in Istio | NGINX (web app routing addon) or BYO controller via `Ingress` |
| VM SKU selection | Azure picks automatically | You specify per node pool |
| K8s upgrades | Automatic | Manual or scheduled maintenance windows |
| OS patching | Automatic | Node image upgrades (manual, scheduled, or unattended) |
| Deployment Safeguards | Enforced, not optional | Optional, recommended |
| Network config | Fully managed (CNI Overlay + Cilium) | You choose: CNI Overlay, CNI + VNet, Kubenet |
| Windows containers | Not supported | Supported via Windows node pools |
| GPU workloads | Not supported | Supported via GPU VM SKUs |

## Node Pools

### System Pool (required)

Every AKS Standard cluster needs at least one system pool. System pools run core AKS components (CoreDNS, metrics-server, etc.). System pods have `CriticalAddonsOnly` toleration.

- Minimum 2 nodes recommended for production (availability during upgrades).
- Use a general-purpose VM SKU: `Standard_D2s_v3` (2 vCPU, 8 GiB) for small clusters, `Standard_D4s_v3` (4 vCPU, 16 GiB) for medium.

### User Pools (optional, recommended)

Run application workloads on dedicated user pools to isolate them from system components.

- You can create multiple user pools with different VM SKUs for different workload types.
- Use taints and tolerations or node selectors to schedule specific workloads on specific pools.

### VM SKU Recommendations

| Workload | Recommended SKU | vCPU | Memory |
|----------|----------------|------|--------|
| Small / dev-test | `Standard_D2s_v3` | 2 | 8 GiB |
| Medium / production | `Standard_D4s_v3` | 4 | 16 GiB |
| Memory-intensive | `Standard_E4s_v3` | 4 | 32 GiB |
| GPU (ML/AI) | `Standard_NC6s_v3` | 6 | 112 GiB + 1 V100 |
| Windows workloads | `Standard_D4s_v3` | 4 | 16 GiB |

### Node Pool Bicep Configuration

```bicep
agentPoolProfiles: [
  {
    name: 'system'
    mode: 'System'
    vmSize: 'Standard_D2s_v3'
    count: 2
    minCount: 2
    maxCount: 4
    enableAutoScaling: true
    osType: 'Linux'
    osSKU: 'AzureLinux'
    availabilityZones: ['1', '2', '3']
  }
  {
    name: 'apps'
    mode: 'User'
    vmSize: 'Standard_D4s_v3'
    count: 2
    minCount: 1
    maxCount: 10
    enableAutoScaling: true
    osType: 'Linux'
    osSKU: 'AzureLinux'
    availabilityZones: ['1', '2', '3']
    nodeTaints: [] // Add taints if you want workload isolation
    nodeLabels: {
      workload: 'app'
    }
  }
]
```

## Ingress

### Recommended: Web Application Routing Addon (NGINX-based)

The simplest path for ingress on AKS Standard is the **web application routing addon**. It deploys a managed NGINX ingress controller.

Enable it in Bicep:

```bicep
ingressProfile: {
  webAppRouting: {
    enabled: true
    dnsZoneResourceIds: [
      dnsZone.id // Optional: for automatic DNS record management
    ]
  }
}
```

### Ingress Resource YAML

Use the standard `Ingress` resource (NOT `Gateway` / `HTTPRoute` — those are for AKS Automatic with Istio):

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  namespace: app-namespace
  annotations:
    # Use the web app routing ingress class
    spec.ingressClassName: webapprouting.kubernetes.azure.com
    # Optional: enable TLS via Key Vault integration
    # kubernetes.azure.com/tls-cert-keyvault-uri: "https://myvault.vault.azure.net/certificates/my-cert"
spec:
  ingressClassName: webapprouting.kubernetes.azure.com
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 8080
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend-service
                port:
                  number: 3000
  tls:
    - hosts:
        - myapp.example.com
      secretName: app-tls-secret
```

### BYO Ingress Controller

If you need more control, install your own ingress controller (e.g., NGINX community, Traefik, HAProxy) via Helm. In that case, do NOT enable the `webAppRouting` addon — use your controller's `ingressClassName` instead.

## Networking

### Recommended: Azure CNI Overlay

Azure CNI Overlay gives pods their own IP addresses from a private CIDR that overlays the VNet. This is simpler than traditional CNI (which consumes VNet IPs for every pod) and avoids IP exhaustion.

```bicep
networkProfile: {
  networkPlugin: 'azure'
  networkPluginMode: 'overlay'
  networkPolicy: 'azure' // Azure NPM; or use 'calico' for Calico
  podCidr: '10.244.0.0/16'
  serviceCidr: '10.0.0.0/16'
  dnsServiceIP: '10.0.0.10'
}
```

### Network Policy Options

| Policy Engine | Best For |
|--------------|----------|
| `azure` (Azure NPM) | Simple L3/L4 policies, native Azure integration |
| `calico` | Advanced policies, L7 rules, global network sets |

Choose one at cluster creation — it cannot be changed later.

## Deployment Safeguards

Deployment Safeguards are **optional** on AKS Standard but **strongly recommended**, especially for production clusters.

### Modes

- **Warning:** Violations are logged in Azure Policy / audit logs but deployments are allowed. Good for rolling out compliance incrementally.
- **Enforcement:** Non-compliant manifests are rejected by the admission controller. Same behavior as AKS Automatic.
- **Off:** No safeguards applied (default for Standard).

### Bicep Configuration

```bicep
properties: {
  safeguardsProfile: {
    level: 'Warning' // or 'Enforcement' or 'Off'
    excludedNamespaces: [
      'kube-system'
      'gatekeeper-system'
    ]
  }
}
```

**See `safeguards.md` for the full list of rules and how to write compliant manifests.** Even if you start with Warning mode, write manifests that pass Enforcement — it makes future tightening painless.

## Workload Identity

Workload Identity setup is the **same** as AKS Automatic: Managed Identity -> Federated Credential -> ServiceAccount -> Pod. The difference is that it's recommended but not enforced — you could use connection strings or secrets, but you shouldn't.

### Enable in Bicep

```bicep
oidcIssuerProfile: {
  enabled: true
}
securityProfile: {
  workloadIdentity: {
    enabled: true
  }
}
```

### ACR Access

Same as Automatic — assign `AcrPull` on the ACR to the cluster's kubelet identity:

```bicep
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, cluster.id, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: cluster.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}
```

**See `workload-identity.md` for full Bicep and Kubernetes manifest examples.**

## Scaling

### Cluster Autoscaler (node-level)

Configured per node pool in `agentPoolProfiles`:

```bicep
{
  name: 'apps'
  mode: 'User'
  vmSize: 'Standard_D4s_v3'
  enableAutoScaling: true
  minCount: 1    // Scale down to 1 node during low usage
  maxCount: 10   // Scale up to 10 nodes under load
  count: 2       // Initial node count
}
```

The autoscaler adds nodes when pods are pending due to insufficient resources and removes nodes when utilization is low.

### Horizontal Pod Autoscaler (pod-level)

Scale pods based on CPU, memory, or custom metrics:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa
  namespace: app-namespace
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-deployment
  minReplicas: 2
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

### Manual Scaling

If autoscaling is disabled, set `count` in the node pool and scale with:

```sh
az aks nodepool scale --resource-group <rg> --cluster-name <cluster> --name apps --node-count 5
```

## Bicep Configuration — Full Cluster

```bicep
resource cluster 'Microsoft.ContainerService/managedClusters@2025-03-01' = {
  name: clusterName
  location: location
  sku: {
    name: 'Base'
    tier: 'Standard' // or 'Free' for dev/test (no SLA), 'Premium' for advanced features
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: clusterName

    nodeResourceGroup: '${clusterName}-nodes'

    agentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        vmSize: 'Standard_D2s_v3'
        count: 2
        minCount: 2
        maxCount: 4
        enableAutoScaling: true
        osType: 'Linux'
        osSKU: 'AzureLinux'
        availabilityZones: ['1', '2', '3']
      }
      {
        name: 'apps'
        mode: 'User'
        vmSize: 'Standard_D4s_v3'
        count: 2
        minCount: 1
        maxCount: 10
        enableAutoScaling: true
        osType: 'Linux'
        osSKU: 'AzureLinux'
        availabilityZones: ['1', '2', '3']
      }
    ]

    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkPolicy: 'azure'
      podCidr: '10.244.0.0/16'
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
    }

    oidcIssuerProfile: {
      enabled: true
    }

    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }

    safeguardsProfile: {
      level: 'Warning'
      excludedNamespaces: [
        'kube-system'
        'gatekeeper-system'
      ]
    }

    ingressProfile: {
      webAppRouting: {
        enabled: true
      }
    }

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

### Contrast with Automatic Bicep

| Property | Standard | Automatic |
|----------|----------|-----------|
| `sku.name` | `'Base'` | `'Automatic'` |
| `agentPoolProfiles` | Explicit system + user pools with `vmSize` | Single system pool, no `vmSize`, NAP handles the rest |
| `networkProfile` | Required — you configure CNI, policy, CIDRs | Not needed — fully managed |
| `ingressProfile.webAppRouting` | Enabled for NGINX ingress | Not used — Gateway API via Istio is built in |
| `safeguardsProfile` | Optional, defaults to `Off` | Always active, cannot be disabled |
| `nodeResourceGroupProfile` | Optional | `restrictionLevel: 'ReadOnly'` enforced |

## When to Choose Standard

Choose AKS Standard over Automatic when you need:

- **Windows containers** — Automatic does not support Windows node pools.
- **Specific VM SKUs** — You need to pin workloads to exact VM families (e.g., memory-optimized E-series, compute-optimized F-series).
- **GPU nodes** — ML/AI workloads requiring NC, ND, or NV-series VMs.
- **Custom networking** — Specific VNet integration, custom route tables, or advanced network policy requirements (Calico).
- **Full control over upgrades** — You want to test K8s upgrades in staging before production, or maintain version pinning.
- **Full control over patching** — Scheduled node image upgrades during specific maintenance windows.
- **BYO ingress controller** — You need Traefik, HAProxy, or a specific NGINX configuration that the web app routing addon doesn't support.
- **Custom addons / extensions** — CSI drivers, service meshes, or policy engines that require node-level access.
- **Compliance requirements** — Regulations that mandate specific node configurations, disk encryption with customer-managed keys, or dedicated hosts.

If none of the above apply, AKS Automatic is simpler and reduces operational burden.
