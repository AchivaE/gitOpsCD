# Portable deployment profiles

The service charts contain Kubernetes and application contracts only. They do
not build images, provision a cloud resource, or assume an Azure controller in
their templates. Select the deployment target with layered values files:

| Profile | Intended target | Integrations enabled |
| --- | --- | --- |
| `values-local.yaml` | kind, k3d, minikube, Docker Desktop Kubernetes | none; native config mode and no ingress |
| `values-azure.yaml` | AKS | Azure Key Vault-backed External Secrets and Application Gateway annotations |
| `values-aws.yaml` | EKS | AWS Secrets Manager-backed External Secrets and AWS Load Balancer Controller annotations |
| `values-dev.yaml`, `values-staging.yaml`, `values-prod.yaml` | lifecycle sizing and release policy | environment-specific image and hostname |

Helm merges files from left to right. The image is always supplied to the
cluster as an image reference; Helm never builds or pushes an image.

## Local Kubernetes smoke test

First make externally built images available to the local cluster (for example,
load them into kind or k3d, or make them visible to Docker Desktop Kubernetes),
tagged as `config-ingestor:dev` and `gateway-ingestor:dev`. `values-dev.yaml`
uses `IfNotPresent`, so Kubernetes uses these local images instead of pulling
from ACR/ECR. For a manual local install, either retag images as `:local` or
pass `--set image.tag=dev`. Then render and install both charts:

```powershell
helm upgrade --install config-ingestor .\config-ingestor -n spaceup-local --create-namespace -f .\config-ingestor\values-local.yaml
helm upgrade --install gateway-ingestor .\gateway-ingestor -n spaceup-local -f .\gateway-ingestor\values-local.yaml
kubectl -n spaceup-local port-forward service/gateway-ingestor 8080:80
```

The local profile intentionally disables External Secrets Operator, Vault,
Consul, NetworkPolicies, HPA, PDB, public ingress and monitoring CRDs. It is a
safe smoke-test profile, not an emulation of production dependencies. To test
those dependencies locally, keep their `enabled` flag true, provide the named
Kubernetes Secrets yourself, and set `externalSecret(s).enabled=false`; no
chart source change is needed.

### Argo CD development environment

The explicit development catalogue in
`argoCD/argo/applications/services-dev/applicationset.yaml` applies
`values.yaml`, `values-dev.yaml`, then `values-local.yaml`. The local layer
therefore wins for developer image names and disables cloud dependencies.
Before synchronizing `dev`, make the image references declared in
`values-local.yaml` available to the Kubernetes node runtime:

```powershell
# Docker Desktop Kubernetes shares Docker's image store.
docker image tag <your-config-image> achiva-insgestor-config-service:latest
docker image tag <your-gateway-image> achiva-insgestor-gateway-service:latest

# kind needs an explicit import after the images are built/tagged.
kind load docker-image achiva-insgestor-config-service:latest achiva-insgestor-gateway-service:latest --name <cluster-name>

# k3d import equivalent.
k3d image import achiva-insgestor-config-service:latest achiva-insgestor-gateway-service:latest -c <cluster-name>
```

Do not use a mutable `latest` tag. When the local image changes, rebuild and
reload the same `:dev` tag, then explicitly restart the deployment; Kubernetes
does not automatically replace a cached `IfNotPresent` image.

## Managed clusters and GitOps

Argo CD applies, in order, `values.yaml`, `values-<provider>.yaml`, then
`values-<environment>.yaml` for managed clusters. The staging and production
ApplicationSets declare the Azure profile explicitly today; an AWS target must
use a separate reviewed ApplicationSet or overlay. The chart code and the
environment values remain unchanged. Enable an AWS target only after an EKS cluster,
the AWS Load Balancer Controller, an `aws-secrets-manager` ClusterSecretStore,
private DNS, and the dependency endpoints have been prepared.

Production-like profiles deliberately fail rendering until a promoted immutable
image, private Consul/Vault endpoints, and restricted egress CIDRs are present.
This prevents a provider migration from silently opening network access or
starting against a public control plane.

`cluster-addons` uses the same `values-local.yaml`, `values-azure.yaml`, and
`values-aws.yaml` convention. Apply its chosen profile separately because it is
cluster-scoped and is intentionally not installed by either service chart.
