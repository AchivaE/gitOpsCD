{{/*
============================================================================
  HORIZONTAL POD AUTOSCALER TEMPLATE
  ============================================================================
  Kubernetes HPA automatically scales deployment based on metrics.
  Scales on CPU, memory, or custom metrics.
  Manages replica count dynamically within min/max bounds.
============================================================================
*/}}

{{- define "microservice-common.hpa" }}
{{- if and .Values.enabled .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "microservice-common.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "microservice-common.labels" . | nindent 4 }}
    {{- include "microservice-common.componentLabels" . | nindent 4 }}

spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "microservice-common.fullname" . }}

  {{/*
  Minimum and maximum replicas
  */}}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}

  {{/*
  Scaling metrics - CPU and/or Memory
  */}}
  metrics:
    {{/*
    CPU utilization target
    */}}
    {{- if .Values.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}

    {{/*
    Memory utilization target
    */}}
    {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}

  {{/*
  Scale-up and scale-down behavior (advanced)
  Prevents thrashing and slow scale-down
  */}}
  {{- if .Values.autoscaling.behavior }}
  behavior:
    {{- toYaml .Values.autoscaling.behavior | nindent 4 }}
  {{- end }}

{{- end }}
{{- end }}

