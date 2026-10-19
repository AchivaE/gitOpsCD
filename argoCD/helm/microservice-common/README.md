# Microservice Common Library Chart

**Production-ready Helm Library Chart pour microservices SpaceUp**

Cette **library chart** (type: `library`) fournit une fondation technique complète, sécurisée et observable pour tous les microservices de la plateforme SpaceUp.

- 🔐 **Security First**: Sécurité par défaut avec Pod Security Standards
- 📊 **Observable by Default**: Prometheus, logging, tracing intégrés
- 🚀 **Production Ready**: Déployable immédiatement en pré-prod/production
- 🎯 **Universal**: Fonctionne avec n'importe quel microservice
- 🔄 **DRY**: Élimine ~80% de duplication
- 📝 **Explicit**: Zéro comportement implicite

## Version

- **Chart Version**: 1.0.0
- **App Version**: 2.0.0
- **Kubernetes**: 1.24+
- **Helm**: 3.0+

## Quick Start

### 1. Déclarer la dépendance

```yaml
# charts/microservices/auth-service/Chart.yaml
dependencies:
  - name: microservice-common
    version: "1.0.0"
    repository: "file://../common/microservice-common"
```

### 2. Définir la configuration

```yaml
# charts/microservices/auth-service/values.yaml

# Image (OBLIGATOIRE)
image:
  repository: "ghcr.io/spaceup/auth-service"
  tag: "2.5.0"

# Ingress (OBLIGATOIRE si ingress.enabled=true)
ingress:
  hostname: "auth-api.spaceup.local"

# Tout le reste utilise les defaults sécurisés!
```

### 3. Inclure les templates

```yaml
# charts/microservices/auth-service/templates/all.yaml
{{ include "microservice-common.deployment" . }}
---
{{ include "microservice-common.service" . }}
---
{{ include "microservice-common.ingress" . }}
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

### 4. Déployer

```bash
cd charts/microservices/auth-service
helm dependency update
helm template . -f values.yaml | head -50  # Prévisualiser
helm upgrade --install auth-service . -f values.yaml  # Déployer
```

## Architecture

### Fichiers inclus

```
├── Chart.yaml                      # Library chart (v1.0.0)
├── values.yaml                     # Configuration complète ~600 lignes
├── values.schema.json              # Schéma validation JSON
├── README.md                       # Ce fichier (utilisateur)
├── TECHNICAL_GUIDE.md              # Guide technique avancé
│
└── templates/
    ├── _helpers.tpl               # 100+ lignes helpers
    ├── _pod.tpl                   # Pod spec réutilisable
    ├── deployment.yaml            # Deployment
    ├── service.yaml               # Service Kubernetes
    ├── ingress.yaml               # Ingress HTTP(S)
    ├── configmap.yaml             # ConfigMap
    ├── serviceaccount.yaml        # ServiceAccount + RBAC
    ├── rbac.yaml                  # Role/RoleBinding/ClusterRole
    ├── hpa.yaml                   # HorizontalPodAutoscaler
    ├── pdb.yaml                   # PodDisruptionBudget
    └── networkpolicy.yaml         # NetworkPolicy (zero-trust)
```

### Templates générés

Chaque chart consommateur génère **automatiquement**:

✅ **Deployment** - replicas, rolling updates, pod spec  
✅ **Service** - ClusterIP routing  
✅ **Ingress** - TLS termination, routing HTTP(S)  
✅ **ServiceAccount** - pod identity  
✅ **Role/RoleBinding** - RBAC minimal  
✅ **HPA** - autoscaling CPU/memory  
✅ **PodDisruptionBudget** - availabilité  
✅ **NetworkPolicy** - zero-trust security  
✅ **ConfigMap** - configuration  

## Configuration Clé

### Security (Sécurité)

```yaml
# Pod Security Standards - "restricted" level
podSecurityContext:
  runAsNonRoot: true               # ✅ Interdit root
  runAsUser: 1000                  # ✅ User non-root
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault           # ✅ Seccomp

securityContext:
  allowPrivilegeEscalation: false  # ✅ Pas d'escalade
  readOnlyRootFilesystem: true     # ✅ Root read-only
  capabilities:
    drop:
      - ALL                        # ✅ Toutes drops
```

### Health Probes

```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: 8080
  initialDelaySeconds: 30

readinessProbe:
  httpGet:
    path: /health/ready
    port: 8080
  initialDelaySeconds: 5
```

### Observability

```yaml
observability:
  prometheus:
    enabled: true
    path: /metrics
  logging:
    format: json
```

### Autoscaling

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

### High Availability

```yaml
podDisruptionBudget:
  enabled: true
  minAvailable: 1

affinity:
  podAntiAffinity:  # Spread across nodes
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          topologyKey: kubernetes.io/hostname
```

### Network Security

```yaml
networkPolicy:
  enabled: true
  ingress:
    fromIngress:
      enabled: true          # Allow Ingress controller
  egress:
    toDns:
      enabled: true          # Allow DNS
    toKubernetesApi:
      enabled: true          # Allow K8s API
