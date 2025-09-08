#!/bin/bash

set -e

## AI service resource group and account name details
resourceGroupName=""
accountName=""

#<list-models>
# Gets the last version of each model definition available in the GlobalStandard SKU
az cognitiveservices account  list-models --name $accountName --resource-group  $resourceGroupName --output table
#</list-models>
