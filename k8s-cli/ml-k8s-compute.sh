set -e

## Set the Azure resource details
export TENANT_ID="16---------------------------------d3"         # Set your Azure tenant ID, e.g. 1234sdf------------21ew2
export SUBSCRIPTION_ID="69-----------------------------------03"   # Set your Azure subscription ID, e.g. 432dsdf------------2132ew32
export REGION="eastus2"                                         # Set your Azure region; e.g. australiaeast

export AKS_RG="rg-k8sworkload"                  # Set your AKS resource group name, e.g. rg-k8sworkload
export AKS_CLUSTER_NAME="devk8s1015"            # Set your AKS cluster name, e.g. devk8s10
export AKS_EXTENSION_NAME="aml"                 # Set the name for the AKS extension, e.g. aml
export AKS_CLUSTER_TYPE="managedClusters"       # Set the type of AKS cluster, e.g. managedClusters

export ML_RG="rg-mlws"              # Set your AML workspace resource group name, e.g. rg-amlworkspaces
export ML_WORKSPACE="mlws01"        # Set your AML workspace name, e.g. dev-mlws
export ML_K8S_COMPUTE="k8s-compute" # Set the name for the AML k8s compute target, e.g. k8s-compute
export NAMESPACE="azureml"          # Set the namespace to use for AML workloads, e.g. azureml
export K8S_INSTANCE_TYPE="usernode_instance_type.yml" # Set the k8s instance type yaml file name, e.g. usernode_instance_type.yml
export AGENTPOOL_NAME="userpool1"  # Set the nodePool name you want to target the ml workload, e.g. userpool1

# Set the current user login - to authenticate with Azure CLI 
# interactively against the other tenant if current user may be mapped to multiple tenants
az login --tenant $TENANT_ID

# Set the subscription id
az account set --subscription $SUBSCRIPTION_ID 

# Read credentials for kubectl context
az aks get-credentials --resource-group "$AKS_RG" --name "$AKS_CLUSTER_NAME" --overwrite-existing

# 1) Install k8s-extension if not already present on the cluster
if ! az k8s-extension show \
      --cluster-name "$AKS_CLUSTER_NAME" \
      --resource-group "$AKS_RG" \
      --cluster-type "$AKS_CLUSTER_TYPE" \
      --name "$AKS_EXTENSION_NAME" &>/dev/null; then
      
    echo "Installing k8s extension '$AKS_EXTENSION_NAME' in cluster '$AKS_CLUSTER_NAME'..."
  
    az k8s-extension create \
        --name "$AKS_EXTENSION_NAME" \
        --extension-type "Microsoft.AzureML.Kubernetes" \
        --config enableTraining=True enableInference=True inferenceRouterServiceType=LoadBalancer allowInsecureConnections=True \
        --cluster-type "$AKS_CLUSTER_TYPE" \
        --cluster-name "$AKS_CLUSTER_NAME" \
        --resource-group "$AKS_RG" \
        --scope "cluster"    

else
    echo "k8s extension '$AKS_EXTENSION_NAME' already exists in cluster '$AKS_CLUSTER_NAME'"
fi

# 2) Attach the AKS cluster as a compute target to an existing AML workspace
if ! az ml compute show \
        --name "$ML_K8S_COMPUTE" \
        --workspace-name "$ML_WORKSPACE" \
        --resource-group "$ML_RG" &>/dev/null; then
    
    echo "Attaching AKS cluster '$AKS_CLUSTER_NAME' as compute target '$ML_K8S_COMPUTE' to AML workspace '$ML_WORKSPACE'..."

    # Read the AKS resource id
    AKS_RESOURCE_ID=$(az aks show \
                          --resource-group "$AKS_RG" \
                          --name "$AKS_CLUSTER_NAME" \
                          --query id -o tsv)

    az ml compute attach \
        --resource-group "$ML_RG" \
        --workspace-name "$ML_WORKSPACE" \
        --type Kubernetes \
        --name "$ML_K8S_COMPUTE" \
        --resource-id "$AKS_RESOURCE_ID" \
        --identity-type SystemAssigned \
        --namespace "$NAMESPACE" \
        --no-wait

    echo "Compute target '$ML_K8S_COMPUTE' is being created in AML workspace '$ML_WORKSPACE'. "

else
    echo "Compute target '$ML_K8S_COMPUTE' already exists in AML workspace '$ML_WORKSPACE'"
fi

# 3) Verify the compute target status until it shows as Healthy
echo "Checking the status of compute target '$ML_K8S_COMPUTE' in AML"
while true; do
    K8S_COMPUTE_PROVISIONING_STATE=$(az ml compute show \
                                        --name "$ML_K8S_COMPUTE" \
                                        --workspace-name "$ML_WORKSPACE" \
                                        --resource-group "$ML_RG" \
                                        --query provisioning_state -o tsv)

    echo "Current provisioning state: $K8S_COMPUTE_PROVISIONING_STATE"

    if [ "$K8S_COMPUTE_PROVISIONING_STATE" == "Succeeded" ]; then
        echo "ML compute is provisioned successfully."
        break
    elif [ "$K8S_COMPUTE_PROVISIONING_STATE" == "Failed" ]; then
        echo "Provisioning failed. Exiting."
        exit 1
    else
        echo "Still provisioning... waiting 30 seconds before retrying."
        sleep 30
    fi
done

# Create or reconcile the custom InstanceType on every run.
# Extract the InstanceType name from YAML (metadata.name)
INSTANCE_TYPE_NAME=$(grep '^  name:' "$K8S_INSTANCE_TYPE" | head -1 | awk '{print $2}')

echo "Applying InstanceType '$INSTANCE_TYPE_NAME' in namespace '$NAMESPACE'..."

# `kubectl apply` is idempotent: it creates the InstanceType or updates it in place.
kubectl apply -f "$K8S_INSTANCE_TYPE" -n "$NAMESPACE"

# Always reconcile spec.nodeSelector.agentpool with the env-var value via a native
# kubectl merge patch. Keeps $AGENTPOOL_NAME as the single source of truth without
# any text-templating tool, and re-asserts the value on every run.
kubectl patch instancetype "$INSTANCE_TYPE_NAME" -n "$NAMESPACE" --type merge \
    -p "{\"spec\":{\"nodeSelector\":{\"agentpool\":\"$AGENTPOOL_NAME\"}}}"

# Echo the resulting object for verification
kubectl get instancetype "$INSTANCE_TYPE_NAME" -n "$NAMESPACE" -o yaml






