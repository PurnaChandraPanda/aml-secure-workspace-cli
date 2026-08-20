set -e

# Prevent Git Bash from rewriting Azure resource IDs as Windows paths.
export MSYS_NO_PATHCONV=1

## Set the Azure resource details
export TENANT_ID="16----------------------------------d3" # Set your Azure tenant ID, e.g. 1234sdf------------21ew2
export SUBSCRIPTION_ID="69----------------------------------03" # Set your Azure subscription ID, e.g. 432dsdf------------2132ew32
export REGION="eastus2" # Set your Azure region; e.g. australiaeast

export AKS_RG="rg-k8sworkload"              # Set your AKS resource group name, e.g. rg-k8sworkload
export AKS_CLUSTER_NAME="devk8s1015"        # Set your AKS cluster name, e.g. devk8s1011
export SYSTEM_NODEPOOL_NAME="system1"       # Set name for your system node pool
export SYSTEM_NODE_COUNT="3"                # Set the system node pool's nodes count
export SYSTEM_NODE_SKU="Standard_DS3_v2"    # Set the SKU for system node
export USER_NODEPOOL_NAME="userpool1"       # Set name for your user node pool
export USER_NODE_COUNT="2"                  # Set desired node count
export USER_NODE_SKU="Standard_E16s_v3"     # Set VM size for user nodes; If GPU needed, pick a GPU SKU like Standard_NC6s_v3, etc.

# --- Bring-your-own VNet for the AKS nodes (needed to reach PNA-disabled private storage) ---
export NETWORK_PLUGIN="azure"               # Azure CNI is recommended for private-endpoint scenarios
export SERVICE_CIDR="10.240.0.0/16"         # Must not overlap the VNet, peered VNets, or on-premises networks
export DNS_SERVICE_IP="10.240.0.10"         # Must be within SERVICE_CIDR and outside its first three addresses
# REQUIRED: resource id of an EXISTING subnet for the system (and default) node pool.
# Get it with: az network vnet subnet show -g <net-rg> --vnet-name <vnet> -n <subnet> --query id -o tsv
export VNET_SUBNET_ID="/subscriptions/69-----------------------------------03/resourceGroups/vnets-rg/providers/Microsoft.Network/virtualNetworks/eus2vnet4324/subnets/default"                    
export USER_VNET_SUBNET_ID=""               # OPTIONAL: separate subnet id for the user node pool; leave empty to reuse the cluster subnet.

# --- Optional: link the blob Private DNS zone to the AKS VNet so nodes resolve the storage private endpoint ---
export BLOB_PRIVATE_DNS_ZONE_RG=""          # OPTIONAL: RG holding the "privatelink.blob.core.windows.net" zone; leave empty to skip linking.

# Set the current user login - to authenticate with Azure CLI 
# interactively against the other tenant if current user may be mapped to multiple tenants
az login --tenant $TENANT_ID

# Set the subscription id
az account set --subscription $SUBSCRIPTION_ID 

# Create resource group if does not exist
{ # try
    RG_RESULT=$(az group show --resource-group $AKS_RG --query name -o tsv)
    if [ -z $RG_RESULT ]; then
        echo "create resource group ..."
        az group create -l $REGION -n $AKS_RG
    else
        echo "$AKS_RG - resource group exists"
    fi
} || { 
    # catch exception 
    echo "not found"
}

