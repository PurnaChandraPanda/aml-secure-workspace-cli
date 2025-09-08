## About

- `ai-services-deployment-template.bicep` - the file where actual bicep template related code for oss model deploy
- `deploy-aiservice-model.sh` - the script file that helps in deployment of bicep template

## How to run it?

- Fill in service and models details in `deploy-aiservice-model.sh` and then run it.

```
cd ai-service-model-deploy
./deploy-aiservice-model.sh
```


## Reference
https://learn.microsoft.com/en-us/azure/ai-foundry/foundry-models/how-to/create-model-deployments?pivots=programming-language-bicep#add-the-model

https://github.com/Azure-Samples/azureai-model-inference-bicep/blob/main/infra/modules/ai-services-deployment-template.bicep

https://learn.microsoft.com/en-us/azure/templates/microsoft.cognitiveservices/accounts/deployments?pivots=deployment-language-bicep

