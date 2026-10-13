targetScope = 'resourceGroup'

param location string = 'centralus'
param prefix string = 'testdev'

param tags object = {
  Environment: 'Dev'
  ManagedBy: 'Bicep'
  Workload: 'EaaS'
}

@description('Entra object ID of the user, group, or service principal receiving the role.')
param rbacPrincipalId string

@description('Built-in/custom role definition GUID. Reader is the default least-privilege example.')
param rbacRoleDefinitionGuid string = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'

@description('Entra principal type for the RBAC assignment.')
@allowed([
  'User'
  'Group'
  'ServicePrincipal'
  'ForeignGroup'
  'Device'
  'ManagedIdentity'
])
param rbacPrincipalType string = 'ServicePrincipal'

@secure()
param vmAdminPassword string

param sqlAdminLogin string = 'sqladminuser'

@secure()
param sqlAdminPassword string

@allowed([
  'dotnet-isolated'
  'node'
  'python'
  'java'
  'powershell'
])
param functionRuntime string = 'dotnet-isolated'

param functionRuntimeVersion string = '8.0'

param sqlDatabaseSkuName string = 'Basic'

@description('Container image used by the Azure Container App.')
param containerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

var vnetName = '${prefix}-vnet'

var nsgName = '${prefix}-nsg'

var storageAccountName = take(
  toLower(
    replace(
      '${prefix}${uniqueString(resourceGroup().id)}sa',
      '-',
      ''
    )
  ),
  24
)

var keyVaultName = take(
  toLower(
    replace(
      '${prefix}-kv-${uniqueString(resourceGroup().id)}',
      '-',
      ''
    )
  ),
  24
)

var vmName = '${prefix}-winvm'

var sqlServerName = take(
  toLower(
    replace(
      '${prefix}-sql-${uniqueString(resourceGroup().id)}',
      '-',
      ''
    )
  ),
  63
)

var sqlDatabaseName = '${prefix}-db'

var functionStorageName = take(
  toLower(
    replace(
      '${prefix}${uniqueString(resourceGroup().id)}funcsa',
      '-',
      ''
    )
  ),
  24
)

var functionAppName = take(
  toLower(
    replace(
      '${prefix}-func-${uniqueString(resourceGroup().id)}',
      '-',
      ''
    )
  ),
  60
)

var appServicePlanName = '${prefix}-func-plan'

var acrName = take(
  toLower(
    replace(
      '${prefix}${uniqueString(resourceGroup().id)}acr',
      '-',
      ''
    )
  ),
  50
)

var containerAppName = '${prefix}-containerapp'

var containerAppsEnvironmentName = '${prefix}-containerapps-env'

var containerAppsWorkspaceName = '${prefix}-containerapps-law'


// ---------------------------------------------------------
// Networking
// ---------------------------------------------------------

module networkModule 'modules/networking/network.bicep' = {
  name: 'network-${uniqueString(resourceGroup().id)}'
  params: {
    location: location
    vnetName: vnetName
    nsgName: nsgName
    tags: tags
  }
}


// ---------------------------------------------------------
// Storage
// ---------------------------------------------------------

module storageModule 'modules/storage/storageAccount.bicep' = {
  name: 'storage-${uniqueString(resourceGroup().id)}'
  params: {
    location: location
    storageAccountName: storageAccountName
    tags: tags
  }
}


// ---------------------------------------------------------
// Key Vault
// ---------------------------------------------------------

module keyVaultModule 'modules/security/keyVault.bicep' = {
  name: 'keyvault-${uniqueString(resourceGroup().id)}'
  params: {
    location: location
    keyVaultName: keyVaultName
    tags: tags
  }
}


// ---------------------------------------------------------
// Windows VM
// ---------------------------------------------------------

module vmModule 'modules/compute/windowsVm.bicep' = {
  name: 'vm-${uniqueString(resourceGroup().id)}'
  params: {
    location: location
    vmName: vmName
    subnetId: networkModule.outputs.vmSubnetId
    nsgId: networkModule.outputs.nsgId
    adminUsername: 'azureadmin'
    adminPassword: vmAdminPassword
    vmSize: 'Standard_B2s'
    tags: tags
  }
}


// ---------------------------------------------------------
// Azure SQL
// ---------------------------------------------------------

module sqlModule 'modules/database/sqlServer.bicep' = {
  name: 'sql-${uniqueString(resourceGroup().id)}'
  params: {
    location: location
    sqlServerName: sqlServerName
    databaseName: sqlDatabaseName
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    databaseSkuName: sqlDatabaseSkuName
    publicNetworkAccess: 'Enabled'
    tags: tags
  }
}


// ---------------------------------------------------------
// Azure Function App
// ---------------------------------------------------------

module functionAppModule 'modules/apps/functionApp.bicep' = {
  name: 'function-${uniqueString(resourceGroup().id)}'
  params: {
    location: location
    functionAppName: functionAppName
    appServicePlanName: appServicePlanName
    storageAccountName: functionStorageName
    functionRuntime: functionRuntime
    functionRuntimeVersion: functionRuntimeVersion
    tags: tags
  }
}


// ---------------------------------------------------------
// Azure RBAC
// ---------------------------------------------------------

module rbacModule 'modules/security/rbac.bicep' = {
  name: 'rbac-${uniqueString(resourceGroup().id)}'
  params: {
    principalId: rbacPrincipalId
    roleDefinitionGuid: rbacRoleDefinitionGuid
    roleAssignmentName: guid(
      resourceGroup().id,
      rbacPrincipalId,
      rbacRoleDefinitionGuid
    )
    principalType: rbacPrincipalType
  }
}


// ---------------------------------------------------------
// Azure Container Registry
// ---------------------------------------------------------

module containerRegistryModule 'modules/containers/containerRegistry.bicep' = {
  name: 'acr-${uniqueString(resourceGroup().id)}'
  params: {
    location: location
    registryName: acrName
    tags: tags
  }
}


// ---------------------------------------------------------
// Azure Container Apps
// ---------------------------------------------------------

module containerAppModule 'modules/containers/containerApp.bicep' = {
  name: 'containerapp-${uniqueString(resourceGroup().id)}'
  params: {
    location: location
    containerAppName: containerAppName
    managedEnvironmentName: containerAppsEnvironmentName
    logAnalyticsWorkspaceName: containerAppsWorkspaceName
    containerImage: containerImage
    tags: tags
  }
}


// ---------------------------------------------------------
// Outputs
// ---------------------------------------------------------

output deployedResourceGroup string = resourceGroup().name

output deployedLocation string = location

output vnetName string = networkModule.outputs.vnetName

output vmName string = vmModule.outputs.vmName

output storageAccountName string = storageModule.outputs.storageAccountName

output keyVaultName string = keyVaultModule.outputs.keyVaultName

output sqlServerName string = sqlModule.outputs.sqlServerName

output sqlDatabaseName string = sqlModule.outputs.databaseName

output functionAppName string = functionAppModule.outputs.functionAppName

output functionStorageAccountName string = functionAppModule.outputs.storageAccountName

output containerRegistryName string = containerRegistryModule.outputs.registryName

output containerRegistryLoginServer string = containerRegistryModule.outputs.loginServer

output containerAppName string = containerAppModule.outputs.containerAppName

output containerAppUrl string = containerAppModule.outputs.containerAppUrl

output containerAppsEnvironmentName string = containerAppModule.outputs.managedEnvironmentName

output containerAppsLogAnalyticsWorkspaceName string = containerAppModule.outputs.logAnalyticsWorkspaceName
