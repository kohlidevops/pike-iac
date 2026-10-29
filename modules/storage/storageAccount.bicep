@description('Storage account name; globally unique, lowercase, 3-24 characters.')
param storageAccountName string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object

@description('Storage account SKU.')
param skuName string

@description('Storage account kind.')
param kind string

@description('Blob access tier.')
param accessTier string

@description('Minimum TLS version.')
param minimumTlsVersion string

@description('Require HTTPS for data-plane traffic.')
param supportsHttpsTrafficOnly bool

@description('Allow anonymous blob access.')
param allowBlobPublicAccess bool

@description('Allow Shared Key authorization.')
param allowSharedKeyAccess bool

@description('Public network access setting.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string

@description('Container names to create.')
param containerNames array

@description('Blob service name (normally default).')
param blobServiceName string

@description('Container public access level.')
@allowed([
  'None'
  'Blob'
  'Container'
])
param containerPublicAccess string

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  kind: kind
  properties: {
    accessTier: accessTier
    minimumTlsVersion: minimumTlsVersion
    supportsHttpsTrafficOnly: supportsHttpsTrafficOnly
    allowBlobPublicAccess: allowBlobPublicAccess
    allowSharedKeyAccess: allowSharedKeyAccess
    publicNetworkAccess: publicNetworkAccess
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: blobServiceName
}

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = [
  for containerName in containerNames: {
    parent: blobService
    name: containerName
    properties: {
      publicAccess: containerPublicAccess
    }
  }
]

output storageAccountId string = storageAccount.id
output storageAccountNameOut string = storageAccount.name
output containerNamesOut array = containerNames
