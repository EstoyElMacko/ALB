[CmdletBinding()]
param (
    [parameter()]
	[string]
	$subscriptionName = 'shmack-AIRS',
	
	# Name of Azure Bastion host to be stopped    
    [Parameter()]
    [string]
    $Name,
    
    # Name of resource group containing Azure Bastion to be shut down
    [Parameter()]
    [string]
    $ResourceGroupName
)

# Enable runbook to run with the managed identity associated with the automation account
Connect-AzAccount -Environment AzureCloud -Identity -Subscription $subscriptionName
Get-AzContext

if([string]::IsNullOrEmpty($Name) -and [string]::IsNullOrEmpty($ResourceGroupName)){
	$bastions = Get-AzBastion
}
else{
    $getBastionSplat = @{}
    if ($Name) {
        $getBastionSplat['Name'] = $Name
    }
    if ($ResourceGroupName) {
        $getBastionSplat['ResourceGroupName'] = $ResourceGroupName
    }
    $bastions = Get-AzBastion @getBastionSplat
}

if($bastions){
	$bastions | Remove-AzBastion -Force
}
else {
	"No bastion hosts found"
}
