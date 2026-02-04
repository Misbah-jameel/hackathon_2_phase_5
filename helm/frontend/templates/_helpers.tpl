{{/*
Generate the fullname of the release.
*/}}
{{- define "todo-frontend.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels for all resources.
*/}}
{{- define "todo-frontend.labels" -}}
app: {{ include "todo-frontend.fullname" . }}
chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
release: {{ .Release.Name }}
managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels used in matchLabels and service selectors.
*/}}
{{- define "todo-frontend.selectorLabels" -}}
app: {{ include "todo-frontend.fullname" . }}
release: {{ .Release.Name }}
{{- end }}
