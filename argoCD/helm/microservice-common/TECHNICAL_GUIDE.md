# Microservice Common Library Chart - Guide Technique Complet

## Vue d'ensemble

Le chart `microservice-common` est une **library chart Helm de type `library`** (pas `application`) qui fournit des templates prêts à l'emploi et réutilisables pour tous les microservices de la plateforme SpaceUp.

### Principes Fondamentaux

- ✅ **Zero Implicit Behavior**: Aucune configuration implicite, tout est explicite
- ✅ **Security First**: Sécurité par défaut avec Pod Security Standards
- ✅ **Observable by Default**: Prometheus, logging, tracing intégrés
- ✅ **Production Ready**: Prêt pour production/pré-production immédiatement
- ✅ **Universality**: Fonctionne avec n'importe quel microservice sans modification
- ✅ **DRY**: Élimine ~80% de duplication entre microservices

---

## Architecture

### Structure des fichiers

```
charts/common/microservice-common/
├── Chart.yaml                          # Métadonnées (library chart, v1.0.0)
├── values.yaml                         # Configuration complète et explicite
├── values.schema.json                  # Schéma de validation JSON
├── README.md                           # Documentation utilisateur
├── TECHNICAL_GUIDE.md                  # Ce fichier - guide technique
└── templates/
    ├── _helpers.tpl                    # Helpers Helm (noms, labels, validation)
    ├── _pod.tpl                        # Pod spec réutilisable
    ├── deployment.yaml                 # Deployment (inclut _pod.tpl)
    ├── service.yaml                    # Service Kubernetes
    ├── ingress.yaml                    # Ingress pour HTTP(S)
    ├── configmap.yaml                  # ConfigMap pour configuration
    ├── serviceaccount.yaml             # ServiceAccount pour RBAC
    ├── rbac.yaml                       # Role/RoleBinding/ClusterRole
    ├── hpa.yaml                        # HorizontalPodAutoscaler
    ├── pdb.yaml                        # PodDisruptionBudget
    └── networkpolicy.yaml              # NetworkPolicy (zero-trust)
```

### Modèle d'héritage

```
Consuming Chart (auth-service)
    ├── Déclare dépendance sur microservice-common
    ├── Définit image.repository, image.tag, ingress.hostname
    ├── Remplace values.yaml au besoin
    │
    └── Inclut templates à son level
        │
        └── microservice-common.deployment
        └── microservice-common.service
        └── microservice-common.ingress
        └── etc...
        
    Résultat: Tous les templates microservice-common sont injectés
              dans le context du chart consommateur
```

---

## Comment utiliser la Library Chart

### 1. Déclarer la dépendance dans Chart.yaml du microservice

```yaml
# charts/microservices/auth-service/Chart.yaml
apiVersion: v2
name: auth-service
description: Authentication and Authorization Service
type: application
version: 1.0.0
appVersion: "2.5.0"

dependencies:
  - name: microservice-common
    version: "1.0.0"
    repository: "file://../common/microservice-common"
```

### 2. Définir la configuration spécifique au service (values.yaml)

```yaml
# charts/microservices/auth-service/values.yaml

# Image du service
image:
  repository: "ghcr.io/spaceup/auth-service"
  tag: "2.5.0"

# Configuration Ingress
ingress:
  enabled: true
  hostname: "auth-api.spaceup.local"
  path: /auth

# Variables d'environnement spécifiques
env:
  - name: SERVICE_NAME
    value: "auth-service"
  - name: LOG_LEVEL
    value: "INFO"

# Configuration de la sonde de santé (si différente de /health/*)
readinessProbe:
  httpGet:
    path: /auth/health/ready
    port: 8080
```

### 3. Inclure les templates dans les fichiers du microservice

```yaml
# charts/microservices/auth-service/templates/all.yaml
# Ce fichier inclut tous les templates de la library
{{ include "microservice-common.deployment" . }}
---
{{ include "microservice-common.service" . }}
---
{{ include "microservice-common.ingress" . }}
---
{{ include "microservice-common.configmap" . }}
---
{{ include "microservice-common.serviceAccount" . }}
---
{{ include "microservice-common.role" . }}
---
{{ include "microservice-common.rolebinding" . }}
---
{{ include "microservice-common.hpa" . }}
---
{{ include "microservice-common.podDisruptionBudget" . }}
---
{{ include "microservice-common.networkPolicy" . }}
```

