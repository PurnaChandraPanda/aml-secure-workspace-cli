set -e

# subscription id of workspace
export SUBSCRIPTION_ID="" #9998------9b41
# resource group of vnet
export VNET_RESOURCE_GROUP="" #vnet-rg
# vnet name where workspace is
export VNET_NAME="" #testvnet
# location where vnet is
export REGION="" #centralindia
# bastion public ip name
export BASTION_PUBLIC_IP_NAME="" #bastion-public-ip001
# bastion rsource name
export BASTION_HOST_NAME="" #bastion001
# bastion subnet address prefixes
export BASTION_SUBNET_ADDRESS_PREFIX="" #10.225.0.0/26
# jumpbox vm name
export JUMPBOX_VM="jumpbox001" # vm name
export VM_ADMIN_USER="" # vm admin user - e.g. vmadmin
export VM_ADMIN_PWD="" # vm admin password
# subnet where vm resides
export VM_SUBNET="" #aks-subnet

# set the subsctiption id
az account set -s $SUBSCRIPTION_ID

# Check if Azure Bastion subnet exists, else create it
{ # try
    BASTION_SUBNET_RESULT=$(az network vnet subnet show --resource-group $VNET_RESOURCE_GROUP --vnet-name $VNET_NAME --name AzureBastionSubnet --query "name" -o tsv)
    if [ -z $BASTION_SUBNET_RESULT ]; then
        echo $BASTION_SUBNET_RESULT "- azure bastion subnet does not exist"
        # Create azure bastion subnet
        az network vnet subnet create \
        --resource-group $VNET_RESOURCE_GROUP \
        --vnet-name $VNET_NAME \
        --name AzureBastionSubnet \
        --address-prefixes $BASTION_SUBNET_ADDRESS_PREFIX
    else
        echo $BASTION_SUBNET_RESULT "- azure bastion subnet exists"
    fi
} || { 
    # catch exception 
    echo "not found"
}

# Check if public ip for Azure Bastion exists, else create it
{ # try
    BASTION_IP_RESULT=$(az network public-ip show --name $BASTION_PUBLIC_IP_NAME --resource-group $VNET_RESOURCE_GROUP --query "name" -o tsv)
    if [ -z $BASTION_IP_RESULT ]; then
        echo $BASTION_IP_RESULT "- azure bastion public-ip does not exist"
        # Create public ip address for bastion
        az network public-ip create \
          --resource-group $VNET_RESOURCE_GROUP \
          --name $BASTION_PUBLIC_IP_NAME \
          --sku Standard \
          --location $REGION
    else
        echo $BASTION_IP_RESULT "- azure bastion public-ip exists"
    fi
} || { 
    # catch exception 
    echo "not found"
}

# Check if host exists for Azure Bastion, else create it
{ # try
    BASTION_HOST_RESULT=$(az network bastion show --name $BASTION_HOST_NAME --resource-group $VNET_RESOURCE_GROUP --query "name" -o tsv)
    if [ -z $BASTION_HOST_RESULT ]; then
        echo $BASTION_HOST_RESULT "- azure bastion host does not exist"
        # Create bastion host
        az network bastion create \
          --resource-group $VNET_RESOURCE_GROUP \
          --name $BASTION_HOST_NAME \
          --vnet-name $VNET_NAME \
          --public-ip-address $BASTION_PUBLIC_IP_NAME \
          --location $REGION
    else
        echo $BASTION_HOST_RESULT "- azure bastion host exists"
    fi
} || { 
    # catch exception 
    echo "not found"
}

# Check if azure-vm exists, else create it
{ # try
    VM_RESULT=$(az vm show --name $JUMPBOX_VM --resource-group $VNET_RESOURCE_GROUP --query "name" -o tsv)
    if [ -z $VM_RESULT ]; then
        echo $VM_RESULT "- azure vm does not exist"
        # Create azure windows vm as jumpbox
        az vm create \
            --resource-group $VNET_RESOURCE_GROUP \
            --name $JUMPBOX_VM \
            --image MicrosoftWindowsDesktop:windows-11:win11-24h2-pro:latest \
            --admin-username $VM_ADMIN_USER \
            --admin-password $VM_ADMIN_PWD \
            --vnet-name $VNET_NAME \
            --subnet $VM_SUBNET \
            --public-ip-address "" \
            --security-type Standard
    else
        echo $VM_RESULT "- azure vm exists"
    fi
} || { 
    # catch exception 
    echo "not found"
}

echo "jumpbox setup successful in vnet"