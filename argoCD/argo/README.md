# Argo CD control plane

The root `kustomization.yaml` is intentionally empty: it is a catalogue, never
a synchronization entry point. Select one overlay for one cluster through the
matching file in `bootstrap/`.

The directory is split by operational responsibility:

- `bootstrap/`: one app-of-apps entry Application per cluster target and the one-time secure bootstrap procedure;
- `overlays/`: exact cluster scopes (`local`, `azure-staging`, `azure-prod`); each deploys only its own environment;
- `projects/`: Argo CD tenancy boundaries for foundation, runtime, identity and environments;
- `applications/`: explicit independent Argo CD `Application` resources, grouped by plane;
- `foundation/`: provider-specific secret-store resources consumed by foundation modules;
- `management/`: Argo CD repository access, configuration, controller RBAC and future management-plane controls;

The distributed-service boundary, namespace model and mandatory dependency
order are defined in [`../ARCHITECTURE.md`](../ARCHITECTURE.md). In particular,
an explicit Application uses an approved catalogue path; adding a chart
directory does not authorize a workload in an environment.

Adding a manifest to a folder does not deploy it. It becomes active only when
referenced by the selected target overlay. This prevents accidental production
changes on a development cluster.
