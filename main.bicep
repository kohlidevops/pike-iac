
 // pike-platform :: root deployment

@description('Workload name.')
param workloadName string = 'sampleapp'

@allowed(['dev', 'stg', 'prod'])
@description('Deployment environment.')
param environment string = 'dev'

@description('Azure region short code used in resource names.')
param regionCode string = 'centralindia'

@description('Zero-padded resource instance number.')
param instance string = '001'

@description('Resource ID of the central Log Analytics workspace. Leave empty while diagnostics are disabled.')
param logAnalyticsWorkspaceId string = ''

@description('Enable Azure SQL deployment.')
param deploySql bool = false

@description('Microsoft Entra administrator object ID for SQL Server.')
param sqlEntraAdminObjectId string = ''

@description('Microsoft Entra administrator login name (UPN) for SQL Server.')
param sqlEntraAdminLogin string = ''

@description('Tenant ID containing the SQL administrator.')
param sqlEntraTenantId string = subscription().tenantId

@description('Cost center tag.')
param costCenter string

@description('Owning team name.')
param owner string

@description('Application/service name.')
param applicationName string

@description('VNet address prefixes.')
param addressPrefixes array = [
  '10.40.0.0/16'
]

@description('VM subnet address prefix.')
param vmSubnetPrefix string = '10.40.1.0/24'

@description('Private endpoint subnet address prefix reserved for future use.')
param privateEndpointSubnetPrefix string = '10.40.2.0/24'

@description('SQL database SKU name.')
param sqlSkuName string = 'GP_S_Gen5_2'

@description('SQL database SKU tier.')
param sqlSkuTier string = 'GeneralPurpose'

@description('Windows VM SKU.')
param vmSize string = 'Standard_B2s'

@description('Windows local administrator username.')
param vmAdminUsername string = 'azureadmin'

@secure()
@description('Windows local administrator password supplied securely from CI.')
param vmAdminPassword string

@description('Key Vault Secrets Officer Entra group Object IDs.')
param secretsOfficerGroupIds array = []

@description('Key Vault Secrets User Entra group Object IDs.')
param secretsReaderGroupIds array = []

// 1. Networking
module network './network/main.bicep' = {
  name: 'network-${workloadName}-${environment}'
  params: {
    workloadName: workloadName
    environment: environment
    regionCode: regionCode
    instance: instance
    addressPrefixes: addressPrefixes
    subnets: [
      {
        name: 'vm'
        addressPrefix: vmSubnetPrefix
      }
      {
        name: 'private-endpoints'
        addressPrefix: privateEndpointSubnetPrefix
      }
    ]
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    costCenter: costCenter
    owner: owner
    applicationName: applicationName
  }
}

// 2. Storage Account
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

// 3. Key Vault
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

// 4. SQL Server and database
module sql './sql-database/main.bicep' = if (deploySql) {
  name: 'sql-${workloadName}-${environment}'
  params: {
    workloadName: workloadName
    environment: environment
    regionCode: regionCode
    instance: instance
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    skuName: sqlSkuName
    skuTier: sqlSkuTier
    entraAdminObjectId: sqlEntraAdminObjectId
    entraAdminLogin: sqlEntraAdminLogin
    entraTenantId: sqlEntraTenantId
    costCenter: costCenter
    owner: owner
    applicationName: applicationName
  }
}

// 5. Windows VM
module vm './vm/main.bicep' = {
  name: 'vm-${workloadName}-${environment}'
  params: {
    workloadName: workloadName
    environment: environment
    regionCode: regionCode
    instance: instance
    subnetResourceId: network.outputs.subnetIds.vm
    adminUsername: vmAdminUsername
    adminPassword: vmAdminPassword
    vmSize: vmSize
    costCenter: costCenter
    owner: owner
    applicationName: applicationName
  }
}

// Deployment outputs
output vnetId string = network.outputs.vnetId
output vmId string = vm.outputs.vmId
output vmName string = vm.outputs.vmName
output vmPrivateIpAddress string = vm.outputs.privateIpAddress
output storageAccountId string = storage.outputs.storageAccountId
output storageAccountName string = storage.outputs.storageAccountName
output keyVaultId string = keyVault.outputs.vaultId
output keyVaultName string = keyVault.outputs.vaultName
output sqlServerId string = deploySql ? sql.outputs.serverId : ''
output sqlServerFqdn string = deploySql ? sql.outputs.serverFqdn : ''
output sqlDatabaseName string = deploySql ? sql.outputs.databaseName : ''
