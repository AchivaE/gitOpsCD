# Initialisation sure d'Argo CD

Un cluster correspond a un seul overlay. Ne jamais appliquer deux fichiers de
bootstrap au meme cluster.

| Cible | Fichier a appliquer | Contenu deploye |
| --- | --- | --- |
| Docker Desktop, kind ou k3d | `argocd-bootstrap.yaml` | `dev` seulement, profil `local`, sans Azure Key Vault |
| AKS staging | `argocd-bootstrap-azure-staging.yaml` | socle staging ; promotions manuelles |
| AKS production | `argocd-bootstrap-azure-prod.yaml` | socle production ; promotions manuelles |

Les bootstraps Azure ne synchronisent jamais automatiquement `main`. Avant une
promotion, remplacer `spec.source.targetRevision` par le SHA Git complet ou le
tag protégé revu, puis lancer une synchronisation manuelle. Le bootstrap local
reste le seul profil qui suit automatiquement `main`.

Ne placez jamais un PAT Git, mot de passe ou Secret Kubernetes dans ce depot.
Si le depot Git est prive, creez avant le bootstrap un Secret `repository` dans
le namespace `argocd`, avec le label
`argocd.argoproj.io/secret-type: repository`, `type=git`, l'URL du depot et un
token Git de lecture seule. Il peut aussi etre ajoute avec l'interface Argo CD,
dans **Settings > Repositories**.

Sur un cluster local, appliquez uniquement :

```powershell
kubectl apply -n argocd -f argoCD/argo/bootstrap/argocd-bootstrap.yaml
```

Sur AKS, Terraform doit d'abord fournir l'identite federée et les droits Key
Vault. Renseignez ensuite uniquement ses identifiants publics et l'URL du
coffre dans
`foundation/security/external-secrets/azure/key-vault-secret-store.yaml`, puis
creez le Secret Git initial. Une fois External Secrets Operator pret,
`management/argocd/repository-access/repository-secret.yaml` prend en charge
la rotation du token depuis Key Vault. Aucun secret ni identifiant sensible ne
doit etre ajoute au depot.
