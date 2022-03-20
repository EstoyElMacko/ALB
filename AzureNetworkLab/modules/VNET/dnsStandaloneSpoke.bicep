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
param defaultSubnet_ipRange string

@description('Resource ID ofNetwork Security Group to be assigned to Azure Firewall Subnet. Note - this will be disabled but is included to prevent alerts on subnet with no NSG')
param defaultSubnet_nsgId string

@description('Resource ID of route table to be assigned to Azure Firewall subnet')
param defaultSubnet_routeTableId string

@description('Name for the default subnet')
param defaultSubnetName string = 'default'

@description('Default location is the resource gorup location')
param location string = resourceGroup().location

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: vnetAddressRanges
    }
    dhcpOptions: {
      dnsServers: dnsServerIPs
    }
    subnets: [
      {
        name: defaultSubnetName
        properties: {
          addressPrefix: defaultSubnet_ipRange
          privateEndpointNetworkPolicies: privateEndpointPolicy
          networkSecurityGroup: {
            id: defaultSubnet_nsgId
          }
          routeTable: {
            id: defaultSubnet_routeTableId
          }
        }
      }
    ]
  }
}

resource vnetRef 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: vnet.name
  resource defaultSubnet 'subnets' existing = {
    name: defaultSubnetName
  }
}

output vnetName string = vnet.name
output vnetId string = vnet.id
output vnetAddressPrefixes array = vnet.properties.addressSpace.addressPrefixes
output azureFirewallSubnetId string = vnetRef::defaultSubnet.id
output azureFirewallSubnetRange string = vnetRef::defaultSubnet.properties.addressPrefix
