Update workspace in public to private via az cli.

## About
- This follows the principles that are discussed in [create secure workspace](https://learn.microsoft.com/en-us/azure/machine-learning/tutorial-create-secure-workspace) doc.
- It extends from [add private endpoint to workspace](https://learn.microsoft.com/en-us/azure/machine-learning/how-to-configure-private-link?tabs=cli#add-a-private-endpoint-to-a-workspace) doc and have steps to update for all its sub-resources.

## Pre-requisites
- Have a workspace deployed in public - with registry or no registry resource availability condition is taken care.
- It is better all private dns zones need to be created first. Then, user can refer to same while creating private endpoints for them.

## Components
- The file [workspace-in-vnet.sh](./workspace-in-vnet.sh) has logic to update private endpoints for aml workspace resource.
- The file [storage-in-vnet.sh](./storage-in-vnet.sh) has logic to update private endpoints for storage resource.
- The file [vault-in-vnet.sh](./vault-in-vnet.sh) has logic to update private endpoint for keyvault resource.
- The file [reistry-in-vnet.sh](./registry-in-vnet.sh) has logic to update private endpoint for container registry resource.

## How to run it?
- Before running the script, make sure to run: 1) az upgrade, 2) az login --identity.
- Fill all the required parameters such as workspace, resource_group, etc. details in [secure-workspce.sh](./secure-workspace.sh).
- The script file [secure-workspce.sh](./secure-workspace.sh) need to be run to have all the child shell scripts run.

```
$ ./secure-workspace.sh
```

## Create public workspace
- Before running the script [create-public-workspace.sh](./create-public-workspace.sh), make sure to run: 1) az upgrade, 2) az login --identity.
- Fill in required parameters in the script file.

```
$ ./create-public-workspace.sh
```