param principalId string
@allowed(['User', 'Group', 'ServicePrincipal', 'ForeignGroup', 'Device', 'ManagedIdentity'])
param principalType string
param roleDefinitionGuid string
param roleAssignmentName string

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: roleAssignmentName
  properties: {
    principalId: principalId
    principalType: principalType
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionGuid)
  }
}
output roleAssignmentId string = roleAssignment.id
