@description('Name of the local VNET that will be peered to a remote VNET')
param vnetName string

@description('Array of VNET IDs. the target VNET will be peered to each remote VNET ID in this parameter')
param remoteVnetIds array

@description('Allows traffic that did not originate from the remote VNET (i.e. was forwarded by a virtual network appliance in the remnote VNET). This value will normally be false in a hub VNET and ')
param allowForwardedTraffic bool

@description('If true, allows resources in the remote VNET to use VNET gateway in the local VNET. If set to true and the the local VNET does not have a gateway, the deployment will fail')
param allowGatewayTransit bool

@description('If set to false, resoruces in the remote VNET cannot access resources in the local VNET via the peering')
param allowVirtualNetworkAccess bool = true

@description('If true, instructs Azure Resource Manager not to validate that the remote VNET has a VNET gateway if the useRemoteGateways parameter is set to true (otherwise, deployment will fail if remote venet does not have VNET Gateway)')
param doNotVerifyRemoteGateways bool = true

@description('If true, the named VNET will use a VNET Gateway in the remote VNET. If ture and the remote VNET does not have a VNET gateway, deployment will fail unless the doNotVerifyRemoteGateways parameter is set to true')
param useRemoteGateways bool

@description('If true, vnet peering will be created')
param deploy bool = true


// which index contains the VNET name when a VNET resource ID is split on the forward slash (/) character
var vnetNamePart = 8
resource localVnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: vnetName
  resource peers 'virtualNetworkPeerings' = [for (remoteId, index) in remoteVnetIds: if(deploy){
    name: '${vnetName}_to_${split(remoteId,'/')[vnetNamePart]}'
    properties: {
      allowForwardedTraffic: allowForwardedTraffic
      allowGatewayTransit: allowGatewayTransit
      allowVirtualNetworkAccess: allowVirtualNetworkAccess
      doNotVerifyRemoteGateways: doNotVerifyRemoteGateways
      useRemoteGateways: useRemoteGateways
      remoteVirtualNetwork: {
        id: remoteId
      }
    }
  }]
}

output peeringInfo array = [for (remoteId, index) in remoteVnetIds: {
  peerName: localVnet::peers[index].name
  localVnetName: vnetName
  localVnetRgName: resourceGroup().name
  remoteId: localVnet::peers[index].properties.remoteVirtualNetwork.id
}]
