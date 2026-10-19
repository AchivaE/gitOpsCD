# Initialisation sure d'Argo CD

Un cluster correspond a un seul overlay. Ne jamais appliquer deux fichiers de
bootstrap au meme cluster.

| Cible | Fichier a appliquer | Contenu deploye |
| --- | --- | --- |
| Docker Desktop, kind ou k3d | `argocd-bootstrap.yaml` | `dev` seulement, profil `local`, sans Azure Key Vault |
| AKS staging | `argocd-bootstrap-azure-staging.yaml` | staging, add-ons et Azure Key Vault |
| AKS production | `argocd-bootstrap-azure-prod.yaml` | production, add-ons et Azure Key Vault |

Ne placez jamais un PAT Git, mot de passe ou Secret Kubernetes dans ce depot.
Si le depot Git est prive, creez avant le bootstrap un Secret `repository` dans
le namespace `argocd`, avec le label
`argocd.argoproj.io/secret-type: repository`, `type=git`, l'URL du depot et un
token Git de lecture seule. Il peut aussi etre ajoute avec l'interface Argo CD,
dans **Settings > Repositories**.

Sur un cluster local, appliquez uniquement :

```powershell
kubectl apply -n argocd -f gitOpsCD/argoCD/argo/bootstrap/argocd-bootstrap.yaml
```

Sur AKS, renseignez d'abord les identifiants Azure et l'URL Key Vault dans
`secrets/key-vault-secret-store.yaml`, puis creez le Secret Git initial. Une
fois External Secrets Operator pret,
`secrets/argocd-repository-secret.yaml` prend en charge la rotation du token
depuis Key Vault.
