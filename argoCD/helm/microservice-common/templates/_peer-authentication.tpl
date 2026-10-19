{{/*
============================================================================
  ISTIO PEER AUTHENTICATION TEMPLATE
  ============================================================================
  Enforces mutual TLS (mTLS) for all traffic within the microservice.
============================================================================
*/}}

{{- define "microservice-common.peerAuthentication" }}
{{- if and .Values.enabled .Values.serviceMesh.istio.enabled .Values.serviceMesh.istio.mtls.enabled }}
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: {{ include "microservice-common.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{ include "microservice-common.labels" . | nindent 4 }}
    {{ include "microservice-common.componentLabels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      {{- include "microservice-common.selectorLabels" . | nindent 6 }}
  mtls:
    mode: {{ .Values.serviceMesh.istio.mtls.mode | default "STRICT" }}
{{- end }}
{{- end }}
