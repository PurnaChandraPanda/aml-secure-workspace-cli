## How to deploy it
- Access the folder `ai-service-model-deploy`
- Fill in the required details of AI Service and OSS model in `terraform.tfvars`
- `main.tf` - is the file with actual deployment definition to get a model deployed in AI Service

- Run from terminal as:

```
cd ./ai-service-model-deploy/code
./deploy-aiservice-model.sh
```

## Reference
https://learn.microsoft.com/en-us/azure/templates/microsoft.cognitiveservices/accounts/deployments?pivots=deployment-language-terraform