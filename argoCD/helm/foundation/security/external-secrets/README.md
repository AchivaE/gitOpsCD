# External Secrets Operator

This Foundation release owns only the External Secrets Operator and its CRDs.
It vendors the upstream `2.15.0` chart so Argo CD renders a reviewed artifact
from Git instead of fetching a chart at synchronization time.
Cloud provider identities and `ClusterSecretStore` resources are deliberately
separate provider contracts under `argo/foundation/security/external-secrets`.

The Argo Application keeps the historical name `external-secrets-operator` and
Helm release name `external-secrets`; changing its Git source therefore does
not intentionally recreate the operator.
