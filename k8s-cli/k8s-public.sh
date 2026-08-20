set -e

## Set the Azure resource details
export TENANT_ID="16----------------------------------d3" # Set your Azure tenant ID, e.g. 1234sdf------------21ew2
export SUBSCRIPTION_ID="69------------------------------------03" # Set your Azure subscription ID, e.g. 432dsdf------------2132ew32
export REGION="eastus2" # Set your Azure region; e.g. australiaeast

export AKS_RG="rg-k8sworkload"              # Set your AKS resource group name, e.g. rg-k8sworkload
export AKS_CLUSTER_NAME="devk8s1015"        # Set your AKS cluster name, e.g. devk8s1011
export SYSTEM_NODEPOOL_NAME="system1"       # Set name for your system node pool
export SYSTEM_NODE_COUNT="3"                # Set the system node pool's nodes count
export SYSTEM_NODE_SKU="Standard_DS3_v2"    # Set the SKU for system node
export USER_NODEPOOL_NAME="userpool1"       # Set name for your user node pool
export USER_NODE_COUNT="2"                  # Set desired node count
export USER_NODE_SKU="Standard_E16s_v3"     # Set VM size for user nodes; If GPU needed, pick a GPU SKU like Standard_NC6s_v3, etc.

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
      
    echo "Creating AKS cluster '$AKS_CLUSTER_NAME' in '$AKS_RG'..."

    az aks create \
        --resource-group "$AKS_RG" \
        --name "$AKS_CLUSTER_NAME" \
        --location "$REGION" \
        --nodepool-name "$SYSTEM_NODEPOOL_NAME" \
        --node-count "$SYSTEM_NODE_COUNT" \
        --node-vm-size "$SYSTEM_NODE_SKU" \
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
    # Prevent non-ml workloads from running on Azure Machine Learning dedicated nodes/node pools
    # Taint the user node pool for ML user workloads
    az aks nodepool add \
        --resource-group "$AKS_RG" \
        --cluster-name "$AKS_CLUSTER_NAME" \
        --name "$USER_NODEPOOL_NAME" \
        --node-count "$USER_NODE_COUNT" \
        --node-vm-size "$USER_NODE_SKU" \
        --mode User \
        --node-taints \
            ml.azure.com/amlarc=true:NoSchedule,ml.azure.com/amlarc-workload=true:NoSchedule
else
    echo "User node pool '$USER_NODEPOOL_NAME' already exists"
fi


echo "k8s resource is created!!!"