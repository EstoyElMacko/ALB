param vnetName string
param remoteVnetName string
param remoteVnetRgName string
param allowForwardedTraffic bool
param allowGatewayTransit bool
param allowVirtualNetworkAccess bool = true
param doNotVerifyRemoteGateways bool = true
param useRemoteGateways bool
param deploy bool = true

resource remoteVnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: remoteVnetName
  scope: resourceGroup(remoteVnetRgName)
}

var peerName = '${vnetName}_to_${remoteVnetName}'
resource localVnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: vnetName
  resource peer 'virtualNetworkPeerings' = if (deploy){
    name: peerName
    properties: {
      allowForwardedTraffic: allowForwardedTraffic
      allowGatewayTransit: allowGatewayTransit
      allowVirtualNetworkAccess: allowVirtualNetworkAccess
      doNotVerifyRemoteGateways: doNotVerifyRemoteGateways
      useRemoteGateways: useRemoteGateways
      remoteVirtualNetwork: {
        id: remoteVnet.id
      }
    }
  }
}

output peerName string = peerName
