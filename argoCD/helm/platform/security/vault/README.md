# Vault security-plane contract

The local overlay renders the pinned official Vault chart for a single-node
validation instance. It is initialized and unsealed only by the workstation
bootstrap script; no token or recovery key is committed to Git.

Staging and production use a private HA Vault service outside the application
cluster, with auto-unseal, audit logs, TLS and a tested recovery procedure.
Argo CD deploys only consumers that authenticate through workload-specific
Kubernetes Auth roles in those environments.

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
