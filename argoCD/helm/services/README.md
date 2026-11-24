# Services techniques

Les services techniques de la plateforme ne sont ni des composants
cluster-scoped, ni des services métier. Chaque chart conserve son propre cycle
de version, son Application Argo CD par environnement et son rollback ciblé.

```text
services/
├── configuration/config-server/  # config-ingestor
└── networking/api-gateway/       # gateway-ingestor
```

Les domaines métier futurs vont sous `helm/workloads/<bounded-context>/`.
Ils ne doivent pas devenir des dépendances Helm du Gateway ou du Config Server.

Les contrats propres à ces deux services sont `DEPLOYMENT-CONTRACT.md`,
`RUNTIME-DEPENDENCIES.md` et `PORTABILITY.md`. Le contrat des futurs services
métier est distinct :
[`../contracts/MICROSERVICE-DEPLOYMENT-CONTRACT.md`](../contracts/MICROSERVICE-DEPLOYMENT-CONTRACT.md).
