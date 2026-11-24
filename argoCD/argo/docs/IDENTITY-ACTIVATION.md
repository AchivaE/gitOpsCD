# Keycloak activation gate

The Keycloak application manifests are intentionally not included in the Azure
overlays. The `platform-identity` namespace and identity AppProject are already
provisioned by the Azure overlays; no Keycloak workload is created by that
fact. To activate staging or production, evidence every item in
`../../helm/platform/identity/keycloak/README.md`, then make one reviewed change:

1. Add only the matching `platform-keycloak-*` application directory to the
   environment overlay.
2. Replace every `REPLACE_WITH_*` remote key and hostname in the Keycloak
   values file, then run the GitOps validation and a staging smoke test.
3. Pin the Application to the reviewed immutable Git SHA or protected release
   tag before manually synchronizing it.

This gate prevents a chart render from creating an authentication outage when
the database, certificates or secret store are not ready.
