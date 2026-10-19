# Observability incident runbook

## External Secrets Operator unavailable

1. Acknowledge the alert and check `external-secrets` deployment readiness.
2. Check the `ClusterSecretStore/azure-keyvault` readiness and the workload
   identity federation/Key Vault role assignment; do not copy a secret into Git
   or create a long-lived Azure client secret as a workaround.
3. Inspect the failing `ExternalSecret` status. Rotate or correct the Key Vault
   value only through the secret-management process.
4. Record the affected workloads and confirm they become ready after ESO
   reconciles. Escalate after 30 minutes because secret rotation stops.

## cert-manager unavailable

1. Check controller, webhook and cainjector readiness in `cert-manager`.
2. Check the `ClusterIssuer` readiness and the affected `Certificate` events.
3. For HTTP-01, verify public DNS and port 80 routing through Application
   Gateway. Do not bypass TLS by serving the gateway in HTTP.

## Certificate expiring soon

1. Identify the certificate labels and inspect its latest issuance failure.
2. Resolve DNS/ACME/issuer access at least seven days before expiry.
3. Validate the renewed secret and a TLS handshake from outside the cluster.

## Persistent volume low space

1. Identify the PVC owner and growth rate; do not delete data as a first step.
2. Confirm a recent successful backup before resizing or retaining less data.
3. Resize only if its StorageClass supports expansion; otherwise execute the
   workload-specific migration plan.

## Alert routing acceptance test

For each production change to `spaceup-cluster-alertmanager-config`, trigger a
controlled warning alert in preproduction and retain evidence that it reached
the named on-call receiver. A valid YAML Secret alone is not proof of paging.
