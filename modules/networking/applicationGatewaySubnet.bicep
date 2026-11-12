@description('Existing Virtual Network name')
param vnetName string

@description('Dedicated Application Gateway subnet name')
param subnetName string

@description('Application Gateway subnet CIDR')
param subnetAddressPrefix string

resource vnet 'Microsoft.Network/virtualNetworks@2025-05-01' existing = {
  name: vnetName
}

resource applicationGatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2025-05-01' = {
  parent: vnet
  name: subnetName
  properties: {
    addressPrefix: subnetAddressPrefix
  }
}

output subnetId string = applicationGatewaySubnet.id
output subnetName string = applicationGatewaySubnet.name
