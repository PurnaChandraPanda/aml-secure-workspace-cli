## !/bin/bash

set -e

# Variables
# Replace with your Cognitive Services account name and resource group name
accountName=""
resourceGroupName=""

#<list-models>
# Gets the last version of each model definition available in the GlobalStandard SKU
az cognitiveservices account  list-models --name $accountName --resource-group  $resourceGroupName --output table
#</list-models>