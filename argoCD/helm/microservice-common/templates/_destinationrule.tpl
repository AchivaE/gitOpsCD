{{/*
============================================================================
  ISTIO DESTINATION RULE TEMPLATE
  ============================================================================
  Defines policies that apply after routing (load balancing, mTLS, subsets).
============================================================================
*/}}

{{- define "microservice-common.destinationRule" }}
{{- if and .Values.enabled .Values.serviceMesh.istio.enabled .Values.serviceMesh.istio.destinationRule.enabled }}
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: {{ include "microservice-common.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "microservice-common.labels" . | nindent 4 }}
spec:
  host: {{ include "microservice-common.fullname" . }}
  {{- if .Values.serviceMesh.istio.mtls.enabled }}
  trafficPolicy:
    tls:
      mode: {{ .Values.serviceMesh.istio.mtls.mode | default "ISTIO_MUTUAL" }}
    {{- with .Values.serviceMesh.istio.destinationRule.loadBalancer }}
    loadBalancer:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with .Values.serviceMesh.istio.destinationRule.outlierDetection }}
    outlierDetection:
      {{- toYaml . | nindent 6 }}
    {{- end }}
  {{- end }}
  {{- with .Values.serviceMesh.istio.destinationRule.subsets }}
  subsets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