Ou individuellement dans des fichiers séparés.

### 4. Déployer avec Helm/ArgoCD

```bash
# Update dependencies
cd charts/microservices/auth-service
helm dependency update

# Valider et visualiser
helm template auth-service . -f values.yaml | head -50

# Déployer via ArgoCD (aucun changement à ApplicationSet/Application.yaml)
# Les ApplicationSet.yaml existants continuent à fonctionner
```

---

## Configuration Détaillée

### Image Container (REQUIS)

```yaml
image:
  repository: "ghcr.io/spaceup/auth-service"  # OBLIGATOIRE - image du service
  tag: "2.5.0"                                 # OBLIGATOIRE - version
  pullPolicy: IfNotPresent                     # Politique d'extraction
  pullSecrets: []                              # Secrets pour registres privés
```

### Répliques et Stratégie

```yaml
replicaCount: 2                    # Replicas si HPA désactivé
strategy:
  type: RollingUpdate              # RollingUpdate | Recreate
  rollingUpdate:
    maxSurge: 1                    # Pods supplémentaires pendant update
    maxUnavailable: 0              # Pods non disponibles minimum
revisionHistoryLimit: 10           # Nombre de revisions conservées
```

### Sécurité Pod

```yaml
podSecurityContext:
  runAsNonRoot: true               # ✅ Interdit root
  runAsUser: 1000                  # ✅ User non-root
  runAsGroup: 1000
  fsGroup: 1000
  fsGroupChangePolicy: OnRootMismatch
  seccompProfile:
    type: RuntimeDefault           # ✅ Seccomp profile

securityContext:
  allowPrivilegeEscalation: false  # ✅ Interdit escalade
  readOnlyRootFilesystem: true     # ✅ Filesystem read-only
  capabilities:
    drop:
      - ALL                        # ✅ Supprime toutes les capabilities
    add: []                        # Ajouter si vraiment nécessaire
  runAsNonRoot: true
  runAsUser: 1000
```

### Service & Ingress

```yaml
service:
  type: ClusterIP                  # ClusterIP | NodePort | LoadBalancer
  port: 80                         # Port externe
  targetPort: 8080                 # Port container
  annotations: {}

ingress:
  enabled: true
  ingressClassName: "nginx"        # Ingress controller
  hostname: "auth-api.spaceup.local" # OBLIGATOIRE
  path: /                          # Prefix | Exact
  tls:
    enabled: true
    secretName: ""                 # Auto-generated si vide
```

### Probes Santé

```yaml
livenessProbe:
  enabled: true
  httpGet:
    path: /health/live             # Endpoint liveness
    port: 8080
  initialDelaySeconds: 30          # Délai avant première vérification
  periodSeconds: 10                # Interval entre vérifications
  timeoutSeconds: 5                # Timeout par vérification
  failureThreshold: 3              # Echecs avant restart

readinessProbe:
  enabled: true
  httpGet:
    path: /health/ready            # Endpoint readiness
    port: 8080
  initialDelaySeconds: 5           # Plus court pour readiness
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

### Ressources

```yaml
resources:
  requests:
    memory: "256Mi"                # Mémoire minimale
    cpu: "100m"                    # CPU minimal
    # ephemeral-storage: "1Gi"     # Storage temporaire (optionnel)
  limits:
    memory: "512Mi"                # Mémoire maximale (IMPORTANT)
    cpu: "250m"                    # CPU maximal (IMPORTANT)
    # ephemeral-storage: "2Gi"
```

### Autoscaling (HPA)

```yaml
autoscaling:
  enabled: true                    # Active HPA
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70      # Scale à 70% CPU
  targetMemoryUtilizationPercentage: 80   # Scale à 80% mémoire
  
  behavior:                        # Advanced scaling behavior
    scaleDown:
      stabilizationWindowSeconds: 300  # Attendre avant scale-down
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0      # Scale-up rapide
      policies:
        - type: Percent
          value: 100
          periodSeconds: 30
