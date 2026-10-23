// PSRule validation fixture — not a real environment deployment config.
using 'main.bicep'

param workloadName = 'psrtest'
param environment = 'dev'
param subnetResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-psrule-test/providers/Microsoft.Network/virtualNetworks/vnet-psrule-test/subnets/default'
param adminUsername = 'azureadmin'
// Dummy value for static validation only; never use this fixture to deploy.
@secure()
param adminPassword = 'NotARealPassword-OnlyForStaticValidation-2026!'
param costCenter = 'CC-0000'
param owner = 'platform-team'
param applicationName = 'psrule-test'
