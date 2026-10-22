using './main.bicep'

// Environment-specific configuration. Secrets are injected from GitHub Actions secrets.
param resourceGroupName = 'rg-test-dev'
param location = 'centralus'
param environment = 'dev'
param prefix = 'testdev'
param tags = {
  Workload: 'EaaS'
  Owner: 'CloudOps'
  CostCenter: 'CC1001'
}

param vmAdminUsername = 'azureadmin'
param vmAdminPassword = readEnvironmentVariable('VM_ADMIN_PASSWORD')
param vmSize = 'Standard_B2s'
param vnetAddressPrefix = '10.40.0.0/16'
param vmSubnetAddressPrefix = '10.40.1.0/24'
param nsgRules = []

param storageSkuName = 'Standard_LRS'
param keyVaultSkuName = 'standard'

param sqlAdminLogin = 'sqladminuser'
param sqlAdminPassword = readEnvironmentVariable('SQL_ADMIN_PASSWORD')
param sqlDatabaseSkuName = 'Basic'
param sqlDatabaseMaxSizeBytes = 2147483648
param sqlPublicNetworkAccess = 'Enabled'

param rbacPrincipalId = readEnvironmentVariable('RBAC_PRINCIPAL_ID')
param rbacPrincipalType = readEnvironmentVariable('RBAC_PRINCIPAL_TYPE')
// Reader role. Change only if the platform design explicitly requires another role.
param rbacRoleDefinitionGuid = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
