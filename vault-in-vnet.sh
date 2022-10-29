set -e

key_vault_resource=$(az ml workspace show --resource-group $RESOURCE_GROUP --name $WORKSPACE_NAME --query "key_vault" -o tsv)
key_vault_name=${key_vault_resource##*/}
echo $key_vault_name

pe_suffix=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 5 | head -n 1)
PE_VAULT_NAME=$key_vault_name-vault-pe-$pe_suffix
PE_VAULT_PRIVATE_CONNECTION_RESOURCE=/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Keyvault/vaults/$key_vault_name

{ # try
    VAULT_PRIVATE_DNS_ZONE_RESULT=$(az network private-dns zone show -g $VNET_RESOURCE_GROUP -n $VAULT_PRIVATE_DNS_ZONE --query "name" -o tsv)
    if [ -z $VAULT_PRIVATE_DNS_ZONE_RESULT ]; then
        echo $VAULT_PRIVATE_DNS_ZONE "- private dns zone does not exist"
        az network private-dns zone create -g $VNET_RESOURCE_GROUP --name $VAULT_PRIVATE_DNS_ZONE
    else
        echo $VAULT_PRIVATE_DNS_ZONE "- private dns zone exists"
    fi
} || { 
    # catch exception 
    echo "not found"
}

{ # try
    VAULT_VNET_LINK_LIST=$(az network private-dns link vnet list -g $VNET_RESOURCE_GROUP -z $VAULT_PRIVATE_DNS_ZONE)
    if [ ${#FILE_VNET_LINK_LIST[@]} > 0 ]; then
        echo ">0 .. vault private dns vnet link exists"
    else
        echo "<=0 .. create private-dns link vnet"
        link_name=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 13 | head -n 1)
        az network private-dns link vnet create -g $VNET_RESOURCE_GROUP --zone-name $VAULT_PRIVATE_DNS_ZONE --name $link_name --virtual-network $VNET_NAME --registration-enabled false    
    fi
} || { 
    # catch exception 
    echo "not found"
}

# create private endpoint for vault
az network private-endpoint create --name $PE_VAULT_NAME --vnet-name $VNET_NAME --subnet $SUBNET_NAME --resource-group $VNET_RESOURCE_GROUP --private-connection-resource-id $PE_VAULT_PRIVATE_CONNECTION_RESOURCE --group-id vault --connection-name vault -l $REGION

az network private-endpoint dns-zone-group create -g $VNET_RESOURCE_GROUP --endpoint-name $PE_VAULT_NAME --name $PRIVATE_DNS_ZONE_GROUP --private-dns-zone $VAULT_PRIVATE_DNS_ZONE --zone-name $VAULT_PRIVATE_DNS_ZONE

sleep 1m

# update keyvault to disable public access
az keyvault update --resource-group $RESOURCE_GROUP --name $key_vault_name --public-network-access Disabled

echo "keyvault PE created"