// ============================================================================
// Azure Cache for Redis Module
// ============================================================================
// Customize:
//   - skuName / skuFamily / skuCapacity: scale up for production workloads
//     (e.g., Premium P1 for persistence, clustering, and VNet injection)
//   - minTlsVersion: keep at 1.2 or higher
// ============================================================================

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Application name used as a prefix for the Redis resource.')
param appName string

@description('Azure region for the Redis cache.')
param location string

@description('SKU name for the Redis cache.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Basic'

@description('SKU family. Use "C" for Basic/Standard, "P" for Premium.')
@allowed([
  'C'
  'P'
])
param skuFamily string = 'C'

@description('SKU capacity (cache size). For C family: 0-6; for P family: 1-5.')
@minValue(0)
@maxValue(6)
param skuCapacity int = 0

@description('Minimum TLS version required by clients.')
@allowed([
  '1.2'
  '1.3'
])
param minTlsVersion string = '1.2'

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------

var redisName = '${appName}-redis'

// ---------------------------------------------------------------------------
// Redis Cache
// ---------------------------------------------------------------------------

resource redis 'Microsoft.Cache/redis@2024-11-01' = {
  name: redisName
  location: location
  properties: {
    sku: {
      name: skuName
      family: skuFamily
      capacity: skuCapacity
    }
    enableNonSslPort: false
    minimumTlsVersion: minTlsVersion
    redisConfiguration: {
      'maxmemory-policy': 'allkeys-lru'
    }
    publicNetworkAccess: 'Enabled'
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('Hostname of the Redis cache (e.g., myapp-redis.redis.cache.windows.net).')
output hostName string = redis.properties.hostName

@description('SSL port for the Redis cache (typically 6380).')
output sslPort int = redis.properties.sslPort

@description('Resource ID of the Redis cache.')
output redisResourceId string = redis.id
