# Contrat Ingress Foundation

Ce repertoire definit la frontiere d'entree du cluster. Le module
`ingress-nginx` est installe uniquement dans l'overlay local pour valider les
ressources `Ingress` avec la classe explicite `nginx`. Il n'est jamais ajoute
aux overlays cloud.

Les services Azure et AWS utilisent leurs classes fournisseur distinctes
(`azure-application-gateway` sur AKS, `alb` sur EKS), leurs identites cloud et
leurs load balancers geres hors du cluster. Installer NGINX dans ces clusters
creerait un point d'entree concurrent et une exposition reseau non maitrisee.

Avant d'ajouter une Application Argo CD, valider :

- un controleur unique par classe d'Ingress (`nginx`, `alb`, ou equivalent) ;
- le mode d'exposition prive/public, les plages CIDR, WAF et journalisation ;
- les `IngressClass`, certificats et `ClusterIssuer` compatibles ;
- les annotations specifiques cloud isolees dans `values-azure.yaml` ou
  `values-aws.yaml`, jamais dans les charts de services ;
- les probes, ressources, PDB, HPA et metriques du controleur ;
- le plan de migration des DNS et certificats, puis le rollback.

L'API Gateway reste un service de plateforme. Le controleur Ingress est une
capacite Foundation : ils ont donc deux releases et deux cycles de vie
independants.

## Gate d'activation des services

L'IaC fournisseur doit creer et tester le controleur avant la promotion du
Gateway :

- AKS : Application Gateway Ingress Controller/add-on, classe
  `azure-application-gateway`, identite managée et Application Gateway prive ou
  public explicitement choisi ;
- EKS : AWS Load Balancer Controller, classe `alb`, role IRSA et sous-reseaux
  explicitement tags ;
- local : `ingress-nginx` est disponible pour des validations de routage HTTP,
  mais le Gateway reste accessible par `kubectl port-forward` tant qu'un
  hostname et une strategie TLS locaux ne sont pas explicitement adoptes.

Le chart Gateway refuse les profils exposes tant que
`ingress.controllerVerified` reste `false`. Cette valeur est une attestation de
la preuve d'installation et du test de routage TLS, pas un remplacement de
l'IaC fournisseur.
