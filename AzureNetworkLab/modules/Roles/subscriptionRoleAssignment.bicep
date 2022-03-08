param roleDefinitionId string
param principalId string
@allowed([
  'ForeignGroup'
  'Group'
  'ServicePrincipal'
  'User'
  /*
  'Application'
  'Device'
  'DirectoryObjectOrGroup'
  'DirectoryRoleTemplate'
  'Everyone'
  'ForeignGroup'
  'Group'
  'MSI'
  'ServicePrincipal'
  'Unknown'
  'User'
  */
])
param principalType string = 'ServicePrincipal'

targetScope = 'subscription'

var roleAssignmentName = guid(subscription().id, roleDefinitionId, principalId)
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: roleAssignmentName
  properties: {
    principalId: principalId
    roleDefinitionId: roleDefinitionId
    principalType: principalType
  }  
}
