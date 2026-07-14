## Prerequisites
- An active Azure subscription with access to the Microsoft Discovery preview.
- The Microsoft.Discovery resource provider registered on your subscription, along with Microsoft.App, Microsoft.ContainerService, Microsoft.Network, Microsoft.ManagedIdentity, and Microsoft.Storage.
- Sufficient role assignments: Discovery Platform Admin, Managed Identity Contributor, Network Contributor, and Storage Account Contributor at the target resource-group scope.
- Microsoft Discovery is available in East US, East US 2, Sweden Central, and UK South.

## Deployment step
For command line deployment, using the scripts in the root of this repo.

```
az login --tenant <tenant-id>
```

- update the parameters correctly and then run it (this step is one time to be carried out in subscription level)
```
# Required for Git Bash on Windows so /subscriptions/... is not path-converted.
export MSYS_NO_PATHCONV=1

./set_discovery_roles.sh
```

```
# create RG
az group create --name rg-swc2discovery --location swedencentral

# initiate resource deployment
az deployment group create \
  --resource-group rg-swc2discovery \
  --template-file main.bicep \
  --parameters main.bicepparam
```

- validate deployment
```
az resource list --resource-group rg-swc2discovery -o table
```

**Note** – The Supercomputer and Workspace resources can each take 30-120 minutes to provision.

- update parameters for post deploy script once discovery setup is ready
```
# Required for Git Bash on Windows so /subscriptions/... is not path-converted.
export MSYS_NO_PATHCONV=1

# Add the `Platform Administrator` or `Scientist` persona
./post_discovery_setup.sh
```

- Once setup scripts are done, follow quickstart for [agent create](https://learn.microsoft.com/en-us/azure/microsoft-discovery/quickstart-agents-studio) and session activities.

## Reference
- [Microsoft.Discovery bicep template](https://learn.microsoft.com/en-us/azure/templates/microsoft.discovery/workspaces?pivots=deployment-language-bicep)
- [Quickstart template reference](https://github.com/Azure/azure-quickstart-templates/tree/master/quickstarts/microsoft.discovery)
- [Discovery NSP pre-requisites](https://learn.microsoft.com/en-us/azure/microsoft-discovery/quickstart-infrastructure-bicep?tabs=CLI#prerequisites)
- [Assign Disvovery persona roles](https://github.com/microsoft/discovery/blob/main/utilities/rbac-roles-assignment/README.md#personas-and-roles)




