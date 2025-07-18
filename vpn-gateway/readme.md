## Pre-requisites
- az cli installed with latest version (run: `az upgrade -y`)
- Subscription is ready with VNET

## Create vnet gateway, P2S configuration with Entra auth
```
cd vpn-gateway
./vpn-gateway-service.sh
```

## P2S configuration for Vnet gateway with Entra ID authentication
https://learn.microsoft.com/en-us/azure/vpn-gateway/point-to-site-entra-gateway

### For UI
- On windows, download the vpn client from the Azure portal. 
- On Azure vpn client, import the downloaded profile from ./AzureVPN folder.
- Connect on demand.
- Modify host file to add DNS name resolution for the private endpoint.

### For CLI (Windows machine)
- Clone repo
- cd .\vpn-gateway\setup-vpn-client\
- Modify file `1.install-azurevpn-client.ps1` and fill in all required azure resource details
- Modify file `2.get-pe-privateip-fqdns.ps1` and fill resource group detail of azure resources

- In PowerShell, run in following order
```
.\-1.unblock-files.bat  
.\0.pre-requisites.ps1  
.\1.install-azurevpn-client.ps1
.\2.get-pe-privateip-fqdns.ps1
```

### For CLI (Ubuntu machine)
There is some challenge with azure vpn client, as its only compatible with GUI based Ubuntu machine and not headless Ubuntu.

#### Install azure vpn ubuntu client
```
curl -sSl https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc
curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | sudo tee /etc/apt/sources.list.d/microsoft-ubuntu-jammy-prod.list
sudo apt-get update
sudo apt-get install microsoft-azurevpnclient
```

#### P2S profile import in Ubuntu
``` 
sudo /opt/microsoft/microsoft-azurevpnclient/microsoft-azurevpnclient import ./p2s-profile/AzureVPN/azurevpnconfig.xml
```

**Challenge:**
The root of the problem is that the Linux "Azure VPN Client" package is really just a GTK-based GUI app with an import/connect sub-command API - it has no true headless CLI and will always try to talk to X11. 

```
sudo /opt/microsoft/microsoft-azurevpnclient list
sudo /opt/microsoft/microsoft-azurevpnclient connect --profile agent-vnet-test
```

## Open to thoughts
- Create vnet gateway, P2S configuration with ssl auth (openssl)
- For openvpn, install certificate in client and connect vnet gateway.
