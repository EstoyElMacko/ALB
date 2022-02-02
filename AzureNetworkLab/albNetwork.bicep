//ToDo: replace all hardcoded resource names with parameters. Look for name:\s*'.+?' (will pick up some variables, so no replace-all)

@description('IP address of one or more custom DNS servers (i.e., Azure Lab Builder domain controller(s))')
param albDnsServerIPs array

@description('Boolean value to determine if Azure Bastion host should be deployed')
param deployBastionHost bool = true

@description('Bolean value to determine if Azure Firewall Policy should be deployed. Use false if no changes have been made to template since last deployment to shorten overall deployment time.')
param deployAzureFirewallPolicy bool = false

@description('Name to give Azure Firewall')
param azureFirewallName string

@description('Name of Azure Firewall Policy')
param azureFirewallPolicyName string
/*
This is the main template for deploying a hub-and-spoke VNET infrastructure for Azure Lab Builders. The template and
its modules are an attempt to find the balance between complexity and compatibility in consolidating a collection
of new and existing VNETs, along with supporting route tables, network security groups, Azure Firewall, and other 
network components to create a reasonable faximile of a typical production environment.

The purspose of this network infrastructure is to create an environment tha can simulate typical network scenerios of
a production environment that is often overlooked when learning how to deploy and use azure infrastructure. The goal is
to provide an environment that forces users to consider network constraings and considerations when learning to use VNET
injected Azure resources (resources that are directly connected to Azure VNETS) as well as test various VNET integration
mechanisms, like Private Endpoints, Service Endpoints or App Service VNET Integration.
*/

/*
This complex object describes the purpose, name and address space of existing VNETs that will be integrated into the 
hub-and-spoke network. The VNET name and address space must be provided. Subnet information can be added if they are
needed to provide address space definitions used by route tables, NSGs or other resources.

format:
{
  <symbolic name (friendly name or descriptor of the VNET's purpose)>: {
    name: <vnet name>
    resourceGroupName: '<resource group name>'
    //Note: The subnets object must exist, but can contain 0 or more properties. Each property must be the name of the subnet
    subnets: {
      //property is subnet name, value is an empty object in case later use requires additional information.
      <subnetName>: {}
    }
  }
}
*/
var existingVnets = {
  albCoreVent: {
    name: 'gml-eus-alb-vnet'
    resourceGroupName: 'gml-eus-networking-rg'
    subnets: {
      management: {}
      ADO_Agents: {}
      app: {}
      data: {}
      web: {}
    }
  }
}

/* Complex object to describe name/address prefixes of VNETs to be created by this template and associated modules. 
   This structure is a compromise between the flexibility to easily change IP address space and the requirement for 
   specific configurations of each VNET; Unfortunately, VNETs are not idempotate, so a dedicated module for each VNET 
   remains the best way to ensure that an additional confguration does not inadvertantly wipe out all other settings 
   on the VNET/subnet. 

   This means that there must be considerable coordination between the individual VNET module parameters and the 
   newVNET object, but in my opinion, it is still easier to manage than adding parameters for the VNET name, resource 
   group name, IP addresss ranges and subnet name/ip range for each subnet each VNET contains.

format:
{
  <Descriptinve name for VNET, e.g. Hub>: {
    name: <vnet name>
    resourceGroupName: '<resource group name>'
    addressPrefixes: [
      '<prefix1>'
    ]
    //Note: must include at least one subnet
    subnets: {
      <subnet name>: {
        addressPrefix: <CIDR format IP range - must be contained withing the VNET address prefixes>
      }
    }
  }
}


*/
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

var azFirewallSubnetAddress = split(newVnets.hub.subnets.AzureFirewallSubnet.addressPrefix, '/')[0]
var azFirewallSubnetParts = split(azFirewallSubnetAddress, '.')
var azFirewallPrivateIp = '${azFirewallSubnetParts[0]}.${azFirewallSubnetParts[1]}.${azFirewallSubnetParts[2]}.${int(azFirewallSubnetParts[3]) + 4}'

// Network Security Groups
module nsg_spokeDefault 'modules/NSG/defaultNsg.bicep' = {
  name: 'deployDefaultNsg'
  params: {
    nsgName: 'gmg-eus-default-nsg'
    spokeVnetCidrIpRanges: union(albVnet.properties.addressSpace.addressPrefixes, newVnets.dnsIntegrated.addressPrefixes, newVnets.dnsStandalone.addressPrefixes)
  }
}

module nsg_hubDefault 'modules/NSG/defaultHubNsg.bicep' = {
  name: 'deployHubDefaultNsg'
  params: {
    nsgName: 'gmg-eus-hubDefault-nsg'
  }
}

