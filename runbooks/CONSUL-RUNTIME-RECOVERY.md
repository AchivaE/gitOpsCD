# Reprise du runtime Consul

## Symptôme couvert

Le serveur Consul peut refuser de démarrer avec un message semblable à :

```text
refusing to rejoin cluster because server has been offline for more than
the configured server_rejoin_age_max
```

Ce comportement protège l'intégrité du Raft log : augmenter aveuglément la
limite de rejoin ou supprimer des fichiers de données en production n'est pas
une correction acceptable.

## Diagnostic non destructif

```powershell
minikube kubectl -- get pods,statefulset,pvc -n platform-runtime
minikube kubectl -- logs -n platform-runtime consul-server-0 --previous --tail=150
minikube kubectl -- get application platform-consul-local -n argocd
```

Vérifier d'abord l'état réseau, les certificats TLS, les Secrets Consul et le
PVC. Utiliser la procédure de reset seulement lorsque le log confirme le refus
de rejoin et lorsque l'environnement est réellement jetable.

## Local : reset contrôlé d'un datacenter jetable

Le profil `local` contient un seul serveur Consul et son PVC porte les données
de catalogue, ACL et Raft. Le reset les détruit. Ne l'exécuter que si aucune
donnée de développement ne doit être conservée.

1. Dans Argo CD, désactiver temporairement l'auto-sync de
   `platform-consul-local`, afin qu'il ne réconcilie pas le StatefulSet pendant
   l'opération.
2. Archiver, si utile, les manifestes, les logs et la liste des services avant
   le reset.
3. Vérifier une dernière fois le nom exact du StatefulSet et du PVC :

```powershell
minikube kubectl -- get statefulset,pvc -n platform-runtime
```

4. Faire valider par le responsable de l'environnement le reset du PVC
   `data-platform-runtime-consul-server-0`.
5. Une fois validé, arrêter le StatefulSet, supprimer **uniquement** ce PVC,
   puis remettre le StatefulSet à un replica :

```powershell
minikube kubectl -- scale statefulset/consul-server -n platform-runtime --replicas=0
minikube kubectl -- delete pvc data-platform-runtime-consul-server-0 -n platform-runtime
minikube kubectl -- scale statefulset/consul-server -n platform-runtime --replicas=1
minikube kubectl -- rollout status statefulset/consul-server -n platform-runtime --timeout=5m
```

> Avec le provisionneur `minikube-hostpath`, le nouveau PVC peut réutiliser le
> même répertoire hôte. Si les logs affichent encore `server_rejoin_age_max`
> après la recréation du PVC, arrêter à nouveau le StatefulSet et vider
> **uniquement** ce répertoire avant de le redémarrer :
>
> ```powershell
> minikube ssh -- sudo find `
>   /tmp/hostpath-provisioner/platform-runtime/data-platform-runtime-consul-server-0 `
>   -mindepth 1 -delete
> ```
>
> Confirmer le chemin avec le PV nouvellement créé avant cette commande. Cette
> purge détruit les mêmes données Consul locales que le reset de PVC.

Si le datacenter a aussi été réinitialisé, supprimer le Secret Kubernetes local
`consul-bootstrap-acl-token` puis relancer la synchronisation Consul. Le chart
génère un nouveau token bootstrap et ses ACL ; l'ancien token ne peut pas
autoriser le nouveau datacenter.

6. Vérifier le leader, le DNS Consul et les services dépendants, puis réactiver
   l'auto-sync de `platform-consul-local` :

```powershell
minikube kubectl -- exec -n platform-runtime consul-server-0 -- \
  consul members -ca-file=/consul/tls/ca/tls.crt
minikube kubectl -- get application platform-consul-local -n argocd
```

## Staging et production : restauration, jamais un reset implicite

Les profils standard staging/production utilisent un Consul externe ou managé.
Pour un Consul Kubernetes explicitement approuvé, arrêter toute automatisation,
déclarer l'incident, restaurer le dernier snapshot chiffré dans une fenêtre
contrôlée, puis valider le quorum, les ACL, les intentions et les services
avant de rouvrir le trafic. Une suppression de PVC exige une décision de reprise
formelle et une preuve de restauration testée.

## Critères de clôture

- Le serveur ou le quorum Consul est sain et un leader est élu.
- Les certificats et ACL sont valides ; aucun secret n'a été régénéré sans
  rotation documentée des consommateurs.
- Les Applications Argo liées sont `Synced` et `Healthy`.
- Les causes de l'indisponibilité et la décision de conservation ou reset des
  données sont consignées dans l'incident.
