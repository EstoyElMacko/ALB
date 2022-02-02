@description('Route Table name')
param routeTableName string

@description('Azure Firewall private IP address (acts as simple routing device)')
param virtualNetworkRouterIpAddress string

resource routeTable 'Microsoft.Network/routeTables@2021-05-01' = {
  name: routeTableName
  location: resourceGroup().location
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
          nextHopType: 'Internet'
        }
      }
    ]
  }
}

output routeTableId string = routeTable.id
