# Catalogue Argo CD des workloads métier

Les Applications métier suivent la frontière
`workloads/<bounded-context>/<service>/<environment>`. Elles ne sont jamais
générées par découverte de répertoires : chaque environnement est un manifest
Argo CD revu et explicite.

Le contrat obligatoire est dans
[`../../../../contracts/MICROSERVICE-DEPLOYMENT-CONTRACT.md`](../../../../contracts/MICROSERVICE-DEPLOYMENT-CONTRACT.md).
