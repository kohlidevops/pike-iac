// PSRule/what-if validation fixture — not a real environment deployment config.
using 'main.bicep'

param domainName = 'psrtest'
param environment = 'non-prod'
param logAnalyticsWorkspaceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-psrule-test/providers/Microsoft.OperationalInsights/workspaces/law-psrule-test'
param pushPrincipalIds = ['00000000-0000-0000-0000-000000000001']
param pullPrincipalIds = ['00000000-0000-0000-0000-000000000002']
param costCenter = 'CC-0000'
param owner = 'platform-team'
param applicationName = 'psrule-test'
