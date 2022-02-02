@description('Azure Firewall name')
param firewallName string

@description('Resource ID of Azure Firewall Policy to assigne to the firewall')
param firewallPolicyId string

@description('Name of the VNET the firewall will be attached to. Must be in the same resource group where the firewall is being deployed')
param virtualNetworkName string

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: virtualNetworkName
  resource firewallSubnet 'subnets' existing = {
    name: 'AzureFirewallSubnet'
  }
}

resource fwPublicIp 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: '${firewallName}_PIP'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2021-05-01' = {
  name: firewallName
  location: resourceGroup().location
  zones: []
  properties: {
    firewallPolicy: {
      id: firewallPolicyId
    }
    sku: {
      tier: 'Standard'
    }
    ipConfigurations: [
      {
        name: 'ipConfig00'
        properties: {
          publicIPAddress: {
            id: fwPublicIp.id
          }
          subnet: {
            id: vnet::firewallSubnet.id
          }
        }
      }
    ]
  }
}
