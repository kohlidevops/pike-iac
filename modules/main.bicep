targetScope = 'subscription'

@description('Deployment environment.')
@allowed([
  'dev'
  'test'
  'uat'
  'prod'
])
param environment string

@description('Default Azure region for this environment.')
param location string

@description('Configuration-driven resource inventory. Add entries to scale deployments.')
param landingZones object

@secure()
@description('Local administrator password for Windows virtual machines.')
param vmAdminPassword string

@secure()
@description('SQL Server administrator password.')
param sqlAdminPassword string

// Resource groups are declared in the parameter file and created first.
module resourceGroupModules './resourcegroup.bicep' = [
  for rg in landingZones.resourceGroups: {
    name: 'rg-${rg.rgName}'
    scope: subscription()
    params: {
      rgname: rg.rgName
      location: rg.location
      tags: rg.tags
    }
  }
]

// Network security groups.
module nsgModules './networking/nsg.bicep' = [
  for nsg in landingZones.nsgs: {
    name: 'nsg-${nsg.name}'
    scope: resourceGroup(nsg.resourceGroupName)
    dependsOn: [
      resourceGroupModules
    ]
    params: {
      location: nsg.location
      nsgName: nsg.name
      securityRules: nsg.securityRules
      tags: nsg.tags
    }
  }
]

// Route tables.
module routeTableModules './networking/routetable.bicep' = [
  for routeTable in landingZones.routeTables: {
    name: 'rt-${routeTable.name}'
    scope: resourceGroup(routeTable.resourceGroupName)
    dependsOn: [
      resourceGroupModules
    ]
    params: {
      routeTableName: routeTable.name
      location: routeTable.location
      disableBgpRoutePropagation: routeTable.disableBgpRoutePropagation
      routes: routeTable.routes
      tags: routeTable.tags
    }
  }
]

// Virtual networks are separate from subnet resources.
module vnetModules './networking/vnet.bicep' = [
  for vnet in landingZones.vnets: {
    name: 'vnet-${vnet.name}'
    scope: resourceGroup(vnet.resourceGroupName)
    dependsOn: [
      resourceGroupModules
    ]
    params: {
      location: vnet.location
      vnetName: vnet.name
      addressPrefixes: vnet.addressPrefixes
      tags: vnet.tags
      dnsServers: vnet.dnsServers
    }
  }
]

// Subnets are individually reusable modules and can be scaled by adding array entries.
module subnetModules './networking/subnet.bicep' = [
  for subnet in landingZones.subnets: {
    name: 'subnet-${subnet.vnetName}-${subnet.name}'
    scope: resourceGroup(subnet.resourceGroupName)
    dependsOn: [
      resourceGroupModules
      vnetModules
      nsgModules
      routeTableModules
    ]
    params: {
      vnetName: subnet.vnetName
      subnetName: subnet.name
      addressPrefix: subnet.addressPrefix
      networkSecurityGroupName: subnet.networkSecurityGroupName
      routeTableName: subnet.routeTableName
      serviceEndpoints: subnet.serviceEndpoints
      privateEndpointNetworkPolicies: subnet.privateEndpointNetworkPolicies
      privateLinkServiceNetworkPolicies: subnet.privateLinkServiceNetworkPolicies
    }
  }
]

// Storage accounts.
module storageAccountModules './storage/storageAccount.bicep' = [
  for storage in landingZones.storageAccounts: {
    name: 'storage-${storage.name}'
    scope: resourceGroup(storage.resourceGroupName)
    dependsOn: [
      resourceGroupModules
    ]
    params: {
      storageAccountName: storage.name
      location: storage.location
      tags: storage.tags
      skuName: storage.skuName
      kind: storage.kind
      accessTier: storage.accessTier
      minimumTlsVersion: storage.minimumTlsVersion
      supportsHttpsTrafficOnly: storage.supportsHttpsTrafficOnly
      allowBlobPublicAccess: storage.allowBlobPublicAccess
      allowSharedKeyAccess: storage.allowSharedKeyAccess
      publicNetworkAccess: storage.publicNetworkAccess
      containerNames: storage.containerNames
      blobServiceName: storage.blobServiceName
      containerPublicAccess: storage.containerPublicAccess
    }
  }
]

// Key Vaults.
module keyVaultModules './security/keyvault.bicep' = [
  for keyVault in landingZones.keyVaults: {
    name: 'keyvault-${keyVault.name}'
    scope: resourceGroup(keyVault.resourceGroupName)
    dependsOn: [
      resourceGroupModules
    ]
    params: {
      keyVaultName: keyVault.name
      location: keyVault.location
      tenantId: subscription().tenantId
      skuName: keyVault.skuName
      skuFamily: keyVault.skuFamily
      enableRbacAuthorization: keyVault.enableRbacAuthorization
      enablePurgeProtection: keyVault.enablePurgeProtection
      softDeleteRetentionInDays: keyVault.softDeleteRetentionInDays
      publicNetworkAccess: keyVault.publicNetworkAccess
      tags: keyVault.tags
    }
  }
]

// Windows virtual machines.
module windowsVmModules './compute/vm.bicep' = [
  for vm in landingZones.vms: {
    name: 'vm-${vm.name}'
    scope: resourceGroup(vm.resourceGroupName)
    dependsOn: [
      resourceGroupModules
      subnetModules
    ]
    params: {
      location: vm.location
      vmName: vm.name
      computerName: vm.computerName
      adminUsername: vm.adminUsername
      vmAdminPassword: vmAdminPassword
      vmSize: vm.vmSize
      tags: vm.tags
      vnetName: vm.vnetName
      subnetName: vm.subnetName
      nicName: vm.nicName
      privateIpAllocationMethod: vm.privateIpAllocationMethod
      imagePublisher: vm.imagePublisher
      imageOffer: vm.imageOffer
      imageSku: vm.imageSku
      imageVersion: vm.imageVersion
      osDiskStorageAccountType: vm.osDiskStorageAccountType
      osDiskCreateOption: vm.osDiskCreateOption
      osDiskSizeGB: vm.osDiskSizeGB
      enableBootDiagnostics: vm.enableBootDiagnostics
    }
  }
]

/*
// Azure SQL Server and database.
module sqlModules './database/sql.bicep' = [
  for sql in landingZones.sqlDatabases: {
    name: 'sql-${sql.serverName}'
    scope: resourceGroup(sql.resourceGroupName)
    dependsOn: [
      resourceGroupModules
    ]
    params: {
      location: sql.location
      serverName: sql.serverName
      databaseName: sql.databaseName
      administratorLogin: sql.administratorLogin
      administratorLoginPassword: sqlAdminPassword
      sqlServerVersion: sql.sqlServerVersion
      databaseSkuName: sql.databaseSkuName
      databaseSkuTier: sql.databaseSkuTier
      databaseCapacity: sql.databaseCapacity
      databaseMaxSizeBytes: sql.databaseMaxSizeBytes
      publicNetworkAccess: sql.publicNetworkAccess
      minimumTlsVersion: sql.minimumTlsVersion
      tags: sql.tags
    }
  }
]
*/
