{{- define "config-ingestor.fullname" -}}config-ingestor{{- end -}}
{{- define "config-ingestor.image" -}}
{{- $tag := required "image.tag must be supplied by CI promotion" .Values.image.tag -}}
{{- if hasPrefix "sha256:" $tag -}}
{{ printf "%s@%s" .Values.image.repository $tag }}
{{- else -}}
{{ printf "%s:%s" .Values.image.repository $tag }}
{{- end -}}
{{- end -}}
{{- define "config-ingestor.selectorLabels" -}}
app.kubernetes.io/name: config-ingestor
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "config-ingestor.labels" -}}
{{ include "config-ingestor.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- /* OCI digests are too long for a Kubernetes label. Add a version label
      only when the promoted image tag itself is label-safe. */}}
{{- if and (le (len .Values.image.tag) 63) (regexMatch "^[A-Za-z0-9]([-A-Za-z0-9_.]*[A-Za-z0-9])?$" .Values.image.tag) }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
{{- end }}
{{- end -}}
