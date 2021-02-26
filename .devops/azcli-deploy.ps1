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
$aspNetCoreEnvironment = 'Development'
$environmentSuffix = "-" + $environment.ToLower()
if ($environmentSuffix -eq '-prod')
{
	$environmentSuffix = ''
	$aspNetCoreEnvironment = 'Production'
}

##Resource Names
$resourceGroupName = "$servicesName$environmentSuffix";
$appInsightsName = "$servicesName-ai$environmentSuffix"
$functionAppName = "$servicesName-func$environmentSuffix"
$keyVaultName = "$servicesName-kv$environmentSuffix"
$cosmosName = "$servicesName-cosmos$environmentSuffix".ToLower()

if($storageAccountName -eq $null){
	$storageAccountName = $servicesName.ToLower().Replace('-','').Replace('_','') + 'storage'
	if ($storageAccountName.Length > 20){
		$storageAccountName = $storageAccountName.Substring(0,20)
	}
	$storageAccountName += $environmentSuffix.Replace('-','')
}

#set subscription
az account set -s $subscriptionId
$subDetails = az account show | ConvertFrom-Json
$subName = $subDetails.name
$tenantId = $subDetails.tenantId

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

#create keyvault
$checkKV = (az keyvault list | ConvertFrom-Json).name.Contains($keyVaultName)
if ($checkKV -eq $true){
	Write-Host "KeyVault '$keyVaultName' exists. Skipping..."
}
else {
	Write-Host "Creating Key Vault '$keyVaultName'"
	az keyvault create `
		--resource-group $resourceGroupName `
		--location $location `
		--tags Environment=$environment  `
		--name $keyVaultName
}

##Storage Account
Write-Host "Creating Storage Account '$storageAccountName'"	
#Create storage account
az storage account create `
	--resource-group $resourceGroupName `
	--name $storageAccountName `
	--location $location `
	--tags Environment=$environment  `
	--sku Standard_LRS

#Save secrets in KeyVault
$storageConnectionString = `
	az storage account show-connection-string `
		--resource-group $resourceGroupName `
		--name $storageAccountName `
		--query connectionString --output tsv

az keyvault secret set `
	--vault-name $keyVaultName `
	--name 'Storage--ConnectionString' `
	--value $storageConnectionString

$storageAccountKey = 
	(az storage account keys list `
		--resource-group $resourceGroupName `
		--account-name $storageAccountName `
		| ConvertFrom-Json)[0].value

az keyvault secret set `
	--vault-name $keyVaultName `
	--name 'Storage--AccountKey' `
	--value $storageAccountKey


##Application Insights
Write-Host "Creating App Insights '$appInsightsName'..."	
az monitor app-insights component create `
	--resource-group $resourceGroupName `
	--app $appInsightsName `
	--location $location `
	--tags Environment=$environment  `
	--kind web `
	--application-type web
$appInsights = az monitor app-insights component show -g $resourceGroupName -a $appInsightsName | ConvertFrom-Json

##Function App
#Create functions
Write-Host "Creating Azure Functions '$functionAppName'"	
az functionapp create `
	--resource-group $resourceGroupName `
	--name $functionAppName `
	--tags Environment=$environment  `
	--consumption-plan-location $location `
	--storage-account $storageAccountName `
	--functions-version 3 `
	--os-type Windows `
	--runtime dotnet `
	--app-insights $appInsightsName `
	--app-insights-key $appInsights.instrumentationKey

#Set configuration	
az functionapp config appsettings set `
	--resource-group $resourceGroupName `
	--name $functionAppName `
	--settings AzureWebJobsStorage=$storageConnectionString `
			   AzureWebJobsDashboard=$storageConnectionString `
			   WEBSITE_CONTENTAZUREFILECONNECTIONSTRING=$storageConnectionString `
			   WEBSITE_CONTENTSHARE="$functionAppName-0210b" `
			   ASPNETCORE_ENVIRONMENT=$aspNetCoreEnvironment `
			   KeyVaultUrl="https://$keyVaultName.vault.azure.net/" `
			   AZURE_TENANT_ID=$tenantId 

#Assign identity
az webapp identity assign `
	--resource-group $resourceGroupName `
	--name $functionAppName 

$functionIdentity = 
	(az webapp identity show `
		--resource-group $resourceGroupName `
		--name $functionAppName `
		| ConvertFrom-Json).principalId

#Give KeyVault permissions
az keyvault set-policy `
	--resource-group $resourceGroupName `
	--name $keyVaultName `
	--object-id $functionIdentity `
	--secret-permissions get list

#Create CosmosDB account
Write-Host "Creating Cosmos DB account"
az cosmosdb create `
	--resource-group $resourceGroupName `
	--name $cosmosName `
	--tags Environment=$environment  `
	--default-consistency-level Session `
	--locations regionName=$location failoverPriority=0 isZoneRedundant=False `
	--capabilities EnableServerless

$cosmosAccountKey = (az cosmosdb keys list --resource-group $resourceGroupName --name $cosmosName | ConvertFrom-Json).primaryMasterKey 
$cosmosConnectionString = (az cosmosdb keys list --resource-group $resourceGroupName --name $cosmosName --type connection-strings  | ConvertFrom-Json).connectionStrings[0].connectionString

az keyvault secret set `
	--vault-name $keyVaultName `
	--name 'CosmosDb--AccountKey' `
	--value $cosmosAccountKey
	
az keyvault secret set `
	--vault-name $keyVaultName `
	--name 'CosmosDb--ConnectionString' `
	--value $cosmosConnectionString
	
