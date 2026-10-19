{{/*
============================================================================
  INGRESS TEMPLATE
  ============================================================================
  Kubernetes Ingress for HTTP(S) external traffic routing.
  Supports TLS termination, path-based routing, multiple hosts.
============================================================================
*/}}

{{- define "microservice-common.ingress" }}
{{- if and .Values.enabled .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "microservice-common.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{ include "microservice-common.labels" . | nindent 4 }}
    {{ include "microservice-common.componentLabels" . | nindent 4 }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{ toYaml . | nindent 4 }}
  {{- end }}

spec:
  {{/*
  Ingress class - typically "nginx" or "istio"
  */}}
  {{- if .Values.ingress.ingressClassName }}
  ingressClassName: {{ .Values.ingress.ingressClassName }}
  {{- end }}

  {{/*
  TLS termination - HTTPS configuration
  */}}
  {{- if include "microservice-common.ingressTLSEnabled" . }}
  tls:
    - secretName: {{ include "microservice-common.tlsSecretName" . | trim }}
      hosts:
        - {{ .Values.ingress.hostname | quote }}
  {{- end }}

  {{/*
  Ingress rules - hostname and path routing
  */}}
  rules:
    - host: {{ .Values.ingress.hostname | quote }}
      http:
        paths:
          - path: {{ .Values.ingress.path }}
            pathType: {{ .Values.ingress.pathType }}
            backend:
              service:
                name: {{ include "microservice-common.fullname" . }}
                port:
                  number: {{ .Values.service.port }}

{{- end }}
{{- end }}

