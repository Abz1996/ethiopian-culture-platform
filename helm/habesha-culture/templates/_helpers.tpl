{{- define "habesha.name" -}}{{ .Values.fullnameOverride | default .Chart.Name }}{{- end -}}
{{- define "habesha.labels" -}}
app.kubernetes.io/name: {{ include "habesha.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: habesha-kitchen
habesha/environment: {{ .Values.environment }}
{{- end -}}
{{- define "habesha.selector" -}}
app.kubernetes.io/name: {{ include "habesha.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
