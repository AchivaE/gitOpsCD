# External Kafka and Vault activation gates

Kafka and Vault are intentionally not Applications in the standard Argo
overlays. They are external HA control planes. The cluster only deploys
workloads that consume them after the following gates are satisfied:

| Plane | Required evidence | Workload activation |
| --- | --- | --- |
| Vault | private endpoint, CA, Kubernetes Auth role, least-privilege policy, audit and recovery test | enable the service's existing Vault values; no token value |
| Kafka | managed private endpoint, TLS/SASL identity, topic ACLs, topic contract, replay/DLQ and failover test | add code-level Kafka client support and its reviewed chart values; local-only broker activation is documented in `helm/platform/eventing/kafka/README.md` |

The detailed runbooks are `runbooks/VAULT-SECURITY-PLANE.md` and
`runbooks/KAFKA-EVENT-PLANE.md`.
