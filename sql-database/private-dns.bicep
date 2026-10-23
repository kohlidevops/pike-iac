
targetScope = 'resourceGroup'

@description('Name of the application virtual network.')
param vnetName string

@description('Resource group containing the application VNet.')
param vnetResourceGroupName string = resourceGroup().name

var zoneName = 'privatelink.database.windows.net'

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: zoneName
  location: 'global'
}

resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${vnetName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: resourceId(
        subscription().subscriptionId,
        vnetResourceGroupName,
        'Microsoft.Network/virtualNetworks',
        vnetName
      )
    }
  }
}

output privateDnsZoneId string = privateDnsZone.id
