
using 'main.bicep'

param workloadName = 'sampleapp'
param environment = 'dev'
param regionCode = 'centralus'
param instance = '001'

// SQL deployment
param deploySql = true

// Azure OpenAI deployment
param deployOpenAI = true
param openAiAccountName = 'pike-openai-sampleapp-dev-001'
param openAiSkuName = 'S0'
param openAiPublicNetworkAccess = 'Enabled'

// SQL administrator
param sqlEntraAdminObjectId = '3e7e4269-f773-4b01-9a41-2261bf9c558b'
param sqlEntraAdminLogin = 'sathish.vit099_gmail.com#EXT#@sathishvit099gmail.onmicrosoft.com'
param sqlEntraTenantId = 'ff360367-7322-4db4-97a7-ade6839352de'

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

// SQL SKU
param sqlSkuName = 'GP_Gen5_2'
param sqlSkuTier = 'GeneralPurpose'

// Windows VM
param vmSize = 'Standard_B2s'
param vmAdminUsername = 'azureadmin'
param vmAdminPassword = readEnvironmentVariable('VM_ADMIN_PASSWORD')

// Key Vault access groups
param secretsOfficerGroupIds = []
param secretsReaderGroupIds = []
