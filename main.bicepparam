// Root deployment parameters for a DEV environment.
// Replace example IDs and organizational values before deployment.
// The password is read from VM_ADMIN_PASSWORD in the process environment.
// Never place a real password in this file or commit it to source control.

using 'main.bicep'

param workloadName = 'sampleapp'
param environment = 'dev'
param regionCode = 'centralus'
param instance = '001'

// Existing shared infrastructure prerequisites
param logAnalyticsWorkspaceId = '/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<OBSERVABILITY_RG>/providers/Microsoft.OperationalInsights/workspaces/<LOG_ANALYTICS_WORKSPACE>'

param sqlPrivateDnsZoneId = '/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<DNS_RG>/providers/Microsoft.Network/privateDnsZones/privatelink.database.windows.net'

param sqlEntraAdminGroupId = '<ENTRA_GROUP_OBJECT_ID>'
param sqlEntraAdminGroupName = 'Azure - sampleapp SQL Admins'

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

// SQL
param sqlSkuName = 'GP_S_Gen5_2'
param sqlSkuTier = 'GeneralPurpose'

// Windows VM
param vmSize = 'Standard_B2s'
param vmAdminUsername = 'azureadmin'
param vmAdminPassword = readEnvironmentVariable('VM_ADMIN_PASSWORD')

// Key Vault access groups
param secretsOfficerGroupIds = []
param secretsReaderGroupIds = []
