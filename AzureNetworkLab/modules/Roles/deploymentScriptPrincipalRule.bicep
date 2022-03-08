resource deploymentScriptRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' = {
  name: 'deployment-script-minimum-privilege-for-deployment-principal'
  properties: {
    roleName: 'deployment-script-minimum-privilege-for-deployment-principal'
    description: 'Configure least privilege for the deployment principal in deployment script'
    type: 'customRole'
    permissions: [
      {
        actions: [
          'Microsoft.Storage/storageAccounts/*'
        'Microsoft.ContainerInstance/containerGroups/*'
        'Microsoft.Resources/deployments/*'
        'Microsoft.Resources/deploymentScripts/*'
        ]
      }
    ]
  }
}
