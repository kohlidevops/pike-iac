
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

// Resource groups.
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

// Virtual networks with their complete subnet collections.
module vnetModules './networking/vnet.bicep' = [
  for vnet in landingZones.vnets: {
    name: 'vnet-${vnet.name}'
    scope: resourceGroup(vnet.resourceGroupName)
    dependsOn: [
      resourceGroupModules
      nsgModules
      routeTableModules
    ]
    params: {
      location: vnet.location
      vnetName: vnet.name
      addressPrefixes: vnet.addressPrefixes
      tags: vnet.tags
      dnsServers: vnet.dnsServers

      subnets: map(
        filter(
          landingZones.subnets,
          subnet => subnet.vnetName == vnet.name
        ),
        subnet => {
          name: subnet.name
          properties: {
            addressPrefix: subnet.addressPrefix
            serviceEndpoints: subnet.serviceEndpoints
            privateEndpointNetworkPolicies: subnet.privateEndpointNetworkPolicies
            privateLinkServiceNetworkPolicies: subnet.privateLinkServiceNetworkPolicies

            networkSecurityGroup: !empty(subnet.networkSecurityGroupName) ? {
              id: resourceId(
                vnet.resourceGroupName,
                'Microsoft.Network/networkSecurityGroups',
                subnet.networkSecurityGroupName
              )
            } : null

            routeTable: !empty(subnet.routeTableName) ? {
              id: resourceId(
                vnet.resourceGroupName,
                'Microsoft.Network/routeTables',
                subnet.routeTableName
              )
            } : null
          }
        }
      )
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
      vnetModules
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
      useExistingNic: vm.?useExistingNic ?? false
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

// Azure SQL Server and databases.
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
