# Platform chart boundaries

This chart is synchronized once per application environment. It contains only components that can safely be scoped to that environment.

It intentionally does **not** enable the following incomplete or cluster-wide components:

- Consul: requires a dedicated module with ACL bootstrap, TLS, gossip encryption, persistent storage and backup/restore testing.
- PostgreSQL, Redis and Keycloak: stateful services need independent lifecycle, backups, recovery objectives and secrets.
- Loki: requires Azure Blob containers plus workload identity before activation.
- Gatekeeper: constraints must be paired with tested ConstraintTemplates.
- namespace-wide RBAC, PDB and NetworkPolicy: service charts own least-privilege RBAC, disruption budgets and network rules.

Cluster-wide add-ons such as cert-manager and kube-prometheus-stack must be deployed once in a dedicated cluster-addons application, not once for each environment. This is the next platform submodule.
