// pike-platform :: modules/vm
// Provisions a Windows Server VM on an existing subnet. Network security is delegated
// to the subnet/NSG managed by modules/network; this module creates no public IP.
// Local administrator password is supplied securely; system-assigned identity and
// Trusted Launch security defaults are enabled.

@description('Workload name, e.g. "checkout".')
param workloadName string

@allowed(['dev', 'qa', 'uat', 'stg', 'prod'])
@description('Environment. Must match the workload deployment target.')
param environment string

@description('Azure region short code, e.g. "eastus2".')
param regionCode string = 'eastus2'

@description('Instance number, zero-padded. Default 001.')
param instance string = '001'

@description('Existing subnet resource ID where the VM NIC will be attached.')
param subnetResourceId string

@description('Windows local administrator username.')
param adminUsername string = 'azureadmin'

@secure()
@description('Windows local administrator password. Supply via a secure pipeline secret; never commit a real password.')
param adminPassword string

@description('Azure VM size.')
param vmSize string = 'Standard_B2s'

@description('Windows image publisher.')
param imagePublisher string = 'MicrosoftWindowsServer'

@description('Windows image offer.')
param imageOffer string = 'WindowsServer'

@description('Windows image SKU. Default is Windows Server 2022 Datacenter Gen2.')
param imageSku string = '2022-datacenter-g2'

@description('Windows image version. Use latest for the publisher-maintained current image version.')
param imageVersion string = 'latest'

@description('OS disk size in GiB.')
@minValue(127)
param osDiskSizeGb int = 128

@description('Cost center tag — required for FinOps chargeback.')
param costCenter string

@description('Owning team name, not an individual.')
param owner string

@description('Application/service name as it appears in the portal catalog.')
param applicationName string

var location = resourceGroup().location
var vmName = take('vm-${workloadName}-${environment}-${regionCode}-${instance}', 64)
var computerName = take('win-${workloadName}-${environment}-${instance}', 15)
var nicName = take('nic-${workloadName}-${environment}-${regionCode}-${instance}', 80)

var mandatoryTags = {
  CostCenter: costCenter
  Environment: environment
  Owner: owner
  Application: applicationName
  ManagedBy: 'pike-platform'
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: nicName
  location: location
  tags: mandatoryTags
  properties: {
    enableAcceleratedNetworking: false
    ipConfigurations: [
      {
        name: 'ipconfig-primary'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetResourceId
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  tags: mandatoryTags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        name: '${vmName}-osdisk'
        createOption: 'FromImage'
        diskSizeGB: osDiskSizeGb
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    osProfile: {
      computerName: computerName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        patchSettings: {
          assessmentMode: 'ImageDefault'
          patchMode: 'AutomaticByOS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            primary: true
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
  }
}

@description('Resource ID of the created virtual machine.')
output vmId string = vm.id

@description('Name of the created virtual machine.')
output vmName string = vm.name

@description('Resource ID of the created network interface.')
output networkInterfaceId string = nic.id

@description('Private IP address assigned to the VM NIC.')
output privateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress

@description('Principal ID of the VM system-assigned managed identity.')
output principalId string = vm.identity.principalId
