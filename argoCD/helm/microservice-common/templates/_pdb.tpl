{{/*
============================================================================
  POD DISRUPTION BUDGET TEMPLATE
  ============================================================================
  Kubernetes PodDisruptionBudget ensures availability during disruptions.
  Defines minimum available replicas during voluntary disruptions.
  Examples: node maintenance, cluster upgrades, resource limits.
============================================================================
*/}}

{{- define "microservice-common.podDisruptionBudget" }}
{{- if and .Values.enabled .Values.podDisruptionBudget.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "microservice-common.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "microservice-common.labels" . | nindent 4 }}
    {{- include "microservice-common.componentLabels" . | nindent 4 }}

spec:
  {{/*
  Selector to identify affected pods
  Must match deployment selector labels
  */}}
  selector:
    matchLabels:
      {{- include "microservice-common.selectorLabels" . | nindent 6 }}

  {{/*
  Availability guarantee - either minAvailable or maxUnavailable
  minAvailable: minimum pods that must stay available
  maxUnavailable: maximum pods that can be disrupted
  */}}
  {{- if .Values.podDisruptionBudget.minAvailable }}
  minAvailable: {{ .Values.podDisruptionBudget.minAvailable }}
  {{- else if .Values.podDisruptionBudget.maxUnavailable }}
  maxUnavailable: {{ .Values.podDisruptionBudget.maxUnavailable }}
  {{- end }}

  {{/*
  Unhealthy pod eviction policy (Kubernetes 1.26+)
  AlwaysAllow: evict even unhealthy pods
  IfHealthyBudget: only evict unhealthy pods if budget not exceeded
  */}}
  {{- if .Values.podDisruptionBudget.unhealthyPodEvictionPolicy }}
  unhealthyPodEvictionPolicy: {{ .Values.podDisruptionBudget.unhealthyPodEvictionPolicy }}
  {{- end }}

{{- end }}
{{- end }}

