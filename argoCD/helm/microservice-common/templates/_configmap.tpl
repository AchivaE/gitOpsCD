{{/*
============================================================================
  CONFIGMAP TEMPLATE
  ============================================================================
  Kubernetes ConfigMap for non-sensitive application configuration.
  Used for application config files, properties, etc.
  NOTE: Use Secrets for sensitive data (passwords, API keys, etc.)
============================================================================
*/}}

{{- define "microservice-common.configmap" }}
{{- if and .Values.enabled .Values.configMap.enabled }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "microservice-common.fullname" . }}-config
  namespace: {{ .Release.Namespace }}
  labels:
    {{ include "microservice-common.labels" . | nindent 4 }}
    {{ include "microservice-common.componentLabels" . | nindent 4 }}
  {{- with .Values.extraAnnotations }}
  annotations:
    {{ toYaml . | nindent 4 }}
  {{- end }}

data:
  {{- if .Values.configMap.data }}
  {{ toYaml .Values.configMap.data | nindent 2 }}
  {{- end }}

{{- end }}
{{- end }}

