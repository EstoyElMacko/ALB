//ToDo: replace all hardcoded resource names with parameters. Look for name:\s*'.+?' (will pick up some variables, so no replace-all)
//ToDo: Develop custom role to allow managed identity to create/reset VNET peering

@description('IP address of one or more custom DNS servers (i.e., Azure Lab Builder domain controller(s))')
param albDnsServerIPs array = [
  '10.1.0.5'
]

@description('Name of managed identity created to manage VNET peering')
param peeringResetIdenittyName string = 'gml-eus-templateScript-mId'

@description('Boolean value to determine if Azure Bastion host should be deployed')
param deployBastionHost bool = true

@description('Bolean value to determine if Azure Firewall Policy should be deployed. Use false if no changes have been made to template since last deployment to shorten overall deployment time.')
param deployAzureFirewallPolicy bool = false

@description('Bolean value to determine if the hub-and-spoke vnets will be peered. Set to true to establish the peerings and leave as false for quick deployments when they are already peered.')
param deployVnetPeering bool = false


@description('Name of Azure Automation Account used to deprovision/shutdown/delete non-VM resources at night')
param shudownAutomationAccountName string

@description('Bolean value to determine if Azure Automation account should be deployed')
param deployAutomationAccountScheduleJobs bool = false

@description('Name to give Azure Firewall')
param azureFirewallName string = 'gmg-eus-hub-firewall'

@description('Name of Azure Firewall Policy')
param azureFirewallPolicyName string = 'gmg-eus-hub-fwPolicy'

@description('Default location is the resource gorup location')
param location string = resourceGroup().location
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
  albCoreVnet: {
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

// Calculate Azure Firewall private IP address - No matter the size of the subnet, private IP will be first available, which is last octet of the subnet CIDR range + 4
var azFirewallSubnetAddress = split(newVnets.hub.subnets.AzureFirewallSubnet.addressPrefix, '/')[0]
var azFirewallSubnetParts = split(azFirewallSubnetAddress, '.')
var azFirewallPrivateIp = '${azFirewallSubnetParts[0]}.${azFirewallSubnetParts[1]}.${azFirewallSubnetParts[2]}.${int(azFirewallSubnetParts[3]) + 4}'

// Assign Azure Policy to prohibit public IP addressed in the current subscription with exception of current resource group
module policy_noPublicIp 'modules/Policy/assignNoPublicIpPolicy.bicep' = {
  name: 'deployPolicyAssignment_noPublicIp'
  scope: subscription()
  params: {
    exclusionScopeResourceIDs: [
      // Get subscription-scoped resource ID of the deployment resource group. Subscription scope Resource IDs are formatted differently than RG scoped IDs
      subscriptionResourceId(subscription().subscriptionId,'Microsoft.Resources/resourceGroups', resourceGroup().name)
    ]
  }
}

// Network Security Groups
module nsg_spokeDefault 'modules/NSG/defaultNsg.bicep' = {
  name: 'deployDefaultNsg'
  params: {
    nsgName: 'gmg-eus-default-nsg'
    spokeVnetCidrIpRanges: union(albVnet.properties.addressSpace.addressPrefixes, newVnets.dnsIntegrated.addressPrefixes, newVnets.dnsStandalone.addressPrefixes)
    location: location
  }
}

module nsg_hubDefault 'modules/NSG/defaultHubNsg.bicep' = {
  name: 'deployHubDefaultNsg'
  params: {
    nsgName: 'gmg-eus-hubDefault-nsg'
    location: location
  }
}

module nsg_bastion 'modules/NSG/bastionSubnetNSG.bicep' = {
  name: 'deployAzureBastionNSG'
  params: {
    nsgName: 'gmg-eus-bastion-nsg'
    location: location
  }
}

// Route Tables
module routeTable_default 'modules/RouteTable/defaultRouteTable-albIntegrated.bicep' = {
  name: 'deployDefaultRouteTable'
  params: {
    routeTableName: 'gmg-eus-labIntegratedDefault-rt'
    virtualNetworkRouterIpAddress: azFirewallPrivateIp
    location: location
  }
}

module routeTable_azureFirewall 'modules/RouteTable/routeTable-azureFirewall.bicep' = {
  name: 'deployAzureFirewallRouteTable'
  params: {
    routeTableName: 'gmg-eus-azureFirewall-rt'
    virtualNetworkRouterIpAddress: azFirewallPrivateIp
    location: location
  }
}

module routeTable_aksBehindAzureFirewall 'modules/RouteTable/routeTable-aksBehindAzureFirewall.bicep' = {
  name: 'deployRouteTableForAksBehindAzFirewall'
  params: {
    routeTableName: 'gmg-eus-aksBehindAzureFirewall-rt'
    azureFirewallPrivateIpAddress: azFirewallPrivateIp
    virtualNetworkRouterIpAddress: azFirewallPrivateIp
    location: location
  }
}

// Reference existing VNETs that will be integrated into hub-and-spoke network
resource albVnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: existingVnets.albCoreVnet.name
  scope: resourceGroup(existingVnets.albCoreVnet.resourceGroupName)
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
    location: location
  }
}

