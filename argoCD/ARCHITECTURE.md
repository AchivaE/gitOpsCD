# Architecture GitOps des microservices distribués

## But et frontière de responsabilité

Ce dépôt est le plan de déploiement, pas le dépôt de code applicatif. Argo CD
ne construit pas d'images et ne crée pas de dépendance métier implicite. Une
image publiée et une configuration promue sont les seules entrées d'un
déploiement applicatif.

Chaque cluster reçoit un seul Root Application, puis la hiérarchie suivante :

```text
Root Application (un cluster, un environnement)
├── foundation                 -20  capacités Kubernetes partagées
│   ├── External Secrets Operator
│   ├── cert-manager
│   └── observabilité
├── platform security local    -17  Vault de validation uniquement
├── platform runtime           -15  composants stateful partagés
│   └── Consul
├── configuration              -10  config-ingestor
├── edge                         0  gateway-ingestor
└── business domains             0+ services métier indépendants
```

Une vague ne remplace pas la résilience applicative : chaque client doit aussi
avoir timeout, retry borné, circuit breaker et un comportement dégradé.

## Plans de la plateforme

| Plan | Namespace | Contenu | Règle |
| --- | --- | --- | --- |
| Gestion | `argocd` | Argo CD, projets et orchestration GitOps | Ne porte aucun workload métier. |
| Fondation | `platform-system` | certificats, métriques, alertes | Installé une seule fois par cluster. |
| Runtime | `platform-runtime` | Consul, puis modules stateful dédiés | Un module Argo par produit stateful. |
| Services plateforme | `spaceup-{environment}` | Config Server, Gateway et services techniques | Indépendants des domaines métier. |
| Métier | namespace par bounded context | microservices et leurs données | Contrat de déploiement obligatoire. |

Lorsque plusieurs équipes ou niveaux de sensibilité existent, créer un
namespace par **bounded context** ou frontière de confiance (par exemple
`spaceup-ingestion`, `spaceup-finance`). Ne pas créer un namespace par Pod, ni
placer toutes les données de tous les domaines dans une base partagée.

## Règles pour un nouveau microservice

Un service n'est ajouté au catalogue Argo que lorsqu'il possède :

1. une image immuable, un owner et une frontière API ou événement claire ;
2. sa propre configuration et ses secrets à privilège minimal ;
3. une politique réseau, des probes, ressources, HPA/PDB adaptés ;
4. une stratégie de données propriétaire et un contrat de sauvegarde ;
5. métriques, traces, logs corrélés et alertes exploitables ;
6. trois Applications Argo explicites (`dev`, `staging`, `prod`) et une
   révision Git immuable pour staging/production.

Le contrat complet est dans `contracts/MICROSERVICE-DEPLOYMENT-CONTRACT.md`.
Un répertoire créé sous `helm/workloads/` ne déploie donc rien par lui-même.

## Décision Consul : disponibilité entreprise

Kubernetes DNS est le mécanisme par défaut pour les appels internes au même
cluster. Consul est réservé aux cas qui le justifient : découverte au-delà du
cluster, workloads hors Kubernetes, ou politique de service mesh explicitement
adoptée. Il ne faut pas enregistrer deux fois le même service sans définir la
source de vérité.

La décision standard est la suivante :

| Environnement | Modèle Consul | But |
| --- | --- | --- |
| local | serveur Consul dans Minikube | validation fonctionnelle, sans promesse de HA |
| staging / production | serveurs Consul externes, managés ou sur VMs dédiées | préserver le plan de découverte lors d'un incident Kubernetes |

Les applications staging/prod utilisent uniquement un endpoint HTTPS privé.
Les serveurs Consul sont répartis sur trois zones de disponibilité au minimum :
trois serveurs pour tolérer une panne, ou cinq serveurs pour tolérer deux pannes.
Ils ont leur propre stockage persistant, snapshots testés, ACL, chiffrement
gossip et certificats. L'API et l'UI ne sont jamais publiques.

