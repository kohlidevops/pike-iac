param location string
param vnetName string
param addressPrefix string
param tags object

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [addressPrefix]
    }
  }
}
output vnetId string = vnet.id
output vnetName string = vnet.name