module dnsIntegratedVnet 'modules/VNET/dnsIntegratedSpokeVnet.bicep' = {
  name: 'deployDnsIntegratedVnet'
  params: {
    aksDemoSubnet_ipRange: newVnets.dnsIntegrated.subnets['AKS-Demo'].addressPrefix
    aksDemoSubnet_nsgId: nsg_spokeDefault.outputs.nsgId
    aksDemoSubnet_routeTableId: routeTable_aksBehindAzureFirewall.outputs.routeTableId
    dnsServerIPs: albDnsServerIPs
    vnetAddressRanges: newVnets.dnsIntegrated.addressPrefixes
    vnetName: newVnets.dnsIntegrated.name
    location: location
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
    location: location
  }
}

// Azure Bastion
module bastion 'modules/HubNetworkResources/bastion.bicep' = if (deployBastionHost) {
  name: 'deployAzureBastion'
  params: {
    bastionHostName: 'gmg-eus-hub-bastion'
    vnetName: hubVnet.outputs.vnetName
    vnetResourceGroupName: resourceGroup().name
    location: location
  }
}

// public IPs for Azure Firewall NAT rules (must be created before creating firewall policy)
module firewallNatPublicIps 'modules/HubNetworkResources/firewallNatPublicIPs.bicep' = {
  name: 'deployPublicIpsforFirewallNatRules'
  params: {
    wapPublicIpName: '${azureFirewallName}_WAP_PIP'
    location: location
  }
}
output wapNatPipId string = firewallNatPublicIps.outputs.wapPublicIpId

// Azure Firewall Policy
module firewallPolicy 'modules/HubNetworkResources/firewallPolicy.bicep' = if(deployAzureFirewallPolicy){
  name: 'deployAzureFirewallPolicy'
  params: {
    firewallPolicyName: azureFirewallPolicyName
    domainControllerSubnetIpRanges: [
      albVnet::managementSubnet.properties.addressPrefix
    ]
    azureKubernetesServiceSubnetRanges: [
      dnsIntegratedVnet.outputs.aksDemoSubnetRange
    ]
    location: location
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
    location: location
  }
}

//*** Reset VNET peering (ensure no peerings are in 'Disconnected' state or peering operions will fail) ***

// create managed identity to reset peerings
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = if (deployVnetPeering){
  name: peeringResetIdenittyName
  location: location
}


var networkContributorRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7')
// assign managed identity the network contributor role at the current subscription.
module networkContributorRoleAssignment 'modules/Roles/subscriptionRoleAssignment.bicep' = if (deployVnetPeering){
  scope: subscription()
  name: 'assignNetworkContributorToSubscription'
  params: {
    //Note: the line below returns the principal ID if deployVnetPeering is true, but 'na' if it is not; avoids error if value from non-deployed resource is called
    principalId: deployVnetPeering ? managedIdentity.properties.principalId : 'na'
    roleDefinitionId: networkContributorRoleDefinitionId
    principalType: 'ServicePrincipal'
  }
}

// Note: call reset module once per resource group. Peer reset template can accept multiple VNET names in a single deployment, but they must all be in the same resoruce group
module resetExternalVNETs 'modules/VNET/vnetPeeringReset.bicep' = if (deployVnetPeering){
  name: 'resetExternalVnets'
  dependsOn: [
    hubVnet
    albVnet
    dnsIntegratedVnet
    dnsStandaloneVnet
  ]
  params: {
    managedIdentityId: managedIdentity.id
    resourceGroupName: existingVnets.albCoreVnet.resourceGroupName
    vnetNames: [
      existingVnets.albCoreVnet.name
    ]
    location: location
  }
}

var newVnetNames = [for vnetData in items(newVnets): vnetData.value.Name]

module resetNewVnetsPeering 'modules/VNET/vnetPeeringReset.bicep' = if (deployVnetPeering){
  name: 'resetNewVnetsPeering'
  dependsOn: [
    resetExternalVNETs
  ]
  params: {
    managedIdentityId: managedIdentity.id
    resourceGroupName: resourceGroup().name
    vnetNames: newVnetNames
    location: location
  }
}
  
// ** Peer VNETs **
module hubAndSpoke 'modules/VNET/peerMap.bicep' = if (deployVnetPeering){
  name: 'initiateHubAndSpokePeering'
  dependsOn: [
    resetNewVnetsPeering
  ]
  params: {
    hubVnetId: hubVnet.outputs.vnetId
    spokeVnetIds: [
      albVnet.id
      dnsIntegratedVnet.outputs.vnetId
      dnsStandaloneVnet.outputs.vnetId
    ]
  }
}

// Deploy Automaiton Account to dealocate Azure Firewall and remove Azure Bastion every night
module shutdownAutomation 'modules/AutomationAccounts/autoShutdown.bicep' = {
  name: 'deployShutdownAutomationAccount'
  params: {
    automationAccountName: shudownAutomationAccountName
    deployScheduleJob: deployAutomationAccountScheduleJobs
    location: location
  }
}
/*

*/
