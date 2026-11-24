# PostgreSQL HA externe pour Keycloak

## Décision

Keycloak utilise une base PostgreSQL **externe au cluster Kubernetes**. Aucun
chart PostgreSQL embarqué, PVC Kubernetes ou compte superuser PostgreSQL ne
peut être utilisé en staging ou production.

| Cible | Service retenu | Disponibilité minimale |
| --- | --- | --- |
| Azure | Azure Database for PostgreSQL Flexible Server | HA zone-redundant, accès privé VNet, TLS imposé |
| AWS | Amazon RDS for PostgreSQL | Multi-AZ, sous-réseaux privés, TLS imposé |

La couche IaC cloud crée ce service. Argo CD ne crée ni le serveur ni son
réseau ; il ne consomme que son DNS privé et les secrets via External Secrets.

## Contrat d'infrastructure

Avant d'activer Keycloak, l'équipe plateforme fournit :

1. une base `keycloak` et un rôle `keycloak` sans privilège superuser,
   `CREATEDB`, `CREATEROLE` ou accès aux autres bases ;
2. un endpoint privé stable, résolu depuis `platform-identity` ; aucune règle
   réseau ou pare-feu publique ;
3. TLS obligatoire avec vérification du certificat serveur et CA disponible ;
4. HA inter-zone, sauvegardes automatiques et point-in-time restore (PITR) ;
5. logs, métriques, alertes de saturation connexions, stockage, réplication,
   échec de sauvegarde et bascule HA ;
6. une protection contre suppression accidentelle au niveau fournisseur ;
7. une preuve de restauration dans un environnement isolé.

Pour Azure, sélectionner le mode zone-redundant dans une région qui possède
des availability zones. Pour AWS, sélectionner RDS PostgreSQL Multi-AZ dans
des subnets privés. Le choix exact du SKU, IOPS, rétention et RTO/RPO doit être
approuvé à partir de la charge de sessions et de la classification des données.

## Secrets attendus

Les valeurs du module `helm/platform/identity/keycloak` pointent vers ces éléments dans
le Secret Store sélectionné. Les noms ci-dessous sont des clés de coffre, pas
des valeurs sensibles :

| Contenu | Clé de coffre recommandée | Clé Kubernetes créée |
| --- | --- | --- |
| Administrateur initial | `keycloak-admin-password` | `keycloak-admin/admin-password` |
| DNS privé PostgreSQL | `keycloak-db-host` | `keycloak-db/host` |
| Port PostgreSQL | `keycloak-db-port` | `keycloak-db/port` |
| Compte DB | `keycloak-db-user` | `keycloak-db/username` |
| Base DB | `keycloak-db-name` | `keycloak-db/database` |
| Mot de passe DB | `keycloak-db-password` | `keycloak-db/password` |
| Certificat TLS interne | `keycloak-tls-crt` | `keycloak-internal-tls/tls.crt` |
| Clé TLS interne | `keycloak-tls-key` | `keycloak-internal-tls/tls.key` |
| CA PostgreSQL | `keycloak-db-ca` | `keycloak-db-ca/ca.crt` |

Le mot de passe du rôle DB n'est jamais réutilisé pour le compte administrateur
Keycloak. La rotation doit être testée en staging avant toute rotation prod.

## Validation avant activation

1. Depuis un Pod éphémère dans `platform-identity`, vérifier DNS privé et
   connexion TLS PostgreSQL avec le compte `keycloak`.
2. Vérifier que l'ExternalSecret matérialise les quatre Secrets sans erreur.
3. Rendre le chart avec les valeurs réelles : aucun `REPLACE_WITH_*` ne doit
   rester.
4. Activer seulement staging, vérifier les logs Keycloak, les métriques, login,
   logout, création de session et redémarrage d'un pod.
5. Faire un test de bascule PostgreSQL et mesurer l'interruption observée.
6. Restaurer un PITR dans un serveur/namespace isolé et documenter durée,
   données restaurées et écart RPO.
7. Après approbation, activer production via une Pull Request dédiée.

## Limite importante

La bascule HA protège d'une panne d'instance ou de zone. Elle ne protège pas
d'une suppression de realm, d'une erreur de données ou d'une mauvaise migration
Keycloak, car ces écritures peuvent être répliquées. Seul PITR/restauration
protège contre ces erreurs logiques.
