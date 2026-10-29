using '../modules/main.bicep'

param environment = 'dev'
param location = 'eastus'
param vmAdminPassword = readEnvironmentVariable('VM_ADMIN_PASSWORD')
param sqlAdminPassword = readEnvironmentVariable('SQL_ADMIN_PASSWORD')

param landingZones = {
  resourceGroups: [
    {
      rgName: 'rg-pikehex-dev-eastus-001'
      location: 'eastus'
      tags: {
        Environment: 'dev'
        Workload: 'pikehex-cloud-migration'
        ManagedBy: 'Bicep'
      }
    }
  ]

  vnets: [
    {
      name: 'vnet-pikehex-dev-001'
      resourceGroupName: 'rg-pikehex-dev-eastus-001'
      location: 'eastus'
      addressPrefixes: [
        '10.40.0.0/16'
      ]
      dnsServers: []
      tags: {
        Environment: 'dev'
        Workload: 'pikehex-cloud-migration'
        ManagedBy: 'Bicep'
      }
    }
  ]

  subnets: [
    {
      name: 'snet-app-dev-001'
      vnetName: 'vnet-pikehex-dev-001'
      resourceGroupName: 'rg-pikehex-dev-eastus-001'
      addressPrefix: '10.40.1.0/24'
      networkSecurityGroupName: 'nsg-pikehex-dev-001'
      routeTableName: 'rt-pikehex-dev-001'
      serviceEndpoints: []
      privateEndpointNetworkPolicies: 'Enabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
    }
  ]

  nsgs: [
    {
      name: 'nsg-pikehex-dev-001'
      resourceGroupName: 'rg-pikehex-dev-eastus-001'
      location: 'eastus'
      tags: {
        Environment: 'dev'
        Workload: 'pikehex-cloud-migration'
        ManagedBy: 'Bicep'
      }
      securityRules: []
    }
  ]

  routeTables: [
    {
      name: 'rt-pikehex-dev-001'
      resourceGroupName: 'rg-pikehex-dev-eastus-001'
      location: 'eastus'
      disableBgpRoutePropagation: false
      routes: []
      tags: {
        Environment: 'dev'
        Workload: 'pikehex-cloud-migration'
        ManagedBy: 'Bicep'
      }
    }
  ]

  vms: [
    {
      name: 'vm-pikehex-dev-001'
      computerName: 'vm-pike-dev-001'
      resourceGroupName: 'rg-pikehex-dev-eastus-001'
      location: 'eastus'
      adminUsername: 'azureadmin'
      vmSize: 'Standard_B2s'
      tags: {
        Environment: 'dev'
        Workload: 'pikehex-cloud-migration'
        ManagedBy: 'Bicep'
      }
      vnetName: 'vnet-pikehex-dev-001'
      subnetName: 'snet-app-dev-001'
      nicName: 'nic-pikehex-dev-001'
      privateIpAllocationMethod: 'Dynamic'
      imagePublisher: 'MicrosoftWindowsServer'
      imageOffer: 'WindowsServer'
      imageSku: '2022-datacenter-azure-edition'
      imageVersion: 'latest'
      osDiskStorageAccountType: 'StandardSSD_LRS'
      osDiskCreateOption: 'FromImage'
      osDiskSizeGB: 128
      enableBootDiagnostics: true
    }
  ]

  keyVaults: [
    {
      name: 'kv-pikehex-dev-001'
      resourceGroupName: 'rg-pikehex-dev-eastus-001'
      location: 'eastus'
      skuName: 'standard'
      skuFamily: 'A'
      enableRbacAuthorization: true
      enablePurgeProtection: true
      softDeleteRetentionInDays: 7
      publicNetworkAccess: 'Enabled'
      tags: {
        Environment: 'dev'
        Workload: 'pikehex-cloud-migration'
        ManagedBy: 'Bicep'
      }
    }
  ]

  storageAccounts: [
    {
      name: 'stpikehexdev001'
      resourceGroupName: 'rg-pikehex-dev-eastus-001'
      location: 'eastus'
      tags: {
        Environment: 'dev'
        Workload: 'pikehex-cloud-migration'
        ManagedBy: 'Bicep'
      }
      skuName: 'Standard_LRS'
      kind: 'StorageV2'
      accessTier: 'Hot'
      minimumTlsVersion: 'TLS1_2'
      supportsHttpsTrafficOnly: true
      allowBlobPublicAccess: false
      allowSharedKeyAccess: true
      publicNetworkAccess: 'Enabled'
      blobServiceName: 'default'
      containerNames: [
        'appdata'
      ]
      containerPublicAccess: 'None'
    }
  ]

  sqlDatabases: [
    {
      serverName: 'sql-pikehex-dev-001'
      databaseName: 'sqldb-pikehex-dev-001'
      resourceGroupName: 'rg-pikehex-dev-eastus-001'
      location: 'eastus'
      administratorLogin: 'pikehexsqladmin'
      sqlServerVersion: '12.0'
      databaseSkuName: 'Basic'
      databaseSkuTier: 'Basic'
      databaseCapacity: 5
      databaseMaxSizeBytes: 2147483648
      publicNetworkAccess: 'Disabled'
      minimumTlsVersion: '1.2'
      tags: {
        Environment: 'dev'
        Workload: 'pikehex-cloud-migration'
        ManagedBy: 'Bicep'
      }
    }
  ]
}
