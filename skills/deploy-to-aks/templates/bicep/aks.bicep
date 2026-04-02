// ============================================================================
// AKS Cluster Module
// ============================================================================
// Customize:
//   - aksType: 'Automatic' for node auto-provisioning, 'Standard' for user-managed pools
//   - vmSize / nodeCount: only used when aksType is 'Standard'
//   - kubernetesVersion: pin to a specific version if needed
//   - logAnalyticsWorkspaceId: supply an existing workspace or let the module create one
// ============================================================================

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Application name used as a prefix for the AKS cluster resource.')
param appName string

@description('Azure region for the AKS cluster.')
param location string

@description('AKS cluster type. "Automatic" uses node auto-provisioning; "Standard" uses user-managed node pools.')
@allowed([
  'Automatic'
  'Standard'
])
param aksType string = 'Automatic'

@description('Kubernetes version. Leave blank to use the latest stable version.')
param kubernetesVersion string = ''

@description('VM size for the default agent pool (Standard mode only).')
param vmSize string = 'Standard_D2s_v3'

@description('Number of nodes in the default agent pool (Standard mode only).')
param nodeCount int = 2

@description('Optional: existing Log Analytics workspace resource ID for Container Insights. When empty the module creates a new workspace.')
param logAnalyticsWorkspaceId string = ''

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------

var clusterName = '${appName}-aks'
var createWorkspace = empty(logAnalyticsWorkspaceId)
var workspaceId = createWorkspace ? logAnalytics.id : logAnalyticsWorkspaceId

// ---------------------------------------------------------------------------
// Log Analytics Workspace (created only when no external ID is provided)
// ---------------------------------------------------------------------------

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = if (createWorkspace) {
  name: '${appName}-law'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// ---------------------------------------------------------------------------
// AKS Cluster
// ---------------------------------------------------------------------------

resource aksCluster 'Microsoft.ContainerService/managedClusters@2025-03-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: aksType == 'Automatic' ? 'Automatic' : 'Base'
    tier: 'Standard'
  }
  properties: {
    // Kubernetes version — omit to let Azure pick the latest stable
    kubernetesVersion: empty(kubernetesVersion) ? null : kubernetesVersion
    dnsPrefix: '${appName}-dns'

    // --- Agent pool profiles (Standard mode only) ---
    agentPoolProfiles: aksType == 'Standard'
      ? [
          {
            name: 'system'
            count: nodeCount
            vmSize: vmSize
            mode: 'System'
            osType: 'Linux'
            osSKU: 'AzureLinux'
            type: 'VirtualMachineScaleSets'
          }
        ]
      : [
          {
            name: 'systempool'
            mode: 'System'
            count: 1 // NAP manages the actual scaling
            vmSize: 'Standard_DS4_v2'
          }
        ]

    // --- Network profile ---
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkDataplane: 'cilium'
    }

    // --- OIDC & Workload Identity ---
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }

    // --- Add-ons ---
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: workspaceId
        }
      }
      // NGINX ingress via web app routing (Standard mode only)
      ...(aksType == 'Standard'
        ? {
            ingressApplicationGateway: {
              enabled: false
            }
          }
        : {})
    }

    // Web app routing add-on for Standard clusters
    ingressProfile: aksType == 'Standard'
      ? {
          webAppRouting: {
            enabled: true
          }
        }
      : null

    // --- Node auto-provisioning for Automatic clusters ---
    nodeProvisioningProfile: aksType == 'Automatic'
      ? {
          mode: 'Auto'
        }
      : null
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('Name of the AKS cluster.')
output clusterName string = aksCluster.name

@description('OIDC issuer URL for federated identity credentials.')
output oidcIssuerUrl string = aksCluster.properties.oidcIssuerProfile.issuerURL

@description('Object ID of the kubelet managed identity (used for ACR pull role assignment).')
output kubeletIdentityObjectId string = aksCluster.properties.identityProfile.kubeletidentity.objectId

@description('Resource ID of the AKS cluster.')
output aksResourceId string = aksCluster.id
