// ============================================================================
// Managed Identity Module – Workload Identity for AKS
// ============================================================================
// Customize:
//   - namespace / serviceAccountName: must match the K8s ServiceAccount your
//     workload uses so the federated credential trust chain is valid
//   - oidcIssuerUrl: the OIDC issuer URL from the AKS cluster
// ============================================================================

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Application name used as a prefix for the identity resources.')
param appName string

@description('Azure region for the managed identity.')
param location string

@description('OIDC issuer URL of the AKS cluster (from aks.bicep outputs).')
param oidcIssuerUrl string

@description('Kubernetes namespace where the workload ServiceAccount lives.')
param namespace string = 'default'

@description('Name of the Kubernetes ServiceAccount bound to this identity.')
param serviceAccountName string = '${appName}-sa'

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------

var identityName = '${appName}-workload-id'

// ---------------------------------------------------------------------------
// User-Assigned Managed Identity
// ---------------------------------------------------------------------------

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

// ---------------------------------------------------------------------------
// Federated Identity Credential
// Links the K8s ServiceAccount to the Azure Managed Identity via OIDC.
// ---------------------------------------------------------------------------

resource federatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  name: '${appName}-federated-cred'
  parent: managedIdentity
  properties: {
    issuer: oidcIssuerUrl
    subject: 'system:serviceaccount:${namespace}:${serviceAccountName}'
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('Client ID of the managed identity (set as azure.workload.identity/client-id annotation on the K8s ServiceAccount).')
output identityClientId string = managedIdentity.properties.clientId

@description('Principal (object) ID of the managed identity (used for Azure role assignments).')
output identityPrincipalId string = managedIdentity.properties.principalId

@description('Display name of the managed identity (used as the PostgreSQL AAD admin principal name).')
output identityName string = managedIdentity.name

@description('Full resource ID of the managed identity.')
output identityResourceId string = managedIdentity.id
