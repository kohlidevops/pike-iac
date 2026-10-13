targetScope = 'resourceGroup'

@description('Globally unique Azure Container Registry name. Only lowercase letters and numbers are allowed.')
param registryName string

@description('Azure region for the Container Registry.')
param location string = resourceGroup().location

@description('Resource tags.')
param tags object = {}

resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: registryName
  location: location

  sku: {
    name: 'Basic'
  }

  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }

  tags: tags
}

output registryName string = registry.name

output loginServer string = registry.properties.loginServer

output registryId string = registry.id
