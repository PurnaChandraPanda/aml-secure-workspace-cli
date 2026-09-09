# Discover Azure ML FE v2 Configurable Parameters

This guide explains how to inspect the Helm release installed by the `Microsoft.AzureML.Kubernetes` extension and identify configurable values used by the `azureml-fe-v2` Deployment.

> [!IMPORTANT]
> The Azure Machine Learning Kubernetes extension is Microsoft-managed.
>
> Values visible in the Helm release may be internal chart values and are not necessarily part of the publicly documented Azure ML extension configuration contract.
>
> Before using a discovered value in production, verify that:
>
> 1. The key exists in the computed Helm values.
> 2. The key affects the rendered Helm manifest.
> 3. The value appears in the live Kubernetes resource.
> 4. The setting persists after extension reconciliation or upgrade.


## 1. Install Helm on Windows

From PowerShell or Windows Terminal, install Helm:

```powershell
winget install Helm.Helm
```

Close and reopen Git Bash after installation.

Verify the installation:

```bash
helm version
```

## 2. Connect to the AKS cluster

Retrieve the AKS cluster credentials:

```bash
az aks get-credentials \
  --resource-group "<aks-resource-group>" \
  --name "<aks-cluster-name>" \
  --overwrite-existing
```

Verify the active Kubernetes context:

```bash
kubectl config current-context
```

Verify cluster access:

```bash
kubectl get nodes
```

## 3. Identify the Azure ML Helm release

List Helm releases in all namespaces:

```bash
helm list --all-namespaces
```

The Azure ML extension release is normally installed in the `azureml` namespace.

The Helm release name and namespace can also be retrieved from the `azureml-fe-v2` Deployment annotations:

```bash
kubectl get deployment azureml-fe-v2 \
  --namespace azureml \
  --output jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}{"\n"}{.metadata.annotations.meta\.helm\.sh/release-namespace}{"\n"}'
```

Example output:

```text
aml
azureml
```

Set reusable shell variables:

```bash
HELM_RELEASE="aml"
HELM_NAMESPACE="azureml"
```

## 4. Inspect the installed chart metadata

Run:

```bash
helm get metadata "$HELM_RELEASE" \
  --namespace "$HELM_NAMESPACE" \
  --output yaml
```

Example output:

```yaml
appVersion: 1.16.0
chart: amlarc-extension
deployedAt: "2026-09-04T10:51:41Z"
labels:
  modifiedAt: "1788519402"
  name: aml
  owner: helm
  status: deployed
  version: "1"
name: aml
namespace: azureml
revision: 1
status: deployed
version: 1.1.106
```

This output identifies:

- Helm release name
- Release namespace
- Chart name
- Installed chart version
- Release revision
- Deployment status

`helm get metadata` does not list all chart values or configuration defaults.

## 5. Extract user-supplied Helm values

Run:

```bash
helm get values "$HELM_RELEASE" \
  --namespace "$HELM_NAMESPACE" \
  --output yaml \
  > aml-user-values.yaml
```

Review the values:

```bash
cat aml-user-values.yaml
```

This file contains values explicitly supplied to the Helm release.

## 6. Extract all computed Helm values

Run:

```bash
helm get values "$HELM_RELEASE" \
  --namespace "$HELM_NAMESPACE" \
  --all \
  --output yaml \
  > aml-computed-values.yaml
```

The computed values include chart defaults and values supplied to the installed release.

Search for FE-related values:

```bash
grep -nEi -A25 -B5 \
  'scoringFe|resourcesEnvoy|resourcesXds|resourcesClb|replica|inferenceRouterHA' \
  aml-computed-values.yaml
```

For extension version `1.1.106`, the following FE v2 resource paths are visible:

```text
scoringFe.resourcesEnvoy.requests.cpu
scoringFe.resourcesEnvoy.requests.memory
scoringFe.resourcesEnvoy.limits.cpu
scoringFe.resourcesEnvoy.limits.memory

scoringFe.resourcesXds.requests.cpu
scoringFe.resourcesXds.requests.memory
scoringFe.resourcesXds.limits.cpu
scoringFe.resourcesXds.limits.memory

scoringFe.resourcesClb.requests.cpu
scoringFe.resourcesClb.requests.memory
scoringFe.resourcesClb.limits.cpu
scoringFe.resourcesClb.limits.memory
```

The resource mappings are:

```text
scoringFe.resourcesEnvoy  -> envoy container
scoringFe.resourcesXds    -> xds container
scoringFe.resourcesClb    -> clb container
```

The generic resource section may also be present:

```text
scoringFe.resources.requests.cpu
scoringFe.resources.requests.memory
scoringFe.resources.limits.cpu
scoringFe.resources.limits.memory
```

The generic `scoringFe.resources` section should not be assumed to control all FE v2 containers. The FE v2 Deployment contains separate `envoy`, `xds`, and `clb` containers with corresponding resource sections.

