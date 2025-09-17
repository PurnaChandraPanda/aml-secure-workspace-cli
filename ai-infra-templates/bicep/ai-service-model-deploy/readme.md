## About

- `ai-services-deployment-template.bicep` - the file where actual bicep template related code for oss model deploy
- `get-models.sh` - the script file that helps in finding right model details for deployment
- `deploy-aiservice-model.sh` - the script file that helps in deployment of bicep template

## How to run it?

- Fill in service and models details in `deploy-aiservice-model.sh` and then run it.

```
cd ai-service-model-deploy
./deploy-aiservice-model.sh
```


## Reference
[Deploy the model in Foundry](https://learn.microsoft.com/en-us/azure/ai-foundry/foundry-models/how-to/create-model-deployments?pivots=programming-language-bicep#add-the-model)

[azureai-model-inference-bicep template](https://github.com/Azure-Samples/azureai-model-inference-bicep/blob/main/infra/modules/ai-services-deployment-template.bicep)

[`Microsoft.CognitiveServices accounts/deployments` Bicep template](https://learn.microsoft.com/en-us/azure/templates/microsoft.cognitiveservices/accounts/deployments?pivots=deployment-language-bicep)

