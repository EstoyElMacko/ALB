@description('Route Table name')
param routeTableName string

@description('private IP address for virtual network appliance to route traffic to internal destinations. If Azure Firewall routes internal and internet traffic, use the Azure Firewall private IP address for this value')
param virtualNetworkRouterIpAddress string

@description('Private IP address for internal NIC of Azure Firewall')
param azureFirewallPrivateIpAddress string

@description('Default location is the resource gorup location')
param location string = resourceGroup().location

resource routeTable 'Microsoft.Network/routeTables@2021-05-01' = {
  name: routeTableName
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'internalDefualt'
        properties: {
          addressPrefix: '10.0.0.0/8'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: virtualNetworkRouterIpAddress
        }
      }
      {
        name: 'defualt'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: azureFirewallPrivateIpAddress
        }
      }
    ]
  }
}

output routeTableId string = routeTable.id
