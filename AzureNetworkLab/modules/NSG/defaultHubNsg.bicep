@description('Network Security Group name')
param nsgName string

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: nsgName
  location: resourceGroup().location
  properties: {
    // Note: Initial configuration will only deploy default rules, which is sufficient because of default VNET allow rules
    securityRules: [
      // Inbound rules
      // Outbound rules
    ]
  }
}

output nsgId string = nsg.id
