## How to deploy it
- Access the folder `ai-service-model-deploy`
- Run `./get-models.sh` and find out model related values to fill in `terraform.tfvars`
```
cd ./ai-service-model-deploy/code
./get-models.sh
```
- Fill in the required details of AI Service and OSS model in `terraform.tfvars`
- `main.tf` - is the file with actual deployment definition to get a model deployed in AI Service

- Run from terminal as:

```
cd ./ai-service-model-deploy/code {if not already}
./deploy-aiservice-model.sh
```

## Reference
[`Microsoft.CognitiveServices accounts/deployments` Terraform API](https://learn.microsoft.com/en-us/azure/templates/microsoft.cognitiveservices/accounts/deployments?pivots=deployment-language-terraform)