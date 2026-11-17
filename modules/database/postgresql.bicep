@description('Azure region for PostgreSQL Flexible Server.')
param location string

@description('Globally unique PostgreSQL Flexible Server name. Lowercase letters, numbers, and hyphens.')
param serverName string

@description('PostgreSQL administrator login.')
param administratorLogin string

@secure()
@description('PostgreSQL administrator password. Supply through GitHub Actions secret.')
param administratorLoginPassword string

@description('PostgreSQL major engine version.')
@allowed([
  '11'
  '12'
  '13'
  '14'
  '15'
  '16'
])
param version string

@description('PostgreSQL compute SKU name, for example Standard_B1ms.')
param skuName string

@description('PostgreSQL compute tier.')
@allowed([
  'Burstable'
  'GeneralPurpose'
  'MemoryOptimized'
])
param skuTier string

@description('PostgreSQL storage size in GB.')
@minValue(32)
param storageSizeGB int

@description('Enable or disable automatic storage growth.')
@allowed([
  'Enabled'
  'Disabled'
])
param storageAutoGrow string

@description('Backup retention period in days.')
@minValue(7)
@maxValue(35)
param backupRetentionDays int

@description('Enable or disable geo-redundant backups.')
@allowed([
  'Enabled'
  'Disabled'
])
param geoRedundantBackup string

@description('High availability mode.')
@allowed([
  'Disabled'
  'SameZone'
  'ZoneRedundant'
])
param highAvailabilityMode string

@description('Enable or disable public network access. Private VNet integration requires delegated subnet and private DNS configuration.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string

@description('Database definitions to create on the server.')
param databases array

@description('Firewall rules. Keep empty unless specific client IP addresses need access.')
param firewallRules array = []

@description('Resource tags.')
param tags object

resource postgresqlServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: serverName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    version: version
    authConfig: {
      activeDirectoryAuth: 'Disabled'
      passwordAuth: 'Enabled'
    }
    backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: geoRedundantBackup
    }
    highAvailability: {
      mode: highAvailabilityMode
    }
    network: {
      publicNetworkAccess: publicNetworkAccess
    }
    storage: {
      storageSizeGB: storageSizeGB
      autoGrow: storageAutoGrow
    }
  }
}

resource postgresqlDatabases 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = [for database in databases: {
  parent: postgresqlServer
  name: database.name
  properties: {
    charset: database.charset
    collation: database.collation
  }
}]

resource postgresqlFirewallRules 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-08-01' = [for rule in firewallRules: {
  parent: postgresqlServer
  name: rule.name
  properties: {
    startIpAddress: rule.startIpAddress
    endIpAddress: rule.endIpAddress
  }
}]

output postgresqlServerId string = postgresqlServer.id
output postgresqlServerName string = postgresqlServer.name
output postgresqlFqdn string = '${serverName}.postgres.database.azure.com'
output databaseNames array = [for database in databases: database.name]
