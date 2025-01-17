set -e

export PE_SUFFIX=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 5 | head -n 1)
export PE_WORKSPACE_NAME=$WORKSPACE_NAME-ws-pe-$PE_SUFFIX
export PE_PRIVATE_CONNECTION_RESOURCE=/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.MachineLearningServices/workspaces/$WORKSPACE_NAME

# set the subsctiption id
az account set -s $SUBSCRIPTION_ID

echo "updating workspace with public network access: disabled ....."

# update the workspace to follow private network
az ml workspace update --resource-group $RESOURCE_GROUP --name $WORKSPACE_NAME --file $WORKSPACE_PL_YML

{ # try
    WORKSPACE_PRIVATE_DNS_ZONE_RESULT=$(az network private-dns zone show -g $VNET_RESOURCE_GROUP -n $WORKSPACE_PRIVATE_DNS_ZONE --query "name" -o tsv)
    if [ -z $WORKSPACE_PRIVATE_DNS_ZONE_RESULT ]; then
        echo $WORKSPACE_PRIVATE_DNS_ZONE "- private dns zone does not exist"  
        az network private-dns zone create -g $VNET_RESOURCE_GROUP --name $WORKSPACE_PRIVATE_DNS_ZONE      
    else
        echo $WORKSPACE_PRIVATE_DNS_ZONE "- private dns zone exists"
    fi
} || { 
    # catch exception 
    echo "not found"
}

{ # try
    VNET_LINK_LIST=$(az network private-dns link vnet list -g $VNET_RESOURCE_GROUP -z $WORKSPACE_PRIVATE_DNS_ZONE)
    if [ $(echo $VNET_LINK_LIST | jq '. | length') -gt 0 ]; then
        echo ">0 .. workspace private dns vnet link exists"
    else
        echo "<=0 .. create workspace private-dns link vnet"
        link_name=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 13 | head -n 1)
        az network private-dns link vnet create -g $VNET_RESOURCE_GROUP --zone-name $WORKSPACE_PRIVATE_DNS_ZONE --name $link_name --virtual-network $VNET_NAME --registration-enabled false
    fi
} || { 
    # catch exception 
    echo "not found"
}

{ # try
    NB_WORKSPACE_PRIVATE_DNS_ZONE_RESULT=$(az network private-dns zone show -g $VNET_RESOURCE_GROUP -n $WORKSPACE_NB_PRIVATE_DNS_ZONE --query "name" -o tsv)
    if [ -z $NB_WORKSPACE_PRIVATE_DNS_ZONE_RESULT ]; then
        echo $WORKSPACE_NB_PRIVATE_DNS_ZONE "- private dns zone does not exist"
        az network private-dns zone create -g $VNET_RESOURCE_GROUP --name $WORKSPACE_NB_PRIVATE_DNS_ZONE 
    else
        echo $WORKSPACE_NB_PRIVATE_DNS_ZONE "- private dns zone exists"
    fi
} || { 
    # catch exception 
    echo "not found"
}

{ # try
    NB_VNET_LINK_LIST=$(az network private-dns link vnet list -g $VNET_RESOURCE_GROUP -z $WORKSPACE_NB_PRIVATE_DNS_ZONE)
    if [ $(echo $NB_VNET_LINK_LIST | jq '. | length') -gt 0 ]; then
        echo ">0 .. NB workspace private dns vnet link exists"
    else
        echo "<=0 .. create NB workspace private-dns link vnet"
        link_name=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 13 | head -n 1)
        az network private-dns link vnet create -g $VNET_RESOURCE_GROUP --zone-name $WORKSPACE_NB_PRIVATE_DNS_ZONE --name $link_name --virtual-network $VNET_NAME --registration-enabled false
    fi
} || { 
    # catch exception 
    echo "not found"
}

# create private endpoint for workspace
az network private-endpoint create --name $PE_WORKSPACE_NAME --vnet-name $VNET_NAME --subnet $SUBNET_NAME --resource-group $VNET_RESOURCE_GROUP --private-connection-resource-id $PE_PRIVATE_CONNECTION_RESOURCE --group-id amlworkspace --connection-name workspace -l $REGION

sleep 1m

az network private-endpoint dns-zone-group create -g $VNET_RESOURCE_GROUP --endpoint-name $PE_WORKSPACE_NAME --name $PRIVATE_DNS_ZONE_GROUP --private-dns-zone $WORKSPACE_PRIVATE_DNS_ZONE --zone-name $WORKSPACE_PRIVATE_DNS_ZONE

az network private-endpoint dns-zone-group add -g $VNET_RESOURCE_GROUP --endpoint-name $PE_WORKSPACE_NAME --name $PRIVATE_DNS_ZONE_GROUP --private-dns-zone $WORKSPACE_NB_PRIVATE_DNS_ZONE --zone-name $WORKSPACE_NB_PRIVATE_DNS_ZONE

sleep 1m

echo "workspace PE created"
