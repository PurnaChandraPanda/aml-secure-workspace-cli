set -e

export PE_SUFFIX=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 5 | head -n 1)
export PE_WORKSPACE_NAME=$WORKSPACE_NAME-ws-pe-$PE_SUFFIX
export PE_WORKSPACE_PRIVATE_CONNECTION_RESOURCE=/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.MachineLearningServices/workspaces/$WORKSPACE_NAME

# set the subsctiption id
az account set -s $SUBSCRIPTION_ID

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
EXISTING_PE=$(az network private-endpoint list \
               --resource-group "$VNET_RESOURCE_GROUP" \
               --query "[?
                    privateLinkServiceConnections[0].privateLinkServiceId=='$PE_WORKSPACE_PRIVATE_CONNECTION_RESOURCE' &&
                    contains(subnet.id, '$VNET_NAME/subnets/$SUBNET_NAME')
                ].name" -o tsv)
if [[ -z "$EXISTING_PE" ]]; then
    echo "Creating private endpoint $PE_WORKSPACE_NAME ..."
    az network private-endpoint create \
            --name                          "$PE_WORKSPACE_NAME" \
            --vnet-name                     "$VNET_NAME" \
            --subnet                        "$SUBNET_NAME" \
            --resource-group                "$VNET_RESOURCE_GROUP" \
            --private-connection-resource-id "$PE_WORKSPACE_PRIVATE_CONNECTION_RESOURCE" \
            --group-id                      amlworkspace \
            --connection-name               workspace \
            --location                      $REGION \
            --only-show-errors
else
    echo "Private endpoint for workspace already exists: $EXISTING_PE"
    
    # Read the retrieved private endpoint name
    PE_WORKSPACE_NAME=$EXISTING_PE
fi

# Create {workspace} DNS zone group for private dns zone 
ZG_EXISTS=$(az network private-endpoint dns-zone-group list \
              --resource-group      "$VNET_RESOURCE_GROUP" \
              --endpoint-name       "$PE_WORKSPACE_NAME" \
              --query "[?name=='$PRIVATE_DNS_ZONE_GROUP'].name" -o tsv)
if [[ -z "$ZG_EXISTS" ]]; then
    echo "Creating zone-group $PRIVATE_DNS_ZONE_GROUP (workspace)…"
    az network private-endpoint dns-zone-group create \
            --resource-group            "$VNET_RESOURCE_GROUP" \
            --endpoint-name             "$PE_WORKSPACE_NAME" \
            --name                      "$PRIVATE_DNS_ZONE_GROUP" \
            --private-dns-zone          "$WORKSPACE_PRIVATE_DNS_ZONE" \
            --zone-name                 "$WORKSPACE_PRIVATE_DNS_ZONE" \
            --only-show-errors
else
    echo "Workspace zone-group $PRIVATE_DNS_ZONE_GROUP already exists"
fi

# Create {notebook} DNS zone group for private dns zone 
NB_Z_EXISTS=$(az network private-endpoint dns-zone-group show \
                --resource-group    "$VNET_RESOURCE_GROUP" \
                --endpoint-name     "$PE_WORKSPACE_NAME" \
                --name              "$PRIVATE_DNS_ZONE_GROUP" \
                --query "privateDnsZoneConfigs[?name=='$WORKSPACE_NB_PRIVATE_DNS_ZONE'].name" \
                -o tsv 2>/dev/null || true)
if [[ -z "$NB_Z_EXISTS" ]]; then
    echo "Adding notebook zone-group $PRIVATE_DNS_ZONE_GROUP (workspace)…"
    az network private-endpoint dns-zone-group add \
            --resource-group            "$VNET_RESOURCE_GROUP" \
            --endpoint-name             "$PE_WORKSPACE_NAME" \
            --name                      "$PRIVATE_DNS_ZONE_GROUP" \
            --private-dns-zone          "$WORKSPACE_NB_PRIVATE_DNS_ZONE" \
            --zone-name                 "$WORKSPACE_NB_PRIVATE_DNS_ZONE" \
            --only-show-errors
else
    echo "Notebook zone-group $PRIVATE_DNS_ZONE_GROUP already exists"
fi

# update the workspace to follow private network
# check current PNA state ----------------------------------------------------
PNA_STATE=$(az ml workspace show \
              --resource-group      "$RESOURCE_GROUP" \
              --name                "$WORKSPACE_NAME" \
              --query "public_network_access" -o tsv)

if [[ "$PNA_STATE" == "Disabled" ]]; then
    echo "Workspace $WORKSPACE_NAME already has public_network_access: Disabled - skip update"
else
    echo "Updating workspace to disable public network access …"
    az ml workspace update \
            --resource-group        "$RESOURCE_GROUP" \
            --name                  "$WORKSPACE_NAME" \
            --file                  "$WORKSPACE_PL_YML" \
            --only-show-errors
fi

echo "workspace PE created"
