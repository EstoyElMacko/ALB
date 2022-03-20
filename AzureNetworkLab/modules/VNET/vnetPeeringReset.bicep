@description('Array of VNET names. VNETs must already exist and must all be in the resource group named by the \'resourceGroupName\' parameter.')
param vnetNames array

@description('Name of the resource group containing all VNETs named in the \'vnetNames\' parameter.')
param resourceGroupName string

@description('The resource ID of the Managed Identity used to deploy the script resource. ID must already exist and all required role assignments created.')
param managedIdentityId string

@description('A uniqueness value used to ensure the deployment script is ran every time it is invoked. Without this value, the script will not execute after the first time unless something in the script has changed.')
param currentTime string = utcNow()

@description('Default location is the resource gorup location')
param location string = resourceGroup().location

var vnetNamesString = string(vnetNames)

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = if (true) {
  name: 'GetDisconnectedPeerings_${currentTime}'
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    arguments: '-vnetName \'${vnetNamesString}\' -resourceGroupName ${resourceGroupName}'
    azPowerShellVersion: '3.0'
    retentionInterval: 'PT5H'
    scriptContent: '''
    [CmdletBinding()]
    param (
        # Name of the VNET that will be checked for disconnected peerings
        [Parameter(Mandatory)]
        [string]
        $vnetName,
        
        # Name of the resource group the named VNET belongs to
        [Parameter(Mandatory)]
        [string]
        $resourceGroupName
    )
        
    # Groom value from nameList in case is is passed as a string value prepared by ARM/Bicep template
    $nameList = $vnetName -replace '(\[|\]|")' -split ',' | ForEach-Object { $_.trim() }
    $disconnectedFound = $false
    foreach ($vName in $nameList) {
        $vnetRef = Get-AzVirtualNetwork -Name $vName -ResourceGroupName $resourceGroupName
        $disconnectedPeerings = $vnetRef.VirtualNetworkPeerings | Where-Object PeeringState -eq 'Disconnected'
        if ($disconnectedPeerings.count -gt 0) {
            # Set value to true if disconnected peer is found, but do not overwrite value if not found as a previously tested VNET could have had a disconnected peering
            $disconnectedFound = $true
        }
        foreach ($discoPeer in $disconnectedPeerings) {
            #Get peer reference: The peering object in $vnetRef does not have all required properties to reset the peering connection
            $peerRef = Get-AzVirtualNetworkPeering -ResourceGroupName $resourceGroupName -VirtualNetworkName $vnetRef.Name -Name $discoPeer.Name
            $remoteVnetRef = Get-AzResource -ResourceId $peerRef.RemoteVirtualNetwork.Id -ErrorAction SilentlyContinue
            if($remoteVnetRef){
                $peerRef | Set-AzVirtualNetworkPeering | Out-Null
            }
            else {
                Remove-AzVirtualNetworkPeering -VirtualNetworkName $vName -Name $peerRef.Name -ResourceGroupName $resourceGroupName -Force
            }
        }
    }
    #verify no disconnected peerings remain in any of the vnets named in $nameList
    $verifyPeerings = $nameList | ForEach-Object {
        $vnetRef = Get-AzVirtualNetwork -Name $_ -ResourceGroupName $resourceGroupName
        $vnetRef.VirtualNetworkPeerings | Where-Object PeeringState -eq 'Disconnected'
    }
    $notDisconnected = $verifyPeerings.count -eq 0
        
    $DeploymentScriptOutputs = @{}
    # return value that indicates at least one disconnected peering was found
    $DeploymentScriptOutputs['DisconnectedFound'] = $disconnectedFound
    # return value that indicates either no disconnected peerings were found or any that were found were reset to 'Initiated'
    $DeploymentScriptOutputs['noDisconnected'] = $notDisconnected
    $DeploymentScriptOutputs['subscriptionName'] = Get-AzContext | Select-Object -ExpandProperty Subscription | Select-Object -ExpandProperty Name
    '''
  }
}

output disconnectedFound bool = deploymentScript.properties.outputs.DisconnectedFound
output noDisconnected bool = deploymentScript.properties.outputs.noDisconnected
