// PSRule/what-if validation fixture — not a real environment deployment config.
// Exercises the on-prem-reachability spoke UDR path (hubFirewallPrivateIp +
// onPremCidrs), separately from main.tests.bicepparam's default (no UDR)
// case, so CI actually validates both branches of the conditional route
// table resource.
using 'main.bicep'

param workloadName = 'psrtest'
param environment = 'qa'
param addressPrefixes = ['10.240.42.0/23']
param subnets = [
  {
    name: 'apps'
    addressPrefix: '10.240.42.0/24'
    networkSecurityGroupResourceId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-psrule-test/providers/Microsoft.Network/networkSecurityGroups/nsg-psrule-test'
  }
  {
    name: 'pe'
    addressPrefix: '10.240.43.0/25'
    networkSecurityGroupResourceId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-psrule-test/providers/Microsoft.Network/networkSecurityGroups/nsg-psrule-test'
  }
]
param logAnalyticsWorkspaceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-psrule-test/providers/Microsoft.OperationalInsights/workspaces/law-psrule-test'
param hubVnetResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-network-test/providers/Microsoft.Network/virtualNetworks/vnet-hub-test'
param onPremCidrs = ['10.0.0.0/8']
param hubFirewallPrivateIp = '10.240.255.4'
param costCenter = 'CC-0000'
param owner = 'platform-team'
param applicationName = 'psrule-test'
