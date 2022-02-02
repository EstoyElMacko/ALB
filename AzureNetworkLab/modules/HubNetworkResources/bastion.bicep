param bastionHostName string
param vnetName string
param vnetResourceGroupName string

var publicIpAddressName = '${bastionHostName}_PIP'

resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: vnetName
  scope: resourceGroup(vnetResourceGroupName)
  resource subnet 'subnets' existing = {
    name: 'AzureBastionSubnet'    
  }
}

resource bastionPublicIP 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: publicIpAddressName
  location: resourceGroup().location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  tags: {}
}

resource bastion 'Microsoft.Network/bastionHosts@2021-02-01' = {
  name: bastionHostName
  location: resourceGroup().location
  sku: {
    name: 'Standard'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: vnet::subnet.id
          }
          publicIPAddress: {
            id: bastionPublicIP.id
          }
        }
      }
    ]
  }
  tags: {}
}

output bastionId string = bastion.id
