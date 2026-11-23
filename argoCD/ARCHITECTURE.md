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
│   ├── cert-manager
│   └── observabilité
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
| Gestion | `argocd` | Argo CD, projets, ApplicationSets | Ne porte aucun workload métier. |
| Fondation | `platform-system` | certificats, métriques, alertes | Installé une seule fois par cluster. |
| Runtime | `platform-runtime` | Consul, puis modules stateful dédiés | Un module Argo par produit stateful. |
| Workloads | `spaceup-{environment}` | services métier et edge | Aucun composant cluster-scoped. |

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
6. une entrée explicitement revue dans chaque ApplicationSet d'environnement.

Un répertoire créé sous `helm/services/` ne déploie donc rien par lui-même.

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

Le sous-module `platform/consul` reste actif pour le développement local. Les
manifests Consul Kubernetes staging/prod sont conservés uniquement comme
alternative self-managed explicitement validée ; les overlays standards ne les
référencent pas. Les deux modèles ne doivent jamais être actifs simultanément
pour le même environnement.

## Modules de plateforme

Les composants stateful ne sont jamais activés dans le chart parapluie legacy
`helm/platform`. Chaque produit possède un sous-module dédié sous
`helm/platform/<produit>` et une Application dédiée : Consul aujourd'hui,
Keycloak, stockage ou broker demain. Cela permet un cycle de mise à jour, une
sauvegarde, des RTO/RPO et des droits séparés.

## Observabilité distribuée

Prometheus et Alertmanager observent le cluster. Une architecture distribuée
requiert en plus, pour chaque service, des métriques applicatives Prometheus et
un trace context propagé de Gateway vers Config et les dépendances. L'activation
de ServiceMonitor reste bloquée tant que les applications n'exposent pas de
métriques réellement exploitables.
