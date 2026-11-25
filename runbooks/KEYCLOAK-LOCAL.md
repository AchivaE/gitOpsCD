# Keycloak local bootstrap

The local Keycloak profile is isolated from staging and production: one
Keycloak replica, a persistent in-cluster PostgreSQL database and no public
Ingress. Credentials are never stored in Git.

The vendored Keycloak chart uses image versions that Bitnami moved to its
Legacy registry. This exception is confined to local development. Staging and
production must use a reviewed, maintained image supply chain before activation.

After Argo CD has synchronized `argocd-bootstrap-local`, create local-only
credentials in Minikube:

```powershell
.\scripts\bootstrap-local-keycloak.ps1
```

Then synchronize `platform-keycloak-local` manually in Argo CD. Manual sync is
intentional: a fresh clone cannot safely invent authentication credentials.

When healthy, access Keycloak locally:

```powershell
minikube kubectl -- port-forward -n platform-identity service/platform-keycloak-local 8081:80
```

Open `http://localhost:8081` and sign in with `platform-admin` and the password
entered during bootstrap. Do not reuse it outside Minikube.
