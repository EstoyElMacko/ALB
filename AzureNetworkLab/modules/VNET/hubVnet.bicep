@description('Virtual Network name')
param vnetName string

@description('Array of CIDR format IP address ranges that will be assigned to the VNET')
param vnetAddressRanges array

@description('Array of IP addresses used for custom DNS resolution. Leave default empty array to use Azure DNS')
param dnsServerIPs array = []

@description('State for private endpoint network policies. Unless Azure has added support, private endpints cannot be created if set to Enabled.')
@allowed([
  'Disabled'
  'Enabled'
])
param privateEndpointPolicy string = 'Disabled'

@description('CIDR format IP range for Azure Firewall subnet')
param firewallSubnet_ipRange string

@description('Resource ID of route table to be assigned to Azure Firewall subnet')
param firewallSubnet_routeTableId string
// Note: Azure Firewall does not supoprt NSG on firewall subnet

@description('CIDR format IP range for Azure Firewall subnet')
param bastionSubnet_ipRange string

@description('Resource ID of route table to be assigned to Azure Firewall subnet')
param bastionSubnet_nsgId string
// note: Azure Bastion does not support route tables

var firewallSubnetName = 'AzureFirewallSubnet'
var bastionSubnetName = 'AzureBastionSubnet'
resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
    name: vnetName
    location: resourceGroup().location
    properties: {
      addressSpace: {
        addressPrefixes: vnetAddressRanges
      }
      dhcpOptions: {
        dnsServers: dnsServerIPs
      }
      subnets: [
        {
          name: firewallSubnetName
          properties: {
            addressPrefix: firewallSubnet_ipRange
            privateEndpointNetworkPolicies: privateEndpointPolicy
            routeTable: {
              id: firewallSubnet_routeTableId
            }
          }
        }
        {
      name: bastionSubnetName
      properties: {
        addressPrefix: bastionSubnet_ipRange
        privateEndpointNetworkPolicies: privateEndpointPolicy
        networkSecurityGroup: {
          id: bastionSubnet_nsgId
        }
      }
    }
      ]
    }
}

/* Note: When creating subnets as subresrouce, I encountered a deployment in progress error, and when I 
   made each subsequent subnet dependOn the prevous, I got an error that in-use subnet cannot be deleted.
   That is why I am creating a reference to the VNET after creation, so I can address each subnet by name
   to return its subnetID
*/
resource vnetRef 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: vnet.name
  resource firewallSubnet 'subnets' existing = {
    name: firewallSubnetName
  }
  resource bastionSubnet 'subnets' existing = {
    name: bastionSubnetName
  }
}

output vnetName string = vnet.name
output vnetId string = vnet.id
output vnetAddressPrefixes array = vnet.properties.addressSpace.addressPrefixes
output azureFirewallSubnetId string = vnetRef::firewallSubnet.id
output azureFirewallSubnetRange string = vnetRef::firewallSubnet.properties.addressPrefix
