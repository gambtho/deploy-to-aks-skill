// ============================================================================
// Azure Key Vault Module
// ============================================================================
// Customize:
//   - skuName: 'standard' or 'premium' (premium supports HSM-backed keys)
//   - identityPrincipalId: the managed identity that needs Key Vault Secrets User access
//   - softDeleteRetentionInDays: 7-90 days (default 90)
//   - enablePurgeProtection: set to true for production to prevent accidental purge
// ============================================================================

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Application name used as a prefix for the Key Vault resource.')
param appName string

@description('Azure region for the Key Vault.')
param location string

@description('SKU tier for the Key Vault.')
@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'

@description('Principal (object) ID of the managed identity to grant Key Vault Secrets User access.')
param identityPrincipalId string

@description('Number of days to retain soft-deleted vaults and secrets (7-90).')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90

@description('Enable purge protection to prevent permanent deletion during the retention period.')
param enablePurgeProtection bool = false

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------

// Key Vault names must be globally unique, 3-24 alphanumeric + hyphens.
var vaultName = '${appName}-kv'

// Built-in role: Key Vault Secrets User
var kvSecretsUserRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4633458b-17de-408a-b874-0445c86b69e6'
)

// ---------------------------------------------------------------------------
// Key Vault
// ---------------------------------------------------------------------------

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: vaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: skuName
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: enablePurgeProtection ? true : null
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// ---------------------------------------------------------------------------
// Role Assignment – Key Vault Secrets User for Workload Identity
// ---------------------------------------------------------------------------

resource kvSecretsUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, identityPrincipalId, kvSecretsUserRoleDefinitionId)
  scope: keyVault
  properties: {
    principalId: identityPrincipalId
    roleDefinitionId: kvSecretsUserRoleDefinitionId
    principalType: 'ServicePrincipal'
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('URI of the Key Vault (e.g., https://myapp-kv.vault.azure.net/).')
output vaultUri string = keyVault.properties.vaultUri

@description('Name of the Key Vault resource.')
output vaultName string = keyVault.name

@description('Resource ID of the Key Vault.')
output vaultResourceId string = keyVault.id
