targetScope = 'subscription'

param policyAssignmentName string = 'prohibit-public-IP'
param exclusionScopeResourceIDs array

// Policy ID for builtin Azure policy "Not allowed resource types" that prohibits deployment of specified resource types
var notAllowedResourcePolicyId = '/providers/Microsoft.Authorization/policyDefinitions/6c112d4e-5bc7-47ae-a041-ea2d9dccd749'

resource assignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: policyAssignmentName
  properties: {
    description: 'Prevent the deployment of public IP addresses in the subscription except for explicitely excluded resource groups'
    displayName: 'Prohibit deployment of public IP addresses'
    nonComplianceMessages: [
      {
        message:'Public IP addresses are not approved to run in this subscription unless they are deployed to exempted resource groups'
      }
    ]
    notScopes: exclusionScopeResourceIDs
    policyDefinitionId: notAllowedResourcePolicyId
    parameters: {
      listOfResourceTypesNotAllowed: {
        value: [
          'microsoft.network/publicipaddresses'
        ]
      }
    }
  }
}

output assignment object = assignment
