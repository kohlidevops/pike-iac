// pike-platform :: root deployment
// Orchestrates the five approved Pike modules into one workload deployment.
// Deploy to an existing resource group. The Log Analytics workspace and SQL
// private DNS zone / Entra admin group are prerequisites managed outside this stack.

@description('Workload name used in resource naming.')
param workloadName string = 'sampleapp'

@allowed(['dev', 'stg', 'prod'])
@description('Deployment environment. Limited to values supported by every selected module.')
param environment string = 'dev'

@description('Azure region short code used in resource names.')
param regionCode string = 'centralindia'

@description('Zero-padded resource instance number.')
param instance string = '001'

@description('Resource ID of the central Log Analytics workspace.')
param logAnalyticsWorkspaceId string

@description('Existing Private DNS zone ID for privatelink.database.windows.net.')
param sqlPrivateDnsZoneId string

@description('Entra ID group object ID for SQL Server administrator.')
param sqlEntraAdminGroupId string

@description('Display name of the Entra ID group for SQL Server administrator.')
param sqlEntraAdminGroupName string

@description('Cost center tag.')
param costCenter string

@description('Owning team name, not an individual.')
param owner string

@description('Application/service name.')
param applicationName string

@description('VNet address prefixes.')
param addressPrefixes array = ['10.40.0.0/16']

@description('VM subnet address prefix.')
param vmSubnetPrefix string = '10.40.1.0/24'

@description('Private endpoint subnet address prefix.')
param privateEndpointSubnetPrefix string = '10.40.2.0/24'

@description('SQL database SKU name approved by the platform catalog.')
param sqlSkuName string = 'GP_S_Gen5_2'

@description('SQL database SKU tier matching sqlSkuName.')
param sqlSkuTier string = 'GeneralPurpose'

@description('Windows VM SKU.')
param vmSize string = 'Standard_B2s'

@description('Windows local administrator username.')
param vmAdminUsername string = 'azureadmin'

@secure()
@description('Windows local administrator password. Supply securely from CI secret/environment variable.')
param vmAdminPassword string

@description('Key Vault Secrets Officer Entra ID group object IDs.')
param secretsOfficerGroupIds array = []

@description('Key Vault Secrets User Entra ID group object IDs.')
param secretsReaderGroupIds array = []

module network './network/main.bicep' = {
  name: 'network-${workloadName}-${environment}'
  params: {
    workloadName: workloadName
    environment: environment
    regionCode: regionCode
    instance: instance
    addressPrefixes: addressPrefixes
    subnets: [
      { name: 'vm', addressPrefix: vmSubnetPrefix }
      { name: 'private-endpoints', addressPrefix: privateEndpointSubnetPrefix }
    ]
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    costCenter: costCenter
    owner: owner
    applicationName: applicationName
  }
}

module storage './storage-account/main.bicep' = {
  name: 'storage-${workloadName}-${environment}'
  params: {
    workloadName: workloadName
    environment: environment
    regionCode: regionCode
    instance: instance
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    costCenter: costCenter
    owner: owner
    applicationName: applicationName
  }
}

module keyVault './key-vault/main.bicep' = {
  name: 'key-vault-${workloadName}-${environment}'
  params: {
    workloadName: workloadName
    environment: environment
    regionCode: regionCode
    instance: instance
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    secretsOfficerGroupIds: secretsOfficerGroupIds
    secretsReaderGroupIds: secretsReaderGroupIds
    costCenter: costCenter
    owner: owner
    applicationName: applicationName
  }
}

module sql './sql-database/main.bicep' = {
  name: 'sql-${workloadName}-${environment}'
  params: {
    workloadName: workloadName
    environment: environment
    regionCode: regionCode
    instance: instance
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    skuName: sqlSkuName
    skuTier: sqlSkuTier
    entraAdminGroupId: sqlEntraAdminGroupId
    entraAdminGroupName: sqlEntraAdminGroupName
    privateEndpointSubnetId: network.outputs.subnetIds['private-endpoints']
    privateDnsZoneId: sqlPrivateDnsZoneId
    costCenter: costCenter
    owner: owner
    applicationName: applicationName
  }
}

module vm './vm/main.bicep' = {
  name: 'vm-${workloadName}-${environment}'
  params: {
    workloadName: workloadName
    environment: environment
    regionCode: regionCode
    instance: instance
    subnetResourceId: network.outputs.subnetIds['vm']
    adminUsername: vmAdminUsername
    adminPassword: vmAdminPassword
    vmSize: vmSize
    costCenter: costCenter
    owner: owner
    applicationName: applicationName
  }
}

output vnetId string = network.outputs.vnetId
output vmId string = vm.outputs.vmId
output vmName string = vm.outputs.vmName
output vmPrivateIpAddress string = vm.outputs.privateIpAddress
output storageAccountId string = storage.outputs.storageAccountId
output storageAccountName string = storage.outputs.storageAccountName
output keyVaultId string = keyVault.outputs.vaultId
output keyVaultName string = keyVault.outputs.vaultName
output sqlServerId string = sql.outputs.serverId
output sqlServerFqdn string = sql.outputs.serverFqdn
output sqlDatabaseName string = sql.outputs.databaseName
