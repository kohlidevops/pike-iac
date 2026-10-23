// pike-platform :: modules/network
// Wraps the AVM virtual-network module with Pike's naming, tagging, and
// diagnostic-settings defaults. Application teams consume THIS module,
// never the AVM module directly — that's how the standard stays standard.

@description('Workload name, e.g. "checkout". Used in the resource name.')
param workloadName string

@allowed(['dev', 'qa', 'uat', 'stg', 'prod'])
@description('Environment. Must match the workload\'s deployment target.')
param environment string

@description('Azure region short code, e.g. "eastus2".')
param regionCode string = 'eastus2'

@description('Instance number, zero-padded. Default 001.')
param instance string = '001'

@description('Address space for the VNet.')
param addressPrefixes array = ['10.0.0.0/16']

@description('Subnets to create. Each: { name, addressPrefix, networkSecurityGroupResourceId? }. NSG association is opt-in per subnet — supply networkSecurityGroupResourceId to attach one.')
param subnets array = [
  { name: 'default', addressPrefix: '10.0.0.0/24' }
]

@description('Resource ID of the central Log Analytics workspace for diagnostics.')
param logAnalyticsWorkspaceId string
param enableDiagnosticSettings bool = false

@description('Resource ID of the hub VNet to peer to (e.g. vnet-hub in the Shared Services subscription). Omit for network-isolated workloads — sandboxes must never set this; see ADR-0001. When set, the deploying identity needs Network Contributor (or equivalent) on the hub VNet\'s resource group — this is a real, separate permission grant, not automatic. Peering itself does not require on-prem reachability — set hubFirewallPrivateIp for firewall-routed egress inspection, and onPremCidrs too (which sets useRemoteGateways: true on the peering) only when this workload actually needs real on-prem routes; the hub\'s reciprocal peering must itself allow gateway transit for that to succeed.')
param hubVnetResourceId string = ''

@description('On-prem CIDR ranges this VNet must reach through the hub Azure Firewall, e.g. ["10.0.0.0/8"]. Empty (default) means no on-prem route is created — most workloads outside domains with an on-prem reachability requirement should leave this empty. Ignored if hubFirewallPrivateIp is not set.')
param onPremCidrs array = []

@description('Private IP of the hub Azure Firewall (e.g. "10.240.255.4"). When set, this module creates a route table sending onPremCidrs AND 0.0.0.0/0 through the firewall (standard hub-spoke egress-inspection pattern) and attaches it to every subnet. The hub side still needs its own per-prefix return route covering this VNet\'s EXACT address space, not a loose aggregate — a loose aggregate causes a real SQL prelogin-timeout failure, confirmed live 2026-09-25 (GAPS.md #58, docs/adr/0005-shared-nonprod-vnet-pattern.md). Use modules/hub-network/gateway-return-route.bicep (deployed into the hub subscription/resource group, not this one) to create that return route — it is real, callable IaC now, not a manual/out-of-band step. Omit for workloads with no on-prem reachability requirement.')
param hubFirewallPrivateIp string = ''

@description('Cost center tag — required, drives FinOps chargeback.')
param costCenter string

@description('Owning team — required. Team name, not an individual.')
param owner string

@description('Application/service name as it appears in the portal catalog.')
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

// Spoke UDR for on-prem reachability through the hub Azure Firewall
// (opt-in via hubFirewallPrivateIp) — one route table per VNet, attached
// to every subnet. Forcing 0.0.0.0/0 through the firewall alongside the
// on-prem CIDRs is the standard hub-spoke egress-inspection pattern:
// without it, on-prem-bound traffic would take the firewall route but
// internet-bound traffic would bypass inspection entirely. Matches the
// real, tested UDR standard from pike-trac-webservice's own
// infra/modules/routeTable.bicep (BACKLOG.md E25/S25.2) --
// disableBgpRoutePropagation + the Entra bypass route were both real,
// confirmed-necessary parts of that standard, not decorative:
// disableBgpRoutePropagation stops a hub VPN/ExpressRoute gateway's own
// BGP-advertised routes from silently overriding these UDRs; the Entra
// bypass keeps auth traffic from hairpinning through the firewall.
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

// Consumes the Microsoft-maintained Azure Verified Module.
// Pin the version explicitly — never floating-tag a platform dependency.
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
    }]
    tags: mandatoryTags
    // Diagnostic settings are opt-OUT, not opt-in — see docs/naming-and-tagging.md
    diagnosticSettings: enableDiagnosticSettings ? [{ workspaceResourceId: logAnalyticsWorkspaceId }] : []
    // Hub-spoke peering (GAPS.md #19) — opt-in via hubVnetResourceId. The AVM
    // module deploys both directions (remotePeeringEnabled: true) itself, via
    // a cross-scope nested deployment — the caller's identity still needs
    // Network Contributor on the hub's resource group for that half to
    // succeed. Naming matches the real convention already in use tenant-wide
    // (e.g. vnet-piketrack-dev's "peer-to-hub").
    //
    // Real bug fixed 2026-09-25 (GAPS.md #58, docs/adr/0005): this was
    // useRemoteGateways: false, which would have silently broken on-prem
    // reachability for any spoke actually relying on this module -- the
    // hub's ExpressRoute gateway only propagates its routes to a spoke
    // that asks for them via useRemoteGateways: true. Confirmed against
    // pike-trac-webservice's own real, working spoke↔hub peering config.
    //
    // Second real bug fixed 2026-10-19 (GAPS.md #111): useRemoteGateways
    // was gated on hubFirewallPrivateIp, not onPremCidrs -- wrong,
    // confirmed by a real deployment failure (RemotePeeringDoesNotAllow
    // GatewayTransit) the first time a consumer set hubFirewallPrivateIp
    // without any onPremCidrs (firewall-routed egress inspection only,
    // no actual on-prem reachability need). useRemoteGateways/
    // allowGatewayTransit is specifically about propagating the hub's
    // VPN/ExpressRoute gateway routes to the spoke -- unrelated to
    // firewall-based UDR egress routing, which the route table above
    // already handles independently. Gating on onPremCidrs instead
    // means a workload only requests gateway transit when it actually
    // needs on-prem routes, which is the only case the hub's reciprocal
    // peering is configured to allow.
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

@description('Resource ID of the created VNet — consumed by dependent modules (AKS, private endpoints).')
output vnetId string = vnet.outputs.resourceId

@description('Name of the created VNet.')
output vnetName string = vnetName

@description('Subnet resource IDs, keyed by subnet name.')
output subnetIds object = toObject(
  range(0, length(subnets)),
  i => subnets[i].name,
  i => vnet.outputs.subnetResourceIds[i]
)

@description('Resource ID of the hub-firewall route table, or empty string if hubFirewallPrivateIp was not set.')
output routeTableId string = empty(hubFirewallPrivateIp) ? '' : routeTable.id