```

### Haute Disponibilité

```yaml
podDisruptionBudget:
  enabled: true
  minAvailable: 1                  # Min 1 pod disponible
  # maxUnavailable: "50%"          # OU max 50% indisponibles
  unhealthyPodEvictionPolicy: AlwaysAllow

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                  - auth-service
          topologyKey: kubernetes.io/hostname  # Spread across nodes
```

### Observabilité

```yaml
observability:
  enabled: true
  
  prometheus:
    enabled: true
    port: 8080
    path: /metrics                 # Endpoint Prometheus
    interval: "30s"
  
  tracing:
    enabled: false                 # Désactivé par défaut
    jaeger:
      agentHost: "jaeger-agent"
      agentPort: 6831
  
  logging:
    enabled: true
    level: "INFO"
    format: "json"
```

### Network Policies (Zero-Trust)

```yaml
networkPolicy:
  enabled: true
  
  # Ingress: qui peut se connecter?
  ingress:
    enabled: true
    fromIngress:
      enabled: true                # Allow Ingress controller
    fromNamespaces:
      enabled: false
    fromPods:
      enabled: false
    ports:
      - port: 8080
        protocol: TCP
  
  # Egress: à qui le service se connecte?
  egress:
    enabled: true
    toDns:
      enabled: true                # Allow DNS (essential)
    toKubernetesApi:
      enabled: true                # Allow K8s API
    toExternal:
      enabled: false
    toServices:
      enabled: false
```

---

## Helpers Disponibles

### Noms et Identifiants

| Helper | Description | Exemple |
|--------|-------------|---------|
| `microservice-common.name` | Nom du service | `auth-service` |
| `microservice-common.fullname` | Nom complet (release-service) | `release-auth-service` |
| `microservice-common.chart` | Label du chart | `auth-service-1.0.0` |
| `microservice-common.serviceAccountName` | Nom ServiceAccount | `release-auth-service` |
| `microservice-common.tlsSecretName` | Nom secret TLS | `release-auth-service-tls` |

### Labels et Sélecteurs

| Helper | Description |
|--------|-------------|
| `microservice-common.labels` | Labels standards Kubernetes (yaml multi-ligne) |
| `microservice-common.selectorLabels` | Labels sélecteur (app + instance) |
| `microservice-common.componentLabels` | Labels composant (component, part-of) |
| `microservice-common.podAnnotations` | Annotations pod (Prometheus, Consul) |

### Validation

| Helper | Description |
|--------|-------------|
| `microservice-common.validateImage` | Valide image.repository obligatoire |
| `microservice-common.validateIngress` | Valide ingress.hostname si ingress activé |
| `microservice-common.validateProbes` | Valide probes configuration |

---

## Patterns Avancés

### Init Containers (Setup/Migration)

```yaml
features:
  initContainers:
    enabled: true
    containers:
      - name: db-migrate
        image: "ghcr.io/spaceup/db-migrate:1.0"
        command:
          - /app/migrate
          - --version
        env:
          - name: DATABASE_URL
            valueFrom:
              secretKeyRef:
                name: db-credentials
                key: connection-string
```

### Sidecar Containers

```yaml
features:
  sidecars:
    enabled: true
    containers:
      - name: logging-sidecar
        image: "fluent/fluent-bit:latest"
        volumeMounts:
          - name: log-volume
            mountPath: /var/log/app
```

### ConfigMap Injection

```yaml
configMap:
  enabled: true
  data:
    application.yml: |
      server:
        port: 8080
        servlet:
          context-path: /auth
      logging:
        level: INFO
    database.yml: |
      spring:
        datasource:
          hikari:
            maximum-pool-size: 10
```

### Volumes et Mounts

```yaml
volumes:
  - name: cache
    emptyDir:
      sizeLimit: 2Gi
  - name: data
    persistentVolumeClaim:
      claimName: auth-service-pvc

volumeMounts:
  - name: cache
    mountPath: /var/cache/app
  - name: data
    mountPath: /data
