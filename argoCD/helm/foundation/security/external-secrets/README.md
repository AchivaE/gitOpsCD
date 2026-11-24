# External Secrets Operator

This Foundation release owns only the External Secrets Operator and its CRDs.
Cloud provider identities and `ClusterSecretStore` resources are deliberately
separate provider contracts under `argo/foundation/security/external-secrets`.

The Argo Application keeps the historical name `external-secrets-operator` and
Helm release name `external-secrets`; changing its Git source therefore does
not intentionally recreate the operator.
