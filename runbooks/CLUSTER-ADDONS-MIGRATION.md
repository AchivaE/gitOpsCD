# Migration de l'ancienne release `cluster-addons`

## Règle de sécurité

La scission vers `foundation-cert-manager-*` et `platform-monitoring-*` est une
**migration de propriété Argo CD**, pas une mise à jour Helm ordinaire. Les
nouvelles Applications ont volontairement de nouveaux noms de release. Elles
ne doivent pas adopter des ressources suivies par `cluster-addons-*`.

Ne poussez pas le refactor avant d'avoir exécuté et archivé les vérifications
ci-dessous pour le cluster concerné. Cette procédure est à répéter par
environnement.

## Pré-vol obligatoire

```powershell
# Inventaire cert-manager
kubectl get crd | Select-String cert-manager.io
kubectl get clusterissuer
kubectl get certificate -A
kubectl get certificaterequest -A
kubectl get secret -A -l controller.cert-manager.io/fao=true

# Inventaire monitoring et stockage
kubectl get statefulset,pvc,pv -A | Select-String "prometheus|grafana|cluster-addons"
kubectl get application cluster-addons-local -n argocd -o yaml
```

Avant la migration, exporter la configuration Grafana et exécuter un snapshot
CSI ou une sauvegarde Velero des PVC Prometheus/Grafana. Documenter leurs noms,
StorageClass, taille et politique de rétention.

## Bascule contrôlée

1. Désactiver l'auto-sync de la **Root Application**
   `argocd-bootstrap-local` dans l'interface Argo CD. Cette étape est
   indispensable : sans elle, Argo peut recréer l'ancienne Application entre
   son orphelinage et l'arrivée du commit de transition.
2. Désactiver également l'auto-sync de `cluster-addons-local`.
3. Vérifier que les nouveaux charts rendent correctement avec les mêmes
   valeurs d'environnement : `validate-local.ps1` et `kubectl kustomize`.
4. Orpheliner l'ancienne Application **avant le push**. Ne jamais supprimer
   les CRD cert-manager pendant cette étape. Si l'interface ou le CLI Argo CD
   est disponible, préférer :

```powershell
argocd app delete cluster-addons-local --cascade=orphan
```

   Si seul `minikube kubectl` est disponible, retirer explicitement le
   finalizer Argo CD, puis supprimer uniquement l'objet `Application` :

```powershell
minikube kubectl -- patch application cluster-addons-local -n argocd `
  --type=merge --patch '{\"metadata\":{\"finalizers\":[]}}'
minikube kubectl -- delete application cluster-addons-local -n argocd --wait=true
```

   Confirmer que l'Application a disparu, mais que les ressources cert-manager
   et monitoring inventoriées au pré-vol existent toujours.
5. Pousser le commit de transition, puis synchroniser **manuellement**
   `argocd-bootstrap-local`. Les nouvelles Applications locales sont créées,
   mais leur synchronisation automatique est volontairement désactivée.
   Confirmer l'annotation `platform.spaceup.io/migration-mode:
   manual-sync-required` sur `foundation-cert-manager-local` et
   `platform-monitoring-local`.
6. Synchroniser d'abord `foundation-cert-manager-local`, vérifier CRD,
   webhooks cert-manager, ClusterIssuers et certificats, puis synchroniser
   `platform-monitoring-local` et vérifier les targets Prometheus, alertes et
   l'accès Grafana.
7. Dans un **second commit**, réactiver `automated.prune` et `selfHeal` sur les
   deux nouvelles Applications. Réactiver ensuite l'auto-sync de la Root
   Application (ou réappliquer son manifest de bootstrap). Confirmer que les
   nouveaux objets sont suivis par ces Applications et seulement ensuite
   supprimer les PVC/PV historiques non retenus par la politique de sauvegarde.

## Données monitoring

La migration par défaut crée un nouveau Prometheus et un nouveau Grafana : elle
ne promet aucune reprise automatique de PVC. Une reprise de données exige une
restauration testée dans une fenêtre distincte ; ne modifiez pas les noms de
release ou les sélecteurs Helm pour forcer l'adoption d'un PVC existant.

## Rollback

Si les nouvelles Applications sont dégradées, arrêter leur auto-sync, supprimer
uniquement leurs ressources non persistantes, puis restaurer l'ancienne
Application depuis la révision Git précédente. Les CRD, certificats, Secrets
TLS et PVC ne sont restaurés qu'avec la procédure et les preuves de sauvegarde
appropriées.
