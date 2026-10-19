{{- define "microservice-common.serviceMonitor" }}
{{- if and .Values.observability.enabled .Values.observability.prometheus.enabled .Values.observability.prometheus.serviceMonitor.enabled }}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "microservice-common.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "microservice-common.labels" . | nindent 4 }}
    {{- include "microservice-common.componentLabels" . | nindent 4 }}
  {{- with .Values.extraAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  selector:
    matchLabels:
      {{- include "microservice-common.selectorLabels" . | nindent 6 }}
  endpoints:
  - port: http
    interval: {{ .Values.observability.prometheus.interval }}
    scrapeTimeout: {{ .Values.observability.prometheus.scrapeTimeout }}
    path: {{ .Values.observability.prometheus.path }}
    scheme: {{ .Values.observability.prometheus.scheme | default "http" }}
    {{- if .Values.observability.prometheus.honorLabels }}
    honorLabels: {{ .Values.observability.prometheus.honorLabels }}
    {{- end }}
    {{- if .Values.observability.prometheus.relabelings }}
    relabelings:
      {{- toYaml .Values.observability.prometheus.relabelings | nindent 4 }}
    {{- end }}
    {{- if .Values.observability.prometheus.metricRelabelings }}
    metricRelabelings:
      {{- toYaml .Values.observability.prometheus.metricRelabelings | nindent 4 }}
    {{- end }}
  {{- if .Values.observability.prometheus.targetLabels }}
  targetLabels:
    {{- toYaml .Values.observability.prometheus.targetLabels | nindent 4 }}
  {{- end }}
  {{- if .Values.observability.prometheus.podTargetLabels }}
  podTargetLabels:
    {{- toYaml .Values.observability.prometheus.podTargetLabels | nindent 4 }}
  {{- end }}
  namespaceSelector:
    matchNames:
      - {{ .Release.Namespace }}
{{- end }}
{{- end }}
