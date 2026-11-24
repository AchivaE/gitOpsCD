# Catalogue des Applications Argo CD

Les chemins Git sont classés par responsabilité ; les noms Kubernetes des
ressources `Application` restent stables afin qu'un refactor de dépôt ne recrée
pas une plateforme déjà synchronisée.

```text
applications/
├── foundation/                 # add-ons cluster-scoped : certificats, monitoring
├── platform/
│   ├── runtime/                # Consul et autres runtimes partagés
│   ├── eventing/               # Kafka, schémas et flux asynchrones
│   └── identity/               # Keycloak et identité
├── services/
│   ├── configuration/          # Config Server, par environnement
│   └── networking/             # API Gateway, par environnement
└── workloads/                  # domaines métier futurs, par bounded context
```

Les documents d'activation sont dans ce dossier. Un nouveau domaine métier
reçoit son propre sous-dossier sous `workloads/`, son AppProject lorsque sa
frontière de confiance le justifie, et ne rejoint jamais un chart de plateforme
ou de service technique.

Les environnements Azure démarrent avec un socle volontairement minimal. Leur
ordre d'activation est défini dans
[`AZURE-ENVIRONMENT-ACTIVATION.md`](AZURE-ENVIRONMENT-ACTIVATION.md).

La migration de l'ancienne Application composite `cluster-addons-*` est une
opération contrôlée décrite dans
[`runbooks/CLUSTER-ADDONS-MIGRATION.md`](../../../runbooks/CLUSTER-ADDONS-MIGRATION.md).
