// pike-platform :: modules/iac-deploy-rbac-grantor-role
// ADR-0008 decision B's constrained-delegation pattern — the same one
// already used for id-iac-deploy-subscriptions — generalized for every
// workload deploy identity (e.g. id-iac-deploy-workloads-nonprod).
//
// Root cause (found 2026-10-01/02, first real app-platform-stack deploy):
// Contributor — what a workload deploy identity gets, per-RG, ADR-0008
// §6 — structurally excludes Microsoft.Authorization/*/write EVERYWHERE,
// including within its own granted RG, not just cross-RG. That's a
// deliberate, standard Azure distinction between Contributor and Owner,
// not a configuration gap. modules/app-platform-stack relies on inline
// role assignments as its core pattern (granting an app's UAMI Key Vault
// Secrets User, an ops group Secrets Officer, and — cross-RG, into the
// shared registry's RG — the UAMI AcrPull). Every one of those writes
// needs this role; none of them work on Contributor alone, regardless of
// which RG they're in.
//
// This is not narrow to one app or one module by design intent, even
// though only app-platform-stack uses it live today: it's the platform's
// own designed self-service path for every future app, in any domain or
// subscription, and id-iac-deploy-workloads-nonprod is itself a single,
// tenant-wide identity per ADR-0008's own identity matrix (not
// domain-scoped) — so the same role definition, assigned with a
// scope-appropriate condition, is the repeatable answer everywhere this
// identity is granted Contributor, not just Field Services.
//
// Broadening to a built-in role like RBAC Administrator would fix the
// symptom but let this identity assign ANY role to ANY principal
// wherever it's assigned — a real widening beyond what ADR-0008
// intended. This role instead grants only the specific actions below;
// every assignment MUST pair it with an ABAC condition restricting the
// roleAssignments write to an explicit allowlist of role definitions —
// never assign this role unconditioned. See
// docs/runbooks/pipeline-identities.md for the current allowlist (Key
// Vault Secrets User, Key Vault Secrets Officer, AcrPull) and how to
// extend it when a future module needs one more.
//
// deployments/write+read is also required, not just roleAssignments —
// found 2026-10-02: Bicep's cross-RG nested module call (`scope:
// resourceGroup(...)`) materializes as a Microsoft.Resources/deployments
// resource AT THE RESOURCE GROUP being deployed into, not under whatever
// resource the nested template targets. A role assignment scoped to a
// child resource can never satisfy that — it's structural to how ARM
// models deployments, not something a condition can route around.
// deployments/write is comparatively low-risk on its own (it only
// creates/reads deployment *records* in a RG — actual resource creation
// is still gated by whatever other permissions apply); it stays
// unconditioned, since the condition's real job is narrowing
// roleAssignments/write specifically.
//
// Microsoft.OperationalInsights/workspaces/sharedkeys/action — added
// 2026-10-02, first real deploy of a Key Vault with diagnostic settings
// pointed at a shared, cross-RG Log Analytics workspace
// (rg-fieldservices-{dev,qa,uat}, one per tier, used by every app in it).
// Wiring diagnosticSettings to an external workspace needs this action on
// the WORKSPACE specifically — not a roleAssignments write at all, so the
// ABAC condition mechanism doesn't apply here. Grant it unconditioned,
// but scoped tightly to the one workspace resource (not its RG) — see
// docs/runbooks/pipeline-identities.md's "once per tier" section. Unlike
// the per-app Key Vault roles, this is a one-time grant per tier: every
// app in that tier shares the same workspace.
//
// Deployed once at a management group (ADR-0008: eventually Pike Root,
// matching modules/iac-whatif-operator-role's own precedent), so the
// definition can be assigned at any subscription or RG below it — once,
// tenant-wide, not once per domain. A role definition is a tenant-level
// object. Deploying it is a landing-zone-level change (gated, AGENTS.md
// §2): a cloud team lead runs it by hand per
// docs/runbooks/pipeline-identities.md until landing-zone/ units deploy.

targetScope = 'managementGroup'

@description('Display name of the custom role. Changing it changes the role GUID (it seeds guid()), so treat it as fixed once deployed.')
param roleName string = 'Pike IaC Deploy RBAC Grantor'

@description('Where the role may be assigned. Default: this management group and everything under it. Azure allows at most one management group here.')
param assignableScopes array = [
  managementGroup().id
]

var actions = [
  'Microsoft.Authorization/roleAssignments/write'
  'Microsoft.Authorization/roleAssignments/read'
  'Microsoft.Resources/deployments/write'
  'Microsoft.Resources/deployments/read'
  // Distinct action, not covered by write/read (confirmed via `az provider
  // operation show --namespace Microsoft.Resources`). Needed so
  // deploy-units.yml's stale-deployment cleanup (added 2026-10-02) can
  // clear a stuck prior deployment here too, not just in RGs this identity
  // separately has Contributor on.
  'Microsoft.Resources/deployments/cancel/action'
  // Not a roleAssignments action — see the header comment. Confirmed exact
  // casing via `az provider operation show --namespace Microsoft.OperationalInsights`.
  'Microsoft.OperationalInsights/workspaces/sharedkeys/action'
  // Distinct sub-resource-type from deployments/read — confirmed via
  // `az provider operation show --namespace Microsoft.Resources`. Found
  // 2026-10-02: without this, ARM's own polling of a cross-RG nested
  // deployment's status (e.g. deploy-acrpull-*) fails with Authorization
  // errors on every poll attempt, which doesn't surface as a clean
  // failure — it just looks stuck for many minutes before ARM eventually
  // gives up. This is almost certainly what made the very first AcrPull
  // deploy attempt look "stuck for 24 minutes" before this fix existed.
  'Microsoft.Resources/deployments/operationstatuses/read'
]

resource role 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(managementGroup().id, roleName)
  properties: {
    roleName: roleName
    description: 'Create/read role assignments, resource-group-scoped deployments, and Log Analytics workspace shared-keys reads only — no write access to any other resource type. Every assignment covering the roleAssignments action MUST carry an ABAC condition restricting it to an explicit role-definition allowlist, per docs/runbooks/pipeline-identities.md — never assign that action unconditioned. The sharedkeys action is not a roleAssignments write; scope it tightly (one workspace resource) instead. Managed by pike-platform (ADR-0008 decision B pattern).'
    type: 'CustomRole'
    permissions: [
      {
        actions: actions
        notActions: []
      }
    ]
    assignableScopes: assignableScopes
  }
}

@description('Role definition GUID. Pass this to the role-assignment command in docs/runbooks/pipeline-identities.md, always together with a scope-appropriate ABAC condition — never assign this role unconditioned.')
output roleDefinitionGuid string = role.name

@description('Full resource ID of the role definition.')
output roleDefinitionId string = role.id
