// pike-platform :: modules/sql-database
// Creates one Azure SQL logical server and one database.
// Microsoft Entra user administrator; Entra-only authentication enabled.
// No private endpoint or private DNS resources are configured.

@description('Workload name, e.g. sampleapp.')
param workloadName string

@allowed(['dev', 'qa', 'uat', 'stg', 'prod'])
param environment string

@description('Azure region short code.')
param regionCode string = 'centralus'

param instance string = '001'

@description('Resource ID of the central Log Analytics workspace.')
param logAnalyticsWorkspaceId string = ''

param enableDiagnosticSettings bool = false

@description('SQL database SKU name, e.g. GP_Gen5_2.')
param skuName string

@description('SQL database SKU tier, e.g. GeneralPurpose.')
param skuTier string

@description('Microsoft Entra administrator object ID.')
param entraAdminObjectId string

@description('Microsoft Entra administrator login name (UPN).')
param entraAdminLogin string

@description('Tenant ID containing the administrator.')
param entraTenantId string = subscription().tenantId

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
  name: take('deploy-${serverName}', 64)
  params: {
    name: serverName
    location: location
    tags: mandatoryTags

    administrators: {
      login: entraAdminLogin
      sid: entraAdminObjectId
      tenantId: entraTenantId
      principalType: 'User'
      azureADOnlyAuthentication: true
    }

    // Required by the AVM module schema.
    // SQL authentication is disabled by Entra-only authentication.
    // administratorLogin: 'sql-admin-${uniqueString(resourceGroup().id, serverName)}'
    // administratorLoginPassword: guid(resourceGroup().id, serverName)

    // Public network access enabled; no private endpoint or DNS resources.
    publicNetworkAccess: 'Enabled'

    securityAlertPolicies: [
      {
        name: 'Default'
        state: 'Enabled'
      }
    ]

    databases: [
      {
        name: databaseName
        sku: {
          name: skuName
          tier: skuTier
        }
        availabilityZone: -1
        tags: mandatoryTags
        diagnosticSettings: enableDiagnosticSettings
          ? [
              {
                workspaceResourceId: logAnalyticsWorkspaceId
              }
            ]
          : []
      }
    ]
  }
}

output serverId string = sqlServer.outputs.resourceId
output serverFqdn string = sqlServer.outputs.fullyQualifiedDomainName
output serverName string = serverName
output databaseName string = databaseName
