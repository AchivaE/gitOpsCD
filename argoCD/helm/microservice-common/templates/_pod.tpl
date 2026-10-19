{{/*
============================================================================
  POD SPECIFICATION TEMPLATE
  ============================================================================
  Reusable pod template spec used by Deployment and other workload resources.
  Defines all container configuration, probes, volumes, security, affinity.
============================================================================
*/}}

{{ define "microservice-common.podSpec" -}}
spec:
  {{/*
  Pod-level security context (applies to all containers)
  */}}
  {{- with .Values.podSecurityContext }}
  securityContext:
    {{ toYaml . | nindent 4 }}
  {{- end }}

  {{/*
  Service account binding
  */}}
  serviceAccountName: {{ include "microservice-common.serviceAccountName" . | trim }}

  {{/*
  Pod restart policy
  */}}
  restartPolicy: Always

  {{/*
  DNS policy (ClusterFirst ensures service discovery works)
  */}}
  dnsPolicy: ClusterFirst

  {{/*
  Enable sharing of network namespace (required for service mesh sidecar injection)
  */}}
  shareProcessNamespace: false

  {{/*
  Hostname and subdomain
  */}}
  {{- if .Values.hostname }}
  hostname: {{ .Values.hostname }}
  {{- end }}
  {{- if .Values.subdomain }}
  subdomain: {{ .Values.subdomain }}
  {{- end }}

  {{/*
  Grace period for termination (allow cleanups)
  */}}
  terminationGracePeriodSeconds: 30

  {{/*
  Init containers (run before main container starts)
  Useful for migrations, setup tasks, etc.
  */}}
  {{- if .Values.features.initContainers.enabled }}
  {{- with .Values.features.initContainers.containers }}
  initContainers:
    {{ toYaml . | nindent 4 }}
  {{- end }}
  {{- end }}

  {{/*
  Main application container
  */}}
  containers:
    - name: {{ include "microservice-common.name" . }}

      {{/*
      Container-level security context
      */}}
      {{- with .Values.securityContext }}
      securityContext:
        {{ toYaml . | nindent 8 }}
      {{- end }}

      {{/*
      Container image specification
      */}}
      image: "{{ if .Values.global.imageRegistry }}{{ .Values.global.imageRegistry }}/{{ end }}{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
      imagePullPolicy: {{ .Values.image.pullPolicy }}

      {{/*
      Container ports
      */}}
      {{- if .Values.ports }}
      ports:
        {{- toYaml .Values.ports | nindent 8 }}
      {{- end }}

      {{/*
      Liveness probe - restart if unhealthy
      Detects stuck/deadlocked applications
      */}}
      {{- if .Values.livenessProbe.enabled }}
      livenessProbe:
        {{- omit .Values.livenessProbe "enabled" | toYaml | nindent 8 }}
      {{- end }}

      {{/*
      Readiness probe - remove from service if not ready
      Prevents traffic to warming-up instances
      */}}
      {{- if .Values.readinessProbe.enabled }}
      readinessProbe:
        {{ omit .Values.readinessProbe "enabled" | toYaml | nindent 8 }}
      {{- end }}

      {{/*
      Startup probe - allow time for slow-starting apps
      Kubernetes 1.18+
      */}}
      {{- if .Values.startupProbe.enabled }}
      startupProbe:
        {{ omit .Values.startupProbe "enabled" | toYaml | nindent 8 }}
      {{- end }}

      {{/*
      Resource requests and limits
      Ensures predictable scheduling and prevents resource starvation
      */}}
      {{- with .Values.resources }}
      resources:
        {{ toYaml . | nindent 8 }}
      {{- end }}

      {{/*
      Environment variables
      Injected from values.yaml
      */}}
      {{- if .Values.env }}
      env:
        {{ toYaml .Values.env | nindent 8 }}
      {{- end }}

      {{/*
      Load entire config from ConfigMap or Secret
      */}}
      {{- if .Values.envFrom }}
      envFrom:
        {{ toYaml .Values.envFrom | nindent 8 }}
      {{- end }}

      {{/*
      Volume mounts for read-only filesystems and data
      */}}
      volumeMounts:
        {{- if .Values.configMap.enabled }}
        - name: config
          mountPath: /etc/config
          readOnly: true
        {{- end }}
        {{- with .Values.volumeMounts }}
        {{ toYaml . | nindent 8 }}
        {{- end }}
        {{/*
        Ephemeral /tmp mount for read-only root filesystems
        */}}
        - name: tmp
          mountPath: /tmp

  {{/*
  Sidecar containers (run alongside main container)
  Examples: logging sidecars, service mesh proxies, etc.
  Injected into the containers list alongside the main application container.
  */}}
  {{- if .Values.features.sidecars.enabled }}
  {{- range .Values.features.sidecars.containers }}
    - {{ toYaml . | nindent 6 }}
  {{- end }}
  {{- end }}

  {{/*
  Pod volumes (supporting various storage types)
  */}}
  volumes:
    {{- if .Values.configMap.enabled }}
    - name: config
      configMap:
        name: {{ include "microservice-common.fullname" . }}-config
        defaultMode: 0444  # Read-only
    {{- end }}
    {{- if or .Values.volumes .Values.volumeMounts }}
    {{- with .Values.volumes }}
    {{ toYaml . | nindent 4 }}
    {{- end }}
    {{- end }}
    {{/*
    Ephemeral temporary filesystem for /tmp
    Required for read-only root filesystem mode
    */}}
    - name: tmp
      emptyDir:
        sizeLimit: 1Gi

  {{/*
  Affinity configuration - merged block to prevent conflicts
  Supports: affinity (full spec), podAffinity, podAntiAffinity
  */}}
  {{- if or .Values.affinity .Values.podAffinity .Values.podAntiAffinity }}
  affinity:
    {{- if .Values.affinity }}
    {{- toYaml .Values.affinity | nindent 4 }}
    {{- end }}
    {{- if .Values.podAffinity }}
    podAffinity:
      {{- toYaml .Values.podAffinity | nindent 6 }}
    {{- end }}
    {{- if .Values.podAntiAffinity }}
    podAntiAffinity:
      {{- toYaml .Values.podAntiAffinity | nindent 6 }}
    {{- end }}
  {{- end }}

  {{/*
  Node selector - schedule to labeled nodes
  */}}
  nodeSelector:
    {{- if and .Values.global (hasKey .Values.global "localisation") .Values.global.localisation .Values.global.localisation.enabled }}
    {{- if .Values.global.localisation.zone }}
    topology.spaceup.io/zone: {{ .Values.global.localisation.zone | quote }}
    {{- end }}
    {{- if .Values.global.localisation.tier }}
    topology.spaceup.io/tier: {{ .Values.global.localisation.tier | quote }}
    {{- end }}
    {{- end }}
    {{- with .Values.nodeSelector }}
    {{- toYaml . | nindent 4 }}
    {{- end }}

  {{/*
  Tolerations - allow scheduling on tainted nodes
  */}}
  {{- if .Values.tolerations }}
  tolerations:
    {{ toYaml .Values.tolerations | nindent 4 }}
  {{- end }}

  {{/*
  Priority class - pod eviction priority during resource pressure
  */}}
  {{- if .Values.priorityClassName }}
  priorityClassName: {{ .Values.priorityClassName }}
  {{- end }}

  {{/*
  Image pull secrets for private registries
  */}}
  {{- if or .Values.image.pullSecrets .Values.global.imagePullSecrets }}
  imagePullSecrets:
    {{- with .Values.image.pullSecrets }}
    {{ toYaml . | nindent 4 }}
    {{- end }}
    {{- with .Values.global.imagePullSecrets }}
    {{ toYaml . | nindent 4 }}
    {{- end }}
  {{- end }}

  {{/*
  Topology spread constraints - ensure replicas are distributed across zones/hosts
  Crucial for high availability and sovereignty.
  */}}
  {{- if .Values.ha.topologySpread.enabled }}
  topologySpreadConstraints:
    - maxSkew: {{ .Values.ha.topologySpread.host.maxSkew | default 1 }}
      topologyKey: "kubernetes.io/hostname"
      whenUnsatisfiable: {{ .Values.ha.topologySpread.host.whenUnsatisfiable | default "ScheduleAnyway" }}
      labelSelector:
        matchLabels:
          {{- include "microservice-common.selectorLabels" . | nindent 10 }}
    - maxSkew: {{ .Values.ha.topologySpread.zone.maxSkew | default 1 }}
      topologyKey: "topology.kubernetes.io/zone"
      whenUnsatisfiable: {{ .Values.ha.topologySpread.zone.whenUnsatisfiable | default "DoNotSchedule" }}
      labelSelector:
        matchLabels:
          {{- include "microservice-common.selectorLabels" . | nindent 10 }}
  {{- end }}
{{- end }}

