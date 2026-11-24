# Platform modules

This directory is a module catalogue, not a Helm chart. It deliberately has no
root `Chart.yaml`, templates, values files or vendored dependencies.

Each stateful platform product owns one dedicated Helm chart and one dedicated
Argo CD Application. This prevents an update of Consul, Keycloak or a future
broker from changing an unrelated product.

| Module | Path | Standard deployment model |
| --- | --- | --- |
| Consul | `platform/runtime/consul` | local Kubernetes validation only; private external HA control plane for staging/prod |
| Keycloak | `platform/identity/keycloak` | dedicated identity plane, external PostgreSQL HA; activation gated |
| Kafka | `platform/eventing/kafka` | explicit local single-node KRaft validation module; managed private event plane for staging/prod |
| Vault | `platform/security/vault` | external private HA security plane; no server chart in Argo CD |
| PostgreSQL | `platform/databases/postgresql` | external managed HA database contract; no in-cluster production chart |
| Logging / tracing | `platform/observability/logging`, `platform/observability/tracing` | activation contracts pending approved object storage and recovery evidence |

Cluster-scoped products (cert-manager, monitoring, alerting) remain in
`../foundation` and `platform/observability`. Technical services remain in
`../services`; business workloads have their own future catalogue.
The architecture rules are in [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md).
