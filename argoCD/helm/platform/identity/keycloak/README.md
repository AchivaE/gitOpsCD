# Keycloak platform module contract

This directory owns the dedicated Keycloak module. Its Argo CD Application and
AppProject are prepared, but deliberately not referenced by the standard Azure
overlays: deploying identity before its database, DNS, certificate, admin
bootstrap secret and recovery plan exist would create a fragile authentication
control plane.

## Required before activation

1. A PostgreSQL service external to Kubernetes with HA, TLS, backups and a
   documented restore test. The embedded PostgreSQL dependency from the legacy
   umbrella chart is forbidden for staging and production.
2. A private database DNS name and CA, plus a least-privilege `keycloak` DB
   account, delivered with External Secrets.
3. A public identity hostname through the approved WAF/load balancer, TLS
   certificate and strict hostname configuration. The management endpoint must
   remain private.
4. Three Keycloak replicas in production across availability zones, with
   anti-affinity, topology spread and a PodDisruptionBudget. Staging may use
   two replicas only when its availability objective permits it.
5. Realm/client configuration imported as reviewed configuration, never by
   storing an administrator password in Git.
6. Prometheus metrics, audit-event export, OpenTelemetry traces and tested
   login/logout recovery during a rolling update.

The module is activated by adding its dedicated Application to the selected
environment overlay only after these preconditions are evidenced.

The full database and restore contract is in
[`../../../../runbooks/POSTGRESQL-KEYCLOAK.md`](../../../../runbooks/POSTGRESQL-KEYCLOAK.md).
