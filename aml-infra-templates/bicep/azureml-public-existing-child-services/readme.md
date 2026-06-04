
## How to use it?
- User session login

```
az login
```

- Create RG if not already

```
az group create --name <rg-name> --location <azure-region>
```
- Update the main.bicepparam file with required values
- Create bicep template deploy on the same RG

```
az deployment group create --resource-group "<rg-name>" --template-file main.bicep --parameters main.bicepparam
```

## reference
[microsoft.machinelearningservices/workspaces: bicep template](https://learn.microsoft.com/en-us/azure/templates/microsoft.machinelearningservices/workspaces?pivots=deployment-language-bicep)
