// This modules is used to map hub-and-spoke peering for the lab environment

@description('Resource ID of the hub VNET. All spokes will be peerted to this vnet')
param hubVnetId string

@description('Array of resource IDs corresponding to all spoke vnets. Each spoke VNET will be peered to the hub VNET')
param spokeVnetIds array

var hubVnetParts = split(hubVnetId, '/')
var spokeVnetParts = [for spokeId in spokeVnetIds: split(spokeId, '/')]

//parse hub VNET resource ID string into needed information
var hubVnetInfo = {
  subscriptionId: hubVnetParts[2]
  resourceGroupName: hubVnetParts[4]
  name: hubVnetParts[8]
}

var spokeVnetInfo = [for spokeParts in spokeVnetParts: {
  subscriptionId: spokeParts[2]
  resourceGroupName: spokeParts[4]
  name: spokeParts[8]
}]

// Peer hub to all spokes
module hubToSpokePeering 'peerToMultipleVnets.bicep' = {
  name: 'peerHubToAllSpokes'
  scope: resourceGroup(hubVnetInfo.subscriptionId, hubVnetInfo.resourceGroupName)
  params: {
    vnetName: hubVnetInfo.name
    remoteVnetIds: spokeVnetIds
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
    deploy: true
  }
}

module spokeToHubPeering 'PeerToMultipleVnets.bicep' = [for spokeInfo in spokeVnetInfo: {
  name: 'peer_${spokeInfo.name}_to_${hubVnetInfo.name}'
  scope: resourceGroup(spokeInfo.subscriptionId, spokeInfo.resourceGroupName)
  params: {
    vnetName: spokeInfo.name
    remoteVnetIds: array(hubVnetId)
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    deploy: true
  }
}]

/*
module spokeToHubPeering 'peerToSingleVnet.bicep' = [for spokeInfo in spokeVnetInfo: {
  name: 'peer_${spokeInfo.name}_to_${hubVnetInfo.name}'
  scope: resourceGroup(spokeInfo.subscriptionId, spokeInfo.resourceGroupName)
  params: {
    vnetName: spokeInfo.name
    remoteVnetName: hubVnetInfo.name
    remoteVnetRgName: hubVnetInfo.resourceGroupName
    remoteVnetSubscriptionId: hubVnetInfo.resourceGroupName
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    deploy: true
  }
}]


*/