The computed values also contain:

```yaml
inferenceRouterHA: true
```

This value enables the high-availability inference-router configuration.

## 7. Extract only the `scoringFe` values

The complete computed-values file can contain internal endpoints, resource identifiers, identity details, and credential-like data.

Extract only the `scoringFe` section:

```bash
sed -n '/^scoringFe:/,/^[^ ]/p' \
  aml-computed-values.yaml \
  > scoring-fe-values.yaml
```

Review the extracted values:

```bash
cat scoring-fe-values.yaml
```

Example structure:

```yaml
scoringFe:
  resources:
    limits:
      cpu: 500m
      memory: 500Mi
    requests:
      cpu: 500m
      memory: 500Mi

  resourcesClb:
    limits:
      cpu: 700m
      memory: 500Mi
    requests:
      cpu: 300m
      memory: 300Mi

  resourcesEnvoy:
    limits:
      cpu: 1200m
      memory: 500Mi
    requests:
      cpu: 500m
      memory: 300Mi

  resourcesXds:
    limits:
      cpu: 100m
      memory: 200Mi
    requests:
      cpu: 100m
      memory: 200Mi
```

## 8. Extract the rendered Helm manifest

Run:

```bash
helm get manifest "$HELM_RELEASE" \
  --namespace "$HELM_NAMESPACE" \
  > aml-rendered-manifest.yaml
```

The rendered manifest contains the Kubernetes resources generated by the installed Helm release.

Search for the FE v2 Deployment:

```bash
grep -n -A250 -B10 \
  'name: azureml-fe-v2' \
  aml-rendered-manifest.yaml
```

The relevant manifest normally includes a source comment similar to:

```text
# Source: amlarc-extension/templates/inference/scoring-fe/fe_rbac_and_deployment_v2.yaml
```

The rendered Deployment shows the final replica count:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: azureml-fe-v2
  namespace: azureml
spec:
  replicas: 3
```

This confirms that the installed chart rendered three FE v2 replicas.

The rendered manifest shows the final output of Helm processing. It does not show the original, unrendered Helm template expression.

## 9. Extract only the FE v2 Deployment

Use `awk`:

```bash
awk '
  /^---$/ {
    if (document ~ /kind: Deployment/ &&
        document ~ /name: azureml-fe-v2/) {
      print document
    }

    document = ""
    next
  }

  {
    document = document $0 ORS
  }

  END {
    if (document ~ /kind: Deployment/ &&
        document ~ /name: azureml-fe-v2/) {
      print document
    }
  }
' aml-rendered-manifest.yaml \
  > azureml-fe-v2-rendered.yaml
```

Review the extracted Deployment:

```bash
cat azureml-fe-v2-rendered.yaml
```

## 10. Compare Helm values with the rendered Deployment

Check the computed FE resource values:

```bash
grep -nEi -A20 -B5 \
  'resourcesEnvoy|resourcesXds|resourcesClb' \
  scoring-fe-values.yaml
```

Check the rendered FE Deployment:

```bash
grep -nE \
  'replicas:|name: envoy|name: xds|name: clb|requests:|limits:|cpu:|memory:' \
  azureml-fe-v2-rendered.yaml
```

A candidate configuration path is strongly validated when:

1. The path exists in `aml-computed-values.yaml`.
2. The value appears in the expected container in the rendered manifest.
3. The value appears in the live `azureml-fe-v2` Deployment.

## 11. Check the live FE v2 Deployment

Display the current replica count and container resources:

```bash
kubectl get deployment azureml-fe-v2 \
  --namespace azureml \
  --output jsonpath='{.spec.replicas}{"\n"}{range .spec.template.spec.containers[*]}{.name}{"\n  requests: "}{.resources.requests}{"\n  limits:   "}{.resources.limits}{"\n\n"}{end}'
```

Example output:

```text
3
envoy
  requests: {"cpu":"500m","memory":"300Mi"}
  limits:   {"cpu":"1200m","memory":"500Mi"}

xds
  requests: {"cpu":"100m","memory":"200Mi"}
  limits:   {"cpu":"100m","memory":"200Mi"}

clb
  requests: {"cpu":"300m","memory":"300Mi"}
  limits:   {"cpu":"700m","memory":"500Mi"}
```

## 12. Check which controller manages the replica field

Run:

```bash
kubectl get deployment azureml-fe-v2 \
  --namespace azureml \
  --output yaml \
  > azureml-fe-v2-live.yaml
```

Search for the extension manager:

```bash
grep -n -A25 -B5 \
  'manager: extensionmanager' \
  azureml-fe-v2-live.yaml
```

In the managed fields, check whether `extensionmanager` owns:

```yaml
f:spec:
  f:replicas: {}
