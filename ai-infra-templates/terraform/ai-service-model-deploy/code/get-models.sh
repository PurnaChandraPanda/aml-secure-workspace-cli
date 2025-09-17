## !/bin/bash

set -e

# Variables
# Replace with your Cognitive Services account name and resource group name
accountName="foundryeus00321"
resourceGroupName="rg-foundry1eus"

#<list-models>
# Gets the last version of each model definition available in the GlobalStandard SKU
az cognitiveservices account  list-models --name $accountName --resource-group  $resourceGroupName --output table
#</list-models>