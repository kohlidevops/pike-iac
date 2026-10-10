param sqlServerName string
param databaseName string
param location string
param administratorLogin string
@secure()
param administratorLoginPassword string
param databaseSkuName string = 'Basic'
param databaseMaxSizeBytes int = 2147483648
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Enabled'
param tags object = {}

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: publicNetworkAccess
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: databaseName
  location: location
  sku: { name: databaseSkuName }
  properties: { maxSizeBytes: databaseMaxSizeBytes }
}

output sqlServerId string = sqlServer.id
output sqlServerName string = sqlServer.name
output databaseId string = sqlDatabase.id
output databaseName string = sqlDatabase.name
