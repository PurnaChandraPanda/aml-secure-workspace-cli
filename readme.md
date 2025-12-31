Work with ml workspace/ foundry resource over public/ private network via az cli.

## About
- This follows the principles that are discussed in [create secure workspace](https://learn.microsoft.com/en-us/azure/machine-learning/tutorial-create-secure-workspace) doc.
- It extends from [add private endpoint to workspace](https://learn.microsoft.com/en-us/azure/machine-learning/how-to-configure-private-link?tabs=cli#add-a-private-endpoint-to-a-workspace) doc and have steps to update for all its sub-resources.

## What all help?
- Create public ml workspace [./create-public-workspace.sh](./create-public-workspace.sh)
- Create/ update private ml workspace [./secure-workspace.sh](./secure-workspace.sh)
- Create UAI based private ml workspace [./create-private-uai-workspace.sh](./create-private-uai-workspace.sh)
- Create vnet jumpbox [./connect-workspace-jumpbox.sh](./connect-workspace-jumpbox.sh)
- Create vnet gateway and vpn client [./vpn-gateway/](./vpn-gateway/)
- Run ml test workload of image build [./workload/](./workload/)

## Pre-requisites
- Have a workspace deployed in public - with registry or no registry resource availability condition is taken care.
- It is better all private dns zones need to be created first. Then, user can refer to same while creating private endpoints for them.
- This script is well-versed to create new private dns zones too.

- In ubuntu, make sure `jq` is installed.
```Install jq
sudo apt-get update
sudo apt-get install jq -y
jq --version
```
## Create UAI based ml workspace in vnet

```
az upgrade -y
az config set extension.dynamic_install_allow_preview=true
az extension remove -n azure-cli-ml
az extension remove -n ml
az extension add -n ml --upgrade
az extension add -n application-insights
./create-private-uai-workspace.sh
```

**For jumpbox setup:**

```
az extension add -n bastion --upgrade
./connect-workspace-jumpbox.sh
```

**For vnet-gateway setup:**

Follow [./vpn-gateway](./vpn-gateway) steps in readme.md.


## Create public workspace
- Before running the script [create-public-workspace.sh](./create-public-workspace.sh), make sure to run: `1) az upgrade, 2) az login --identity`.
- Fill in required parameters in the script file.

```
$ ./create-public-workspace.sh
```

Capture both stdout and stderr into a log file. With help of `tee`, print stdout and stderr in terminal as well.
```
$ ./create-public-workspace.sh 2>&1 | tee -a sh.log
```

## Create public ml workspace with UAI

```
az upgrade -y
az config set extension.dynamic_install_allow_preview=true
az extension remove -n azure-cli-ml
sudo az extension remove -n ml
sudo az extension add -n ml --upgrade
sudo az extension add -n application-insights
./create-public-uai-workspace.sh
```

## Components
- The file [workspace-in-vnet.sh](./workspace-in-vnet.sh) has logic to update private endpoints for aml workspace resource.
- The file [storage-in-vnet.sh](./storage-in-vnet.sh) has logic to update private endpoints for storage resource.
- The file [vault-in-vnet.sh](./vault-in-vnet.sh) has logic to update private endpoint for keyvault resource.
- The file [reistry-in-vnet.sh](./registry-in-vnet.sh) has logic to update private endpoint for container registry resource.

## How to run it?
- Before running the script, make sure to run `az login`.
```
az upgrade
az login --identity
```
- Fill all the required parameters such as workspace, resource_group, etc. details in [secure-workspce.sh](./secure-workspace.sh).
- The script file [secure-workspce.sh](./secure-workspace.sh) need to be run to have all the child shell scripts run.

```
$ ./secure-workspace.sh
```
## Create jumpbox
- For jumpbox setup, make sure bastion extension is installed in az cli.
```
az extension add -n bastion
az extension update -n bastion
```
- Create jumpbox VM in vnet, which involves bastion resource be created for private access.
- Fill in variable details in export section, then run the file [connect-workspace-jumpbox.sh](./connect-workspace-jumpbox.sh)
```
$ ./connect-workspace-jumpbox.sh
```
- Via `bastion connect`, connect the VM for RDP session.
- In RDP session,
```
-> Settings
-> Accounts
-> Access work or school
-> Add a work or school account [pick corporate id]
-> note: {leave it for one or two days - will sync up with entra}
```
- Once VM is enabled with entra, access az portal and ml studio to try other secure ops.

## k8s in vnet
- Create k8s in vnet
- Flag `enable-private-cluster` helps create a new vnet/ subnet, also k8s private dns zone and PE for api server.
```
az group create --name {rg} --location {region}
 
az aks create --name {aks-name} --resource-group {rg} --load-balancer-sku standard --enable-private-cluster --generate-ssh-keys
 
```
- Access the k8s resource in private jumpbox machine.

- For `public k8s`, following command can be followed with just LB.
```
az aks create --name {aks-name} --resource-group {rg} --load-balancer-sku standard --node-vm-size Standard_DS3_v2 --generate-ssh-keys
```

### kubectl session in Ubuntu
Bash
```
sudo apt-get update
sudo snap install kubectl --classic
kubectl version --client
```

```
az login --identity
az aks get-credentials --resource-group rg --name aks --overwrite-existing
kubectl get deployments -A
```
### kubectl session in Windows
Cmd
```
curl.exe -LO "https://dl.k8s.io/release/v1.32.0/bin/windows/amd64/kubectl.exe"
setx PATH "%PATH%;C:\Users\vmadmin"
```
- Close cmd and open new cmd session
```
az login
az account set --subscription {your-sub-id}
az aks get-credentials --resource-group rg --name aks --overwrite-existing
kubectl get deployments -A
```

### install k8s-extension
Update `cluster-name` and `resource-group` values, and then create k8s-extension for ml.

```
az k8s-extension create --name aml --extension-type Microsoft.AzureML.Kubernetes --config enableTraining=True enableInference=True inferenceRouterServiceType=LoadBalancer allowInsecureConnections=True InferenceRouterHA=False internalLoadBalancerProvider=azure --cluster-type managedClusters --cluster-name {} --resource-group {}  --scope cluster
```
- For `public k8s`, k8s-extension is to be installed without ILB.
```
az k8s-extension create --name aml --extension-type Microsoft.AzureML.Kubernetes --config enableTraining=True enableInference=True inferenceRouterServiceType=LoadBalancer allowInsecureConnections=True InferenceRouterHA=False --cluster-type managedClusters --cluster-name {} --resource-group {} --scope cluster
```

### Attach k8s compute
Update `resource-group`, `workspace-name` and `resource-id` (of k8s resource) values.

```
az ml compute attach --resource-group {} --workspace-name {} --type Kubernetes --name k8s-compute --resource-id "{/subscriptions/6---------2103/resourceGroups/{}/providers/Microsoft.ContainerService/managedClusters/{}}" --identity-type SystemAssigned --namespace azureml --no-wait
```