module nsg_bastion 'modules/NSG/bastionSubnetNSG.bicep' = {
  name: 'deployAzureBastionNSG'
  params: {
    nsgName: 'gmg-eus-bastion-nsg'
  }
}

// Route Tables
module routeTable_default 'modules/RouteTable/defaultRouteTable-albIntegrated.bicep' = {
  name: 'deployDefaultRouteTable'
  params: {
    routeTableName: 'gmg-eus-labIntegratedDefault-rt'
    virtualNetworkRouterIpAddress: azFirewallPrivateIp
  }
}

module routeTable_azureFirewall 'modules/RouteTable/routeTable-azureFirewall.bicep' = {
  name: 'deployAzureFirewallRouteTable'
  params: {
    routeTableName: 'gmg-eus-azureFirewall-rt'
    virtualNetworkRouterIpAddress: azFirewallPrivateIp
  }
}

// Reference existing VNETs that will be integrated into hub-and-spoke network
resource albVnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: existingVnets.albCoreVent.name
  scope: resourceGroup(existingVnets.albCoreVent.resourceGroupName)
  resource managementSubnet 'subnets' existing = {
    name: 'management'
  }
}

// New VNETs
module hubVnet 'modules/VNET/hubVnet.bicep' = {
  name: 'deployHubVnet'
  params: {
    bastionSubnet_ipRange: newVnets.hub.subnets.AzureBastionSubnet.addressPrefix
    bastionSubnet_nsgId: nsg_bastion.outputs.nsgId
    firewallSubnet_ipRange: newVnets.hub.subnets.AzureFirewallSubnet.addressPrefix
    firewallSubnet_routeTableId: routeTable_azureFirewall.outputs.routeTableId
    vnetAddressRanges: newVnets.hub.addressPrefixes
    vnetName: newVnets.hub.name
  }
}

module dnsIntegratedVnet 'modules/VNET/dnsIntegratedSpokeVnet.bicep' = {
  name: 'deployDnsIntegratedVnet'
  params: {
    aksDemoSubnet_ipRange: newVnets.dnsIntegrated.subnets['AKS-Demo'].addressPrefix
    aksDemoSubnet_nsgId: nsg_spokeDefault.outputs.nsgId
    aksDemoSubnet_routeTableId: routeTable_default.outputs.routeTableId
    dnsServerIPs: albDnsServerIPs
    vnetAddressRanges: newVnets.dnsIntegrated.addressPrefixes
    vnetName: newVnets.dnsIntegrated.name
  }
}

module dnsStandaloneVnet 'modules/VNET/dnsStandaloneSpoke.bicep' = {
  name: 'deployDnsStandaloneVnet'
  params: {
    defaultSubnet_ipRange: newVnets.dnsStandalone.subnets.default.addressPrefix
    defaultSubnet_nsgId: nsg_spokeDefault.outputs.nsgId
    defaultSubnet_routeTableId: routeTable_default.outputs.routeTableId
    vnetAddressRanges: newVnets.dnsStandalone.addressPrefixes
    vnetName: newVnets.dnsStandalone.name
  }
}

// Azure Bastion
module bastion 'modules/HubNetworkResources/bastion.bicep' = if (deployBastionHost) {
  name: 'deployAzureBastion'
  params: {
    bastionHostName: 'gmg-eus-hub-bastion'
    vnetName: newVnets.hub.name
    vnetResourceGroupName: resourceGroup().name
  }
}

// public IPs for Azure Firewall NAT rules (must be created before creating firewall policy)
module firewallNatPublicIps 'modules/HubNetworkResources/firewallNatPublicIPs.bicep' = {
  name: 'deployPublicIpsforFirewallNatRules'
  params: {
    wapPublicIpName: '${azureFirewallName}_WAP_PIP'
  }
}
output wapNatPipId string = firewallNatPublicIps.outputs.wapPublicIpId

// Azure Firewall Policy
module firewallPolicy 'modules/HubNetworkResources/firewallPolicy.bicep' = if(deployAzureFirewallPolicy){
  name: 'deployAzureFirewallPolicy'
  params: {
    domainControllerSubnetIpRanges: [
      albVnet::managementSubnet.properties.addressPrefix
    ]
    firewallPolicyName: azureFirewallPolicyName
  }
}

resource firewallPolicyRef 'Microsoft.Network/firewallPolicies@2021-05-01' existing = if (deployAzureFirewallPolicy==false) {
  name: azureFirewallPolicyName
}
module azureFirewall 'modules/HubNetworkResources/firewall.bicep' = {
  name: 'deployAzureFirewall'
  params: {
    firewallName: 'gmg-eus-hub-firewall'
    firewallPolicyId: deployAzureFirewallPolicy ? firewallPolicy.outputs.policyId : firewallPolicyRef.id
    virtualNetworkName: hubVnet.outputs.vnetName
  }
}
/*
*/
