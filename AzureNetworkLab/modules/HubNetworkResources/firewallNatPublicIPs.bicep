@description('Name for Public IP that will be used to map inbound internet traffic to Web Application Proxy VM private IP address')
param wapPublicIpName string

@description('Default location is the resource gorup location')
param location string = resourceGroup().location

resource wapPublicIp 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: wapPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

output wapPublicIpId string = wapPublicIp.id
