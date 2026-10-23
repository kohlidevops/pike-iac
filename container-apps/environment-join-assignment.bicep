// pike-platform :: modules/container-apps/environment-join-assignment.bicep
// Grants an identity permission to join an existing shared Container Apps
// managed environment. Designed for the cross-resource-group scenario: the
// shared environment lives in one RG (e.g. rg-fieldservices-dev), while the
// app's managed identity and its own Container App are deployed into a
// different one (e.g. rg-pdf-extractor-dev).
//
// Deploy this module scoped to the environment's own resource group, after the
// identity exists — same pattern as modules/container-registry/acr-pull-assignment.bicep.
//
// Found 2026-10-02/03, first real app deploy end-to-end test — two rounds:
// round 1, a plain `Microsoft.App/managedEnvironments/read` AuthorizationFailed
// (fixed by an earlier version of this module granting built-in Reader).
// Round 2, confirmed by the app repo's own session after that fix: joining a
// managed environment is gated by a SEPARATE "linked resource authorization"
// check — `Microsoft.App/managedEnvironments/join/action` — which built-in
// Reader does NOT cover (Reader is `*/read` only; join/action is a distinct
// action verb, same family as needing permission on a subnet to attach a VM).
// Confirmed live via `az role definition list --name "Container Apps
// Contributor"` that this built-in role's action list includes
// managedEnvironments/join/action (plus broader containerApps/* actions) —
// those broader actions are inert at this module's scope: a managedEnvironment
// is not a parent of containerApps in ARM's resource hierarchy, so scoping
// this role assignment to the one environment resource (not its RG) never
// grants anything on any containerApps resource, here or elsewhere.

@description('Name of the existing shared Container Apps managed environment (not its resource ID — the resource must exist in the resource group this deployment targets).')
param environmentName string

@description('Object ID of the managed identity or service principal to grant join access to.')
param principalId string

var containerAppsContributorRoleId = '358470bc-b998-42bd-ab17-a7e34c199c0f' // Container Apps Contributor (built-in)

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
  name: environmentName
}

resource joinAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(environment.id, principalId, containerAppsContributorRoleId)
  scope: environment
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', containerAppsContributorRoleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
