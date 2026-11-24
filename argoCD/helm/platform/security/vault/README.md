# Vault security-plane contract

Vault is represented here as an external platform contract, not a Helm chart.
Staging and production use a private HA Vault service with auto-unseal, audit
logs, TLS and a tested recovery procedure. Argo CD only deploys consumers that
authenticate through workload-specific Kubernetes Auth roles.

See [`../../../ARCHITECTURE.md`](../../../ARCHITECTURE.md) and
[`../../../services/RUNTIME-DEPENDENCIES.md`](../../../services/RUNTIME-DEPENDENCIES.md).

## Activation artifacts

`policies/gateway-ingestor.hcl` and
`kubernetes-auth/gateway-ingestor-role.json` are input artifacts for the Vault
platform team. They are not Kubernetes manifests and cannot be applied by Argo
CD. Replace their namespace placeholder only in the secure Vault configuration
workflow, then use the Vault CLI/API to create the policy and auth role.

The gateway chart is already prepared for Kubernetes Auth: it mounts a
truststore from External Secrets, uses its dedicated ServiceAccount and never
accepts a Vault root token. Production activation remains blocked until the
private endpoint, CA, policy, role and audit/recovery evidence exist.
