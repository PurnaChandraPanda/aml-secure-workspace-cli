### Fill in required azure resource details
$TENANT_ID="" # Set your Azure tenant ID
$SUBSCRIPTION_ID="" # Set your Azure subscription ID
$REGION="" # Set your Azure region; e.g. eastus2
$RESOURCE_GROUP="" # Set your Azure ML workspace resource group name; e.g. rg-eus2-sparks
$WORKSPACE_NAME="" # Set your Azure ML workspace name; e.g. mlworkspaces10092
$AttachedSparkComputeName="" # Set your attached synapse spark compute name; e.g. syn1c
$PipelineYamlPath=".\spark\attached-spark-standalone.yml" # Path to the pipeline yaml file

# Login to Azure CLI
# az login --tenant $TENANT_ID

# Set the subscription
# az account set --subscription $SUBSCRIPTION_ID

# Check on ml workspace
$WS_ID = $(az ml workspace show `
                        --name $WORKSPACE_NAME `
                        --resource-group $RESOURCE_GROUP `
                        --query id -o tsv 2>$null)

if (-not $WS_ID) {
    Write-Host "ML Workspace $WORKSPACE_NAME not found in resource group $RESOURCE_GROUP" -ForegroundColor Red
    exit 1
}

Write-Host "ML Workspace found: $WS_ID"

# Ensure compute exists and is synapseSpark
$compJson = $(az ml compute show `
                        --name $AttachedSparkComputeName `
                        --workspace-name $WORKSPACE_NAME `
                        --resource-group $RESOURCE_GROUP `
                        --output json 2>$null)

if (-not $compJson) {
    Write-Host "Compute $AttachedSparkComputeName not found in workspace $WORKSPACE_NAME" -ForegroundColor Red
    exit 1
}
$comp = $compJson | ConvertFrom-Json
if ($comp.type -ne "synapsespark") {
    Write-Host "Compute $AttachedSparkComputeName is not of type SynapseSpark, actual type: $($comp.type)" -ForegroundColor Red
    exit 1
}
Write-Host "Compute found: $AttachedSparkComputeName of type $($comp.type)"

# Submit a standalone spark job
az ml job create `
        --file $PipelineYamlPath --set "compute=azureml:$AttachedSparkComputeName" `
        --workspace-name $WORKSPACE_NAME `
        --resource-group $RESOURCE_GROUP `

Write-Host "Spark standalone job is submitted."