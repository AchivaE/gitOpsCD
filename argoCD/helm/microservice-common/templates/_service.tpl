{{/*
============================================================================
  SERVICE TEMPLATE
  ============================================================================
  Kubernetes Service for internal and external traffic routing.
  Supports ClusterIP, NodePort, LoadBalancer, ExternalName types.
============================================================================
*/}}

{{- define "microservice-common.service" }}
{{- if .Values.enabled }}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "microservice-common.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "microservice-common.labels" . | nindent 4 }}
    {{- include "microservice-common.componentLabels" . | nindent 4 }}
  {{- with .Values.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}

spec:
  {{/*
  Service type (ClusterIP | NodePort | LoadBalancer | ExternalName)
  */}}
  type: {{ .Values.service.type }}

  {{/*
  Service cluster IP (leave empty for auto-assignment)
  */}}
  {{- if .Values.service.clusterIP }}
  clusterIP: {{ .Values.service.clusterIP }}
  {{- end }}

  {{/*
  External name (only used for ExternalName service type)
  */}}
  {{- if .Values.service.externalName }}
  externalName: {{ .Values.service.externalName }}
  {{- end }}

  {{/*
  Port mappings - external service port -> container port
  */}}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
      {{- if and (eq .Values.service.type "NodePort") .Values.service.nodePort }}
      nodePort: {{ .Values.service.nodePort }}
      {{- end }}

  {{/*
  Pod selector - routes traffic to pods matching these labels
  */}}
  selector:
    {{- include "microservice-common.selectorLabels" . | nindent 4 }}

  {{/*
  Session affinity - route traffic from same client to same pod
  */}}
  {{- if .Values.service.sessionAffinity }}
  sessionAffinity: {{ .Values.service.sessionAffinity }}
  {{- if .Values.service.sessionAffinityTimeout }}
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: {{ .Values.service.sessionAffinityTimeout }}
  {{- end }}
  {{- end }}

  {{/*
  IP families - IPv4 or dual-stack support
  */}}
  ipFamilyPolicy: SingleStack

{{- end }}
{{- end }}

