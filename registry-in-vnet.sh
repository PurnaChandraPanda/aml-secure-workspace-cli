set -e

container_registry_resource="$1"
if [[ -z "$container_registry_resource" ]]; then
    echo "Usage: resgistry-in-vnet.sh <registry_resource_id>"
    exit 1
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
    if [ $(echo $REGISTRY_VNET_LINK_LIST | jq '. | length') -gt 0 ]; then
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

# Create private endpoint for registry
EXISTING_PE=$(az network private-endpoint list \
               --resource-group "$VNET_RESOURCE_GROUP" \
               --query "[?
                    privateLinkServiceConnections[0].privateLinkServiceId=='$PE_REGISTRY_PRIVATE_CONNECTION_RESOURCE' &&
                    contains(subnet.id, '$VNET_NAME/subnets/$SUBNET_NAME')
                ].name" -o tsv)
if [[ -z "$EXISTING_PE" ]]; then
    echo "Creating private endpoint $PE_REGISTRY_NAME ..."
    az network private-endpoint create \
                --name                  "$PE_REGISTRY_NAME" \
                --vnet-name             "$VNET_NAME" \
                --subnet                "$SUBNET_NAME" \
                --resource-group        "$VNET_RESOURCE_GROUP" \
                --private-connection-resource-id "$PE_REGISTRY_PRIVATE_CONNECTION_RESOURCE" \
                --group-id              registry \
                --connection-name       registry \
                --location $REGION \
                --only-show-errors
else
    echo "Private endpoint for Container Registry already exists: $EXISTING_PE"

    # Read the retrieved private endpoint name
    PE_REGISTRY_NAME=$EXISTING_PE
fi

# Create DNS zone group for private dns zone
ZG_NAME=$(az network private-endpoint dns-zone-group show \
            --endpoint-name  "$PE_REGISTRY_NAME" \
            --name           "$PRIVATE_DNS_ZONE_GROUP" \
            --resource-group "$VNET_RESOURCE_GROUP" \
            --query name -o tsv 2>/dev/null)
if [[ -z "$ZG_NAME" ]]; then
    echo "Creating DNS zone group for private endpoint $PE_REGISTRY_NAME ..."
    az network private-endpoint dns-zone-group create \
        --resource-group                "$VNET_RESOURCE_GROUP" \
        --endpoint-name                 "$PE_REGISTRY_NAME" \
        --name                          "$PRIVATE_DNS_ZONE_GROUP" \
        --private-dns-zone              "$REGISTRY_PRIVATE_DNS_ZONE" \
        --zone-name $REGISTRY_PRIVATE_DNS_ZONE \
        --only-show-errors
else
    echo "DNS zone group for private endpoint $PE_REGISTRY_NAME already exists"
fi


# update the ACR to follow private network
# check current PNA state ----------------------------------------------------
PNA_STATE=$(az acr show \
              --resource-group "$RESOURCE_GROUP" \
              --name            "$container_registry_name" \
              --query "publicNetworkAccess" \
              -o tsv)
if [[ "$PNA_STATE" == "Disabled" ]]; 
then
    echo "Container Registry $container_registry_name already has public_network_access: Disabled - skip update"
else
    echo "Disabling public network access for Container Registry $container_registry_name..."
    az acr update \
            --resource-group            "$RESOURCE_GROUP" \
            --name                      "$container_registry_name" \
            --public-network-enabled    false \
            --only-show-errors
fi

echo "acr PE created"