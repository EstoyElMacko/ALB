[CmdletBinding()]
param (
    [Parameter()]

    [string]
    $resourceGroupName = 'alb-eus-netorking-rg'
)

Push-Location
Set-Location $PSScriptRoot
New-AzResourceGroupDeployment -Name deployAlbNetworkLab -ResourceGroupName $resourceGroupName -TemplateFile .\albNetwork.bicep -TemplateParameterFile .\albNetwork.parameters.json

