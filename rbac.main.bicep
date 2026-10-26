
targetScope = 'managementGroup'

@description('Name of the management group where the custom role will be created.')
param targetManagementGroupName string = 'rbac-module-test'

@description('Name of the custom RBAC role.')
param roleName string = 'Pike IaC Deploy RBAC Grantor'

module rbacRole 'iac-deploy-rbac-grantor-role/main.bicep' = {
  name: 'deploy-pike-rbac-grantor-role'
  scope: managementGroup(targetManagementGroupName)
  params: {
    roleName: roleName
    assignableScopes: [
      '/providers/Microsoft.Management/managementGroups/${targetManagementGroupName}'
    ]
  }
}

output roleDefinitionGuid string = rbacRole.outputs.roleDefinitionGuid

output roleDefinitionId string = rbacRole.outputs.roleDefinitionId
