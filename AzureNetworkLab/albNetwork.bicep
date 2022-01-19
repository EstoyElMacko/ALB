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
    addressPrefixes: [
      '<prefix1>'
    ]
    //Note: The subnets object must exist, but can contain 0 or more properties. Each property must be the name of the subnet
    subnets: {
      name: '<subnet name>'
      addressPrefix: '<CIDR format IP range>'
    }
  }
}
*/
var existingVnets = {
  albCoreVent: {
    name: 'gml-eus-alb-vnet'
    resourceGroupName: 'gml-eus-networking-rg'
    addressPrefixes: [
      '10.0.0.0/16'
    ]
    subnets: {
      management: '10.1.0.0/24'
      ADO_Agents: '10.1.1.0/24'
      app: '10.1.2.0/24'
      data: '10.1.3.0/34'
      web: '10.1.4.0/24'
    }
  }
}

/* Complex object to describe name/address prefixes of VNETs to be created by this template and associated modules. 
   Each property fo newVnets must be associated with a modules in the modules/VNET folder that is named:
   <vnetName>.bicep

format:
{
  <symbolic name (friendly name or descriptor of the VNET's purpose)>: {
    name: <vnet name>
    resourceGroupName: '<resource group name>'
    addressPrefixes: [
      '<prefix1>'
    ]
    //Note: must include at least one subnet
    subnets: {
      name: <subnet name>
      addressPrefix: <CIDR format IP range - must be contained withing the VNET address prefixes>
    }
  }
}
*/
var newVnets = {
  // Central hub VNET, contains Azure Firewall (simple routing and HTTP/TCP packet filtering) and any virtual network appliances
  hubVnet: {
    name: 'gml-eus-nub-vnet'
    resourceGroupName: resourceGroup().name
    addressPrefixes: [
      '10.0.0.0/16'
    ]
    subnets: {
      AzureFirewallSubnet: '10.0.0.0/24'
    }
  }
  // spoke VNET primarily for VNET injected PaaS resources that will use ALB DNS (hosted on IaaS Domaion Controller)
  privateDnsIntegrated: {
    name:'gml-privateDns-vnet'
    resourceGroupName: resourceGroup().name
    addressPrefixes: [
      '10.2.0.0/16'
    ]
    subnets: {
      'AKS-Demo': '10.2.0.0/24'
    }
  }
  /* spoke VNET primarily for VNET injected PaaS resources that will use Azure DNS - Default route for subnets will 
     tend to be directly to internet, but that can be decided per subnet.
  */
  azureDnsIntegrated: {
    name: 'gml-eus-azureDns-vnet'
  }
}

/*
  toDo: Create a seperate module for each subnet defined in newVnets named <vnet name>.bicep.
  Ensure inpubs include:
  vnetName
  subnetObject (use subnets object as input)
  nsgId
  routeTableId
*/
