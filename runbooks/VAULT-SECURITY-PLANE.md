# Vault external security-plane activation

## Scope

Vault is external to Kubernetes for staging/production. Kubernetes workloads
authenticate using the Kubernetes Auth method; no root token, AppRole secret ID
or static `VAULT_TOKEN` is permitted in Git, Helm values or an application
Secret.

## Required evidence

1. Private HTTPS endpoint, private DNS resolution from workload subnets and
   NetworkPolicy CIDR approved for TCP/8200.
2. HA storage, auto-unseal backed by cloud KMS/HSM, TLS on every hop, audit
   device forwarding to the protected logging service.
3. Recovery keys controlled under the approved break-glass process and a
   documented, tested backup/recovery exercise.
4. Kubernetes Auth configured with the target cluster issuer/CA and reviewer
   permissions required by Vault.
5. Policy `gateway-ingestor` created from
   `argoCD/helm/platform/security/vault/policies/gateway-ingestor.hcl`.
6. One role per environment from
   `argoCD/helm/platform/security/vault/kubernetes-auth/gateway-ingestor-role.json`,
   with its namespace placeholder replaced by the actual workload namespace.

## Staging activation test

1. Store only the Vault truststore material in the selected Secret Store.
2. Enable gateway Vault values with the private URI and CIDR; do not add a
   token value.
3. Verify the ExternalSecret is Ready and the gateway starts using Kubernetes
   Auth.
4. Confirm it can read `achiva/shared` and `achiva/gateway-ingestor` but gets
   `permission denied` for any other path.
5. Rotate a test secret, wait for the approved refresh behavior and record the
   result. Repeat during a Vault active-node failover.