```

### Affinity pour Haute Disponibilité

```yaml
# Spread across nodes
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
            - key: app.kubernetes.io/name
              operator: In
              values:
                - auth-service
        topologyKey: kubernetes.io/hostname

# Schedule to specific node types
nodeSelector:
  node-type: compute
  zone: us-east-1a

# Tolerate tainted nodes
tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "microservices"
    effect: "NoSchedule"
```

---

## Exemples Complets

### Service Simple (Minimal)

```yaml
# values.yaml minimal - seulement overrides
image:
  repository: ghcr.io/spaceup/simple-service
  tag: "1.0.0"

ingress:
  hostname: simple-api.spaceup.local
```

**Résultat**: Deployment, Service, Ingress, ServiceAccount, HPA, NetworkPolicy, PDB - tout activé et sécurisé!

### Service Complet (Full-Featured)

```yaml
# values.yaml complet
image:
  repository: ghcr.io/spaceup/complex-service
  tag: "3.2.1"

replicaCount: 3

strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 2
    maxUnavailable: 1

service:
  type: ClusterIP
  port: 80
  targetPort: 8080

ingress:
  enabled: true
  ingressClassName: nginx
  hostname: complex-api.spaceup.local
  path: /api
  tls:
    enabled: true
    certIssuer: letsencrypt-prod

resources:
  requests:
    memory: 512Mi
    cpu: 250m
  limits:
    memory: 1Gi
    cpu: 500m

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

env:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: url
  - name: LOG_LEVEL
    value: "DEBUG"

configMap:
  enabled: true
  data:
    application.yaml: |
      app:
        name: complex-service
        version: 3.2.1

features:
  initContainers:
    enabled: true
    containers:
      - name: db-init
        image: ghcr.io/spaceup/db-init:1.0
        env:
          - name: DB_HOST
            value: postgres.databases.svc.cluster.local

observability:
  prometheus:
    enabled: true
    path: /metrics
  tracing:
    enabled: true

networkPolicy:
  enabled: true
  ingress:
    enabled: true
    fromIngress:
      enabled: true
  egress:
    enabled: true
    toDns:
      enabled: true
```

---

## Backward Compatibility & Migration

### De l'ancienne structure à la library

Si vous aviez des templates individuels dans chaque microservice:

```
AVANT:
charts/
  ├── microservices/auth-service/
  │   ├── Chart.yaml
  │   ├── values.yaml
  │   └── templates/
  │       ├── deployment.yaml       ❌ À SUPPRIMER
  │       ├── service.yaml          ❌ À SUPPRIMER
  │       ├── ingress.yaml          ❌ À SUPPRIMER
  │       ├── configmap.yaml        ❌ À SUPPRIMER
  │       ├── _helpers.tpl          ❌ À SUPPRIMER
  │       └── all.yaml              ❌ À REMPLACER

APRÈS:
charts/
  ├── common/microservice-common/   ✅ Nouvelle library
  │   ├── Chart.yaml (type: library)
  │   ├── values.yaml (complet)
  │   └── templates/
  │       ├── _helpers.tpl
  │       ├── _pod.tpl
  │       ├── deployment.yaml
  │       ├── service.yaml
  │       ├── ingress.yaml
  │       ├── configmap.yaml
  │       ├── serviceaccount.yaml
  │       ├── rbac.yaml
  │       ├── hpa.yaml
  │       ├── pdb.yaml
  │       └── networkpolicy.yaml
  │
  └── microservices/auth-service/
      ├── Chart.yaml (dépendance: microservice-common)
      ├── values.yaml (overrides)
      └── templates/
          └── all.yaml ({{ include "..." . }})
```

### Validation ArgoCD

✅ **Aucun changement requis!**

```yaml
# ApplicationSet.yaml - fonctionne inchangé
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: spaceup-microservices
spec:
  generators:
    - git:
        repoURL: https://github.com/spaceup/platform
        revision: HEAD
        directories:
          - path: "charts/microservices/*"
  template:
    spec:
      source:
        repoURL: https://github.com/spaceup/platform
        path: "{{ path }}"
        helm:
          releaseName: "{{ path.basename }}"
