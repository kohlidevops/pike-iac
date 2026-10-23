// PSRule/what-if validation fixture — not a real environment deployment config.
// Exercises the no-VNet path added for S24.1 (optional subnetId): a plain
// Consumption environment with public ingress and no VNet integration, for
// workloads like the AI Development Factory service that don't need private
// networking. Mirrors main.tests.bicepparam, minus subnetId.
using 'main.bicep'

param workloadName = 'psrtest'
param environment = 'dev'
param logAnalyticsWorkspaceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-psrule-test/providers/Microsoft.OperationalInsights/workspaces/law-psrule-test'
param costCenter = 'CC-0000'
param owner = 'platform-team'
param applicationName = 'psrule-test'