Le sous-module `platform/runtime/consul` reste actif pour le développement local. Les
manifests Consul Kubernetes staging/prod sont conservés uniquement comme
alternative self-managed explicitement validée ; les overlays standards ne les
référencent pas. Les deux modèles ne doivent jamais être actifs simultanément
pour le même environnement.

## Modules de plateforme

Les composants stateful ne sont jamais activés dans le chart parapluie legacy
`helm/platform`. Chaque produit possède un sous-module dédié sous
`helm/platform/<domaine>/<produit>` et une Application dédiée : Consul aujourd'hui,
Keycloak, stockage ou broker demain. Cela permet un cycle de mise à jour, une
sauvegarde, des RTO/RPO et des droits séparés.

## Kafka : event plane externe avec validation locale contrôlée

Kafka est un plan partagé d'événements asynchrones. Le module Helm dédié
`platform/eventing/kafka` permet une validation locale KRaft à un nœud, uniquement sur
activation explicite : il ne fait pas partie de l'overlay Root Application. En
staging/production, les brokers sont un service Kafka managé, privé et
multi-zone ; Argo CD ne déploie ni brokers, ni contrôleurs KRaft, ni disques
Kafka. Les services utilisent TLS et une identité SASL/OAuth spécifique, avec
ACL par topic et consumer group.

Chaque topic est un contrat de domaine versionné, avec owner, rétention,
partitionnement, schéma, droits, stratégie de replay et DLQ. Kafka ne remplace
pas un appel HTTP simple : il est adopté lorsqu'un échange asynchrone, durable
et découplé est réellement nécessaire. Le contrat opérationnel est dans
`runbooks/KAFKA-EVENT-PLANE.md`.

## Vault : secret plane externe

Vault est un plan de sécurité, pas une dépendance Helm de workload. Le module
`platform/security/vault` existe uniquement dans l'overlay `local`, afin de
valider Kubernetes Auth et External Secrets sans exposer de token dans Git.
Pour staging et production, Vault est externe au cluster Kubernetes et hautement
disponible : service managé, ou cluster dédié avec stockage HA, auto-unseal via
KMS/HSM, TLS de bout en bout, audit logs centralisés et procédure de recovery
testée. Il n'existe donc aucune Application Argo `vault` dans les overlays
staging ou production.

Azure Key Vault ou AWS Secrets Manager peut rester le coffre de secrets
statiques utilisé par External Secrets Operator. Vault sert aux secrets
dynamiques, PKI, chiffrement transit et identités de workload. Les deux outils
ne doivent pas contenir une copie non maîtrisée du même secret.

Chaque service accède à Vault avec Kubernetes Auth et un rôle lié à son seul
ServiceAccount ; aucun `VAULT_TOKEN` ni token root n'est injecté dans Helm,
Git ou un Secret applicatif.

## Keycloak : identity plane dédié

Keycloak est un module d'identité distinct du gateway et des services métier.
La cible staging/production est :

```text
Internet / WAF / Load Balancer
              │ TLS
        Keycloak (3 replicas réparties par zone)
              │ TLS
       PostgreSQL externe HA et sauvegardé
```

Le module futur utilisera le Keycloak Operator versionné dans GitOps, ou un
chart explicitement validé. La base PostgreSQL embarquée par un chart Keycloak
est interdite hors local : les credentials, hostname, CA et paramètres de base
viennent d'External Secrets. Les pods ont anti-affinity, topology spread, PDB,
ressources explicites, probes, métriques et ingress TLS avec hostname strict.

Pour une disponibilité régionale, trois réplicas sur plusieurs zones suffisent
si la base externe satisfait le RTO/RPO. Pour tolérer la perte complète d'un
cluster, utiliser deux clusters Keycloak et un load balancer global seulement
après validation de la topologie multi-cluster et de la réplication de base.

## Observabilité distribuée

Prometheus et Alertmanager observent le cluster. Une architecture distribuée
requiert en plus, pour chaque service, des métriques applicatives Prometheus et
un trace context propagé de Gateway vers Config et les dépendances. L'activation
de ServiceMonitor reste bloquée tant que les applications n'exposent pas de
métriques réellement exploitables.
