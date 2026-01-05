## Table of contents
- [Setup Azure Synapse](#setup-azure-synapse)
- [Setup Azure Synapse on AzureML side](#setup-azure-synapse-on-azureml-side)
  - [Interactive spark notebook experience](#interactive-spark-notebook-experience)
  - [Remote spark job submit experience](#remote-spark-job-submit-experience)
- [Spark code level logging](#spark-code-level-logging)
- [Pre-requisite for workload run](#pre-requisite-for-workload-run)
- [Run workload (in Windows machine) in Powershell](#run-workload-in-windows-machine-in-powershell)

## Setup Azure Synapse
- Azureml workspace is created with PEs for own vnet, having PNA disabled and UAI based identity-based access is setup for workspace mapped Storage account.
- Two options to create "Azure Synapse Analytics" service resources:
1) With "Managed Virtual Network" Disabled
2) With "Managed Virtunal Network" Enabled
- In either case, create PEs for all three endpoints in synapse level (from own vnet), such as sql and dev endpoints. It's primarily for incoming into the Azure Synapse instance by user.
1) Dedicated SQL endpoint: {yoursynapseresource}.sql.azuresynapse.net
2) Serverless SQL endpoint: {yoursynapseresource}-ondemand.sql.azuresynapse.net
3) Development endpoint: {yoursynapseresource}.dev.azuresynapse.net

- For either of synapse instance, load its studio:
    - Navigate like: Manage -> Apache Spark pools -> {Add new Apache Spark pool} (e.g. named `testap1` with SKU and scaling setup)
    - Navigate like: Acess Control: {add Access Control}
        - As synapse is setup with MSI, assign the MSI (search by synapse instance name) `Synapse Administrator` role (if not already).
        - Assign ML mapped UAI `Synapse Contributor` role or the minimum as `Synapse Compute Operator` role. It is primarily to allow ML side managed id to allow interacting with compute pools in Synapse end.

- As all Azure ML bound operations for Synapse are supposed to be carried by UAI, make sure the UAI has `contributor` role on the synapse instance (if not already present).

- For managed vnet based synapse instance, validate on `managed private endpoints`.
    - Design in ml job flow is like: once incoming traffic is received in worker pools (when submitted azureml job), it has to make outbound calls for `azureml service` and `azure blob storage` instances (blob storage is already attached to azureml service).
    - For outbound calls to succeed, create managed PEs by launching the synapse studio -> managed private endpoints -> {+New}. 
    - Manual step would be to navigate to those destination service -> networking -> private endpoints -> [approve] the private endpoint creation.

- For no managed vnet synapse workspace from azure portal -> navigate to `Networking`. 
- On Firewall rules, `Allow Azure services and resources to access this workspace` must be enabled. This will allow other caller service like azureml reach the synapse instance pools. Add `client ip` is optional here, as it just talks about client browser experience of synapse instance.

- For managed vnet synapse workspace from azure portal -> navigate to `Networking`. PNA will appear as `Disabled`. 
- For azureml side -> Notebooks (spark notebook), interactive notebook experience (for attached synapse workspace pools in ml) or spark ml job flow, azureml relies on backbone service layers to reach the destination synapse workspace.
- If PNA is disabled on Synapse end, then backbone layers won't have a way to interact with the synapse instance.
- For azureml side activities work on Synapse, PNA should be `Enabled` on the Synapse workspace end.
- On Firewall rules, `Allow Azure services and resources to access this workspace` must be enabled. This will allow other caller service like azureml and also backbone services reach the synapse instance pools. Add `client ip` is optional here, as it just talks about client browser experience of synapse instance.

## Setup Azure Synapse on AzureML side
- In azureml studio, navigate like: compute -> attached computes -> add [Synapse Spark pool]
- Supply a compute name, pick synapse workspace, then pool, then assign a managed identity with UAI (the one ML workspace is created with or like to control rest of ml operations with that id). 
- SAI can also be followed in attached compute step for synapse, but make sure those permissions are there on synapse related in the Synapse.

### Interactive spark notebook experience
- In azureml, you have a jupyter notebook with spark code. 
- This notebook can easily be followed interactive way - with attached synapse compute, where synapse workspace is created with no managed vnet. 
- On interactive access of notebook for attached synapse compute, where synapse workspace is created with managed vnet but PNA disabled, then interactive auth access will be broken on network layer. It is because with PNA disabled for synapse, there is no incoming route created for azure backbone layers (which are followed in azureml platform behind the scenes). Hence, to make the interactive notebook access work for attached synapse, make sure PNA is enabled, and allow azure services to access option is selected.
- Interactive access of notebook for serverless spark compute will also work fine, where azureml has PNA disabled with PE created for own vnet. Behind the scenes, ml platform creates synapse instance and attaches to the azureml workspace for quick fire-and-forget mode interaction.

### Remote spark job submit experience
Flow is like: 
- From azureml, user will submit the spark based ml job - with compute as synapse pool instance. 
- Then, ml job will kick of the spark pool computes. From the spark pool compute, the user code will access the data points (via inputs/ ouputs) that are supplied in job schema, process the user script with "user identity" supplied in job schema, mount data points in spark pool computes, post the telemetry run data to azureml attached blob storage account, put the output in expected storage, and then exit the job run.

```
$schema: https://azuremlschemas.azureedge.net/latest/sparkJob.schema.json
type: spark

code: ./src
entry:
  file: titanic.py

conf:
  spark.driver.cores: 1
  spark.driver.memory: 2g
  spark.executor.cores: 2
  spark.executor.memory: 2g
  spark.executor.instances: 2

inputs:
  titanic_data:
    type: uri_file
    path: azureml://datastores/workspaceblobstore/paths/data/titanic.csv    
    mode: direct

outputs:
  wrangled_data:
    type: uri_folder
    path: azureml://datastores/workspaceblobstore/paths/data/wrangled/
    mode: direct

args: >-
  --titanic_data ${{inputs.titanic_data}}
  --wrangled_data ${{outputs.wrangled_data}}

identity:
  type: managed
```

#### ML job on managed vnet synapse with PNA disabled
- User will submit azureml job from client machine, i.e. connected to private vnet linked PC (via private endpoint resolve for azureml workspace) - with target to run on attached synapse compute.
- AzureML control plane will try to discover the synapse ingress route now - via job schema based managed identity (or caller) supplied user.
- It means from AzureML control plane layer, i.e. its Azure backbone layers, the synapse attached compute host will be reached.
- There's PE on own vnet for the synapse workspace with PNA disabled. However, its not useful, as the intermediary caller layer is azure backbone here. Synapse own vnet PE is only useful when its workspace studio launched or synapse api called from the vnet connected PC.
- The destination synapse did not whitelist for the azure backbone. Hence, it will deny the inbound call in this job submit exercise.


#### ML job on managed vnet synapse with PNA enabled
- User will submit azureml job from client machine, i.e. connected to private vnet linked PC (via private endpoint resolve for azureml workspace) - with target to run on attached synapse compute.
- AzureML control plane will try to discover the synapse ingress route now - via job schema based managed identity (or caller) supplied user.
- It means from AzureML control plane layer, i.e. its Azure backbone layers, the synapse attached compute host will be reached.
- There's PE on own vnet for the synapse workspace with PNA enabled. However, PE would not be useful, as the intermediary caller layer is azure backbone here. Synapse own vnet PE is only useful when its workspace studio launched or synapse api called from the vnet connected PC.
- As `Allow Azure services and resources to access this workspace` option is enabled on synapse, the azure backbone layers will be allowed to communicate with destination Synapse control plane APIs.
- Though PNA is enabled for Synapse, it does not mean anyone can access it. By network wise, yes, they can reach on connectivity, but still the control or data plane access will happen via some caller identity, which can be controlled to be allowed or not (on synapse level).
- Once the spark job script lands in Synapse control plane, there will be spark pool based computes brought online. From these pool computes, the user script job execution management will start in synapse side (via azureml hosttools layers).
- In this pre script run time, as user supplied inputs/ outputs that point to `azureml://datastores` or `wasbs://` (or abfs or storage uri), using the `identity`, data points will try be validated first by reaching the azureml control plane APIs.
- This datastore access will work, as synapse created managed vnet based PE for destination azureml (with private route) - for blob and dfs sources. Also, the managed identity is earlier given contributor on RG level directly, so authorization will work fine for azureml control plane APIs.
- At the same time, azureml based job run from synapse computes need to write its execution events back to storage (mapped with azureml workspace). Hence, the managed vnet storage PE route will be taken up to reach storage. The authorization for storage will happen via the identity, which has to be given `storage blob data contributor` role on the storage.
- After data point validation, the spark based user script run (e.g. `titanic.py`) will start line by line code execution. 

```
import pyspark.pandas as pd
df = pd.read_csv(args.titanic_data, index_col="PassengerId") # read
### todo: write logic to modify df
df.to_csv(args.wrangled_data, index_col="PassengerId") # write
```

- When the spark `read_csv()` call is attempted, via azueml control plane api and allowed storage (via managed vnet spark PEs) access for identity, the data is read and processed.
- After data is processed, the dataframe is persisted on `outputs` path.
- In the meantime, job run events are propagated to storage for logging purpose.
- Then, spark run instance is exited. Then, runtime status propagate back to azureml control plane to exit the job run with its actual status (of completed or failed).


#### ML job on no managed vnet synapse
- User will submit azureml job from client machine, i.e. connected to private vnet linked PC (via private endpoint resolve for azureml workspace) - with target to run on attached synapse compute.
- AzureML control plane will try to discover the synapse ingress route now - via job schema based managed identity (or caller) supplied user.
- It means from AzureML control plane layer, i.e. its Azure backbone layers, the synapse attached compute host will be reached.
- There's PE on own vnet for the synapse workspace. However, PE would not be useful, as the intermediary caller layer is azure backbone here. Synapse own vnet PE is only useful when its workspace studio launched or synapse api called from the vnet connected PC.
- As `Allow Azure services and resources to access this workspace` option is enabled on synapse, the azure backbone layers will be allowed to communicate with destination Synapse control plane APIs.
- Once the spark job script lands in Synapse control plane, there will be spark pool based computes brought online. From these pool computes, the user script job execution management will start in synapse side (via azureml hosttools layers).
- In this pre script run time, as user supplied inputs/ outputs that point to `azureml://datastores` or `wasbs://` (or abfs or storage uri), using the `identity`, data points will try be validated first by reaching the azureml control plane APIs.
- In a private setup, the azureml workspace and storage will have PNA disabled.
- This datastore access will not work, as synapse computes are in public for destination azureml (there's no egress private route from synapse to azureml here). With PNA disabled for azureml, the azureml will deny the incoming request. Same is applied for blob storage too.
- With PNA enabled for azureml and storage, this access will only be allowed (whereabouts of synapse pool computes are unknown to azureml/ storage control plane).
- Also, the managed identity is earlier given contributor on RG level directly, so authorization will work fine for azureml control plane APIs.
- At the same time, azureml based job run from synapse computes need to write its execution events back to storage (mapped with azureml workspace). Hence, the public route will be taken up to reach storage. The authorization for storage will happen via the identity, which has to be given `storage blob data contributor` role on the storage.
- After data point validation, the spark based user script run (e.g. `titanic.py`) will start line by line code execution. 

```
import pyspark.pandas as pd
df = pd.read_csv(args.titanic_data, index_col="PassengerId") # read
### todo: write logic to modify df
df.to_csv(args.wrangled_data, index_col="PassengerId") # write
```

- When the spark `read_csv()` call is attempted, via azueml control plane api and allowed storage access for identity, the data is read and processed.
- After data is processed, the dataframe is persisted on `outputs` path.
- In the meantime, job run events are propagated to storage for logging purpose.
- Then, spark run instance is exited. Then, runtime status propagate back to azureml control plane to exit the job run with its actual status (of completed or failed).


#### ML job on serverless spark synapse
- User will submit azureml job from client machine, i.e. connected to private vnet linked PC (via private endpoint resolve for azureml workspace) - with target to run on serverless spark compute.
- AzureML control plane will try to discover the synapse ingress route now - via job schema based managed identity (or caller) supplied user.
- It means from AzureML control plane layer, i.e. its Azure backbone layers, the azureml infra will spin the synapse instance with pool computs on demand (on MS based subscription) and synapse host will be reached.
- Once the spark job script lands in Synapse control plane, there will be spark pool based computes brought online. From these pool computes, the user script job execution management will start in synapse side (via azureml hosttools layers).
- In this pre script run time, as user supplied inputs/ outputs that point to `azureml://datastores` or `wasbs://` (or abfs or storage uri), using the `identity`, data points will try be validated first by reaching the azureml control plane APIs.
- In a private setup, the azureml workspace and storage will have PNA disabled with PEs.
- This datastore access will work, as synapse pool computes are in same control plane as destination azureml and storage. 
- Also, the managed identity is earlier given contributor on RG level directly, so authorization will work fine for azureml control plane APIs.
- At the same time, azureml based job run from synapse computes need to write its execution events back to storage (mapped with azureml workspace). The authorization for storage will happen via the identity, which has to be given `storage blob data contributor` role on the storage.
- After data point validation, the spark based user script run (e.g. `titanic.py`) will start line by line code execution. 

```
import pyspark.pandas as pd
df = pd.read_csv(args.titanic_data, index_col="PassengerId") # read
### todo: write logic to modify df
df.to_csv(args.wrangled_data, index_col="PassengerId") # write
```

- When the spark `read_csv()` call is attempted, via azueml control plane api and allowed storage access for identity, the data is read and processed.
- After data is processed, the dataframe is persisted on `outputs` path.
- In the meantime, job run events are propagated to storage for logging purpose.
- Then, spark run instance is exited. Then, runtime status propagate back to azureml control plane to exit the job run with its actual status (of completed or failed).

## Spark code level logging

- Spark level logging is enabled via `log4j2.properties` file in the current src folder where script file is kept. Control logging levels there as needed.

- `log4j2.properties` - configuration file for various namespace appears as following to capture azureml:// uri based usage tracking.

```
status = error

appender.console.type = Console
appender.console.name = STDOUT
appender.console.layout.type = PatternLayout
appender.console.layout.pattern = %d{HH:mm:ss.SSS} %-5p %c - %m%n

rootLogger.level = info
rootLogger.appenderRefs = stdout
rootLogger.appenderRef.stdout.ref = STDOUT

logger.azureml.name = org.apache.hadoop.fs.azureml
logger.azureml.level = debug

logger.hadoopfs.name = org.apache.hadoop.fs
logger.hadoopfs.level = debug

logger.azure.name = org.apache.hadoop.fs.azure
logger.azure.level = debug

logger.azurebfs.name = org.apache.hadoop.fs.azurebfs
logger.azurebfs.level = debug

logger.msstorage.name = com.microsoft.azure.storage
logger.msstorage.level = debug
```

- Also, the spark job yaml where inputs/ outputs details are specified, supply the configuration for `log4j2.properties` file adoption to emit runtime events for better debugging, along with rest of other configuration details related to hardware.

```
conf:
  spark.files: log4j2.properties
  spark.driver.extraJavaOptions: -Dlog4j.configurationFile=log4j2.properties
  spark.executor.extraJavaOptions: -Dlog4j.configurationFile=log4j2.properties
```

- Sample log file in stdout points that azureml datastore uri access translates to `*.dfs.core.windows.net` based uri access ultimately, which is mounted on pool filesystem for local operation. This is same for inputs as well as outputs.

```
11:56:20.487 DEBUG org.apache.hadoop.fs.azureml.AzureMLFileSystem - [AzureMLFileSystem::initialize(uri: "azureml://subscriptions/6977e295-0d7c-4557-8e0b-26e2f6532103/resourcegroups/rg-eus2-sparks/workspaces/mlworkspaces10092/datastores/workspaceblobstore/paths/data/titanic.csv", configuration: <Configuration>)]
11:56:20.490 DEBUG org.apache.hadoop.fs.azureml.utils.DatastoreClient - [DatastoreClient::fetchDatastoreDto] Making a request to datastore metadata service at 'https://35360ec3-dad7-4730-b416-e070aaa7bd5c.workspace.eastus2.api.azureml.ms'
11:56:20.491 DEBUG org.apache.hadoop.fs.azureml.utils.HttpClient - [HttpClient::get] cache miss for URI 'https://35360ec3-dad7-4730-b416-e070aaa7bd5c.workspace.eastus2.api.azureml.ms/datastore/v1.0/subscriptions/6977e295-0d7c-4557-8e0b-26e2f6532103/resourceGroups/rg-eus2-sparks/providers/Microsoft.MachineLearningServices/workspaces/mlworkspaces10092/datastores/workspaceblobstore'
11:56:20.627 DEBUG org.apache.hadoop.fs.azureml.resolvers.WorkspaceDataPathResolver - [WorkspaceDataPathResolver::resolve] resolving org.apache.hadoop.fs.azureml.datapaths.LongFormDataPath@6f813294
11:56:20.627 DEBUG org.apache.hadoop.fs.azureml.AzureMLFileSystem - [AzureMLFileSystem::tryResolveDatapath] azureml://subscriptions/6977e295-0d7c-4557-8e0b-26e2f6532103/resourcegroups/rg-eus2-sparks/workspaces/mlworkspaces10092/datastores/workspaceblobstore/paths/data/titanic.csv resolved to abfss://azureml-blobstore-35360ec3-dad7-4730-b416-e070aaa7bd5c@mlstorage10092.dfs.core.windows.net/data/titanic.csv
11:56:20.628 DEBUG org.apache.hadoop.fs.azureml.resolvers.WorkspaceDataPathResolver - [WorkspaceDataPathResolver::setAzureBlobConfig] Credential-less datastore
11:56:20.628 DEBUG org.apache.hadoop.fs.FileSystem - Starting: Acquiring creator semaphore for abfss://azureml-blobstore-35360ec3-dad7-4730-b416-e070aaa7bd5c@mlstorage10092.dfs.core.windows.net/data/titanic.csv
```


## Pre-requisite for workload run
- Run it in jumpbox Windows PC, or let PC be connect via vnet gateway
- In .ps1 files, remember to set current Azure resource details

## Run workload (in Windows machine) in Powershell
```
cd .\azure-synapse\
.\-1.unblock-files.bat  
.\0.pre-requisites.ps1
```

- Upload local data into storage for repro work.
```
.\1.prep-for-ml.ps1
```

- Update resource and compute details. Then, run the spark jobs on updated hardware pools.

```
.\2.run-attached-standalone-sparkjob.ps1
.\3.run-attached-pipeline-sparkjob.ps1
```

```
.\4.run-serverless-standalone-sparkjob.ps1
.\5.run-serverless-pipeline-sparkjob.ps1
```


