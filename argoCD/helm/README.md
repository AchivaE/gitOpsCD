# Helm catalogue

Ce repertoire est un catalogue de releases Helm independantes. Il ne contient
pas de chart racine : une release ne doit pas entrainer le rendu, la mise a
jour ou le rollback d'une autre.

| Plan | Repertoire | Regle de responsabilite |
| --- | --- | --- |
| Foundation | `foundation/` | Capacites Kubernetes partagees et parfois cluster-scoped. |
| Runtime | `platform/runtime/`, `platform/eventing/`, `platform/identity/`, `platform/security/` | Produits partages, avec cycle de vie et donnees propres. |
| Services | `services/` | Services techniques SpaceUP, deployes independamment. |
| Business | `workloads/` | Services autonomes soumis au contrat de deploiement. |

Un nouveau chart doit posseder une Application Argo CD explicite par
environnement, des valeurs de profil, un owner operationnel et une procedure
de rollback. Les charts ne doivent jamais embarquer un autre produit partage
(Kafka, Vault, Consul, Keycloak, base de donnees ou observabilite) comme
sous-chart applicatif.

Les modules sans chart deployable sont documentes comme des contrats : cela
evite d'afficher une capacite comme prete alors que son stockage, ses identites
ou ses dependances ne sont pas encore approuves.
