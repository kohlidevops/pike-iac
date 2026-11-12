@description('Application Gateway name')
param applicationGatewayName string

@description('Azure region')
param location string

@description('Existing Virtual Network name')
param vnetName string

@description('Dedicated Application Gateway subnet name')
param subnetName string

@description('Public IP resource name')
param publicIpName string

@description('Private frontend IP address')
param privateFrontendIp string

@description('Minimum autoscale capacity')
@minValue(0)
@maxValue(125)
param minCapacity int = 1

@description('Maximum autoscale capacity')
@minValue(1)
@maxValue(125)
param maxCapacity int = 2

@description('Frontend ports')
param frontendPorts array

@description('Backend address pools')
param backendPools array

@description('Backend HTTP settings')
param backendHttpSettings array

@description('Health probes')
param healthProbes array

@description('HTTP listeners')
param listeners array

@description('Request routing rules')
param routingRules array

@description('Enable HTTP/2')
param enableHttp2 bool = true

@description('Resource tags')
param tags object = {}

// Existing VNet
resource vnet 'Microsoft.Network/virtualNetworks@2025-05-01' existing = {
  name: vnetName
}

// Existing dedicated Application Gateway subnet
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2025-05-01' existing = {
  parent: vnet
  name: subnetName
}

// Public frontend IP
resource publicIp 'Microsoft.Network/publicIPAddresses@2025-05-01' = {
  name: publicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// Application Gateway
resource appGateway 'Microsoft.Network/applicationGateways@2025-05-01' = {
  name: applicationGatewayName
  location: location
  tags: tags

  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
    }

    autoscaleConfiguration: {
      minCapacity: minCapacity
      maxCapacity: maxCapacity
    }

    enableHttp2: enableHttp2

    gatewayIPConfigurations: [
      {
        name: 'gateway-ip-config'
        properties: {
          subnet: {
            id: subnet.id
          }
        }
      }
    ]

    frontendIPConfigurations: [
      {
        name: 'frontend-public'
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
      {
        name: 'frontend-private'
        properties: {
          privateIPAddress: privateFrontendIp
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: subnet.id
          }
        }
      }
    ]

    frontendPorts: [
      for port in frontendPorts: {
        name: port.name
        properties: {
          port: port.port
        }
      }
    ]

    backendAddressPools: [
      for pool in backendPools: {
        name: pool.name
        properties: {
          backendAddresses: pool.backendAddresses
        }
      }
    ]

    probes: [
      for probe in healthProbes: {
        name: probe.name
        properties: {
          protocol: probe.protocol
          host: probe.host
          path: probe.path
          interval: probe.interval
          timeout: probe.timeout
          unhealthyThreshold: probe.unhealthyThreshold
          match: {
            statusCodes: probe.statusCodes
          }
        }
      }
    ]

    backendHttpSettingsCollection: [
      for setting in backendHttpSettings: {
        name: setting.name
        properties: {
          port: setting.port
          protocol: setting.protocol
          requestTimeout: setting.requestTimeout
          cookieBasedAffinity: setting.cookieBasedAffinity
          probe: {
            id: resourceId(
              'Microsoft.Network/applicationGateways/probes',
              applicationGatewayName,
              setting.probeName
            )
          }
        }
      }
    ]

    httpListeners: [
      for listener in listeners: {
        name: listener.name
        properties: {
          frontendIPConfiguration: {
            id: resourceId(
              'Microsoft.Network/applicationGateways/frontendIPConfigurations',
              applicationGatewayName,
              listener.frontendIPConfigurationName
            )
          }
          frontendPort: {
            id: resourceId(
              'Microsoft.Network/applicationGateways/frontendPorts',
              applicationGatewayName,
              listener.frontendPortName
            )
          }
          protocol: listener.protocol
        }
      }
    ]

    requestRoutingRules: [
      for rule in routingRules: {
        name: rule.name
        properties: {
          priority: rule.priority
          ruleType: 'Basic'
          httpListener: {
            id: resourceId(
              'Microsoft.Network/applicationGateways/httpListeners',
              applicationGatewayName,
              rule.listenerName
            )
          }
          backendAddressPool: {
            id: resourceId(
              'Microsoft.Network/applicationGateways/backendAddressPools',
              applicationGatewayName,
              rule.backendPoolName
            )
          }
          backendHttpSettings: {
            id: resourceId(
              'Microsoft.Network/applicationGateways/backendHttpSettingsCollection',
              applicationGatewayName,
              rule.httpSettingName
            )
          }
        }
      }
    ]
  }
}

output applicationGatewayId string = appGateway.id
output applicationGatewayName string = appGateway.name
output publicIpId string = publicIp.id
output publicIpAddress string = publicIp.properties.ipAddress