# Create k8s resource with public load balancer if not already
if ! az aks show \
      --resource-group "$AKS_RG" \
      --name "$AKS_CLUSTER_NAME" &>/dev/null; then

    # A BYO subnet is required for this private-nodes variant
    if [ -z "$VNET_SUBNET_ID" ]; then
        echo "ERROR: VNET_SUBNET_ID is empty. Set it to an existing subnet resource id before running this script."
        exit 1
    fi

    echo "Creating AKS cluster '$AKS_CLUSTER_NAME' in '$AKS_RG'..."

    az aks create \
        --resource-group "$AKS_RG" \
        --name "$AKS_CLUSTER_NAME" \
        --location "$REGION" \
        --nodepool-name "$SYSTEM_NODEPOOL_NAME" \
        --node-count "$SYSTEM_NODE_COUNT" \
        --node-vm-size "$SYSTEM_NODE_SKU" \
        --network-plugin "$NETWORK_PLUGIN" \
        --service-cidr "$SERVICE_CIDR" \
        --dns-service-ip "$DNS_SERVICE_IP" \
        --vnet-subnet-id "$VNET_SUBNET_ID" \
        --load-balancer-sku standard \
        --generate-ssh-keys

    # Check if k8s cluster is provisioned correctly
    AKS_CLUSTER_STATUS=$(az aks show \
                            --resource-group "$AKS_RG" \
                            --name "$AKS_CLUSTER_NAME" \
                            --query provisioningState -o tsv)
    if [ "$AKS_CLUSTER_STATUS" == "Succeeded" ]; then
        # Discourage non-system pods from running on Azure Machine Learning dedicated nodes/ node pools
        # (soft taint via PreferNoSchedule below - see note on line effect)
        # Taint the system node pool for ML system components
        ## AKS design restriction: (SystemPoolHasRestrictedTaint) Placing custom taints on system pool is not supported (except 'CriticalAddonsOnly' taint or taint effect is 'PreferNoSchedule').
        ## Option 1: Keep system pool clean, add a dedicated AML system pool
        ## Option 2: Use PreferNoSchedule on system pool
        ### This is a soft taint: pods without tolerations can still land there if no other nodes are available. So isolation is weaker.
        az aks nodepool update \
            --resource-group "$AKS_RG" \
            --cluster-name "$AKS_CLUSTER_NAME" \
            --name "$SYSTEM_NODEPOOL_NAME" \
            --node-taints \
                ml.azure.com/amlarc=true:PreferNoSchedule,ml.azure.com/amlarc-system=true:PreferNoSchedule
        echo "AKS cluster created with status: $AKS_CLUSTER_STATUS; Updated with system taints"

        # Optionally link the blob Private DNS zone to the AKS VNet so nodes resolve
        # the storage private endpoint (required for PNA-disabled storage access).
        if [ -n "$BLOB_PRIVATE_DNS_ZONE_RG" ]; then
            # Derive the VNet id by stripping "/subnets/<name>" off the subnet id
            AKS_VNET_ID="${VNET_SUBNET_ID%/subnets/*}"
            echo "Linking blob Private DNS zone to AKS VNet '$AKS_VNET_ID'..."
            az network private-dns link vnet create \
                --resource-group "$BLOB_PRIVATE_DNS_ZONE_RG" \
                --zone-name "privatelink.blob.core.windows.net" \
                --name "link-$AKS_CLUSTER_NAME-blob" \
                --virtual-network "$AKS_VNET_ID" \
                --registration-enabled false
        else
            echo "BLOB_PRIVATE_DNS_ZONE_RG is empty; skipping blob Private DNS zone link."
        fi
    else
        echo "AKS cluster '$AKS_CLUSTER_NAME' not created successfully"
    fi
    
else
    echo "AKS cluster '$AKS_CLUSTER_NAME' already exists"
fi

# Update the existing k8s resource with user node pool details, if it does not exist
if ! az aks nodepool show \
      --resource-group "$AKS_RG" \
      --cluster-name "$AKS_CLUSTER_NAME" \
      --name "$USER_NODEPOOL_NAME" &>/dev/null; then

    echo "Adding user node pool '$USER_NODEPOOL_NAME' with $USER_NODE_COUNT nodes of SKU $USER_NODE_SKU..."

    # Optionally place the user pool in a separate subnet; otherwise it inherits the cluster subnet.
    USER_SUBNET_ARG=()
    if [ -n "$USER_VNET_SUBNET_ID" ]; then
        USER_SUBNET_ARG=(--vnet-subnet-id "$USER_VNET_SUBNET_ID")
    fi

    # Prevent non-ml workloads from running on Azure Machine Learning dedicated nodes/node pools
    # Taint the user node pool for ML user workloads
    az aks nodepool add \
        --resource-group "$AKS_RG" \
        --cluster-name "$AKS_CLUSTER_NAME" \
        --name "$USER_NODEPOOL_NAME" \
        --node-count "$USER_NODE_COUNT" \
        --node-vm-size "$USER_NODE_SKU" \
        --mode User \
        "${USER_SUBNET_ARG[@]}" \
        --node-taints \
            ml.azure.com/amlarc=true:NoSchedule,ml.azure.com/amlarc-workload=true:NoSchedule
else
    echo "User node pool '$USER_NODEPOOL_NAME' already exists"
fi


echo "k8s resource is created!!!"