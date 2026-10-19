{{/*
============================================================================
  RBAC TEMPLATES (Role & RoleBinding)
  ============================================================================
  Kubernetes Role-Based Access Control for service authorization.
  Grants minimal required permissions to service account.
  Follows principle of least privilege.
============================================================================
*/}}

{{/*
Role - namespace-scoped permissions
*/}}
{{- define "microservice-common.role" }}
{{- if and .Values.enabled .Values.rbac.create }}
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ include "microservice-common.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "microservice-common.labels" . | nindent 4 }}
    {{- include "microservice-common.componentLabels" . | nindent 4 }}

rules:
  {{- if .Values.rbac.rules }}
  {{- toYaml .Values.rbac.rules | nindent 2 }}
  {{- else }}
  {{/*
  Default: no special permissions (pod already has default service account)
  Service can only access its own namespace, own ConfigMaps/Secrets
  */}}
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch"]
    resourceNames:
      - {{ include "microservice-common.fullname" . }}-config
  {{- end }}

{{- end }}
{{- end }}

{{/*
RoleBinding - grant Role to ServiceAccount
*/}}
{{- define "microservice-common.rolebinding" }}
{{- if and .Values.enabled .Values.rbac.create }}
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ include "microservice-common.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "microservice-common.labels" . | nindent 4 }}
    {{- include "microservice-common.componentLabels" . | nindent 4 }}

subjects:
  - kind: ServiceAccount
    name: {{ include "microservice-common.serviceAccountName" . | trim }}
    namespace: {{ .Release.Namespace }}

roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: {{ include "microservice-common.fullname" . }}

{{- end }}
{{- end }}

{{/*
ClusterRole - cross-namespace permissions (if needed)
*/}}
{{- define "microservice-common.clusterRole" }}
{{- if and .Values.enabled .Values.rbac.create .Values.rbac.clusterRules }}
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: {{ include "microservice-common.fullname" . }}-cluster
  labels:
    {{- include "microservice-common.labels" . | nindent 4 }}
    {{- include "microservice-common.componentLabels" . | nindent 4 }}

rules:
  {{- toYaml .Values.rbac.clusterRules | nindent 2 }}

{{- end }}
{{- end }}

{{/*
ClusterRoleBinding - grant ClusterRole to ServiceAccount
*/}}
{{- define "microservice-common.clusterRoleBinding" }}
{{- if and .Values.enabled .Values.rbac.create .Values.rbac.clusterRules }}
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: {{ include "microservice-common.fullname" . }}-cluster
  labels:
    {{- include "microservice-common.labels" . | nindent 4 }}
    {{- include "microservice-common.componentLabels" . | nindent 4 }}

subjects:
  - kind: ServiceAccount
    name: {{ include "microservice-common.serviceAccountName" . | trim }}
    namespace: {{ .Release.Namespace }}

roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: {{ include "microservice-common.fullname" . }}-cluster

{{- end }}
{{- end }}

