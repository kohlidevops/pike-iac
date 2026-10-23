// pike-platform :: modules/sql-database
// Wraps AVM's SQL logical-server module, provisioning exactly one
// database on it. Microsoft Entra-only authentication — no SQL login/
// password for anyone to manage or leak, matching the "no long-lived
// secrets" posture already established for app identities
// (docs/entra-permission-catalog.md). Public network access is denied
// by default; connect via a private endpoint on modules/network's
// subnet, same convention as modules/key-vault and
// modules/storage-account.

@description('Workload name, e.g. "checkout".')
param workloadName string

@allowed(['dev', 'qa', 'uat', 'stg', 'prod'])
param environment string

@description('Azure region short code.')
param regionCode string = 'eastus2'

param instance string = '001'

@description('Resource ID of the central Log Analytics workspace.')
param logAnalyticsWorkspaceId string

@description('SQL database SKU name — must be one of golden-paths/database-request/catalog.md\'s approved tiers, e.g. GP_S_Gen5_2 (General Purpose Serverless) or S1 (Standard DTU).')
param skuName string

@description('SQL database SKU tier, e.g. GeneralPurpose or Standard — must match skuName per Azure\'s SKU table.')
param skuTier string

@description('Entra ID GROUP object ID for the server admin — never an individual user, per least-privilege convention.')
param entraAdminGroupId string

@description('Display name of the Entra ID group set as server admin (for portal readability).')
param entraAdminGroupName string

@description('Tenant ID the Entra admin group belongs to.')
param entraTenantId string = subscription().tenantId

@description('Subnet resource ID (from modules/network) for the private endpoint.')
param privateEndpointSubnetId string

@description('Private DNS zone resource ID for privatelink.database.windows.net, for the private endpoint\'s DNS registration.')
param privateDnsZoneId string

param costCenter string
param owner string
param applicationName string

var location = resourceGroup().location
var serverName = take('sql-${workloadName}-${environment}-${regionCode}-${instance}', 63)
var databaseName = '${workloadName}-db'

var mandatoryTags = {
  CostCenter: costCenter
  Environment: environment
  Owner: owner
  Application: applicationName
  ManagedBy: 'pike-platform'
}

module sqlServer 'br/public:avm/res/sql/server:0.22.1' = {
  // Deployment names are capped at 64 chars; serverName can be up to
  // 63, so 'deploy-' + serverName could exceed that — truncate the
  // deployment name itself, not the server's own name.
  name: take('deploy-${serverName}', 64)
  params: {
    name: serverName
    location: location
    tags: mandatoryTags
    // Entra-only auth: administratorLogin/-Password are required by
    // the resource schema but never usable once this is true — no
    // secret to store or rotate.
    administrators: {
      login: entraAdminGroupName
      sid: entraAdminGroupId
      tenantId: entraTenantId
      principalType: 'Group'
      azureADOnlyAuthentication: true
    }
    administratorLogin: 'sql-admin-${uniqueString(resourceGroup().id, serverName)}'
    administratorLoginPassword: guid(resourceGroup().id, serverName)
    publicNetworkAccess: 'Disabled'
    privateEndpoints: [
      {
        subnetResourceId: privateEndpointSubnetId
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            { privateDnsZoneResourceId: privateDnsZoneId }
          ]
        }
      }
    ]
    securityAlertPolicies: [
      { name: 'Default', state: 'Enabled' }
    ]
    databases: [
      {
        name: databaseName
        sku: {
          name: skuName
          tier: skuTier
        }
        availabilityZone: -1 // no zone pinning by default; revisit per-tier if a catalog entry needs zone-redundant HA
        tags: mandatoryTags
        diagnosticSettings: [
          { workspaceResourceId: logAnalyticsWorkspaceId }
        ]
      }
    ]
  }
}

output serverId string = sqlServer.outputs.resourceId
output serverFqdn string = sqlServer.outputs.fullyQualifiedDomainName
output serverName string = serverName
output databaseName string = databaseName
