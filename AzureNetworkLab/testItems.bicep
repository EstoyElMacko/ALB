var newVnets = {
  // Central hub VNET, contains Azure Firewall (simple routing and HTTP/TCP packet filtering) and any virtual network appliances
  hub: {
    name: 'gml-eus-hub-vnet'
    resourceGroupName: resourceGroup().name
    addressPrefixes: [
      '10.0.0.0/16'
    ]
    subnets: {
      AzureFirewallSubnet: {
        addressPrefix: '10.0.0.0/24'
      }
      AzureBastionSubnet: {
        addressPrefix: '10.0.1.0/24'
      }
    }
  }
  // spoke VNET primarily for VNET injected PaaS resources that will use ALB DNS (hosted on IaaS Domaion Controller)
  'dnsIntegrated': {
    name: 'gml-eus-dnsIntegrated-vnet'
    resourceGroupName: resourceGroup().name
    addressPrefixes: [
      '10.2.0.0/16'
    ]
    subnets: {
      'AKS-Demo': {
        addressPrefix: '10.2.0.0/24'
      }
    }
  }
  /* spoke VNET primarily for VNET injected PaaS resources that will use Azure DNS - Default route for subnets will 
     tend to be directly to internet, but that can be decided per subnet.
  */
  'dnsStandalone': {
    name: 'gml-eus-azureDns-vnet'
    addressPrefixes: [
      '10.3.0.0/16'
    ]
    subnets: {
      default: {
        addressPrefix: '10.3.0.0/24'
      }
    }
  }
}

var newVnetNames = [for vnetData in items(newVnets): vnetData.value.Name]
output newVnetNames array = newVnetNames