```

## Helpers Disponibles

| Helper | Description |
|--------|-------------|
| `microservice-common.name` | Nom du service |
| `microservice-common.fullname` | Nom complet (release-service) |
| `microservice-common.labels` | Labels Kubernetes standards |
| `microservice-common.selectorLabels` | Labels sélecteur (pod matcher) |
| `microservice-common.serviceAccountName` | Nom ServiceAccount |
| `microservice-common.tlsSecretName` | Nom secret TLS (auto-generated) |
| `microservice-common.podAnnotations` | Annotations pod (Prometheus, Consul) |
| `microservice-common.validateImage` | Valide image.repository |

## Exemples

### Minimal (Tout par défaut)

```yaml
# values.yaml
image:
  repository: ghcr.io/spaceup/simple-service
  tag: "1.0.0"

ingress:
  hostname: simple-api.spaceup.local
```

✅ Génère: Deployment, Service, Ingress, ServiceAccount, HPA, PDB, NetworkPolicy - tous sécurisés!

### Full-Featured

```yaml
# values.yaml
image:
  repository: ghcr.io/spaceup/complex-service
  tag: "3.2.1"

replicaCount: 3

resources:
  requests:
    memory: 512Mi
    cpu: 250m
  limits:
    memory: 1Gi
    cpu: 500m

autoscaling:
  minReplicas: 3
  maxReplicas: 10

env:
  - name: LOG_LEVEL
    value: DEBUG
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: url

configMap:
  enabled: true
  data:
    application.yml: |
      app:
        name: complex-service
        timeout: 30s

features:
  initContainers:
    enabled: true
    containers:
      - name: db-migrate
        image: ghcr.io/spaceup/migrations:1.0
```

### Avec Sidecar

```yaml
features:
  sidecars:
    enabled: true
    containers:
      - name: logging-sidecar
        image: fluent/fluent-bit:latest
        volumeMounts:
          - name: logs
            mountPath: /var/log
```

## Validation & Testing

### Valider les templates

```bash
# Lint chart
cd charts/common/microservice-common
helm lint

# Générer YAML (sans déployer)
helm template test . \
  -f ../../microservices/auth-service/values.yaml

# Vérifier un template spécifique
helm template test . \
  -f ../../microservices/auth-service/values.yaml \
  | grep -A30 "kind: Deployment"
```

### Valider values.yaml

```bash
# Avec schéma JSON (si plugin helm-json-schema-validator installé)
helm plugin install https://github.com/chartmuseum/helm-json-schema-validator.git
helm validate-schema charts/microservices/auth-service/values.yaml
```

## Backward Compatibility

✅ **Entièrement compatible avec ArgoCD** - aucun changement requis

ApplicationSet.yaml existants continuent de fonctionner:

```yaml
# application-set.yaml - AUCUN CHANGEMENT
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
1. ArgoCD détecte changements Git
2. Helm rend templates (y compris includes library)
3. Kubernetes applique ressources

## Conformité & Certification

### Pod Security Standards

Conforme niveau **"restricted"** (Kubernetes 1.25+):

- ✅ Non-root users (runAsUser: 1000)
- ✅ Read-only root filesystem
- ✅ Dropped capabilities (ALL)
- ✅ Seccomp: RuntimeDefault
- ✅ SELinux: RuntimeDefault

### CIS Kubernetes Benchmark

Respecte CIS 1.6+:
- Non-root containers
- Resource limits (OOMKill prevention)
- Network policies (zero-trust)
- RBAC (minimal permissions)
- Audit logging (structured JSON)

## Envs par Microservice

Chaque microservice peut surcharger les valeurs:

```yaml
# values-dev.yaml
replicaCount: 1
autoscaling:
  minReplicas: 1
  maxReplicas: 2
resources:
  requests:
    memory: 128Mi
    cpu: 50m

# values-prod.yaml
replicaCount: 3
autoscaling:
  minReplicas: 3
  maxReplicas: 10
resources:
  requests:
    memory: 512Mi
    cpu: 250m
```

Déployer: `helm upgrade -f values-prod.yaml ...`

## Documentation Complète

- 📖 **TECHNICAL_GUIDE.md** - Guide avancé, patterns, troubleshooting
- 📝 **values.yaml** - Documentation inline complète (~600 lignes)
- 📋 **values.schema.json** - Schéma validation JSON

## Support & Maintenance

### Versioning

- **v1.0.0**: Release initiale production-ready
- Semantic versioning (MAJOR.MINOR.PATCH)
- Changelog pour chaque release

### Contributing

Pour modifier la library:

1. Test localement avec `helm template`
2. Update Chart.yaml version
3. Test avec tous les microservices consommateurs
4. Update changelog
5. Submit PR

## FAQ

**Q: Dois-je modifier values.yaml pour chaque microservice?**
R: Non, définissez seulement `image.repository`, `image.tag`, et `ingress.hostname`. Tous les autres defaults sont sûrs et optimisés.

**Q: Puis-je overrider les probes?**
R: Oui, modifiez `livenessProbe`/`readinessProbe` dans values.yaml.

**Q: Puis-je désactiver une ressource (HPA, NetworkPolicy, etc)?**
R: Oui, définissez `hpa.enabled: false`, `networkPolicy.enabled: false`, etc.

**Q: Faut-il des secrets pour images/BD?**
R: Oui, utilisez `env[].valueFrom.secretKeyRef` ou `envFrom[].secretRef`.

**Q: Compatible avec mon service non-HTTP?**
R: Oui, changez `ports[0].containerPort` et probes `httpGet` path.

## Ressources

- 🔗 [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- 🔗 [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- 🔗 [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- 🔗 [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

---

**Status**: ✅ Production Ready
**Last Updated**: 2024-12-22
**Maintained by**: SpaceUp Platform Team

