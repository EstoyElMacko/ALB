@description('Azure Firewall Policy name')
param firewallPolicyName string

@description('CIDR format IP range for subnet where AD domain controllers are located')
param domainControllerSubnetIpRanges array

@description('CIDR format IP range of AKS cluster subnets. Used to ensure AKS service traffic is allowed to internet')
param azureKubernetesServiceSubnetRanges array

@description('Default location is the resource group location')
param location string = resourceGroup().location

resource fwPolicy 'Microsoft.Network/firewallPolicies@2021-05-01' = {
  name: firewallPolicyName
  location: location
  properties: {
    dnsSettings: {
      enableProxy: true
    }
    sku: {
      tier: 'Standard'
    }
  }
  //Important!!! Use dependOn to ensure each subresource only runs when the previous one finishes to avoid AnotherOperationInProgress deployment error
  resource natRuleCollctionGroups 'ruleCollectionGroups' = {
    name: 'natRuleCollctionGroup'
    properties: {
      priority: 100
    }
  }
  // Within a rule colleciton group, network rules are processed before app rules. This group ensures specific app rules are processed before network rules.
  resource priorityApplicationruleCollectionGroup 'ruleCollectionGroups' = {
    name: 'priorityApplicationRuleCollectionGroup'
    dependsOn: [
      natRuleCollctionGroups
    ]
    properties: {
      priority: 200
    }
  }
  resource aksruleCollectionGroup 'ruleCollectionGroups' = {
    name: 'aksRuleCollectionGroups'
    dependsOn: [
      priorityApplicationruleCollectionGroup
    ]
    properties: {
      priority: 300
      ruleCollections: [
        {
          name: 'AKS-Service-Traffic-Network-Rules'
          priority: 200
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          action: {
            type: 'Allow'
          }
          rules: [
            {
              ruleType: 'NetworkRule'
              name: 'aks nodes to controller - UDP'
              ipProtocols: [
                'UDP'
              ]
              sourceAddresses: azureKubernetesServiceSubnetRanges
              sourceIpGroups: []
              destinationAddresses: [
                'AzureCloud'
              ]
              destinationIpGroups: []
              destinationFqdns: []
              destinationPorts: [
                '1194'
              ]
            }
            {
              ruleType: 'NetworkRule'
              name: 'aks nodes to controller - TCP'
              ipProtocols: [
                'TCP'
              ]
              sourceAddresses: azureKubernetesServiceSubnetRanges
              sourceIpGroups: []
              destinationAddresses: [
                'AzureCloud'
              ]
              destinationIpGroups: []
              destinationFqdns: []
              destinationPorts: [
                '9000'
              ]
            }
            {
              ruleType: 'NetworkRule'
              name: 'aks nodes to NTP'
              ipProtocols: [
                'UDP'
              ]
              sourceAddresses: azureKubernetesServiceSubnetRanges
              sourceIpGroups: []
              destinationAddresses: []
              destinationIpGroups: []
              destinationFqdns: [
                'ntp.ubuntu.com'
              ]
              destinationPorts: [
                '123'
              ]
            }
            {
              ruleType: 'NetworkRule'
              name: 'aks nodes to DNS'
              ipProtocols: [
                'UDP'
              ]
              sourceAddresses: azureKubernetesServiceSubnetRanges
              sourceIpGroups: []
              destinationAddresses: [
                '*'
              ]
              destinationIpGroups: []
              destinationFqdns: []
              destinationPorts: [
                '53'
              ]
            }
            {
              ruleType: 'NetworkRule'
              name: 'Azure Monitor'
              ipProtocols: [
                'TCP'
              ]
              sourceAddresses: azureKubernetesServiceSubnetRanges
              sourceIpGroups: []
              destinationAddresses: [
                'AzureMonitor'
              ]
              destinationIpGroups: []
              destinationFqdns: []
              destinationPorts: [
                '443'
              ]
            }
            {
              ruleType: 'NetworkRule'
              name: 'Azure Storage'
              ipProtocols: [
                'TCP'
              ]
              sourceAddresses: azureKubernetesServiceSubnetRanges
              sourceIpGroups: []
              destinationAddresses: [
                'Storage'
              ]
              destinationIpGroups: []
              destinationFqdns: []
              destinationPorts: [
                '443'
              ]
            }
          ]
        }
        {
          name: 'AKS-Service-Traffic-Application'
          priority: 300
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          action: {
            type: 'Allow'
          }
          rules: [
            {
              ruleType: 'ApplicationRule'
              name: 'AKS Service Traffic'
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              fqdnTags: [
                'AzureKubernetesService'
              ]
              webCategories: []
              targetFqdns: []
              targetUrls: []
              terminateTLS: false
              sourceAddresses: azureKubernetesServiceSubnetRanges
              destinationAddresses: []
              sourceIpGroups: []
            }
          ]
        }
      ]
      }
    }
  resource defaultruleCollectionGroup 'ruleCollectionGroups' = {
    name: 'defaultRuleCollectionGroups'
    dependsOn: [
      aksruleCollectionGroup
    ]
    properties: {
      priority: 30000
      ruleCollections: [
        {
          name: 'Allow-DNS-in-Private-Network'
          priority: 200
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'Allow DNS to custom DNS solution'
              ruleType: 'NetworkRule'
              sourceAddresses: [
                '10.0.0.0/8'
              ]
              destinationAddresses: domainControllerSubnetIpRanges
              ipProtocols: [
                'TCP'
                'UDP'
              ]
              destinationPorts: [
                '53'
              ]
            }
            {
              name: 'Allow DNS from custom DNS solution'
              ruleType: 'NetworkRule'
              sourceAddresses: domainControllerSubnetIpRanges
              destinationAddresses: [
                '10.0.0.0/8'
              ]
              ipProtocols: [
                'TCP'
                'UDP'
              ]
              destinationPorts: [
                '53'
              ]
            }
          ]
        }
      ]
    }
  }
}

output policyId string = fwPolicy.id
