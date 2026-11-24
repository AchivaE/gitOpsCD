# Contrat de déploiement d'un microservice SpaceUP

Ce contrat est le seuil d'admission d'un service dans le **Business Plane**.
Il ne s'applique pas aux composants de fondation, de plateforme, ni aux
services techniques `config-server` et `api-gateway`.

Un service ne devient pas une Application Argo CD parce qu'un dossier existe :
son owner doit fournir les preuves ci-dessous et une Application explicite par
environnement doit être revue.

## Frontière Git obligatoire

```text
argoCD/
├── helm/workloads/<bounded-context>/<service>/
│   ├── Chart.yaml
│   ├── service-contract.yaml
│   ├── values.yaml
│   ├── values-local.yaml
│   ├── values-staging.yaml
│   └── values-prod.yaml
└── argo/applications/workloads/<bounded-context>/<service>/
    ├── dev/application.yaml
    ├── staging/application.yaml
    └── prod/application.yaml
```

Chaque fichier `application.yaml` est une ressource Argo `Application`
indépendante. Les charts métier ne doivent pas inclure Kafka, Vault, Consul,
Keycloak, PostgreSQL, Redis, cert-manager ou Prometheus comme sous-charts.
Les produits partagés sont consommés via leur endpoint, leur identité et des
contrats explicites.

## Preuves d'admission obligatoires

| Domaine | Exigence non négociable |
| --- | --- |
| Ownership | bounded context, équipe owner, niveau de données, API ou événement owner dans `service-contract.yaml` |
| Image | registre approuvé, tag immuable ; staging/prod référencent un digest `sha256:` ou une révision d'image attestée |
| Configuration | valeurs non secrètes externalisées ; aucun secret, token, mot de passe ou clé privée dans Git/Helm |
| Identité | ServiceAccount dédiée ; RBAC namespace-scoped et seulement si nécessaire |
| Réseau | NetworkPolicy ingress/egress explicitement limitée à DNS et aux dépendances déclarées |
| Disponibilité | startup, readiness et liveness probes ; requests/limits ; PDB/HPA selon l'objectif de disponibilité |
| Observabilité | logs structurés, métriques Prometheus réelles, traces corrélées et alertes exploitables |
| Données | propriétaire de la base/cache/topic, classification, sauvegarde, RPO/RTO, migration et politique de rétention |
| Contrat distribué | OpenAPI/AsyncAPI ou contrat d'événement versionné ; idempotence, replay et DLQ si asynchrone |
| Rollback | compatibilité descendante, point de non-retour, commande/procédure de retour et validation post-rollback |

## Contrôles mécaniques

Le prévol vérifie pour tout chart métier admis : `ServiceAccount`, `Deployment`,
`Service`, `NetworkPolicy`, probes startup/readiness/liveness et ressources
dans le rendu local ; un digest OCI dans les rendus staging et production ; et
l'absence de manifeste Kubernetes `Secret` créé par le chart. Les Secrets
viennent d'External Secrets ou sont préexistants, jamais de valeurs Helm.

## `service-contract.yaml`

Ce fichier est obligatoire dans le chart. Les valeurs réelles sont fournies par
l'équipe propriétaire ; les exemples ci-dessous sont des champs contractuels,
pas un service fictif à déployer.

```yaml
apiVersion: spaceup.io/v1alpha1
kind: WorkloadContract
metadata:
  name: <service>
spec:
  domain: <bounded-context>
  owner: <team-or-email-alias>
  exposure: internal # internal | edge | asynchronous
  interfaceContract: <openapi-or-asyncapi-location>
  image:
    immutable: true
  data:
    owner: <service>
    classification: <public|internal|confidential|restricted>
    rpo: <approved-rpo>
    rto: <approved-rto>
    migration: <location-or-not-applicable>
  dependencies:
    - name: <dependency>
      purpose: <reason>
      protocol: <https|kafka|postgresql|...>
  rollback:
    procedure: <runbook-location>
    compatibility: <backward-compatible|coordinated>
```

## Révision Git et promotion

`dev` peut suivre `main`. Une Application `staging` ou `prod` doit référencer
une révision Git immuable : SHA complet ou tag de release protégé. `main`, une
branche mutable et `HEAD` sont interdits pour ces deux environnements.

## Admission et suppression

1. Exécuter `pipelines/gitops/validate-workload-contract.ps1`.
2. Rendre le chart avec Helm et tous ses profils.
3. Faire relire le contrat par l'owner domaine, plateforme, sécurité et data.
4. Ajouter les trois Applications explicitement aux overlays concernés.
5. Une suppression passe par un changement Argo revu, un plan de conservation
   des données et une désactivation explicite des producteurs/consommateurs.
