// pike-platform :: modules/key-vault
// Wraps AVM's key-vault module. RBAC-based access model only — no vault
// access policies, per the "Entra ID groups only, no individual grants"
// rule in the marching-orders doc. Purge protection is on by default and
// is NOT a parameter — see rationale below.

@description('Workload name, e.g. "checkout".')
param workloadName string

@allowed(['dev', 'stg', 'prod'])
param environment string

@description('Azure region short code.')
param regionCode string = 'eastus2'

param instance string = '001'

@description('Resource ID of the central Log Analytics workspace.')
param logAnalyticsWorkspaceId string
param enableDiagnosticSettings bool = false

@description('Principal IDs (Entra ID GROUP object IDs, not users) granted Key Vault Secrets Officer.')
param secretsOfficerGroupIds array = []

@description('Principal IDs (Entra ID GROUP object IDs) granted Key Vault Secrets User (read-only).')
param secretsReaderGroupIds array = []

param costCenter string
param owner string
param applicationName string

var location = resourceGroup().location
// Key Vault names are capped at 24 chars and can't end in a hyphen — truncating
// blindly (like modules/storage-account does) can land the cut right after a
// separator. Strip a trailing hyphen if the truncation produces one.
var rawVaultName = take('kv-${workloadName}-${environment}-${regionCode}-${instance}', 24)
var vaultName = endsWith(rawVaultName, '-') ? take(rawVaultName, length(rawVaultName) - 1) : rawVaultName

var mandatoryTags = {
  CostCenter: costCenter
  Environment: environment
  Owner: owner
  Application: applicationName
  ManagedBy: 'pike-platform'
}

// Built-in role IDs — Key Vault Secrets Officer / Secrets User
var secretsOfficerRoleId = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
var secretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

var secretsOfficerRoleAssignments = [for id in secretsOfficerGroupIds: {
  principalId: id
  principalType: 'Group'
  roleDefinitionIdOrName: secretsOfficerRoleId
}]
var secretsReaderRoleAssignments = [for id in secretsReaderGroupIds: {
  principalId: id
  principalType: 'Group'
  roleDefinitionIdOrName: secretsUserRoleId
}]

module vault 'br/public:avm/res/key-vault/vault:0.9.0' = {
  name: 'deploy-${vaultName}'
  params: {
    name: vaultName
    location: location
    tags: mandatoryTags
    enablePurgeProtection: true // Not exposed as a param — never allow disabling this by mistake.
    enableSoftDelete: true
    enableRbacAuthorization: true // access policies are disallowed; RBAC only
    publicNetworkAccess: environment == 'prod' ? 'Disabled' : 'Enabled' // prod: private endpoint only
    networkAcls: {
      defaultAction: 'Deny' // least-privilege default; publicNetworkAccess above governs prod vs non-prod
      bypass: 'AzureServices'
    }
    diagnosticSettings: enableDiagnosticSettings ? [{ workspaceResourceId: logAnalyticsWorkspaceId }] : []
    roleAssignments: concat(secretsOfficerRoleAssignments, secretsReaderRoleAssignments)
  }
}

output vaultId string = vault.outputs.resourceId
output vaultUri string = vault.outputs.uri
output vaultName string = vaultName
