@description('Network Security Group name')
param nsgName string

@description('Default location is the resource gorup location')
param location string = resourceGroup().location

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: nsgName
  location: location
  properties: {
    // Note: Initial configuration will only deploy default rules, which is sufficient because of default VNET allow rules
    securityRules: [
      // Inbound rules
      // Outbound rules
    ]
  }
}

output nsgId string = nsg.id
