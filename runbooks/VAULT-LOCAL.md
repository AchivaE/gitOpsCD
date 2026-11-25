# Vault + External Secrets local validation

This runbook validates the GitOps integration only. The local Vault is a
single-node, manually initialized and manually unsealed instance. It is not a
production architecture and has neither HA nor auto-unseal.

## Guardrails

- `platform-vault-local` exists only in the `local` overlay.
- The Vault root token and recovery keys are generated on the workstation by
  the bootstrap script. They are never committed, rendered by Helm or stored in
  an Argo CD Application.
- Staging and production use an external private HA Vault with KMS/HSM
  auto-unseal, audit logs and tested recovery. Their activation remains subject
  to `VAULT-SECURITY-PLANE.md`.

## Procedure

1. Push the GitOps commit and wait until `external-secrets-operator` is
   `Synced/Healthy` and `platform-vault-local` has created the `vault-0` pod.
   Vault is expected to be sealed before the next step.
2. From repository root, run:

   ```powershell
   .\scripts\bootstrap-local-vault.ps1
   ```

3. The script initializes Vault, unseals it, enables KV v2 at `kv/`, enables
   Kubernetes Auth, grants ESO read-only access to `kv/data/platform/*`, and
   refreshes the `vault-local` ClusterSecretStore.
4. Verify the control plane:

   ```powershell
   minikube kubectl -- get applications -n argocd
   minikube kubectl -- get clustersecretstore vault-local
   minikube kubectl -- get pods -n external-secrets
   minikube kubectl -- get pod vault-0 -n platform-security
   ```

## Local UI

```powershell
minikube kubectl -- port-forward -n platform-security service/vault-ui 8200:8200
```

Open `http://localhost:8200`. Retrieve the generated root token only from the
protected local recovery file created by the bootstrap script.

## Recovery

For a local restart, unseal the pod with three keys from the local recovery
file. For a clean local reset, explicitly remove the local Vault PVC and the
recovery file, then redeploy and re-run the bootstrap. Never use this procedure
for staging or production.
