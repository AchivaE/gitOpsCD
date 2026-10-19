{{/*
============================================================================
  NETWORK POLICY TEMPLATE
  ============================================================================
  Kubernetes NetworkPolicy restricts network traffic to/from pods.
  Implements security boundaries at network layer (zero-trust networking).
  Requires CNI plugin supporting network policies (Calico, Cilium, etc).
============================================================================
*/}}

{{- define "microservice-common.networkPolicy" }}
{{- if include "microservice-common.networkPolicyEnabled" . }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "microservice-common.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "microservice-common.labels" . | nindent 4 }}
    {{- include "microservice-common.componentLabels" . | nindent 4 }}

spec:
  {{/*
  Pod selector - which pods this policy applies to
  */}}
  podSelector:
    matchLabels:
      {{- include "microservice-common.selectorLabels" . | nindent 6 }}

  {{/*
  Policy types - what directions to apply (Ingress, Egress, or both)
  */}}
  policyTypes:
    {{- toYaml .Values.networkPolicy.policyType | nindent 4 }}

  {{/*
  DEFAULT DENY - Implement zero-trust by denying all by default (if enabled)
  Actual allow rules follow below.
  */}}
  {{- if and .Values.networkPolicy.ingress.enabled (not (or .Values.networkPolicy.ingress.fromIngress.enabled .Values.networkPolicy.ingress.fromNamespaces.enabled .Values.networkPolicy.ingress.fromPods.enabled)) }}
  ingress: []
  {{- end }}
  {{- if and .Values.networkPolicy.egress.enabled (not .Values.networkPolicy.egress.toDns.enabled) }}
  egress: []
  {{- end }}

  {{/*
  INGRESS RULES - allow inbound traffic
  */}}
  {{- if .Values.networkPolicy.ingress.enabled }}
  ingress:
    {{/*
    Allow from Consul sidecar (mTLS Proxy)
    */}}
    {{- if or .Values.serviceMesh.consul.enabled .Values.global.serviceMesh.enabled }}
    - from:
        - podSelector:
            matchLabels:
              {{- include "microservice-common.selectorLabels" . | nindent 14 }}
      ports:
        - protocol: TCP
          port: {{ .Values.serviceMesh.consul.connectServicePort | default .Values.global.serviceMesh.port | default "8080" }}
    {{- end }}

    {{/*
    Allow from Ingress controller
    */}}
    {{- if .Values.networkPolicy.ingress.fromIngress.enabled }}
    - from:
        - namespaceSelector:
            matchLabels:
              {{- toYaml .Values.networkPolicy.ingress.fromIngress.namespaceSelector.matchLabels | nindent 14 }}
      ports:
        {{- toYaml .Values.networkPolicy.ingress.ports | nindent 8 }}
    {{- end }}

    {{/*
    Allow from specific namespaces
    */}}
    {{- if .Values.networkPolicy.ingress.fromNamespaces.enabled }}
    - from:
        - namespaceSelector:
            matchLabels:
              {{- toYaml .Values.networkPolicy.ingress.fromNamespaces.labels | nindent 14 }}
      ports:
        {{- toYaml .Values.networkPolicy.ingress.ports | nindent 8 }}
    {{- end }}

    {{/*
    Allow from specific pods
    */}}
    {{- if .Values.networkPolicy.ingress.fromPods.enabled }}
    - from:
        - podSelector:
            matchLabels:
              {{- toYaml .Values.networkPolicy.ingress.fromPods.matchLabels | nindent 14 }}
      ports:
        {{- toYaml .Values.networkPolicy.ingress.ports | nindent 8 }}
    {{- end }}
  {{- end }}

  {{/*
  EGRESS RULES - allow outbound traffic
  */}}
  {{- if .Values.networkPolicy.egress.enabled }}
  egress:
    {{/*
    Allow DNS queries (port 53 UDP/TCP)
    Targets kube-dns/CoreDNS in kube-system namespace
    */}}
    {{- if .Values.networkPolicy.egress.toDns.enabled }}
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    {{- end }}

    {{/*
    Allow to Kubernetes API server
    */}}
    {{- if .Values.networkPolicy.egress.toKubernetesApi.enabled }}
    - to:
        - namespaceSelector:
            matchLabels:
              name: default
      ports:
        - protocol: TCP
          port: 443
    {{- end }}

    {{/*
    Allow to external services by CIDR
    */}}
    {{- if .Values.networkPolicy.egress.toExternal.enabled }}
    - to:
        {{- range .Values.networkPolicy.egress.toExternal.cidr }}
        - ipBlock:
            cidr: {{ . }}
        {{- end }}
    {{- end }}

    {{/*
    Allow to specific services within cluster
    */}}
    {{- if .Values.networkPolicy.egress.toServices.enabled }}
    - to:
        - podSelector:
            matchLabels:
              {{- toYaml .Values.networkPolicy.egress.toServices.podSelector | nindent 14 }}
          namespaceSelector:
            {{- toYaml .Values.networkPolicy.egress.toServices.namespaceSelector | nindent 12 }}
    {{- end }}
  {{- end }}

{{- end }}
{{- end }}

