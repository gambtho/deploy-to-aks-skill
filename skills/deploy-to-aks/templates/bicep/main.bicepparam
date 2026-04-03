// =============================================================================
// Bicep Parameter File Template — AKS Deploy Skill
// =============================================================================
// Environment-specific values for the main.bicep orchestrator.
//
// REPLACE: <app-name>  — your application name (e.g., myapp)
// REPLACE: <location>  — Azure region (e.g., eastus2)
//
// Toggle backing services based on the Phase 2 architecture contract.
// =============================================================================

using './main.bicep'

param appName = '<app-name>'
param location = '<location>'
param aksType = 'Automatic'

// Backing services — set to true only for services in the architecture contract
param enablePostgresql = false
param enableRedis = false
param enableKeyvault = false

// Workload Identity — match the namespace and ServiceAccount from k8s/ manifests
param workloadNamespace = '<app-name>'
param workloadServiceAccount = '<app-name>-sa'
