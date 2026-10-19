# Argo CD control plane

The root `kustomization.yaml` is intentionally empty: it is a catalogue, never
a synchronization entry point. Select one overlay for one cluster through the
matching file in `bootstrap/`.

The directory is split by operational responsibility:

- `bootstrap/`: one app-of-apps entry Application per cluster target and the one-time secure bootstrap procedure;
- `overlays/`: exact cluster scopes (`local`, `azure-staging`, `azure-prod`); each deploys only its own environment;
- `projects/`: Argo CD tenancy boundaries for development, staging, and production;
- `applications/`: ApplicationSets for platform dependencies and deployable services;
- `secrets/`: External Secrets Operator, Azure Key Vault store, and repository-secret rotation;
- `security/`: Argo CD RBAC and retained legacy policy material;
- `config/`: optional Argo CD configuration overrides, not enabled until explicitly added to `kustomization.yaml`.

Adding a manifest to a folder does not deploy it. It becomes active only when
referenced by the selected target overlay. This prevents accidental production
changes on a development cluster.
