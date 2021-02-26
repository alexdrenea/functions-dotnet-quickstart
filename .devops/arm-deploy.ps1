param (
	[Parameter(Mandatory)]
	$subscriptionId,
		
	[Parameter(Mandatory)]
	$servicesName,
	
	[ValidateSet('prod','uat','qa','dev','test')]
	$environment = 'dev',
	
	$location = 'CanadaCentral'
)

## Variables

#Environment suffix for resources
$environmentSuffix = "-" + $environment.ToLower()
#Don't add -prod suffix to names
if ($environmentSuffix -eq '-prod')
{
	$environmentSuffix = ''
}

##Resource Names
$resourceGroupName = "$servicesName$environmentSuffix";
$keyvaultName = "$servicesName-kv$environmentSuffix"


#set subscription
az account set -s $subscriptionId
$subDetails = az account show | ConvertFrom-Json

$subName = $subDetails.name
Write-Host "Using Subscription '$subName'"

#create resource group

$checkRG = az group exists -g $resourceGroupName
if ($checkRG -eq $true){
	Write-Host "Resource Group '$resourceGroupName' exists. Skipping..."
}
else{
	Write-Host "Creating Resource Group '$resourceGroupName'"
	az group create `
		--resource-group $resourceGroupName `
		--location $location `
		--tags Environment=$environment 
}

$checkKV = (az keyvault list | ConvertFrom-Json).name.Contains($keyvaultName)
if ($checkKV -eq $true){
	Write-Host "KeyVault '$keyvaultName' exists. Skipping..."
}
else {
	Write-Host "Creating Key Vault '$keyvaultName'"
	az keyvault create `
		--resource-group $resourceGroupName `
		--location $location `
		--tags Environment=$environment  `
		--name $keyvaultName
}

Write-Host "Starting template deployment..."
az deployment group create `
	--resource-group $resourceGroupName `
	--template-file main-arm-template.json `
	--parameters serviceName=$servicesName environment=$environment

