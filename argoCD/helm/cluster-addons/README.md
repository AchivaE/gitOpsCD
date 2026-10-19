# Cluster add-ons

This chart is intentionally deployed once to `platform-system`, never once per application namespace.

It owns the Prometheus Operator, Prometheus, Grafana and cert-manager. Application charts may create `ServiceMonitor` and `PrometheusRule` resources; Prometheus is configured to discover both across namespaces.

Before production sync, add `spaceup-cluster-grafana-admin-user` and `spaceup-cluster-grafana-admin-password` to the provider-selected secret store. External Secrets Operator materializes them as `grafana-admin` in `platform-system`; no default Grafana password is accepted.

Add `spaceup-cluster-alertmanager-config` to that secret store as a complete, valid `alertmanager.yaml`. It must contain the approved on-call receiver (Teams, e-mail, PagerDuty, etc.) and routing policy. External Secrets Operator materializes it as `alertmanager-config`; the chart deliberately does not fall back to Alertmanager's `null` receiver.

The chart also installs platform alerts for External Secrets Operator, cert-manager,
certificate expiry, and PVC capacity. Response actions and the alert-routing
acceptance test are in `../../../runbooks/OBSERVABILITY.md`.

## Public certificates

This chart creates `letsencrypt-staging` and `letsencrypt-prod` ClusterIssuers when the selected provider profile enables them. cert-manager stores each ACME account key in `platform-system`.

Before syncing production, verify that each public gateway hostname resolves to the selected public ingress controller and that TCP port 80 is reachable by Let's Encrypt. If the gateway is private, HTTP-01 cannot work: keep `letsencrypt-prod` unsynchronized and implement a DNS-01 issuer instead.
## Namespace ownership and project boundary

This chart owns only cluster-wide platform concerns. It creates the three
application namespaces (`spaceup-dev`, `spaceup-staging`, `spaceup`) once and
labels them with the Kubernetes `restricted` Pod Security Standard. Service
ApplicationSets must not create namespaces implicitly.

External Secrets Operator runs in the `spaceup-cluster-addons` AppProject, not
the unconstrained Argo CD `default` project. The project permits only its
explicit Git and chart repositories.

