@description('Azure Firewall Policy name')
param firewallPolicyName string

@description('CIDR format IP range for subnet where AD domain controllers are located')
param domainControllerSubnetIpRanges array


resource fwPolicy 'Microsoft.Network/firewallPolicies@2021-05-01' = {
  name: firewallPolicyName
  location: resourceGroup().location
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
