targetScope = 'resourceGroup'

param location string
param environment string
param prefix string
param tags object
param vmAdminUsername string
@secure()
param vmAdminPassword string
param vmSize string
param vnetAddressPrefix string
param vmSubnetAddressPrefix string
param nsgRules array
param storageSkuName string
param keyVaultSkuName string
param sqlAdminLogin string
@secure()
param sqlAdminPassword string
param sqlDatabaseSkuName string
param sqlDatabaseMaxSizeBytes int
@allowed(['Enabled', 'Disabled'])
param sqlPublicNetworkAccess string
param rbacPrincipalId string
@allowed(['User', 'Group', 'ServicePrincipal', 'ForeignGroup', 'Device', 'ManagedIdentity'])
param rbacPrincipalType string
param rbacRoleDefinitionGuid string

var baseName = '${prefix}-${environment}'
var vnetName = '${baseName}-vnet'
var nsgName = '${baseName}-nsg'
var vmName = '${baseName}-vm'
var storageAccountName = take(toLower(replace('${prefix}${environment}${uniqueString(resourceGroup().id)}sa', '-', '')), 24)
var keyVaultName = take(toLower(replace('${baseName}-kv-${uniqueString(resourceGroup().id)}', '-', '')), 24)
var sqlServerName = take(toLower(replace('${baseName}-sql-${uniqueString(resourceGroup().id)}', '-', '')), 63)
var sqlDatabaseName = '${baseName}-db'

module nsgModule '../networking/nsg.bicep' = {
  name: 'nsg-${uniqueString(resourceGroup().id)}'
  params: {
    location: location
    nsgName: nsgName
    securityRules: nsgRules
    tags: tags
  }
}

module vnetModule '../networking/vnet.bicep' = {
  name: 'vnet-${uniqueString(resourceGroup().id)}'
  params: {
    location: location
    vnetName: vnetName
    addressPrefix: vnetAddressPrefix
    tags: tags
  }
}

module subnetModule '../networking/subnet.bicep' = {
  name: 'subnet-${uniqueString(resourceGroup().id)}'
  params: {
    vnetName: vnetName
    subnetName: '${baseName}-snet-vm'
    addressPrefix: vmSubnetAddressPrefix
    networkSecurityGroupId: nsgModule.outputs.nsgId
  }
  dependsOn: [vnetModule]
}

module vmModule '../compute/windowsVm.bicep' = {
  name: 'vm-${uniqueString(resourceGroup().id)}'
  params: {
    location: location
    vmName: vmName
    subnetId: subnetModule.outputs.subnetId
    adminUsername: vmAdminUsername
    adminPassword: vmAdminPassword
    vmSize: vmSize
    tags: tags
  }
}

module storageModule '../storage/storageAccount.bicep' = {
  name: 'storage-${uniqueString(resourceGroup().id)}'
  params: {
    location: location
    storageAccountName: storageAccountName
    skuName: storageSkuName
    tags: tags
  }
}

module keyVaultModule '../security/keyVault.bicep' = {
  name: 'keyvault-${uniqueString(resourceGroup().id)}'
  params: {
    location: location
    keyVaultName: keyVaultName
    skuName: keyVaultSkuName
    tags: tags
  }
}

module sqlModule '../database/azureSql.bicep' = {
  name: 'sql-${uniqueString(resourceGroup().id)}'
  params: {
    location: location
    sqlServerName: sqlServerName
    databaseName: sqlDatabaseName
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    databaseSkuName: sqlDatabaseSkuName
    databaseMaxSizeBytes: sqlDatabaseMaxSizeBytes
    publicNetworkAccess: sqlPublicNetworkAccess
    tags: tags
  }
}

module rbacModule '../security/rbac.bicep' = {
  name: 'rbac-${uniqueString(resourceGroup().id)}'
  params: {
    principalId: rbacPrincipalId
    principalType: rbacPrincipalType
    roleDefinitionGuid: rbacRoleDefinitionGuid
    roleAssignmentName: guid(resourceGroup().id, rbacPrincipalId, rbacRoleDefinitionGuid)
  }
}

output vnetName string = vnetName
output vmName string = vmModule.outputs.vmName
output storageAccountName string = storageModule.outputs.storageAccountName
output keyVaultName string = keyVaultModule.outputs.keyVaultName
output sqlServerName string = sqlModule.outputs.sqlServerName
output sqlDatabaseName string = sqlModule.outputs.databaseName
