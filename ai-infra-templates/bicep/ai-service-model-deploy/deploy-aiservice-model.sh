# AI service resource group and account name details
RESOURCE_GROUP=""
ACCOUNT_NAME=""

# Run ./get-models.sh to get the oss model details
## e.g. MODEL_NAME="gpt-oss-120b" VERSION="1" PROVIDER="OpenAI-OSS"
MODEL_NAME=""
VERSION=""
PROVIDER=""

az deployment group create --resource-group $RESOURCE_GROUP --template-file ai-services-deployment-template.bicep --parameters accountName=$ACCOUNT_NAME modelName=$MODEL_NAME modelVersion=$VERSION modelPublisherFormat=$PROVIDER

