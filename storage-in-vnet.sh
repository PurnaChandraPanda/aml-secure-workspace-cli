set -e

storage_account_resource=$(az ml workspace show --resource-group $RESOURCE_GROUP --name $WORKSPACE_NAME --query "storage_account" -o tsv)
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

# create private endpoint for storage
az network private-endpoint create --name $PE_STORAGEFILE_NAME --vnet-name $VNET_NAME --subnet $SUBNET_NAME --resource-group $VNET_RESOURCE_GROUP --private-connection-resource-id $PE_STORAGE_PRIVATE_CONNECTION_RESOURCE --group-id file --connection-name file -l $REGION

az network private-endpoint create --name $PE_STORAGEBLOB_NAME --vnet-name $VNET_NAME --subnet $SUBNET_NAME --resource-group $VNET_RESOURCE_GROUP --private-connection-resource-id $PE_STORAGE_PRIVATE_CONNECTION_RESOURCE --group-id blob --connection-name blob -l $REGION

sleep 1m

az network private-endpoint dns-zone-group create -g $VNET_RESOURCE_GROUP --endpoint-name $PE_STORAGEFILE_NAME --name $PRIVATE_DNS_ZONE_GROUP --private-dns-zone $STORAGE_FILE_PRIVATE_DNS_ZONE --zone-name $STORAGE_FILE_PRIVATE_DNS_ZONE

az network private-endpoint dns-zone-group create -g $VNET_RESOURCE_GROUP --endpoint-name $PE_STORAGEBLOB_NAME --name $PRIVATE_DNS_ZONE_GROUP --private-dns-zone $STORAGE_BLOB_PRIVATE_DNS_ZONE --zone-name $STORAGE_BLOB_PRIVATE_DNS_ZONE

sleep 1m

#az storage account update --resource-group $RESOURCE_GROUP --name $storage_account_name --default-action Deny
az storage account update --resource-group $RESOURCE_GROUP --name $storage_account_name --public-network-access Disabled

echo "storage PE created"
