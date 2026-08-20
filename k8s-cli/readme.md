# Goal
- In azure k8s, create system and worker node pools.
- Install azureml k8s extension on this k8s service.
- Native k8s/ ML side system pods should only be created in system node pool.
- The ml workload related to ML endpoint or ML job pods would only create in user node pool.
- Once ml extension is installed, it will talk to one or private endpoint based blob storage (that is already mapped to azureml workspace), when ml endpoint or jobs run in k8s nodes.
- It means I need to work with taint/ tolerate points described in [Reference for configuring Kubernetes cluster for Azure Machine Learning - Azure Machine Learning | Microsoft Learn](https://learn.microsoft.com/en-us/azure/machine-learning/reference-kubernetes?view=azureml-api-2#azure-machine-learning-jobs-connect-with-custom-data-storage)


# Install kubectl

- install kubectl in ubuntu

```
sudo apt-get update
sudo snap install kubectl --classic
kubectl version --client
```

- install kubectl in windows git bash

```
az aks install-cli
```

# Install extensions
```
az extension add --upgrade -n k8s-extension

az extension remove -n ml
az extension add -n ml
```

# Notes about Taint and Toleration
Kubernetes clusters integrated with Azure Machine Learning (including AKS and Arc Kubernetes clusters) now support specific Azure Machine Learning [taints and tolerations](https://learn.microsoft.com/en-us/azure/machine-learning/reference-kubernetes?view=azureml-api-2#supported-azure-machine-learning-taints-and-tolerations), allowing users to add specific Azure Machine Learning taints on the Azure Machine Learning-dedicated nodes, to prevent non-Azure Machine Learning workloads from being scheduled onto these dedicated nodes.


# Run the commands

- From git bash session, add following to read `/subscription/...` properly

```bash
export MSYS_NO_PATHCONV=1
```

- Create k8s cluster

```bash
cd ./k8s-cli

# for public k8s
./k8s-public.sh

# for private k8s
./k8s-byon.sh
```

- Attach k8s cluster as the ml compute

```bash
./ml-k8s-compute.sh
```

- Connect the k8s

```bash
kubectl version --client

az aks get-credentials --resource-group rg-k8sworkload --name devk8s1015

kubectl get nodes
```

You will notice the azureml related system PODs will always be created in system node pool. There would be no leak into user node pools.

# Delete POD and watch if rolls over to user pool nodes

Pods do not transition between nodes. Deleting one causes the Deployment to create a new pod, which the scheduler assigns to a node. In this case, as the taint exists for user pool nodes, the node scheduling will never go for this user pool node.

$ kubectl get pods -n azureml -o wide | grep fe-v2

```
azureml-fe-v2-68bdb9bb7b-fvdvj                           3/3     Running     0             46m   10.0.0.75   aks-system1-41291085-vmss000001   <none>           <none>
azureml-fe-v2-68bdb9bb7b-kzbqb                           3/3     Running     0             46m   10.0.0.52   aks-system1-41291085-vmss000002   <none>           <none>
azureml-fe-v2-68bdb9bb7b-s75t2                           3/3     Running     0             46m   10.0.0.31   aks-system1-41291085-vmss000000   <none>           <none>
```

$ kubectl delete pod azureml-fe-v2-68bdb9bb7b-fvdvj -n azureml

```
pod "azureml-fe-v2-68bdb9bb7b-fvdvj" deleted from azureml namespace
```

$ kubectl get pods -n azureml -o wide | grep fe-v2

```
azureml-fe-v2-68bdb9bb7b-dlfzm                           3/3     Running     0             2m8s10.0.0.70   aks-system1-41291085-vmss000001   <none>           <none>
azureml-fe-v2-68bdb9bb7b-kzbqb                           3/3     Running     0             49m10.0.0.52   aks-system1-41291085-vmss000002   <none>           <none>
azureml-fe-v2-68bdb9bb7b-s75t2                           3/3     Running     0             49m10.0.0.31   aks-system1-41291085-vmss000000   <none>           <none>
```

To test k8s job workloads, follow [/k8s/job](../workload/azureml/k8s/job).