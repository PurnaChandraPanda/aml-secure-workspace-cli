set -e

storage_account_resource="$1"
if [[ -z "$storage_account_resource" ]]; then
    echo "Usage: storage-in-vnet.sh <storage_account_resource_id>"
    exit 1
fi
storage_account_name=${storage_account_resource##*/}
echo $storage_account_name

export PE_SUFFIX=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 5 | head -n 1)
export PE_STORAGEFILE_NAME=$storage_account_name-file-pe-$PE_SUFFIX
export PE_STORAGEBLOB_NAME=$storage_account_name-blob-pe-$PE_SUFFIX
export PE_STORAGE_PRIVATE_CONNECTION_RESOURCE=/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$storage_account_name

{ # try
    FILE_PRIVATE_DNS_ZONE_RESULT=$(az network private-dns zone show -g $VNET_RESOURCE_GROUP -n $STORAGE_FILE_PRIVATE_DNS_ZONE --query "name" -o tsv)
    if [ -z $FILE_PRIVATE_DNS_ZONE_RESULT ]; then
        echo $STORAGE_FILE_PRIVATE_DNS_ZONE "- private dns zone does not exist"
        az network private-dns zone create -g $VNET_RESOURCE_GROUP --name $STORAGE_FILE_PRIVATE_DNS_ZONE
    else
        echo $STORAGE_FILE_PRIVATE_DNS_ZONE "- private dns zone exists"
    fi
} || { 
    # catch exception 
    echo "not found"
}

{ # try
    FILE_VNET_LINK_LIST=$(az network private-dns link vnet list -g $VNET_RESOURCE_GROUP -z $STORAGE_FILE_PRIVATE_DNS_ZONE)    
    if [ $(echo $FILE_VNET_LINK_LIST | jq '. | length') -gt 0 ]; then
        echo ">0 .. file private dns vnet link exists"
    else
        echo "<=0 .. create private-dns link vnet"
        link_name=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 13 | head -n 1)
        az network private-dns link vnet create -g $VNET_RESOURCE_GROUP --zone-name $STORAGE_FILE_PRIVATE_DNS_ZONE --name $link_name --virtual-network $VNET_NAME --registration-enabled false    
    fi
} || { 
    # catch exception 
    echo "not found"
}

{ # try
    BLOB_PRIVATE_DNS_ZONE_RESULT=$(az network private-dns zone show -g $VNET_RESOURCE_GROUP -n $STORAGE_BLOB_PRIVATE_DNS_ZONE --query "name" -o tsv)
    if [ -z $BLOB_PRIVATE_DNS_ZONE_RESULT ]; then
        echo $STORAGE_BLOB_PRIVATE_DNS_ZONE "- private dns zone does not exist"
        az network private-dns zone create -g $VNET_RESOURCE_GROUP --name $STORAGE_BLOB_PRIVATE_DNS_ZONE
    else
        echo $STORAGE_BLOB_PRIVATE_DNS_ZONE "- private dns zone exists"
    fi
} || { 
    # catch exception 
    echo "not found"
}

{ # try
    BLOB_VNET_LINK_LIST=$(az network private-dns link vnet list -g $VNET_RESOURCE_GROUP -z $STORAGE_BLOB_PRIVATE_DNS_ZONE)
    if [ $(echo $BLOB_VNET_LINK_LIST | jq '. | length') -gt 0 ]; then
        echo ">0 .. blob private dns vnet link exists"
    else
        echo "<=0 .. create private-dns link vnet"
        link_name=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 13 | head -n 1)
        az network private-dns link vnet create -g $VNET_RESOURCE_GROUP --zone-name $STORAGE_BLOB_PRIVATE_DNS_ZONE --name $link_name --virtual-network $VNET_NAME --registration-enabled false    
    fi
} || { 
    # catch exception 
    echo "not found"
}

# Create private endpoint for storage (file)
FILE_PE_EXISTS=$(az network private-endpoint list \
                   --resource-group "$VNET_RESOURCE_GROUP" \
                   --query "[?
                       privateLinkServiceConnections[0].privateLinkServiceId=='$PE_STORAGE_PRIVATE_CONNECTION_RESOURCE' &&
                       privateLinkServiceConnections[0].groupIds[0]=='file' &&
                       contains(subnet.id, '$VNET_NAME/subnets/$SUBNET_NAME')
                     ].name" -o tsv)

if [[ -z "$FILE_PE_EXISTS" ]]; then
    echo "Creating private endpoint for storage file $FILE_PE_EXISTS …"
    az network private-endpoint create \
        --name                  "$PE_STORAGEFILE_NAME" \
        --vnet-name             "$VNET_NAME" \
        --subnet                "$SUBNET_NAME" \
        --resource-group        "$VNET_RESOURCE_GROUP" \
        --private-connection-resource-id "$PE_STORAGE_PRIVATE_CONNECTION_RESOURCE" \
        --group-id              file \
        --connection-name       file \
        --location              "$REGION" \
        --only-show-errors
