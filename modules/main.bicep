
targetScope = 'subscription'

@description('Deployment environment.')
@allowed([
  'dev'
  'test'
  'uat'
  'prod'
])
param environment string

@description('Default Azure region.')
param location string

@description('Landing zone configuration.')
param landingZones object

@secure()
@description('Windows VM administrator password.')
param vmAdminPassword string

@secure()
@description('SQL administrator password.')
param sqlAdminPassword string

// 1. Resource Groups
module resourceGroupModules './resourcegroup.bicep' = [
  for rg in landingZones.resourceGroups: {
    name: 'rg-${rg.rgName}'
    params: {
      rgname: rg.rgName
      location: rg.location
      tags: rg.tags
    }
  }
]

// 2. Network Security Groups
module nsgModules './networking/nsg.bicep' = [
  for nsg in landingZones.nsgs: {
    name: 'nsg-${nsg.name}'
    scope: resourceGroup(nsg.resourceGroupName)
    params: {
      nsgName: nsg.name
      location: nsg.location
      securityRules: nsg.securityRules
      tags: nsg.tags
    }
    dependsOn: [
      resourceGroupModules
    ]
  }
]

// 3. Route Tables
module routeTableModules './networking/routetable.bicep' = [
  for rt in landingZones.routeTables: {
    name: 'rt-${rt.name}'
    scope: resourceGroup(rt.resourceGroupName)
    params: {
      routeTableName: rt.name
      location: rt.location
      disableBgpRoutePropagation: rt.disableBgpRoutePropagation
      routes: rt.routes
      tags: rt.tags
    }
    dependsOn: [
      resourceGroupModules
    ]
  }
]

// 4. Virtual Networks and complete subnet configuration
module vnetModules './networking/vnet.bicep' = [
  for vnet in landingZones.vnets: {
    name: 'vnet-${vnet.name}'
    scope: resourceGroup(vnet.resourceGroupName)
    params: {
      vnetName: vnet.name
      location: vnet.location
      addressPrefixes: vnet.addressPrefixes
      dnsServers: vnet.dnsServers
      tags: vnet.tags

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
              id: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${vnet.resourceGroupName}/providers/Microsoft.Network/networkSecurityGroups/${subnet.networkSecurityGroupName}'
            } : null

            routeTable: !empty(subnet.routeTableName) ? {
              id: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${vnet.resourceGroupName}/providers/Microsoft.Network/routeTables/${subnet.routeTableName}'
            } : null
          }
        }
      )
    }
    dependsOn: [
      resourceGroupModules
      nsgModules
      routeTableModules
    ]
  }
]

// 5. Storage Accounts
module storageAccountModules './storage/storageAccount.bicep' = [
  for storage in landingZones.storageAccounts: {
    name: 'storage-${storage.name}'
    scope: resourceGroup(storage.resourceGroupName)
    params: {
      storageAccountName: storage.name
      location: storage.location
      skuName: storage.skuName
      kind: storage.kind
      accessTier: storage.accessTier
      minimumTlsVersion: storage.minimumTlsVersion
      supportsHttpsTrafficOnly: storage.supportsHttpsTrafficOnly
      allowBlobPublicAccess: storage.allowBlobPublicAccess
      allowSharedKeyAccess: storage.allowSharedKeyAccess
      publicNetworkAccess: storage.publicNetworkAccess
      blobServiceName: storage.blobServiceName
      containerNames: storage.containerNames
      containerPublicAccess: storage.containerPublicAccess
      tags: storage.tags
    }
    dependsOn: [
      resourceGroupModules
    ]
  }
]

// 6. Key Vaults
module keyVaultModules './security/keyvault.bicep' = [
  for kv in landingZones.keyVaults: {
    name: 'keyvault-${kv.name}'
    scope: resourceGroup(kv.resourceGroupName)
    params: {
      keyVaultName: kv.name
      location: kv.location
      tenantId: tenant().tenantId
      skuName: kv.skuName
      skuFamily: kv.skuFamily
      enableRbacAuthorization: kv.enableRbacAuthorization
      enablePurgeProtection: kv.enablePurgeProtection
      softDeleteRetentionInDays: kv.softDeleteRetentionInDays
      publicNetworkAccess: kv.publicNetworkAccess
      tags: kv.tags
    }
    dependsOn: [
      resourceGroupModules
    ]
  }
]

// 7. Windows Virtual Machines
module windowsVmModules './compute/vm.bicep' = [
  for vm in landingZones.vms: {
    name: 'vm-${vm.name}'
    scope: resourceGroup(vm.resourceGroupName)
    params: {
      vmName: vm.name
      computerName: vm.computerName
      location: vm.location
      adminUsername: vm.adminUsername
      vmAdminPassword: vmAdminPassword
      vmSize: vm.vmSize
      imagePublisher: vm.imagePublisher
      imageOffer: vm.imageOffer
      imageSku: vm.imageSku
      imageVersion: vm.imageVersion
      osDiskCreateOption: vm.osDiskCreateOption
      osDiskSizeGB: vm.osDiskSizeGB
      osDiskStorageAccountType: vm.osDiskStorageAccountType
      enableBootDiagnostics: vm.enableBootDiagnostics
      nicName: vm.nicName
      useExistingNic: vm.?useExistingNic ?? false
      vnetName: vm.vnetName
      subnetName: vm.subnetName
      privateIpAllocationMethod: vm.privateIpAllocationMethod
      tags: vm.tags
    }
    dependsOn: [
      resourceGroupModules
      vnetModules
    ]
  }
]

// 8. SQL Servers and Databases
module sqlModules './database/sql.bicep' = [
  for sql in landingZones.sqlDatabases: {
    name: 'sql-${sql.serverName}'
    scope: resourceGroup(sql.resourceGroupName)
    params: {
      serverName: sql.serverName
      location: sql.location
      administratorLogin: sql.administratorLogin
      administratorLoginPassword: sqlAdminPassword
      sqlServerVersion: sql.sqlServerVersion
      databaseName: sql.databaseName
      databaseSkuName: sql.databaseSkuName
      databaseSkuTier: sql.databaseSkuTier
      databaseCapacity: sql.databaseCapacity
      databaseMaxSizeBytes: sql.databaseMaxSizeBytes
      publicNetworkAccess: sql.publicNetworkAccess
      minimumTlsVersion: sql.minimumTlsVersion
      tags: sql.tags
    }
    dependsOn: [
      resourceGroupModules
    ]
  }
]

// 9. Azure OpenAI Services
module openAiModules './ai/openai.bicep' = [
  for openAi in landingZones.openAiServices: {
    name: 'openai-${openAi.name}'
    scope: resourceGroup(openAi.resourceGroupName)
    params: {
      accountName: openAi.name
      location: openAi.location
      skuName: openAi.skuName
      customSubDomainName: openAi.customSubDomainName
      publicNetworkAccess: openAi.publicNetworkAccess
      tags: openAi.tags
    }
    dependsOn: [
      resourceGroupModules
    ]
  }
]
