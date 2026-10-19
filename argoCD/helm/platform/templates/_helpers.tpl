{{- define "platform.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "platform.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end }}

{{- define "platform.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{ define "platform.labels" -}}
helm.sh/chart: {{ include "platform.chart" . }}
{{ include "platform.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
environment: {{ .Values.global.environment | quote }}
{{- end }}

{{ define "platform.selectorLabels" -}}
app.kubernetes.io/name: {{ include "platform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "platform.namespace" -}}
{{- .Values.global.namespace | quote -}}
{{- end }}

{{- define "platform.environment" -}}
{{- .Values.global.environment | quote -}}
{{- end }}

{{- define "platform.domain" -}}
{{- .Values.global.domain | quote -}}
{{- end }}

{{- define "platform.imagePullPolicy" -}}
{{- .Values.global.imagePullPolicy | default "IfNotPresent" | quote -}}
{{- end }}

{{- define "platform.serviceAccountName" -}}
{{- if .Values.rbac.create -}}
{{- default (include "platform.fullname" .) .Values.rbac.serviceAccountName -}}
{{- else -}}
{{- default "default" .Values.rbac.serviceAccountName -}}
{{- end -}}
{{- end }}

{{/*
Create environment-specific labels
*/}}
{{ define "platform.environmentLabels" -}}
environment: {{ .Values.global.environment }}
namespace: {{ .Values.global.namespace }}
managed-by: helm
version: {{ .Chart.Version }}
{{- end }}

{{/*
Return storage class name if defined
*/}}
{{ define "platform.storageClass" -}}
{{- if .storageClass }}
storageClassName: {{ .storageClass | quote }}
{{- end }}
{{- end }}

{{- define "platform.logging.level" -}}
{{- .Values.global.logging.level | default "INFO" | quote -}}
{{- end }}

{{- define "platform.tls.issuer" -}}
{{- .Values.global.tls.issuer | default "letsencrypt-prod" | quote -}}
{{- end }}
