
---

## `templates/_helpers.tpl`

```yaml
{{- define "live-stream-packager.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "live-stream-packager.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := include "live-stream-packager.name" . }}
{{- if contains $name .Release.Name }}
{{- $name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "live-stream-packager.labels" -}}
app.kubernetes.io/name: {{ include "live-stream-packager.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
{{- end }}

{{- define "live-stream-packager.selectorLabels" -}}
app.kubernetes.io/name: {{ include "live-stream-packager.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

