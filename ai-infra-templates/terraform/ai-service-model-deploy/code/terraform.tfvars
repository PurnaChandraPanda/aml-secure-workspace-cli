# terraform.tfvars (fill the details)
## subscription id of ai service resource
subscription_id           = ""
## resource group name where ai service is created
resource_group_name       = ""
## location of ai service resource
location                  = ""
## name of ai service resource
account_name              = ""

## run `./get-model.sh` to know exact details of OSS models
### create model deployment name as, e.g. "gpt-oss-120b"
deployment_name           = ""
### name of model to be deployed, e.g. "gpt-oss-120b"
model_name                = ""
### version the model to be deployed, e.g. "1"
model_version             = ""
### set model publisher format details, e.g. "OpenAI-OSS"
model_publisher_format    = ""

# Optional—override defaults if needed
sku_name                 = "GlobalStandard"
## supply TPM number for deployment, e.g. 500k
capacity                 = 500
content_filter_policy_name = "Microsoft.DefaultV2"