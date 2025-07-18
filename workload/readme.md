## Pre-requisite
- Run it in jumpbox Windows PC, or let PC be connect via vnet gateway
- In .ps1 files, remember to set current Azure resource details

## Run workload (in Windows machine) in Powershell
```
cd .\workload\
.\-1.unblock-files.bat  
.\0.pre-requisites.ps1  
.\1.prep-for-ml.ps1  
.\2.build-env-ml.ps1 
```

