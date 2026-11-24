# PostgreSQL externe HA

Ce repertoire est un contrat de produit externe, volontairement sans
`Chart.yaml` ni Application Argo CD. Installer PostgreSQL par Helm dans le
cluster pour staging ou production couplerait les donnees a l'incident du
cluster, au CSI et au cycle de mise a jour Kubernetes.

## Responsabilites

| Domaine | Responsable |
| --- | --- |
| Instance PostgreSQL, HA, reseau prive, sauvegardes et PITR | IaC / data platform |
| Base, role a privilege minimal et classification | owner du produit consommateur |
| DNS prive, CA et secret de connexion | data platform + External Secrets |
| Deployment Keycloak ou autre consommateur | Argo CD |
| Test de restauration et preuve RPO/RTO | owner data + exploitation |

Le premier consommateur est Keycloak. Son contrat complet, les cles de coffre
attendues et le protocole PITR sont definis dans
[`../../../../../runbooks/POSTGRESQL-KEYCLOAK.md`](../../../../../runbooks/POSTGRESQL-KEYCLOAK.md).

## Conditions minimales de consommation

- endpoint prive resolvable uniquement depuis les reseaux autorises ;
- TLS avec verification de la CA, jamais `sslmode=disable` ;
- role distinct par produit, sans superuser, `CREATEDB` ni `CREATEROLE` ;
- sauvegarde automatique, PITR, protection contre suppression et restauration
  isolee testee ;
- metriques, alertes de disponibilite, stockage, connexions et echec de backup ;
- secret injecte par External Secrets, jamais dans `values.yaml` ou Git.

Un chart PostgreSQL local peut etre cree plus tard sous un repertoire
explicitement `local/` pour des tests isoles. Il ne doit jamais etre promu par
copie vers staging ou production.
