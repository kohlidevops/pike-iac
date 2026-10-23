// pike-platform :: modules/container-registry/acr-pull-assignment.bicep
// Grants AcrPull or AcrPush on an existing shared container registry to a
// managed identity or service principal. Designed for the cross-resource-group
// scenario: the shared registry lives in one RG (e.g. rg-fieldservices-shared),
// while the app's managed identity is created in a different one (e.g.
// rg-fieldservices-dev).
//
// Deploy this module scoped to the registry's own resource group at app-stack
// deploy time, after the identity exists — avoiding the registry-creation-time
// coupling that modules/container-registry/main.bicep's own pullPrincipalIds
// requires (which only works when all identity IDs are known at registry creation).
//
// Ported from pike-trac-webservice's infra/modules/acrPullAssignment.bicep
// (migration map PR #85, S25.3). The role IDs are confirmed live — AcrPull
// matches the one already used in modules/container-registry/main.bicep.
//
// role param added 2026-10-02 (GAPS.md, first real app deploy): app-platform-stack's
// UAMI is used both at CI time (`docker push` the newly-built image) and at
// Container App runtime (pull it) — AcrPull alone covers only the second half.
// AcrPush is a superset of AcrPull (confirmed via the built-in role's own
// action list), so one grant covers both; kept as a single param rather than
// two separate role assignments to avoid granting both roles redundantly.

@description('Name of the existing shared container registry (not its resource ID — the resource must exist in the resource group this deployment targets).')
param registryName string

@description('Object ID of the managed identity or service principal to grant the role to.')
param principalId string

@description('Which built-in ACR role to grant. AcrPush is a superset of AcrPull (push implies pull) — use it when the same identity both builds/pushes (CI) and runs/pulls (Container App runtime) the image.')
@allowed(['AcrPull', 'AcrPush'])
param role string = 'AcrPull'

var roleIds = {
  AcrPull: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  AcrPush: '8311e382-0749-4cb8-b61a-304f252e45ec'
}
var roleId = roleIds[role]

resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: registryName
}

resource acrRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, principalId, roleId)
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
