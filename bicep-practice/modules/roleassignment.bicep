@description('The principal ID to assign the role to')
param principalId string

param name string

@description('The role definition GUID (not the full resource ID)')
param roleDefinitionId string

@description('The type of the principal being assigned the role')
@allowed(['Device', 'ForeignGroup', 'Group', 'ServicePrincipal', 'User'])
param principalType string = 'User'

@description('Optional description for the role assignment')
param assignmentDescription string = ''

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: name
  properties: {
    principalId: principalId
    principalType: principalType
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    description: empty(assignmentDescription) ? null : assignmentDescription
  }
}
