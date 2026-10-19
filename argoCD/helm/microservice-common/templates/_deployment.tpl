{{/*
============================================================================
  DEPLOYMENT TEMPLATE
  ============================================================================
  Production-grade Kubernetes Deployment configuration.
  Includes rolling update strategy, replicas, selector, pod template.
============================================================================
*/}}

{{- define "microservice-common.deployment" }}
{{- if .Values.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "microservice-common.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{ include "microservice-common.labels" . | nindent 4 }}
    {{ include "microservice-common.componentLabels" . | nindent 4 }}
  {{- with .Values.extraAnnotations }}
  annotations:
    {{ toYaml . | nindent 4 }}
  {{- end }}

spec:
  {{/*
  Replica count - overridden by HPA if enabled
  */}}
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}

  {{/*
  Rolling update strategy configuration
  */}}
  {{- with .Values.strategy }}
  strategy:
    {{ toYaml . | nindent 4 }}
  {{- end }}

  {{/*
  Pod selector - matches pods managed by this Deployment
  */}}
  selector:
    matchLabels:
      {{ include "microservice-common.selectorLabels" . | nindent 6 }}

  {{/*
  Revision history for rollback capability
  */}}
  revisionHistoryLimit: {{ .Values.revisionHistoryLimit | default 10 }}

  {{/*
  Pod template specification
  */}}
  template:
    metadata:
      {{/*
      Pod annotations - for monitoring, service mesh, etc.
      */}}
      annotations:
        {{- include "microservice-common.podAnnotations" . | nindent 8 }}

      {{/*
      Pod labels for identification and selection
      */}}
      labels:
        {{ include "microservice-common.selectorLabels" . | nindent 8 }}
        {{ include "microservice-common.componentLabels" . | nindent 8 }}
        {{- with .Values.extraLabels }}
        {{ toYaml . | nindent 8 }}
        {{- end }}

    {{/*
    Pod specification with containers, volumes, security, scheduling
    */}}
    {{ include "microservice-common.podSpec" . | nindent 4 }}

{{- end }}
{{- end }}

