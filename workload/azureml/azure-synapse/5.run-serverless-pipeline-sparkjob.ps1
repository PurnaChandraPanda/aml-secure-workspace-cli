### Fill in required azure resource details
$TENANT_ID="" # Set your Azure tenant ID
$SUBSCRIPTION_ID="" # Set your Azure subscription ID
$REGION="" # Set your Azure region; e.g. eastus2
$RESOURCE_GROUP="" # Set your Azure ML workspace resource group name; e.g. rg-privateaml092
$WORKSPACE_NAME="" # Set your Azure ML workspace name; e.g. mlworkspaces10092
$PipelineYamlPath=".\spark\serverless-spark-pipeline.yml" # Path to the pipeline yaml file

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

# Submit a pipeline job with spark component
az ml job create `
        --file $PipelineYamlPath `
        --workspace-name $WORKSPACE_NAME `
        --resource-group $RESOURCE_GROUP `

Write-Host "Spark pipeline job is submitted."