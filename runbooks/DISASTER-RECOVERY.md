# Disaster recovery and restore evidence

## Initial objectives to approve

| Scope | Proposed RPO | Proposed RTO | Evidence required |
| --- | ---: | ---: | --- |
| GitOps manifests | 1 hour | 1 hour | protected Git mirror and tested bootstrap |
| Kubernetes workload manifests | 24 hours | 4 hours | successful Velero backup and restore drill |
| Persistent application data | workload-specific | workload-specific | database-native restore test |
| Vault and Consul control planes | operator-defined | operator-defined | independent backup/restore exercise |

These are proposed objectives, not achieved commitments. Product, security and
service owners must approve the final RPO/RTO per data classification.

## Velero release gate

Do not enable Velero merely because a Helm chart renders. Before sync, provide:

1. A private Azure Blob container dedicated to backups, with retention and
   deletion protection approved by security.
2. A least-privilege workload identity for the Velero ServiceAccount; no Azure
   storage account key in Git or a Kubernetes Secret.
3. A tested CSI snapshot/data-movement design for every PVC-backed workload.
4. A `BackupStorageLocation` in `Available` state and a successful on-demand
   backup of the target namespace.
5. An isolated restore namespace or cluster for the drill.

## Quarterly restore drill

1. Select the latest successful backup and set the storage location read-only.
2. Restore into an isolated namespace/cluster; never use a production restore
   drill as the first test.
3. Verify workload readiness, ingress/TLS, secret reconciliation, data
   consistency and application smoke tests.
4. Record elapsed time, backup identifier, restored commit/digest, failures,
   corrective actions and whether the approved RPO/RTO was met.
5. Return the storage location to read-write only after the drill closes.

Velero restore is non-destructive by default, but it is not a substitute for
database-consistent backups. Stateful services require their own recovery plan.
