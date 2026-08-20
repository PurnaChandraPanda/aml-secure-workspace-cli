# Submit the hello-world job to Azure ML on AKS

This sample submits a command job to the Azure Machine Learning workspace and
runs it on the attached AKS compute target.

## Prerequisites

- Azure CLI with the Azure Machine Learning extension:

  ```bash
  az extension add --name ml --upgrade
  ```

- The AKS cluster must be attached to the workspace as the `k8s-compute`
  compute target.
- The `usernodetype` Kubernetes `InstanceType` must exist in the Azure ML
  namespace. The repository's `k8s-cli/ml-k8s-compute.sh` script creates both
  the compute attachment and this instance type.
- The identity submitting the job must have permission to create jobs in the
  workspace.

## Configuration

Update these values in `submit-helloworld-job.sh` before running it:

- `TENANT_ID`: Microsoft Entra tenant containing the subscription.
- `SUBSCRIPTION_ID`: Azure subscription containing the workspace.
- `ML_RESOURCE_GROUP`: Resource group containing the Azure ML workspace.
- `ML_WORKSPACE`: Azure ML workspace name.

The job definition in `helloworld-job.yml` uses:

- `compute: azureml:k8s-compute` to select the attached AKS compute.
- `resources.instance_type: usernodetype` to select nodes configured for Azure
  ML user workloads.
- `library/python:latest` as the container image and a Python command that
  prints `Hello world!`.

The cluster must have outbound access to pull the container image unless it is
already cached. For repeatable production jobs, replace the `latest` image tag
with a fixed version or digest.

## Submit the job

From Git Bash:

```bash
cd workload/azureml/k8s/job
chmod +x submit-helloworld-job.sh
./submit-helloworld-job.sh
```

The script signs in to the configured tenant, selects the subscription,
submits the YAML job, and streams its output until the job reaches a terminal
state.

To inspect recent jobs separately:

```bash
az ml job list \
  --resource-group rg-mlws \
  --workspace-name mlws01 \
  --query "[].{Name:name,Status:status,Compute:compute}" \
  --output table
```

To confirm that the workload pod is scheduled on the intended AKS user pool:

```bash
kubectl get pods -n azureml -o wide --watch
```