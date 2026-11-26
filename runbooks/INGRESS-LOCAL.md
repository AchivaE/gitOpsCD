# Ingress Controller local

`foundation-ingress-nginx-local` fournit l'IngressClass `nginx` seulement pour
Minikube. Il ne rend aucun service SpaceUp accessible de lui-meme.

## Validation apres synchronisation Argo CD

```powershell
minikube kubectl -- get application foundation-ingress-nginx-local -n argocd
minikube kubectl -- get pods -n ingress-nginx
minikube kubectl -- get ingressclass nginx
minikube service -n ingress-nginx ingress-nginx-controller --url
```

L'Application, le Pod controller et l'IngressClass doivent etre sains avant
d'activer une route applicative.

## Acces local

Le service controller est un `NodePort`. La commande `minikube service --url`
retourne son URL locale. Les Ingress utilisent explicitement :

```yaml
spec:
  ingressClassName: nginx
```

Ne definissez pas `nginx` comme classe par defaut : un Ingress sans classe ne
doit pas etre expose accidentellement.

## TLS

Le certificat public ACME n'est pas active pour un hostname Minikube local.
Pour des validations HTTPS locales, utilisez un CA de developpement explicite
(par exemple `mkcert`) et un Secret TLS cree hors Git, ou conservez le
`port-forward`. Les certificats d'environnement restent geres par
cert-manager et le controleur Azure/AWS retenu pour le cluster cible.
