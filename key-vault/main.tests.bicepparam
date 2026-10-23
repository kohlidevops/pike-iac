// PSRule validation fixture — not a real environment deployment config.
using 'main.bicep'

param workloadName = 'psrtest'
param environment = 'dev'
param logAnalyticsWorkspaceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-psrule-test/providers/Microsoft.OperationalInsights/workspaces/law-psrule-test'
param costCenter = 'CC-0000'
param owner = 'platform-team'
param applicationName = 'psrule-test'
