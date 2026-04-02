// ============================================================================
// Azure Container Registry Module
// ============================================================================
// Customize:
//   - acrSku: upgrade to 'Premium' if you need geo-replication or private endpoints
//   - kubeletIdentityObjectId: the AKS kubelet identity that needs AcrPull access
// ============================================================================

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Application name used as a prefix for the ACR resource.')
param appName string

@description('Azure region for the Container Registry.')
param location string

@description('SKU tier for the Container Registry.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acrSku string = 'Standard'

@description('Object ID of the AKS kubelet managed identity to grant AcrPull access.')
param kubeletIdentityObjectId string

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------

// ACR names must be globally unique, alphanumeric only, 5-50 chars.
var acrName = replace('${appName}acr', '-', '')

// Built-in role: AcrPull
var acrPullRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '7f951dda-4ed3-4680-a7ca-43fe172d538d'
)

// ---------------------------------------------------------------------------
// Container Registry
// ---------------------------------------------------------------------------

resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: false
  }
}

// ---------------------------------------------------------------------------
// Role Assignment – AcrPull for AKS kubelet identity
// ---------------------------------------------------------------------------

resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, kubeletIdentityObjectId, acrPullRoleDefinitionId)
  scope: acr
  properties: {
    principalId: kubeletIdentityObjectId
    roleDefinitionId: acrPullRoleDefinitionId
    principalType: 'ServicePrincipal'
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('Login server URL for the Container Registry (e.g., myacr.azurecr.io).')
output acrLoginServer string = acr.properties.loginServer

@description('Name of the Container Registry resource.')
output acrName string = acr.name

@description('Resource ID of the Container Registry.')
output acrResourceId string = acr.id
