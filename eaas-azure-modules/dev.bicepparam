using './main.bicep'

param location = 'centralus'
param prefix = 'testdev'

param vmAdminPassword = readEnvironmentVariable('VM_ADMIN_PASSWORD')
param sqlAdminPassword = readEnvironmentVariable('SQL_ADMIN_PASSWORD')
param rbacPrincipalId = readEnvironmentVariable('RBAC_PRINCIPAL_ID')
param rbacPrincipalType = readEnvironmentVariable('RBAC_PRINCIPAL_TYPE')

param rbacRoleDefinitionGuid = 'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader
param sqlAdminLogin = 'sqladminuser'
param sqlDatabaseSkuName = 'Basic'
param functionRuntime = 'dotnet-isolated'
param functionRuntimeVersion = '8.0'
