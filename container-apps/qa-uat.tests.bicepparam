// PSRule/what-if validation fixture — not a real environment deployment config.
// Exercises the qa/uat environment enum values added for the per-domain
// dev/qa/uat-inside-one-Non-Prod-subscription model (BACKLOG.md E11 adjacent
// design work, docs/adr/0001), separately from main.tests.bicepparam's
// default 'dev' case.
using 'main.bicep'

param workloadName = 'psrtest'
param environment = 'uat'
param subnetId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-psrule-test/providers/Microsoft.Network/virtualNetworks/vnet-psrule-test/subnets/infra'
param logAnalyticsWorkspaceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-psrule-test/providers/Microsoft.OperationalInsights/workspaces/law-psrule-test'
param costCenter = 'CC-0000'
param owner = 'platform-team'
param applicationName = 'psrule-test'