```

If `extensionmanager` owns `spec.replicas`, a manual replica change can be reverted during:

- Extension reconciliation
- Extension upgrade
- Cluster restart
- Extension reinstallation

## 13. Determine whether FE v2 replica count is configurable

Search the computed values for replica-related settings:

```bash
grep -nEi -A10 -B5 \
  'scoringFe.*replica|replicaCount|replicas|minReplicas|maxReplicas|autoscaling' \
  aml-computed-values.yaml
```

For extension version `1.1.106`, the top-level `scoringFe` values expose resource settings for the `envoy`, `xds`, and `clb` containers.

The computed values do not show a setting such as:

```yaml
scoringFe:
  replicaCount: 5
```

The rendered manifest contains:

```yaml
spec:
  replicas: 3
```

The available evidence therefore confirms:

```text
inferenceRouterHA=True -> 3 FE v2 replicas
```

## 14. Example extension resource configuration

The following FE v2 resource configuration has matching value paths in extension version `1.1.106`:

```bash
az k8s-extension create \
  --name "$AKS_EXTENSION_NAME" \
  --extension-type "Microsoft.AzureML.Kubernetes" \
  --config \
      enableTraining=True \
      enableInference=True \
      inferenceRouterServiceType=LoadBalancer \
      inferenceRouterHA=True \
      allowInsecureConnections=True \
      scoringFe.resources.requests.cpu=1000m \
      scoringFe.resources.requests.memory=2Gi \
      scoringFe.resources.limits.cpu=2000m \
      scoringFe.resources.limits.memory=4Gi \
      scoringFe.resourcesEnvoy.requests.cpu=1000m \
      scoringFe.resourcesEnvoy.requests.memory=2Gi \
      scoringFe.resourcesEnvoy.limits.cpu=2000m \
      scoringFe.resourcesEnvoy.limits.memory=4Gi \
      scoringFe.resourcesXds.requests.cpu=250m \
      scoringFe.resourcesXds.requests.memory=512Mi \
      scoringFe.resourcesXds.limits.cpu=500m \
      scoringFe.resourcesXds.limits.memory=1Gi \
      scoringFe.resourcesClb.requests.cpu=500m \
      scoringFe.resourcesClb.requests.memory=1Gi \
      scoringFe.resourcesClb.limits.cpu=1000m \
      scoringFe.resourcesClb.limits.memory=2Gi \
  --cluster-type "$AKS_CLUSTER_TYPE" \
  --cluster-name "$AKS_CLUSTER_NAME" \
  --resource-group "$AKS_RG" \
  --scope cluster
```

## 15. Validate the extension configuration

After creating or updating the extension, verify what Azure stored:

```bash
az k8s-extension show \
  --name "$AKS_EXTENSION_NAME" \
  --cluster-type "$AKS_CLUSTER_TYPE" \
  --cluster-name "$AKS_CLUSTER_NAME" \
  --resource-group "$AKS_RG" \
  --query configurationSettings \
  --output yaml
```

Verify the computed Helm values:

```bash
helm get values "$HELM_RELEASE" \
  --namespace "$HELM_NAMESPACE" \
  --all \
  --output yaml \
  > aml-computed-values-after-update.yaml
```

Extract the updated FE section:

```bash
sed -n '/^scoringFe:/,/^[^ ]/p' \
  aml-computed-values-after-update.yaml
```

Verify the live Deployment:

```bash
kubectl get deployment azureml-fe-v2 \
  --namespace azureml \
  --output jsonpath='{.spec.replicas}{"\n"}{range .spec.template.spec.containers[*]}{.name}{"\n  requests: "}{.resources.requests}{"\n  limits:   "}{.resources.limits}{"\n\n"}{end}'
```

A setting should not be considered effective only because it appears in the extension resource.

The value should also appear in:

1. The computed Helm values
2. The rendered Helm manifest
3. The live Kubernetes Deployment

## Summary

Use the following commands to investigate Azure ML FE v2 configuration:

```bash
helm get metadata aml \
  --namespace azureml \
  --output yaml
```

```bash
helm get values aml \
  --namespace azureml \
  --all \
  --output yaml \
  > aml-computed-values.yaml
```

```bash
helm get manifest aml \
  --namespace azureml \
  > aml-rendered-manifest.yaml
```

```bash
kubectl get deployment azureml-fe-v2 \
  --namespace azureml \
  --output yaml \
  > azureml-fe-v2-live.yaml
```

For extension version `1.1.106`, the verified FE v2 resource paths are:

```text
scoringFe.resourcesEnvoy.*
scoringFe.resourcesXds.*
scoringFe.resourcesClb.*
```

The chart renders:

```yaml
spec:
  replicas: 3
```

The computed values do not expose an arbitrary FE v2 replica-count setting. Therefore, a value such as `scoringFe.replicaCount=5` should not be treated as supported without further confirmation.
