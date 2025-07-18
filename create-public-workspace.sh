set -e

export SUBSCRIPTION_ID="" #"49------------30e1c09b41"
export RESOURCE_GROUP="" #"vnetwspp0012-rg"
export WORKSPACE_NAME="" #"vnetwspp0012"
export REGION="" #"centralindia"

# set true, if acr need to be created
# set false, if acr need not be created
export ACR_INTEGRATE=true 

# set the subsctiption id
az account set -s $SUBSCRIPTION_ID

# create resource group if does not exist
{ # try
    RG_RESULT=$(az group show --resource-group $RESOURCE_GROUP --query name -o tsv)
    if [ -z $RG_RESULT ]; then
        echo "create resource group ..."
        az group create -l $REGION -n $RESOURCE_GROUP
    else
        echo "resource group exists"
    fi
} || { 
    # catch exception 
    echo "not found"
}

# create workspace - will create applicationinsights, storage, keyvault
az ml workspace create -n $WORKSPACE_NAME -g $RESOURCE_GROUP -l $REGION

if $ACR_INTEGRATE 
then
    echo "integrate acr"
    random_suffix=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)
    REGISTRY_NAME=$WORKSPACE_NAME"reg"$random_suffix

    # create acr resource with admin enabled
    REGISTRY_ID=$(az acr create -n $REGISTRY_NAME -g $RESOURCE_GROUP -l $REGION --sku Premium --admin-enabled true --query id -o tsv)
    echo "acr resource -" $REGISTRY_ID

    # update aml with the just created acr as registry
    az ml workspace update -n $WORKSPACE_NAME -g $RESOURCE_GROUP -c $REGISTRY_ID -u

    echo "acr is integrated with aml workspace"
else
    echo "no acr integration"
fi

echo "now, update the vnet integration (if needed) ..... "

