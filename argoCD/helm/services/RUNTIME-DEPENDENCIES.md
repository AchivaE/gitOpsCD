# Runtime dependencies: production contract

`config-ingestor` and `gateway-ingestor` are deployed by Argo CD as workloads
only. They never build images and they do not install Consul or Vault. Their
runtime dependencies are deliberately external to the service charts so they
can be operated, patched, backed up, and access-controlled independently.

## Deployment modes

The charts have layered provider profiles: `values-local.yaml` for a local
Kubernetes smoke test, `values-azure.yaml` for AKS, and `values-aws.yaml` for
EKS. Provider choice changes values only; it never forks a chart or embeds a
cloud provider API in a workload manifest. See [PORTABILITY.md](PORTABILITY.md)
for installation commands and the exact layer order.

When External Secrets is disabled, the same chart consumes pre-created
Kubernetes Secrets with the names declared in values. This supports an isolated
developer cluster without teaching Helm how to create or store credentials.

## Release gate

For every environment, replace all `REPLACE_WITH_*` entries in the service
`values-<environment>.yaml` files as part of CI promotion. Helm rejects a
release with placeholder image tags, private endpoints, or egress CIDRs. This
is intentional: an application must not start against an unintended control
plane.

The image reference must be immutable (a unique release tag or, preferably, a
digest). CI promotes the image reference; Argo CD pulls it from the configured
OCI registry.
There is no `build`, Docker socket, Kaniko, or image-push permission in the
charts.

## Consul contract

Both services require a Consul HTTPS API that is reachable from AKS through a
private endpoint, private DNS, and a narrowly scoped NetworkPolicy egress
CIDR. Port `8501` is the required API port. The endpoint certificate must have
the configured private DNS name in its SAN. Do not expose port `8500`, the UI,
or a management ACL token to workloads.

Azure Key Vault must provide the following secrets. PKCS12 values are stored
Base64-encoded so External Secrets Operator can materialize binary files.

| Service | ACL token | TLS material |
| --- | --- | --- |
| config-ingestor | `config-ingestor-consul-acl-token` | `config-ingestor-consul-keystore-p12`, `config-ingestor-consul-keystore-password`, `config-ingestor-consul-truststore-p12`, `config-ingestor-consul-truststore-password` |
| gateway-ingestor | `gateway-ingestor-consul-acl-token` | `gateway-ingestor-consul-keystore-p12`, `gateway-ingestor-consul-keystore-password`, `gateway-ingestor-consul-truststore-p12`, `gateway-ingestor-consul-truststore-password` |

Each Consul token must be workload-specific and least-privilege. The
config-ingestor token needs only its own service registration and health check;
the gateway token needs only discovery/read and its own registration. Never
reuse the Consul bootstrap or management token.

## Vault contract

`gateway-ingestor` also requires an existing, HA Vault service on a private
HTTPS endpoint. A Vault server is not provisioned by this repository yet, so
this is a hard production prerequisite, not an optional feature.

Before promotion, the Vault operator must configure the Kubernetes auth mount
(`kubernetes` by default) and a `gateway-ingestor` role bound only to the
`gateway-ingestor` ServiceAccount in the target namespace. The role must be
read-only and limited to the KV paths `achiva/shared` and
`achiva/gateway-ingestor`. It must not grant policy or token administration.

Key Vault must contain `gateway-ingestor-vault-truststore-p12` (Base64 PKCS12)
and `gateway-ingestor-vault-truststore-password`. The gateway uses Kubernetes
authentication, never `VAULT_TOKEN` in Git or in a Helm value.

## Configuration Git repository

`config-ingestor` clones only an HTTPS private configuration repository. Store
the Git username/token in Key Vault under `config-ingestor-git-username` and
`config-ingestor-git-token`. Its NetworkPolicy must allow TCP/443 only to the
private endpoint CIDR(s) of that Git service; unrestricted internet egress is
not accepted by the chart.

## Application observability prerequisite

The charts always create a Kubernetes availability alert, which relies on
`kube-state-metrics` rather than an application endpoint. They intentionally
do **not** create a `ServiceMonitor` by default: the current service POM files
do not include `micrometer-registry-prometheus`, so `/actuator/prometheus`
would return no usable metrics. Add that dependency and expose the endpoint in
both applications, then set `monitoring.serviceMonitorEnabled: true` in the
relevant environment values. The charts also override actuator exposure to
`health,info` and hide health details, preventing the current `env` and verbose
health data from being exposed in production.

## Legacy Consul Terraform module

`infra/azure/consul` is legacy and is **not approved for production use**. It
currently conflicts with this contract: it provisions a public load balancer,
uses HTTP/8500 in its pipeline, and does not deliver the generated TLS material
to the VMs. Do not run it or copy `AZURE_PIPELINES_CONFIG.yaml` into a pipeline.
It must be replaced by a separately reviewed Consul platform module before it
can serve these charts.

HashiCorp recommends secure TLS with incoming, outgoing, and server-hostname
verification, plus narrowly scoped ACL tokens. Spring Cloud Vault Kubernetes
authentication is based on the pod ServiceAccount token and role binding.
