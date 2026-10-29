using '../modules/main.bicep'

param environment = 'prod'
param location = 'eastus'
param vmAdminPassword = readEnvironmentVariable('VM_ADMIN_PASSWORD')
param sqlAdminPassword = readEnvironmentVariable('SQL_ADMIN_PASSWORD')

param landingZones = {
  resourceGroups: []
  vnets: []
  subnets: []
  nsgs: []
  routeTables: []
  vms: []
  keyVaults: []
  storageAccounts: []
  sqlDatabases: []
}
