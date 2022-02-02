@description('Network Security Group name')
param nsgName string

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: nsgName
  location: resourceGroup().location
  properties: {
    securityRules: [
      // Inbound rules
      {
        name: 'Allow-Inbound-HttsFromInternet'
        properties: {
          direction: 'Inbound'
          priority: 200
          access: 'Allow'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
          protocol: 'Tcp'
          description: 'Azure Bastion requires inbound HTTPS to Bastion subnet'
        }
      }
      {
        name: 'Allow-Inbound-GatewayManager'
        properties: {
          direction: 'Inbound'
          priority: 300
          access: 'Allow'
          sourceAddressPrefix: 'GatewayManager'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
          protocol: 'Tcp'
          description: 'Azure Bastion requires inbound HTTPS to Bastion subnet'
        }
      }
      {
        name: 'Allow-Inbound-AzureLoadbalancer'
        properties: {
          direction: 'Inbound'
          priority: 400
          access: 'Allow'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
          protocol: 'Tcp'
          description: 'Azure Bastion requires inbound HTTPS from Azure Load Balancer to Bastion subnet'
        }
      }
      {
        name: 'Allow-Inbound-BastionHostCommunications'
        properties: {
          direction: 'Inbound'
          priority: 500
          access: 'Allow'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          protocol: '*'
          description: 'Open required communicaiton between Bastion Hosts within the VNET'
        }
      }
      // Outbound rules
      {
        name: 'Allow-Outbound-SshAndRdp'
        properties: {
          direction: 'Outbound'
          priority: 200
          access: 'Allow'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '22'
            '3389'
          ]
          protocol: '*'
          description: 'Azure Bastion requires outbound traffic for SSH and RDP'
        }
      }
      {
        name: 'Allow-Outbound-AzureCloud'
        properties: {
          direction: 'Outbound'
          priority: 300
          access: 'Allow'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'AzureCloud'
          destinationPortRange: '443'
          protocol: 'Tcp'
          description: 'Azure Bastion requires outbound HTTPS to all Azure services in the host cloud (e.g., Commercial or US Government)'
        }
      }
      {
        name: 'Allow-Outbound-BastionCommunication'
        properties: {
          direction: 'Outbound'
          priority: 400
          access: 'Allow'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          protocol: '*'
          description: 'Azure bastion requires traffic on ports 8080 and 5701 within the VNET'
        }
      }
      {
        name: 'Allow-Outbound-GetSessionInformation'
        properties: {
          direction: 'Outbound'
          priority: 500
          access: 'Allow'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRange: '80'
          protocol: '*'
          description: 'Azure Bastion requires HTTP access to the internet to get session and certificate validation'
        }
      }
    ]
  }
}

output nsgId string = nsg.id
