param location string
param vnetName string
param nsgName string
param tags object = {}

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowVnetInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: ['10.40.0.0/16']
    }
    subnets: [
      {
        name: 'snet-vm'
        properties: {
          addressPrefix: '10.40.1.0/24'
          networkSecurityGroup: { id: nsg.id }
        }
      }
      {
        name: 'snet-function-integration'
        properties: {
          addressPrefix: '10.40.2.0/26'
          delegations: [
            {
              name: 'MicrosoftWebServerFarmsDelegation'
              properties: { serviceName: 'Microsoft.Web/serverFarms' }
            }
          ]
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output nsgId string = nsg.id
output vmSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'snet-vm')
output functionIntegrationSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'snet-function-integration')
