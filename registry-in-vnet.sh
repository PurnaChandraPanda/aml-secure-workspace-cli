set -e

container_registry_resource=$(az ml workspace show --resource-group $RESOURCE_GROUP --name $WORKSPACE_NAME --query "container_registry" -o tsv)

# exit, if there's no acr
if [ -z "$container_registry_resource" ]; then
     echo "acr empty"
     exit
fi

# continue, if there's acr
container_registry_name=${container_registry_resource##*/}
echo $container_registry_name

pe_suffix=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 5 | head -n 1)
export PE_REGISTRY_NAME=$container_registry_name-registry-pe-$pe_suffix
export PE_REGISTRY_PRIVATE_CONNECTION_RESOURCE=/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerRegistry/registries/$container_registry_name

{ # try
    REGISTRY_PRIVATE_DNS_ZONE_RESULT=$(az network private-dns zone show -g $VNET_RESOURCE_GROUP -n $REGISTRY_PRIVATE_DNS_ZONE --query "name" -o tsv)
    if [ -z $REGISTRY_PRIVATE_DNS_ZONE_RESULT ]; then
        echo $REGISTRY_PRIVATE_DNS_ZONE "- private dns zone does not exist"
        az network private-dns zone create -g $VNET_RESOURCE_GROUP --name $REGISTRY_PRIVATE_DNS_ZONE
    else
        echo $REGISTRY_PRIVATE_DNS_ZONE "- private dns zone exists"
    fi
} || { 
    # catch exception 
    echo "not found"
}

{ # try
    REGISTRY_VNET_LINK_LIST=$(az network private-dns link vnet list -g $VNET_RESOURCE_GROUP -z $REGISTRY_PRIVATE_DNS_ZONE)
    if [ ${#FILE_VNET_LINK_LIST[@]} > 0 ]; then
        echo ">0 .. registry private dns vnet link exists"
    else
        echo "<=0 .. create private-dns link vnet"
        link_name=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 13 | head -n 1)
        az network private-dns link vnet create -g $VNET_RESOURCE_GROUP --zone-name $REGISTRY_PRIVATE_DNS_ZONE --name $link_name --virtual-network $VNET_NAME --registration-enabled false    
    fi
} || { 
    # catch exception 
    echo "not found"
}

# create private endpoint for registry
az network private-endpoint create --name $PE_REGISTRY_NAME --vnet-name $VNET_NAME --subnet $SUBNET_NAME --resource-group $VNET_RESOURCE_GROUP --private-connection-resource-id $PE_REGISTRY_PRIVATE_CONNECTION_RESOURCE --group-id registry --connection-name registry -l $REGION

az network private-endpoint dns-zone-group create -g $VNET_RESOURCE_GROUP --endpoint-name $PE_REGISTRY_NAME --name $PRIVATE_DNS_ZONE_GROUP --private-dns-zone $REGISTRY_PRIVATE_DNS_ZONE --zone-name $REGISTRY_PRIVATE_DNS_ZONE

sleep 1m

# update acr to disable public access
az acr update --resource-group $RESOURCE_GROUP --name $container_registry_name --public-network-enabled false

echo "acr PE created"