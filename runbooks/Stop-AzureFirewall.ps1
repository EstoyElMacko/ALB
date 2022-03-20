[CmdletBinding()]
param (
    # Name of Azure Firewall instance to be stopped    
    [Parameter()]
    [string]
    $Name,
    
    # Name of resource group containing Azure Firewall to be shut down
    [Parameter()]
    [string]
    $ResourceGroupName
)

# Enable runbook to run with the managed identity associated with the automation account
Connect-AzAccount -Environment AzureCloud -Identity

# Iterate all applicable Azure Firewall instances. Ensure tags are in place to identify VNET and Public IP addresses associated with each Azure Firewall instance so it can be restarted
$getAfwSplat = @{}
if ($Name) {
    $getAfwSplat['Name'] = $Name
}
if ($ResourceGroupName) {
    $getAfwSplat['ResourceGroupName'] = $ResourceGroupName
}
$firewalInstances = Get-AzFirewall @getAfwSplat

$subnetIdPattern = '/subscriptions/[^/]+/resourceGroups/(?<ResourceGroupName>[^/]+)/providers/Microsoft.Network/virtualNetworks/(?<vnetName>[^/]+)/subnets/(?<subnetName>.+)$'
foreach ($azfw in $firewalInstances) {
    #region Get reallocation data
    $subnetId = $azfw.IpConfigurations[0].Subnet.Id
    # Match subnet ID with $subnetIdPattern. -match operation generates a $matches object that will have named matches defined in the pattern
    $isMatch = $subnetId -match $subnetIdPattern
    if ($false -eq $isMatch) {
        Write-Warning "Unable to parse subnet ID from IP configuration. Check the subnetIdPattern"
        exit
    }
    $ResourceGroupName = $matches.ResourceGroupName
    $vnetName = $matches.vnetName
    $pip = @()
    $managementPIP = @()
    foreach ($ipConfig in $azfw.IpConfigurations) {
        $ipConfig.Subnet.Id -match $subnetIdPattern | Out-Null
        $pipName = $ipConfig.PublicIpAddress.Id -split '/' | Select-Object -Last 1
        switch ($matches.subnetName) {
            'AzureFirewallSubnet' { 
                $pip += $_
            }
            'AzureFirewallManagementSubnet' {
                $managementPIP += $_
            }
        }
    }
    $tagData = @{
        resourceGroupName = $ResourceGroupName
        vnetName = $vnetName
        #Note: sending $pip to ForEach-Object so result will be scalar if only one or an array if more than one
        publicIpName = $pip | ForEach-Object{$_}
    }
    if($managementPIP.count -gt 0){
                #Note: sending $managementPIP to ForEach-Object so result will be scalar if only one or an array if more than one
        $tagData['managementPIP'] = $managementPIP | ForEach-Object{$_}
    }
    $tagValue = [PSCustomObject]$tagData | ConvertTo-Json
    #endregion Get reallocaiton data
    if ($azfw.Tag['allocationData'] -ne $tagValue) {
        $azfw.Tag['allocationData'] = $tagValue
    }
    $azfw.Deallocate()
    $azfw | Set-AzFirewall
}

