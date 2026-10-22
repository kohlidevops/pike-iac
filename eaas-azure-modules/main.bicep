targetScope = 'subscription'

@description('Target resource group name for this environment.')
param resourceGroupName string
@description('Azure region for the resource group and resources.')
param location string
@description('Environment identifier used in names and tags.')
@minLength(2)
@maxLength(12)
param environment string
@description('Short workload prefix. Use lowercase letters and digits where resource naming rules require it.')
@minLength(2)
@maxLength(10)
param prefix string
param tags object

@description('Azure VM administrator username.')
param vmAdminUsername string
@secure()
@description('VM administrator password supplied through a GitHub Actions secret/environment variable.')
param vmAdminPassword string
@description('Azure VM size for this environment.')
param vmSize string
@description('Virtual network address space in CIDR notation.')
param vnetAddressPrefix string
@description('VM subnet address range in CIDR notation.')
param vmSubnetAddressPrefix string
@description('NSG rules to apply to the VM subnet. Avoid broad inbound rules from Internet.')
param nsgRules array
@description('Storage account SKU, e.g. Standard_LRS.')
param storageSkuName string
@description('Key Vault SKU.')
@allowed(['standard', 'premium'])
param keyVaultSkuName string
@description('SQL administrator login name.')
param sqlAdminLogin string
@secure()
@description('SQL administrator password supplied through a GitHub Actions secret/environment variable.')
param sqlAdminPassword string
@description('Azure SQL database SKU name, e.g. Basic or GP_S_Gen5_1.')
param sqlDatabaseSkuName string
@description('Maximum Azure SQL database size in bytes.')
param sqlDatabaseMaxSizeBytes int
@description('Whether the SQL server public endpoint is enabled. Use Disabled with private networking for production.')
@allowed(['Enabled', 'Disabled'])
param sqlPublicNetworkAccess string
@description('Entra object ID receiving the configured RBAC role at the resource-group scope.')
param rbacPrincipalId string
@description('Entra principal type for the RBAC assignment.')
@allowed(['User', 'Group', 'ServicePrincipal', 'ForeignGroup', 'Device', 'ManagedIdentity'])
param rbacPrincipalType string
@description('Built-in/custom role definition GUID.')
param rbacRoleDefinitionGuid string

var commonTags = union(tags, {
  Environment: environment
  ManagedBy: 'Bicep'
})

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: commonTags
}

module workload './modules/resource-group/workload.bicep' = {
  name: 'workload-${uniqueString(subscription().id, resourceGroupName, environment)}'
  scope: rg
  params: {
    location: location
    environment: environment
    prefix: prefix
    tags: commonTags
    vmAdminUsername: vmAdminUsername
    vmAdminPassword: vmAdminPassword
    vmSize: vmSize
    vnetAddressPrefix: vnetAddressPrefix
    vmSubnetAddressPrefix: vmSubnetAddressPrefix
    nsgRules: nsgRules
    storageSkuName: storageSkuName
    keyVaultSkuName: keyVaultSkuName
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
    sqlDatabaseSkuName: sqlDatabaseSkuName
    sqlDatabaseMaxSizeBytes: sqlDatabaseMaxSizeBytes
    sqlPublicNetworkAccess: sqlPublicNetworkAccess
    rbacPrincipalId: rbacPrincipalId
    rbacPrincipalType: rbacPrincipalType
    rbacRoleDefinitionGuid: rbacRoleDefinitionGuid
  }
}

output resourceGroupName string = rg.name
output resourceGroupId string = rg.id
output resourceGroupLocation string = rg.location
output vnetName string = workload.outputs.vnetName
output vmName string = workload.outputs.vmName
output storageAccountName string = workload.outputs.storageAccountName
output keyVaultName string = workload.outputs.keyVaultName
output sqlServerName string = workload.outputs.sqlServerName
output sqlDatabaseName string = workload.outputs.sqlDatabaseName
