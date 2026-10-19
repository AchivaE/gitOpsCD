{{/*
============================================================================
  MICROSERVICE COMMON LIBRARY - HELM HELPERS
  ============================================================================
  Production-grade helper templates for Kubernetes resource generation
  - Name/identifier generation
  - Label management
  - Security context helpers
  - Observability annotations
  - Validation helpers
============================================================================
*/}}

{{/*
NAMING HELPERS
============================================================================
*/}}

{{/*
Expand the name of the chart.
Strips "microservice-common" prefix from chart name to get service name.
*/}}
{{- define "microservice-common.name" -}}
{{- $chartName := .Chart.Name }}
{{- if contains "microservice-common" .Chart.Name }}
{{- .Chart.Name | replace "microservice-common" "" | trimPrefix "-" }}
{{- else }}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create a default fully qualified app name.
If release name contains chart name it will be used as a full name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{ define "microservice-common.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "microservice-common.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create the service account name to use.
If not set and create is true, generate a name using the fullname template.
*/}}
{{ define "microservice-common.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{ default (include "microservice-common.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{ default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Get the namespace for the release.
Returns the release namespace, allowing for dynamic namespace resolution.
*/}}
{{- define "microservice-common.namespace" -}}
{{- .Release.Namespace }}
{{- end }}


{{/*
LABEL & SELECTOR HELPERS
============================================================================
*/}}

{{/*
Common labels applied to all resources.
Returns YAML to support multi-line inclusion.
*/}}
{{ define "microservice-common.labels" -}}
app.kubernetes.io/name: {{ include "microservice-common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | replace "+" "_" | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
helm.sh/chart: {{ include "microservice-common.chart" . }}
{{- with .Values.finops }}
finops.spaceup.org/cost-center: {{ .costCenter | quote }}
finops.spaceup.org/business-unit: {{ .businessUnit | quote }}
finops.spaceup.org/owner: {{ .owner | quote }}
{{- end }}
{{- with .Values.extraLabels }}
{{ toYaml . | indent 0 }}
{{- end }}
{{- end }}

{{/*
Selector labels used by Service and Deployment selector.
These match pods with the Deployment they belong to.
*/}}
{{ define "microservice-common.selectorLabels" -}}
app.kubernetes.io/name: {{ include "microservice-common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Component classification labels for resource organization.
Used to tag resources by their functional role.
*/}}
{{ define "microservice-common.componentLabels" -}}
app.kubernetes.io/component: microservice
app.kubernetes.io/part-of: {{ .Values.global.appName | default "spaceup-platform" }}
{{- end }}

{{/*
SECURITY & CONTEXT HELPERS
============================================================================
*/}}

{{/*
Ingress TLS secret name.
Auto-generate if not specified, using fullname-tls pattern.
*/}}
{{- define "microservice-common.tlsSecretName" }}
{{- if .Values.ingress.tls.secretName }}
{{- .Values.ingress.tls.secretName }}
{{- else }}
{{ printf "%s-tls" (include "microservice-common.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Pod security context as inline YAML.
Returns complete pod-level security configuration.
*/}}
{{ define "microservice-common.podSecurityContext" -}}
{{ toYaml .Values.podSecurityContext | nindent 0 }}
{{- end }}

{{/*
Container security context as inline YAML.
Returns complete container-level security configuration.
*/}}
{{- define "microservice-common.securityContext" -}}
{{- toYaml .Values.securityContext | nindent 0 }}
{{- end }}

{{/*
OBSERVABILITY & INTEGRATION HELPERS
============================================================================
*/}}

{{/*
Standard pod annotations for Prometheus monitoring and Consul integration.
Injected into pod metadata by default.
*/}}
{{- define "microservice-common.podAnnotations" -}}
{{- if or .Values.observability.enabled .Values.global.observability.enabled }}
{{- if or .Values.observability.prometheus.enabled .Values.global.prometheus.enabled }}
prometheus.io/scrape: "true"
prometheus.io/port: {{ .Values.observability.prometheus.port | default .Values.global.prometheus.port | default "8080" | quote }}
prometheus.io/path: {{ .Values.observability.prometheus.path | default .Values.global.prometheus.path | default "/actuator/prometheus" | quote }}
{{- end }}
{{- end }}
{{- if or .Values.serviceMesh.consul.enabled .Values.global.serviceMesh.enabled }}
consul.hashicorp.com/connect-inject: "true"
consul.hashicorp.com/connect-service: {{ include "microservice-common.fullname" . }}
consul.hashicorp.com/connect-service-port: {{ .Values.serviceMesh.consul.connectServicePort | default .Values.global.serviceMesh.port | default "8080" | quote }}
{{- end }}
{{- with .Values.podAnnotationsOverride }}
{{ toYaml . | nindent 0 }}
{{- end }}
{{- end }}

{{/*
VALIDATION HELPERS
============================================================================
*/}}

{{/*
Validate required image configuration.
Fails if image.repository is empty (must be set by consuming chart).
*/}}
{{- define "microservice-common.validateImage" -}}
{{- if not .Values.image.repository }}
  {{- fail "ERROR: image.repository must be set in values.yaml" }}
{{- end }}
{{- if and (eq .Values.image.tag "") (not (eq .Chart.AppVersion "0.0.0")) }}
  {{- fail "ERROR: image.tag must be set in values.yaml or use appVersion" }}
{{- end }}
{{- end }}

{{/*
Validate required ingress configuration when ingress is enabled.
*/}}
{{- define "microservice-common.validateIngress" -}}
{{- if .Values.ingress.enabled }}
  {{- if not .Values.ingress.hostname }}
    {{- fail "ERROR: ingress.hostname must be set when ingress.enabled=true" }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Validate probe configuration.
Ensures probes have proper httpGet configuration.
*/}}
{{- define "microservice-common.validateProbes" -}}
{{- if .Values.livenessProbe.enabled }}
  {{- if not .Values.livenessProbe.httpGet.path }}
    {{- fail "ERROR: livenessProbe.httpGet.path must be set when livenessProbe.enabled=true" }}
  {{- end }}
{{- end }}
{{- if .Values.readinessProbe.enabled }}
  {{- if not .Values.readinessProbe.httpGet.path }}
    {{- fail "ERROR: readinessProbe.httpGet.path must be set when readinessProbe.enabled=true" }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
POD SPECIFICATION HELPERS
============================================================================
*/}}

{{/*
Generate probe configuration object from values.
Handles both enabled/disabled probes with proper YAML structure.
*/}}
{{- define "microservice-common.probeConfig" -}}
{{- $probe := . -}}
{{- if $probe.enabled }}
httpGet:
  path: {{ $probe.httpGet.path }}
  port: {{ $probe.httpGet.port }}
  scheme: {{ $probe.httpGet.scheme | default "HTTP" }}
initialDelaySeconds: {{ $probe.initialDelaySeconds }}
periodSeconds: {{ $probe.periodSeconds }}
timeoutSeconds: {{ $probe.timeoutSeconds }}
failureThreshold: {{ $probe.failureThreshold }}
successThreshold: {{ $probe.successThreshold | default 1 }}
{{- end }}
{{- end }}

{{/*
Generate resource requests and limits configuration.
Ensures both requests and limits are properly formatted.
*/}}
{{- define "microservice-common.resourcesConfig" -}}
{{- if .Values.resources }}
requests:
  {{- if .Values.resources.requests }}
  {{- toYaml .Values.resources.requests | nindent 0 }}
  {{- end }}
limits:
  {{- if .Values.resources.limits }}
  {{- toYaml .Values.resources.limits | nindent 0 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
CONDITIONAL HELPERS
============================================================================
*/}}

{{/*
Check if HPA is enabled and override replicaCount in Deployment.
HPA should manage replicas when enabled.
*/}}
{{- define "microservice-common.replicaCount" -}}
{{- if .Values.autoscaling.enabled -}}
{{- else -}}
{{ .Values.replicaCount }}
{{- end -}}
{{- end }}

{{/*
Determine if Ingress TLS should be configured.
Requires both tls.enabled=true and proper hostname configuration.
*/}}
{{- define "microservice-common.ingressTLSEnabled" -}}
{{- and .Values.ingress.enabled .Values.ingress.tls.enabled -}}
{{- end }}

{{/*
Check if network policy should be created.
Requires enabled=true and policyType configuration.
*/}}
{{- define "microservice-common.networkPolicyEnabled" -}}
{{- and .Values.networkPolicy.enabled (or .Values.networkPolicy.ingress.enabled .Values.networkPolicy.egress.enabled) -}}
{{- end }}

{{/*
DEBUGGING HELPERS
============================================================================
*/}}

{{/*
Output debug information if debug.enabled=true.
Useful for troubleshooting values injection.
*/}}
{{- define "microservice-common.debug" -}}
{{- if .Values.debug.enabled }}
# DEBUG INFO
# Chart: {{ .Chart.Name }}
# Version: {{ .Chart.Version }}
# Release: {{ .Release.Name }}
# Namespace: {{ .Release.Namespace }}
# Service: {{ include "microservice-common.fullname" . }}
{{- if .Values.debug.dumpValues }}
# VALUES DUMP:
{{ toYaml .Values | indent 2 }}
{{- end }}
{{- end }}
{{- end }}

