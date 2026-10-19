{{/*
============================================================================
  ISTIO VIRTUAL SERVICE TEMPLATE
  ============================================================================
  Defines routing rules for traffic entering the service mesh.
  Enables Canary, Blue/Green deployment, and advanced traffic splitting.
============================================================================
*/}}

{{- define "microservice-common.virtualService" }}
{{- if and .Values.enabled .Values.serviceMesh.istio.enabled .Values.serviceMesh.istio.virtualService.enabled }}
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: {{ include "microservice-common.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "microservice-common.labels" . | nindent 4 }}
spec:
  hosts:
    {{- if .Values.serviceMesh.istio.virtualService.hosts }}
    {{- toYaml .Values.serviceMesh.istio.virtualService.hosts | nindent 4 }}
    {{- else }}
    - {{ include "microservice-common.fullname" . }}
    {{- if .Values.ingress.enabled }}
    - {{ .Values.ingress.hostname | quote }}
    {{- end }}
    {{- end }}
  gateways:
    {{- if .Values.serviceMesh.istio.virtualService.gateways }}
    {{- toYaml .Values.serviceMesh.istio.virtualService.gateways | nindent 4 }}
    {{- end }}
  http:
    - route:
        - destination:
            host: {{ include "microservice-common.fullname" . }}
            {{- if .Values.serviceMesh.istio.virtualService.subset }}
            subset: {{ .Values.serviceMesh.istio.virtualService.subset }}
            {{- end }}
            port:
              number: {{ .Values.service.port }}
      {{- with .Values.serviceMesh.istio.virtualService.retries }}
      retries:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.serviceMesh.istio.virtualService.timeout }}
      timeout: {{ . }}
      {{- end }}
{{- end }}
{{- end }}
