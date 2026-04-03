// ============================================================================
// Main Orchestrator - Deploy to AKS
// ============================================================================
// Customize:
//   - appName: unique prefix for all resources
//   - aksType: 'Automatic' (node auto-provisioning) or 'Standard' (user-managed pools)
//   - enablePostgresql / enableRedis / enableKeyvault: toggle optional backing services
//   - workloadNamespace / workloadServiceAccount: K8s identifiers for federated credentials
// ============================================================================

targetScope = 'resourceGroup'

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Application name used as a prefix for all deployed resources.')
param appName string

@description('Azure region for all resources. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('AKS cluster type. "Automatic" uses node auto-provisioning; "Standard" uses user-managed node pools.')
@allowed([
  'Automatic'
  'Standard'
])
param aksType string = 'Automatic'

@description('Enable an Azure Database for PostgreSQL Flexible Server.')
param enablePostgresql bool = false

@description('Enable an Azure Cache for Redis instance.')
param enableRedis bool = false

@description('Enable an Azure Key Vault instance.')
param enableKeyvault bool = false

@description('Kubernetes namespace for the workload identity federated credential.')
param workloadNamespace string = 'default'

@description('Kubernetes ServiceAccount name for the workload identity federated credential.')
param workloadServiceAccount string = '${appName}-sa'

@description('PostgreSQL administrator login name (used only when enablePostgresql is true).')
param postgresAdminLogin string = '${appName}admin'

// ---------------------------------------------------------------------------
// Modules – always deployed
// ---------------------------------------------------------------------------

module aks 'aks.bicep' = {
  name: '${appName}-aks'
  params: {
    appName: appName
    location: location
    aksType: aksType
  }
}

module acr 'acr.bicep' = {
  name: '${appName}-acr'
  params: {
    appName: appName
    location: location
    kubeletIdentityObjectId: aks.outputs.kubeletIdentityObjectId
  }
}

module identity 'identity.bicep' = {
  name: '${appName}-identity'
  params: {
    appName: appName
    location: location
    oidcIssuerUrl: aks.outputs.oidcIssuerUrl
    namespace: workloadNamespace
    serviceAccountName: workloadServiceAccount
  }
}

// ---------------------------------------------------------------------------
// Modules – conditionally deployed
// ---------------------------------------------------------------------------

module postgresql 'postgresql.bicep' = if (enablePostgresql) {
  name: '${appName}-postgresql'
  params: {
    appName: appName
    location: location
    administratorLogin: postgresAdminLogin
    administratorPrincipalId: identity.outputs.identityPrincipalId
    administratorPrincipalName: identity.outputs.identityName
  }
}

module redis 'redis.bicep' = if (enableRedis) {
  name: '${appName}-redis'
  params: {
    appName: appName
    location: location
  }
}

module keyvault 'keyvault.bicep' = if (enableKeyvault) {
  name: '${appName}-keyvault'
  params: {
    appName: appName
    location: location
    identityPrincipalId: identity.outputs.identityPrincipalId
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('Name of the deployed AKS cluster.')
output aksClusterName string = aks.outputs.clusterName

@description('Login server URL for the Azure Container Registry.')
output acrLoginServer string = acr.outputs.acrLoginServer

@description('Name of the resource group containing all resources.')
output resourceGroupName string = resourceGroup().name

@description('OIDC issuer URL of the AKS cluster (used for workload identity federation).')
output aksOidcIssuerUrl string = aks.outputs.oidcIssuerUrl

@description('Client ID of the workload managed identity.')
output workloadIdentityClientId string = identity.outputs.identityClientId

@description('Name of the Azure Container Registry.')
output acrName string = acr.outputs.acrName

@description('Name of the AKS cluster (alias for aksClusterName, used by deploy scripts).')
output aksName string = aks.outputs.clusterName
