## Foundry Agent Service: Standard Agent Setup with byo AOAI
- This template assumes that user already ran the tf template of [15b-private-network-standard-agent-setup-byovnet](https://github.com/microsoft-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-terraform/15b-private-network-standard-agent-setup-byovnet), so that Standard Foundry exists in own vnet.
- On the existing Standard Foundry setup in vnet, it will have connection added for existing aoai.
- As the Foundry exists here, it means capability host exists here too.
- By design, capability host is immutable.

**Note:**
- So, once this template adds the connection for existing aoai, next step is to delete the project capability host, create capability host with ai service connection details again.
- With tf or bicep, the caphost can't be updated. So, need to take help of scripts to get caphost updated.

### Variables

The variables listed below [must be provided](https://developer.hashicorp.com/terraform/language/values/variables#variable-definition-precedence) when performing deploying the templates. The file example.tfvars provides a sample Terraform variables file that can be used.
- **subscription_id** - The subscription ID (ex: 55555555-5555-5555-5555-555555555555) where the Foundry resource is created.
- **resource_group_name** - The name of the resource group where Foundry resource is created in.
- **foundry_account_name** - The name of the existing Foundry account resource.
- **foundry_project_name** - The name of the existing Foundry account based project resource.
- **existingAoaiResourceId** - The ARM resource id existing aoai.
- **aoaiConnectionName** - The connection name to be created for existig aoai.

## Key changes for existing aoai service

- Add project level connection for existing aoai.

```
# Project connection -> Existing Azure OpenAI
resource "azapi_resource" "ai_project_connection_existing_aoai" {
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
  name      = var.aoaiConnectionName
  parent_id = data.azapi_resource.foundry_project.id

  body = {
    properties = {
      category = "AzureOpenAI"
      target = local.aoaiEndpoint
      authType = "AAD"
      useWorkspaceManagedIdentity = true
      metadata = {
        ApiType = "Azure"
        resourceId = var.existingAoaiResourceId
        accountName = local.aoaiResourceName
      }
    }
  }

  depends_on = [
    data.azapi_resource.foundry_project
  ]
}
```

---

## Deploy the Terraform template

1. Fill in the required information for the variables listed in the example.tfvars file and rename the file to terraform.tfvars.

2. If performing the deployment interactively, log in to Az CLI with a user that has sufficient permissions to deploy the resources.

```bash
az login
```

3. Ensure the proper environmental variables are set for [AzApi](https://registry.terraform.io/providers/Azure/azapi/latest/docs) and [AzureRm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) providers. At a minimum, you must set the ARM_SUBSCRIPTION_ID environment variable to the subscription the Foundry resoruces will be deployed to. You can do this with the commands below:

Linux/MacOS
```bash
export ARM_SUBSCRIPTION_ID="YOUR_SUBSCRIPTION_ID"
```

Windows
```cmd
set ARM_SUBSCRIPTION_ID="YOUR_SUBSCRIPTION_ID"
```

PowerShell Command Prompt
```
$env:ARM_SUBSCRIPTION_ID="YOUR_SUBSCRIPTION_ID"
```

4. Initialize Terraform

```bash
terraform init
```

5. Deploy the resources
```bash
terraform apply
```

--

## CapHost update
Update the project caphost layer with expected aoai connection. The details are discussed in [scripts-caphost](../../bicep/43-aoaiexisting-foundry-standard-agent-setup/scripts-caphost/readme.md).