else
    echo "Private endpoint for storage file $FILE_PE_EXISTS already exists"

    ## Read the PE values from recent query on PE than reading the initialized variables
    PE_STORAGEFILE_NAME=$(printf '%s\n' "$FILE_PE_EXISTS" | head -n1)
fi

# Create private endpoint for storage (blob)
BLOB_PE_EXISTS=$(az network private-endpoint list \
                   --resource-group "$VNET_RESOURCE_GROUP" \
                   --query "[?
                       privateLinkServiceConnections[0].privateLinkServiceId=='$PE_STORAGE_PRIVATE_CONNECTION_RESOURCE' &&
                       privateLinkServiceConnections[0].groupIds[0]=='blob' &&
                       contains(subnet.id, '/subnets/$SUBNET_NAME')
                     ].name" -o tsv)

if [[ -z "$BLOB_PE_EXISTS" ]]; then
    echo "Creating private endpoint for storage blob $BLOB_PE_EXISTS ..."
    az network private-endpoint create \
            --name          "$PE_STORAGEBLOB_NAME" \
            --vnet-name     "$VNET_NAME" \
            --subnet        "$SUBNET_NAME" \
            --resource-group "$VNET_RESOURCE_GROUP" \
            --private-connection-resource-id "$PE_STORAGE_PRIVATE_CONNECTION_RESOURCE" \
            --group-id        blob \
            --connection-name blob \
            --location      "$REGION" \
            --only-show-errors
else
    echo "Private endpoint for storage blob $BLOB_PE_EXISTS already exists"

    ## Read the PE values from recent query on PE than reading the initialized variables
    PE_STORAGEBLOB_NAME=$(printf '%s\n' "$BLOB_PE_EXISTS" | head -n1)
fi

# Create private DNS zone group for storage file private dns zone
ZG_NAME=$(az network private-endpoint dns-zone-group show \
            --endpoint-name  "$PE_STORAGEFILE_NAME" \
            --name           "$PRIVATE_DNS_ZONE_GROUP" \
            --resource-group "$VNET_RESOURCE_GROUP" \
            --query name -o tsv 2>/dev/null)
if [[ -z "$ZG_NAME" ]]; then
    echo "Creating DNS-zone group for file endpoint …"
    az network private-endpoint dns-zone-group create \
        --resource-group        "$VNET_RESOURCE_GROUP" \
        --endpoint-name         "$PE_STORAGEFILE_NAME" \
        --name                  "$PRIVATE_DNS_ZONE_GROUP" \
        --private-dns-zone      "$STORAGE_FILE_PRIVATE_DNS_ZONE" \
        --zone-name             "$STORAGE_FILE_PRIVATE_DNS_ZONE" \
        --only-show-errors
else
    echo "DNS-zone group for file endpoint already exists"
fi

# Create private DNS zone group for storage blob private dns zone
ZGB_NAME=$(az network private-endpoint dns-zone-group show \
            --endpoint-name  "$PE_STORAGEBLOB_NAME" \
            --name           "$PRIVATE_DNS_ZONE_GROUP" \
            --resource-group "$VNET_RESOURCE_GROUP" \
            --query name -o tsv 2>/dev/null)
if [[ -z "$ZGB_NAME" ]]; then
    echo "Creating DNS-zone group for blob endpoint …"
    az network private-endpoint dns-zone-group create \
        --resource-group    "$VNET_RESOURCE_GROUP" \
        --endpoint-name     "$PE_STORAGEBLOB_NAME" \
        --name              "$PRIVATE_DNS_ZONE_GROUP" \
        --private-dns-zone  "$STORAGE_BLOB_PRIVATE_DNS_ZONE" \
        --zone-name         "$STORAGE_BLOB_PRIVATE_DNS_ZONE" \
        --only-show-errors
else
    echo "DNS-zone group for blob endpoint already exists"
fi


# update the storage to follow private network
# check current PNA state ----------------------------------------------------
#az storage account update --resource-group $RESOURCE_GROUP --name $storage_account_name --default-action Deny
PNA_STATE=$(az storage account show \
              --resource-group "$RESOURCE_GROUP" \
              --name "$storage_account_name" \
              --query "publicNetworkAccess" -o tsv)
if [[ "$PNA_STATE" == "Disabled" ]]; then
    echo "Storage $storage_account_name already has public_network_access: Disabled - skip update"
else
    echo "Updating storage to disable public network access …"
    az storage account update \
            --resource-group        "$RESOURCE_GROUP" \
            --name                  "$storage_account_name" \
            --public-network-access Disabled \
            --only-show-errors
fi

echo "storage PEs created"
