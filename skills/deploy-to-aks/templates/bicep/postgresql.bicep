// ============================================================================
// Azure Database for PostgreSQL Flexible Server Module
// ============================================================================
// Customize:
//   - skuName / skuTier: scale up for production workloads
//   - storageSizeGB: increase for larger datasets
//   - postgresVersion: pin to a specific major version
//   - databaseName: change to match your application schema
//   - administratorLogin: local admin credential (used alongside Entra ID auth)
// ============================================================================

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Application name used as a prefix for the PostgreSQL server.')
param appName string

@description('Azure region for the PostgreSQL Flexible Server.')
param location string

@description('SKU name for the PostgreSQL server.')
param skuName string = 'Standard_B1ms'

@description('SKU tier for the PostgreSQL server.')
@allowed([
  'Burstable'
  'GeneralPurpose'
  'MemoryOptimized'
])
param skuTier string = 'Burstable'

@description('Storage size in GB.')
param storageSizeGB int = 32

@description('PostgreSQL major version.')
@allowed([
  '14'
  '15'
  '16'
  '17'
])
param postgresVersion string = '16'

@description('Local administrator login name.')
param administratorLogin string

@description('Local administrator password. Must be at least 8 characters.')
@secure()
param administratorLoginPassword string = newGuid()

@description('Principal (object) ID of the managed identity to set as Azure AD administrator.')
param administratorPrincipalId string

@description('Principal name (client ID) of the managed identity to set as Azure AD administrator.')
param administratorPrincipalName string

@description('Name of the default database to create.')
param databaseName string = '${appName}db'

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------

var serverName = '${appName}-pg'

// ---------------------------------------------------------------------------
// PostgreSQL Flexible Server
// ---------------------------------------------------------------------------

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: serverName
  location: location
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    version: postgresVersion
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    storage: {
      storageSizeGB: storageSizeGB
    }
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Enabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
  }
}

// ---------------------------------------------------------------------------
// Azure AD Administrator
// ---------------------------------------------------------------------------

resource aadAdmin 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2024-08-01' = {
  name: administratorPrincipalId
  parent: postgresServer
  properties: {
    principalType: 'ServicePrincipal'
    principalName: administratorPrincipalName
    tenantId: subscription().tenantId
  }
}

// ---------------------------------------------------------------------------
// Default Database
// ---------------------------------------------------------------------------

resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = {
  name: databaseName
  parent: postgresServer
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// ---------------------------------------------------------------------------
// Firewall Rule – Allow Azure Services
// ---------------------------------------------------------------------------

resource firewallAllowAzure 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-08-01' = {
  name: 'AllowAzureServices'
  parent: postgresServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('Fully qualified domain name of the PostgreSQL server.')
output fqdn string = postgresServer.properties.fullyQualifiedDomainName

@description('Name of the default database.')
output databaseName string = database.name

@description('Resource ID of the PostgreSQL Flexible Server.')
output serverResourceId string = postgresServer.id
