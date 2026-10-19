{{/*
============================================================================
  EXTERNAL SECRET TEMPLATE
  ============================================================================
  Integrates with External Secrets Operator to fetch sensitive data from
  Vault, AWS Secrets Manager, etc.
============================================================================
*/}}

{{- define "microservice-common.externalSecret" }}
{{- if and .Values.enabled .Values.secrets.externalSecrets.enabled }}
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{ include "microservice-common.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{ include "microservice-common.labels" . | nindent 4 }}
    {{ include "microservice-common.componentLabels" . | nindent 4 }}
spec:
  refreshInterval: {{ .Values.secrets.externalSecrets.refreshInterval | default "1h" }}
  secretStoreRef:
    name: {{ .Values.secrets.externalSecrets.secretStoreName | default (printf "%s-secret-store" .Values.global.appName) }}
    kind: {{ .Values.secrets.externalSecrets.secretStoreKind | default "SecretStore" }}
  target:
    name: {{ .Values.secrets.externalSecrets.targetSecretName | default (include "microservice-common.fullname" .) }}
    creationPolicy: Owner
    deletionPolicy: Retain
  data:
    {{- range .Values.secrets.externalSecrets.data }}
    - secretKey: {{ .secretKey }}
      remoteRef:
        key: {{ .remoteRef.key }}
        property: {{ .remoteRef.property }}
    {{- end }}
{{- end }}
{{- end }}
