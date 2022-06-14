@description('Network Security Group name')
param nsgName string

@description('Array of all CIDR format IP ranges assigned to spoke VNETs of hub-and-spoke network.')
param spokeVnetCidrIpRanges array

@description('Default location is the resource group location')
param location string = resourceGroup().location

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      // Inbound rules
      {
        name: 'inbound-albSpokes'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          // Note: Hub IP space is not explicitely added because Hub is peered to each spoke, and is therefore allowed via the default VirtualNetwork allow rule
          sourceAddressPrefixes: spokeVnetCidrIpRanges
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          priority: 200
          description: 'ensure inbound traffic from all spoke VNETs in hub-and-spoke network'

        }
      }

      // Outbound rules
      {
        name: 'outbound-albSpokes'
        properties: {
          access: 'Allow'
          direction: 'Outbound'
          protocol: '*'
          // Note: Hub IP space is not explicitely added because Hub is peered to each spoke, and is therefore allowed via the default VirtualNetwork allow rule
          sourceAddressPrefixes: spokeVnetCidrIpRanges
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          priority: 200
          description: 'ensure outbound traffic from all spoke VNETs in hub-and-spoke network'

        }
      }

    ]
  }
}

output nsgId string = nsg.id