```

Le déploiement fonctionne exactement pareil:
1. ArgoCD détecte changements dans git
2. Helm template rend tout (y compris les includes de la library)
3. Kubernetes applique les ressources

---

## Troubleshooting

### Vérifier les templates générés

```bash
# Visualiser YAML généré (sans déployer)
helm template auth-service charts/microservices/auth-service/ \
  -f charts/microservices/auth-service/values.yaml

# Vérifier un template spécifique
helm template auth-service charts/microservices/auth-service/ \
  -f charts/microservices/auth-service/values.yaml \
  | grep -A20 "kind: Deployment"
```

### Valider la chart

```bash
# Lint chart (détecte erreurs YAML, helpers invalides)
helm lint charts/microservices/auth-service/

# Valider schéma JSON values
# (Helm 3.0+ supporté via plugin)
helm plugin install https://github.com/chartmuseum/helm-json-schema-validator.git
```

### Déboguer helpers

```yaml
# Dans deployment.yaml temporairement:
metadata:
  annotations:
    DEBUG: "{{ include \"microservice-common.labels\" . }}"
```

### Erreurs courantes

| Erreur | Cause | Solution |
|--------|-------|----------|
| `Error: chart requires a version` | Chart.yaml sans version | Ajouter `version: 1.0.0` |
| `undefined variable .Values.image.repository` | Image non définie | Ajouter `image.repository` dans values.yaml |
| `failed to load: chart requirements must be a list` | Syntaxe dépendances | Vérifier indentation YAML |
| `Ingress missing hostname` | hostname non défini | Ajouter `ingress.hostname` |

---

## Performance & Optimisation

### Selector Labels
Les `selectorLabels` sont minimalistes pour performance (2 labels):
```yaml
app.kubernetes.io/name: auth-service
app.kubernetes.io/instance: release-name
```

### Resource Limits
Toujours définir requests ET limits:
- **Requests**: Réservation garantie au scheduling
- **Limits**: Plafond maximal (OOMKill si dépassé)

### HPA Behavior
Par défaut: scale-up rapide (stabilization=0), scale-down lent (stabilization=300s)
Évite thrashing lors de pics de charge.

### Network Policies
Activées par défaut mais ne bloquent que si CNI les supporte (Calico, Cilium).
Sinon, ignorées silencieusement (comportement permissif).

---

## Conformité & Certification

### Pod Security Standards (PSS)

Cette chart est conforme **"restricted"** level:

✅ Capabilities: ALL dropped
✅ Privileged: false
✅ ReadOnlyRootFilesystem: true
✅ RunAsNonRoot: true
✅ SeLinux: RuntimeDefault
✅ Seccomp: RuntimeDefault
✅ Windows: N/A (Linux only)

### CIS Kubernetes Benchmark

Respecte CIS 1.6+:
- Non-root users
- Read-only root filesystem
- Resource limits
- Network policies
- RBAC

### GDPR/Compliance

- Pas de données sensibles en ConfigMap (utiliser Secrets)
- Logs structurés JSON pour audit trails
- Encryption TLS à l'ingress

---

## Support & Versioning

### Semantic Versioning

- **MAJOR**: Breaking changes (pod spec changes incompatibles)
- **MINOR**: New features (templates, helpers)
- **PATCH**: Bug fixes

### Changelog

Voir CHANGELOG.md (à maintenir) pour chaque release.

### Contribution

Pour modifier la library:
1. Test localement avec `helm template`
2. Update version dans Chart.yaml
3. Test avec chaque microservice consommateur
4. Submit PR avec changelog

---

## Références

- Kubernetes Best Practices: https://kubernetes.io/docs/concepts/configuration/overview/
- Helm Best Practices: https://helm.sh/docs/chart_best_practices/
- Pod Security Standards: https://kubernetes.io/docs/concepts/security/pod-security-standards/
- Network Policies: https://kubernetes.io/docs/concepts/services-networking/network-policies/

---

**Document généré**: 2024-12-22
**Version Chart**: 1.0.0
**Status**: Production Ready ✅

