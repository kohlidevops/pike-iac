// pike-platform :: modules/container-registry
// Wraps AVM's container-registry module. One registry per domain per
// environment tier (ADR-0004) — parameterized by domainName, not
// workloadName, because this is shared by every app in a domain's
// Non-Prod or Prod subscription, not scoped to a single workload the
// way modules/key-vault or modules/storage-account are.
//
// Deliberately no default RBAC baked in. Non-Prod's registry accepts
// pushes from that domain's CI identities and pulls from that
// domain's Container Apps environment(s). Prod's registry NEVER
// accepts a direct push — only pulls from Prod's Container Apps
// environment(s) and a push from the promotion identity that runs
// `az acr import` from Non-Prod (ADR-0004 Rule 2). This module doesn't
// enforce that split itself (it can't know who's calling it) — the
// caller is responsible for only ever granting AcrPush on a Prod
// registry to the promotion identity, never to a CI identity.

@description('Domain slug, e.g. "field-services" — must match golden-paths/new-service/domains.json\'s key.')
param domainName string

@allowed(['non-prod', 'prod'])
@description('Environment tier — matches ADR-0001/ADR-0004\'s two-tier-per-domain model, not the finer dev/stg/prod used for individual app resources.')
param environment string

@description('Azure region short code.')
param regionCode string = 'eastus2'

param instance string = '001'

@description('Resource ID of the central Log Analytics workspace.')
param logAnalyticsWorkspaceId string

@description('Principal IDs (service principals or managed identities) granted AcrPush — CI identities for non-prod, the promotion identity only for prod. Never grant a CI identity AcrPush on a prod registry.')
param pushPrincipalIds array = []

@description('Principal IDs (service principals or managed identities) granted AcrPull — typically a domain\'s Container Apps environment(s).')
param pullPrincipalIds array = []

@description('Enables registry-wide anonymous (unauthenticated) pull. Defaults false, matching every existing domain registry (which hold Pike\'s own proprietary application images, not safe to expose). Only set true for a registry deliberately scoped to contain nothing but already-public, re-hosted images (e.g. the shared base-image mirror, GAPS.md #116) — never a domain\'s own app-image registry.')
param anonymousPullEnabled bool = false

@description('Overrides the computed cr<domainName><environment><regionCode><instance> name entirely. Only for a registry that genuinely isn\'t one of a domain\'s non-prod/prod pair (ADR-0004) — the shared base-image mirror is the only real case so far (GAPS.md #116); every per-domain registry should keep using the computed name, not this.')
param name string = ''

param costCenter string
param owner string
param applicationName string

var location = resourceGroup().location

// ACR names: alphanumeric only (no hyphens), 5-50 chars, globally unique.
var rawName = empty(name) ? 'cr${domainName}${environment}${regionCode}${instance}' : name
var registryName = toLower(take(replace(rawName, '-', ''), 50))

var mandatoryTags = {
  CostCenter: costCenter
  Environment: environment
  Owner: owner
  Application: applicationName
  ManagedBy: 'pike-platform'
}

// Built-in role IDs — AcrPush / AcrPull, confirmed live via
// `az role definition list` 2026-09-20, not assumed from memory.
var acrPushRoleId = '8311e382-0749-4cb8-b61a-304f252e45ec'
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

var pushRoleAssignments = [for id in pushPrincipalIds: {
  principalId: id
  principalType: 'ServicePrincipal'
  roleDefinitionIdOrName: acrPushRoleId
}]
var pullRoleAssignments = [for id in pullPrincipalIds: {
  principalId: id
  principalType: 'ServicePrincipal'
  roleDefinitionIdOrName: acrPullRoleId
}]

// Consumes the Microsoft-maintained Azure Verified Module. Version
// and parameter names confirmed 2026-09-20 directly against MCR's own
// tags API (mcr.microsoft.com/v2/bicep/avm/res/container-registry/registry/tags/list)
// and the module's real README/main.bicep — not assumed.
module registry 'br/public:avm/res/container-registry/registry:0.13.1' = {
  name: 'deploy-${registryName}'
  params: {
    // BCP334: Bicep can't statically prove the computed name is always
    // >=5 chars (AVM's own @minLength(5) on `name`) since domainName/
    // environment/regionCode/instance have no length decorators of
    // their own — a known Bicep type-inference limitation for
    // concatenated/truncated strings, not a real risk. In practice
    // "cr" + a real domain slug + tier + region + instance is always
    // well over 5 chars; storage-account/key-vault don't hit this only
    // because their target AVM modules' own minLength happens not to
    // trip the same inference gap.
    #disable-next-line BCP334
    name: registryName
    location: location
    tags: mandatoryTags
    acrSku: 'Standard' // Premium (this module's own AVM default) buys geo-replication/Private Link we don't need yet — revisit if a domain's real throughput needs it (ADR-0004's revisit trigger).
    acrAdminUserEnabled: false // RBAC-only, matching every other module in this repo — no shared admin credential.
    // Confirmed live 2026-09-20 by an actual failed deployment, not
    // assumed from Key Vault's pattern: Standard/Basic SKU ACR has NO
    // network isolation option at all — no private endpoints, no
    // firewall/VNet rules (Premium-only, verified against Microsoft's
    // own docs). publicNetworkAccess must stay Enabled for both tiers;
    // access control here is RBAC/Entra-only (AcrPush/AcrPull grants
    // above), not network-level, for as long as this stays Standard.
    // If network isolation for prod becomes a real requirement, that's
    // a Premium-tier decision, not something this module can add
    // without it — flag to whoever owns ADR-0004 rather than fake it
    // with a setting Standard SKU silently ignores.
    publicNetworkAccess: 'Enabled'
    // The AVM module's own networkRuleSetDefaultAction default is
    // 'Deny', which — even with publicNetworkAccess left Enabled —
    // makes the module construct a networkRuleSet block internally
    // (its shouldConfigureNetworkRuleSet logic), which then fails to
    // deploy on Standard SKU (confirmed by an actual failed
    // deployment, twice, before finding this). Must be explicitly
    // 'Allow' to suppress that block entirely — this is not the same
    // as "network access is open," it just means "no network-level
    // ACL exists," consistent with the Standard-tier RBAC-only model
    // documented above.
    networkRuleSetDefaultAction: 'Allow'
    anonymousPullEnabled: anonymousPullEnabled
    diagnosticSettings: [
      { workspaceResourceId: logAnalyticsWorkspaceId }
    ]
    roleAssignments: concat(pushRoleAssignments, pullRoleAssignments)
  }
}

@description('Resource ID of the created registry.')
output registryId string = registry.outputs.resourceId

@description('Login server (e.g. crfieldservicesprodeastus2001.azurecr.io) — consumed as build-deploy-*.yml\'s acr-login-server input.')
output loginServer string = registry.outputs.loginServer

@description('Name of the created registry.')
output registryName string = registryName
