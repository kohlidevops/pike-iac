param location string
@minLength(3)
@maxLength(24)
param storageAccountName string
param tags object = {}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Enabled'
  }
}

output storageAccountId string = storage.id
output storageAccountName string = storage.name
output blobEndpoint string = storage.properties.primaryEndpoints.blob
