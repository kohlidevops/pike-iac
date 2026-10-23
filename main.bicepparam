// Root deployment parameters for a DEV environment.
// Replace all example IDs and organizational values before deployment.
// The password is read from VM_ADMIN_PASSWORD in the process environment;
// never place a real password in this file or commit it to source control.
using 'main.bicep'

param workloadName = 'sampleapp'
param environment = 'dev'
param regionCode = 'centralindia'
param instance = '001'
param logAnalyticsWorkspaceId = '/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<OBSERVABILITY_RG>/providers/Microsoft.OperationalInsights/workspaces/<LOG_ANALYTICS_WORKSPACE>'
param sqlPrivateDnsZoneId = '/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<DNS_RG>/providers/Microsoft.Network/privateDnsZones/privatelink.database.windows.net'
param sqlEntraAdminGroupId = '<ENTRA_GROUP_OBJECT_ID>'
param sqlEntraAdminGroupName = 'Azure - sampleapp SQL Admins'
param costCenter = 'CC-1001'
param owner = 'platform-team'
param applicationName = 'sampleapp'
param addressPrefixes = [
  '10.40.0.0/16'
]
param vmSubnetPrefix = '10.40.1.0/24'
param privateEndpointSubnetPrefix = '10.40.2.0/24'
param sqlSkuName = 'GP_S_Gen5_2'
param sqlSkuTier = 'GeneralPurpose'
param vmSize = 'Standard_B2s'
param vmAdminUsername = 'azureadmin'
param vmAdminPassword = readEnvironmentVariable('VM_ADMIN_PASSWORD')
param secretsOfficerGroupIds = []
param secretsReaderGroupIds = []
