## Install terraform in Ubuntu
```
sudo snap install terraform --classic
terraform -version
```

## Install terraform in Windows
- Launch cmd as administrator
- Uninstall tf

```
winget uninstall HashiCorp.Terraform
```

- Install tf

```
winget install HashiCorp.Terraform
```

## About terraform templates

- [15b-aoaiexist-private-network-standard-agent-setup-byovnet](./15b-aoaiexist-private-network-standard-agent-setup-byovnet/README.md)
    - Deploy Foundry standard agent in BYO VNET with existing AOAI
- [15b-aoaiexist-private-standard-agent](./15b-aoaiexist-private-standard-agent/readme.md)
    - Update Foundry standard agent with existing AOAI
- [ai-service-model-deploy](./ai-service-model-deploy/readme.md)
    - Deploy model from model catalog in Foundry
