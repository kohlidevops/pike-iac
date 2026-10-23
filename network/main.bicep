// pike-platform :: modules/network
// Wraps the AVM virtual-network module with Pike naming, tagging,
// diagnostics defaults, and explicit subnet network policies.

@description('Workload name used in the resource name.')
param workloadName string

@allowed(['dev', 'qa', 'uat', 'stg', 'prod'])
@description('Deployment environment.')
param environment string

@description('Azure region short code.')
param regionCode string = 'eastus2'

@description('Instance number, zero-padded.')
param instance string = '001'

@description('Address space for the VNet.')
param addressPrefixes array = ['10.0.0.0/16']

@description('Subnets to create. Each subnet can include name, addressPrefix and optional networkSecurityGroupResourceId.')
param subnets array = [
  { name: 'default', addressPrefix: '10.0.0.0/24' }
]

@description('Resource ID of the central Log Analytics workspace.')
param logAnalyticsWorkspaceId string
param enableDiagnosticSettings bool = false

@description('Resource ID of the hub VNet to peer to.')
param hubVnetResourceId string = ''

@description('On-prem CIDR ranges reachable through the hub Azure Firewall.')
param onPremCidrs array = []

@description('Private IP of the hub Azure Firewall.')
param hubFirewallPrivateIp string = ''

@description('Cost center tag.')
param costCenter string

@description('Owning team name.')
param owner string

@description('Application/service name.')
param applicationName string

var location = resourceGroup().location
var vnetName = 'vnet-${workloadName}-${environment}-${regionCode}-${instance}'

var onPremRoutes = [for cidr in onPremCidrs: {
  name: 'udr-onprem-${replace(replace(cidr, '.', '-'), '/', '-')}-to-fw'
  properties: {
    addressPrefix: cidr
    nextHopType: 'VirtualAppliance'
    nextHopIpAddress: hubFirewallPrivateIp
  }
}]

var mandatoryTags = {
  CostCenter: costCenter
  Environment: environment
  Owner: owner
  Application: applicationName
  ManagedBy: 'pike-platform'
}

// Optional spoke UDR for firewall-routed egress and on-prem traffic.
resource routeTable 'Microsoft.Network/routeTables@2023-11-01' = if (!empty(hubFirewallPrivateIp)) {
  name: 'rt-${vnetName}'
  location: location
  tags: mandatoryTags
  properties: {
    disableBgpRoutePropagation: true
    routes: concat(onPremRoutes, [
      {
        name: 'udr-default-to-fw'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: hubFirewallPrivateIp
        }
      }
      {
        name: 'udr-entra-to-internet'
        properties: {
          addressPrefix: 'AzureActiveDirectory'
          nextHopType: 'Internet'
        }
      }
    ])
  }
}

// Azure Verified Module, pinned to a specific version.
module vnet 'br/public:avm/res/network/virtual-network:0.5.1' = {
  name: 'deploy-${vnetName}'
  params: {
    name: vnetName
    location: location
    addressPrefixes: addressPrefixes
    subnets: [for s in subnets: {
      name: s.name
      addressPrefix: s.addressPrefix
      networkSecurityGroupResourceId: s.?networkSecurityGroupResourceId
      routeTableResourceId: empty(hubFirewallPrivateIp) ? null : routeTable.id
      privateEndpointNetworkPolicies: 'Disabled'
    }]
    tags: mandatoryTags
    diagnosticSettings: enableDiagnosticSettings ? [{ workspaceResourceId: logAnalyticsWorkspaceId }] : []
    peerings: empty(hubVnetResourceId) ? [] : [
      {
        name: 'peer-to-hub'
        remoteVirtualNetworkResourceId: hubVnetResourceId
        remotePeeringEnabled: true
        allowForwardedTraffic: true
        allowVirtualNetworkAccess: true
        allowGatewayTransit: false
        useRemoteGateways: !empty(onPremCidrs)
      }
    ]
  }
}

@description('Resource ID of the created VNet.')
output vnetId string = vnet.outputs.resourceId

@description('Name of the created VNet.')
output vnetName string = vnetName

@description('Subnet resource IDs, keyed by subnet name.')
output subnetIds object = toObject(
  range(0, length(subnets)),
  i => subnets[i].name,
  i => vnet.outputs.subnetResourceIds[i]
)

@description('Resource ID of the hub-firewall route table, or empty string when not configured.')
output routeTableId string = empty(hubFirewallPrivateIp) ? '' : routeTable.id
