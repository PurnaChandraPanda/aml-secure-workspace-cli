# AzureML and Azure AI Infrastructure Templates

This folder is a high-level catalog of reference Bicep and Terraform templates for Azure Machine Learning and Azure AI Foundry infrastructure. Each child folder owns the detailed parameters, deployment commands, and post-deployment steps for that specific sample.

## Samples

| Scenario | Bicep | Terraform | Use when |
| --- | --- | --- | --- |
| AzureML public workspace with existing child services | [bicep/azureml-public-existing-child-services](./bicep/azureml-public-existing-child-services) | [terraform/azureml-public-existing-child-services](./terraform/azureml-public-existing-child-services) | You want an Azure Machine Learning workspace that stays public and reuses existing Storage, Key Vault, Application Insights, and Container Registry resources. |
| AzureML secure workspace with managed VNet | [bicep/azureml-secure-managedvnet](./bicep/azureml-secure-managedvnet) | [terraform/azureml-secure-managedvnet](./terraform/azureml-secure-managedvnet) | You need an AzureML workspace pattern with managed network isolation, private endpoints, private DNS, and monitoring support. |
| Azure AI Foundry hub/project secure infrastructure | [bicep/foundry-hubproject-secure-managedvnet](./bicep/foundry-hubproject-secure-managedvnet) | [terraform/foundry-hubproject-secure-managedvnet](./terraform/foundry-hubproject-secure-managedvnet) | You need secure Azure AI Foundry hub and project infrastructure with private networking and supporting platform resources. |

## Common starting points

- For a simple AzureML public workspace, start with `azureml-public-existing-child-services`.
- For secure AzureML infrastructure, start with `azureml-secure-managedvnet`.
- For Azure AI Foundry secure hub and project infrastructure, start with `foundry-hubproject-secure-managedvnet`.

## Template types

- [bicep](./bicep) contains Azure Bicep versions of the samples.
- [terraform](./terraform) contains Terraform versions of the samples.

## Before using a sample

- Open the child sample README first.
- Review the parameter or tfvars file in the sample folder.
- Confirm the target subscription, tenant, region, and naming values.
- For secure samples, review the virtual network, private endpoint, and private DNS choices before deployment.
