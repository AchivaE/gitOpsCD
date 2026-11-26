# Images privées GitHub Container Registry

Les charts `config-ingestor` et `gateway-ingestor` tirent les versions locales
depuis `ghcr.io/achivae`. Le Secret de lecture est volontairement hors Git :
un jeton GitHub ayant uniquement le droit `read:packages` ne doit jamais être
commité dans le dépôt GitOps.

Avant de synchroniser les Applications Argo CD, créer le même Secret dans
chaque namespace qui exécute une image privée :

```powershell
$ghcrUser = "AchivaE"
$ghcrToken = Read-Host "GitHub token (read:packages)" -AsSecureString
$ghcrTokenText = [System.Net.NetworkCredential]::new("", $ghcrToken).Password

minikube kubectl -- create secret docker-registry ghcr-achivae `
  --namespace spaceup-dev `
  --docker-server=ghcr.io `
  --docker-username=$ghcrUser `
  --docker-password=$ghcrTokenText `
  --dry-run=client -o yaml | minikube kubectl -- apply -f -

Remove-Variable ghcrTokenText
```

Pour staging et production, la même donnée `dockerconfigjson` doit être
stockée dans Vault ou le gestionnaire de secrets cloud, puis matérialisée par
External Secrets dans le namespace cible. Ne pas réutiliser le PAT personnel
d'un développeur en production : employer un compte de service GitHub dédié,
avec `read:packages` uniquement.

Après création du Secret et un push GitOps, Argo CD remplace les Pods par les
images référencées dans `values-local.yaml`. Vérification :

```powershell
minikube kubectl -- get pods -n spaceup-dev
minikube kubectl -- get pod -n spaceup-dev -l app.kubernetes.io/name=gateway-ingestor `
  -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,IMAGE_ID:.status.containerStatuses[0].imageID
```
