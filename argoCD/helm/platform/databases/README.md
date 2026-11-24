# Data products platform

Les bases de donnees partagees sont des produits de donnees, pas des
sous-charts des applications. Une base est ajoutee uniquement lorsqu'un owner,
une classification de donnees, un RPO/RTO et une strategie de restauration sont
approuves.

Les services cloud managés sont la cible standard de staging et production.
Argo CD ne cree pas leurs instances, reseaux, pare-feu, sauvegardes ni
identites cloud : cette responsabilite appartient a l'IaC et a l'equipe data
platform. Argo CD deploye seulement les consommateurs Kubernetes et leurs
ExternalSecrets.

| Produit | Etat | Mode standard staging/production |
| --- | --- | --- |
| PostgreSQL | contrat actif pour Keycloak | Azure Database for PostgreSQL Flexible Server ou Amazon RDS PostgreSQL, endpoint prive et HA inter-zone |
| Redis | non provisionne | ajouter seulement apres un besoin explicite de cache, session ou verrou distribue |

Ne pas utiliser une base partagee entre bounded contexts. Chaque base, schema,
compte applicatif et politique de retention possede un owner explicite.
