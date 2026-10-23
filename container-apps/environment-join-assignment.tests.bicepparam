// PSRule/what-if validation fixture — not a real deployment config.
// PSRule validates the template structure at compile time; the existing
// environment reference is a placeholder and does not need to resolve to a
// live resource for static analysis to pass.
using 'environment-join-assignment.bicep'

param environmentName = 'cae-psrtest-dev-eastus2-001'
param principalId = '00000000-0000-0000-0000-000000000001'
