{{/*
============================================================================
  SERVICE ACCOUNT TEMPLATE
  ============================================================================
  Kubernetes ServiceAccount for pod identity and RBAC authorization.
  Required for secure pod-to-API communication.
============================================================================
*/}}

{{- define "microservice-common.serviceAccount" }}
{{- if and .Values.enabled .Values.serviceAccount.create }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "microservice-common.serviceAccountName" . | trim }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "microservice-common.labels" . | nindent 4 }}
    {{- include "microservice-common.componentLabels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}

automountServiceAccountToken: {{ .Values.serviceAccount.automountToken | default false }}

{{- end }}
{{- end }}

