// pike-platform :: modules/storage-account
// Wraps AVM's storage-account module. Public blob access is denied by
// default and is not a parameter — golden paths that genuinely need public
// blobs (rare — think static site assets) must document the exception per
// golden-paths/new-service/SPEC.md and get a reviewed override, not flip a flag.

@description('Workload name, e.g. "checkout". NOTE: storage account names allow no dashes — this module strips them.')
param workloadName string

@allowed(['dev', 'stg', 'prod'])
param environment string

param regionCode string = 'eastus2'
param instance string = '001'

@description('Resource ID of the central Log Analytics workspace.')
param logAnalyticsWorkspaceId string

@allowed(['Standard_LRS', 'Standard_ZRS', 'Standard_GRS'])
param skuName string = 'Standard_ZRS'

param costCenter string
param owner string
param applicationName string

var location = resourceGroup().location

// Storage account names: lowercase alphanumeric only, <=24 chars.
var rawName = 'st${workloadName}${environment}${regionCode}${instance}'
var storageAccountName = toLower(take(replace(rawName, '-', ''), 24))

var mandatoryTags = {
  CostCenter: costCenter
  Environment: environment
  Owner: owner
  Application: applicationName
  ManagedBy: 'pike-platform'
}

module storageAccount 'br/public:avm/res/storage/storage-account:0.14.3' = {
  name: 'deploy-${storageAccountName}'
  params: {
    name: storageAccountName
    location: location
    tags: mandatoryTags
    skuName: skuName
    allowBlobPublicAccess: false // not a param — see header comment
    allowSharedKeyAccess: false // Entra ID / RBAC data access only, no account-key auth
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: environment == 'prod' ? 'Disabled' : 'Enabled'
    supportsHttpsTrafficOnly: true
    diagnosticSettings: [
      { workspaceResourceId: logAnalyticsWorkspaceId }
    ]
  }
}

output storageAccountId string = storageAccount.outputs.resourceId
output storageAccountName string = storageAccountName
output primaryBlobEndpoint string = storageAccount.outputs.primaryBlobEndpoint
