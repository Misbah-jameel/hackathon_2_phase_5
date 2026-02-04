{{/*
Generate the fullname of the release.
*/}}
{{- define "todo-backend.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels for all resources.
*/}}
{{- define "todo-backend.labels" -}}
app: {{ include "todo-backend.fullname" . }}
chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
release: {{ .Release.Name }}
managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels used in matchLabels and service selectors.
*/}}
{{- define "todo-backend.selectorLabels" -}}
app: {{ include "todo-backend.fullname" . }}
release: {{ .Release.Name }}
{{- end }}
