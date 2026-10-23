// pike-platform :: modules/container-apps
// Wraps AVM's Container Apps managed-environment module. This is the
// default self-service compute target (GAPS.md #20, BACKLOG.md E14) —
// AKS (modules/aks) stays available as an escalation path for teams that
// need full Kubernetes, not the default assumption.
// Normally deploys into a subnet produced by modules/network, mirroring
// modules/aks's own philosophy for domain workloads that need private
// networking (e.g. Field Services' Postgres-backed apps). subnetId is
// optional (S24.1): omit it to get a plain Consumption environment with
// public ingress and no VNet integration, for simpler internal tools that
// don't need private networking (e.g. the AI Development Factory service,
// which uses public HTTPS + real Entra auth instead). Either way, this
// module provisions the shared environment only; individual container apps
// (the actual workloads) are deployed separately via the build & deploy
// golden path (E6), not baked in here — infra provisioning and workload
// deployment stay independently testable steps.

@description('Workload name, e.g. "checkout".')
param workloadName string

@allowed(['dev', 'qa', 'uat', 'stg', 'prod'])
param environment string

param regionCode string = 'eastus2'
param instance string = '001'

@description('Subnet resource ID from modules/network output (subnetIds.<name>). Must be delegated/sized per AVM Container Apps requirements. Optional (S24.1) — omit (empty string) to deploy a plain Consumption environment with public ingress and no VNet integration, for workloads that don\'t need private networking (e.g. the AI Development Factory service). When provided, behaves exactly as before: VNet-integrated, same as Field Services\' Postgres-backed apps.')
param subnetId string = ''

@description('Resource ID of the central Log Analytics workspace.')
param logAnalyticsWorkspaceId string

@description('Whether the environment only exposes an internal load balancer (no public IP). Defaults to false — most workloads need public ingress; flip to true for genuinely internal-only services, not based on environment tier alone. Ignored (forced false) when subnetId is omitted — internal ingress requires VNet integration, per the AVM module\'s own "internal requires infrastructureSubnetResourceId" constraint.')
param internal bool = false

@description('Zone redundancy. Defaults to prod-only — right-size non-prod, matching modules/aks\'s Free-tier-for-non-prod convention. Requires internal + subnet, both already true/present when this is true in prod. Ignored (forced false) when subnetId is omitted — zone redundancy also requires VNet integration.')
param zoneRedundant bool = environment == 'prod'

@description('Workload profiles for the managed environment. Defaults to a single Consumption profile, enabling the newer Workload Profiles environment type rather than the legacy Consumption-only model — this lets apps opt into dedicated profiles later without rebuilding the environment. Ported from pike-trac-webservice\'s infra/environment.bicep (S25.3).')
param workloadProfiles array = [
  {
    name: 'Consumption'
    workloadProfileType: 'Consumption'
  }
]

param costCenter string
param owner string
param applicationName string

var location = resourceGroup().location
var envName = 'cae-${workloadName}-${environment}-${regionCode}-${instance}'

// S24.1: subnetId is optional. When omitted, deploy a plain Consumption
// environment with public ingress and no VNet integration (e.g. the AI
// Development Factory service) — internal/zoneRedundant both require VNet
// integration per the AVM module itself, so force them off in that case
// rather than letting a caller pass an invalid combination through.
var hasSubnet = !empty(subnetId)
var effectiveInternal = hasSubnet ? internal : false
var effectiveZoneRedundant = hasSubnet ? zoneRedundant : false

var mandatoryTags = {
  CostCenter: costCenter
  Environment: environment
  Owner: owner
  Application: applicationName
  ManagedBy: 'pike-platform'
}

module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.16.0' = {
  name: 'deploy-${envName}'
  params: {
    name: envName
    location: location
    tags: mandatoryTags
    infrastructureSubnetResourceId: hasSubnet ? subnetId : null
    internal: effectiveInternal
    zoneRedundant: effectiveZoneRedundant
    workloadProfiles: workloadProfiles
    // Workload Identity-equivalent for Container Apps — apps opt into this
    // environment's system identity, or bring their own, matching the
    // "no stored secrets" principle already used in modules/aks.
    managedIdentities: {
      systemAssigned: true
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceId
    }
    diagnosticSettings: [
      {
        workspaceResourceId: logAnalyticsWorkspaceId
      }
    ]
  }
}

@description('Resource ID of the Container Apps environment — consumed by the build & deploy golden path (E6) to deploy individual container apps into it.')
output environmentId string = containerAppsEnvironment.outputs.resourceId

@description('Name of the created Container Apps environment.')
output environmentName string = envName

@description('Default domain for apps deployed into this environment.')
output defaultDomain string = containerAppsEnvironment.outputs.defaultDomain
