// DEV deployment parameters.
// SQL is temporarily disabled until the Entra administrator group is available.
// Diagnostics remain disabled until a Log Analytics workspace is configured.
// Never commit real passwords to source control.

using 'main.bicep'

param workloadName = 'sampleapp'
param environment = 'dev'
param regionCode = 'centralus'
param instance = '001'

// SQL deployment switch
param deploySql = false

// Required only when deploySql is true
param sqlEntraAdminGroupId = ''
param sqlEntraAdminGroupName = ''

// Governance tags
param costCenter = 'CC-1001'
param owner = 'platform-team'
param applicationName = 'sampleapp'

// Networking
param addressPrefixes = [
  '10.40.0.0/16'
]

param vmSubnetPrefix = '10.40.1.0/24'
param privateEndpointSubnetPrefix = '10.40.2.0/24'

// SQL SKU settings (unused while SQL is disabled)
param sqlSkuName = 'GP_S_Gen5_2'
param sqlSkuTier = 'GeneralPurpose'

// Windows VM
param vmSize = 'Standard_B2s'
param vmAdminUsername = 'azureadmin'
param vmAdminPassword = readEnvironmentVariable('VM_ADMIN_PASSWORD')

// Key Vault access groups
param secretsOfficerGroupIds = []
param secretsReaderGroupIds = []
