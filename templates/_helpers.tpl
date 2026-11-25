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

{{- define "live-stream-packager.image" -}}
{{- if .digest -}}
{{- printf "%s@%s" .repository .digest -}}
{{- else -}}
{{- printf "%s:%s" .repository .tag -}}
{{- end -}}
{{- end }}

{{- define "live-stream-packager.ffmpegInputUrl" -}}
{{- if .Values.cubemap.enabled -}}
{{- printf "http://%s-cubemap:%d/stream.ts" (include "live-stream-packager.fullname" .) (int .Values.cubemap.httpPort) -}}
{{- else -}}
{{- .Values.ffmpeg.inputSourceUrl -}}
{{- end -}}
{{- end }}

{{/*
Pod affinity for a component. User-set .Values.affinity wins; otherwise, with
highAvailability.spreadAcrossNodes, at most one pod of the component per node,
and (for the origin) only on a node that runs a Cubemap.
*/}}
{{- define "live-stream-packager.affinity" -}}
{{- $root := index . 0 -}}
{{- $component := index . 1 -}}
{{- if $root.Values.affinity -}}
{{ toYaml $root.Values.affinity }}
{{- else if $root.Values.highAvailability.spreadAcrossNodes -}}
podAntiAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    - topologyKey: kubernetes.io/hostname
      labelSelector:
        matchLabels:
          {{- include "live-stream-packager.selectorLabels" $root | nindent 10 }}
          app.kubernetes.io/component: {{ $component }}
{{- if and (eq $component "origin") $root.Values.cubemap.enabled }}
podAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    - topologyKey: kubernetes.io/hostname
      labelSelector:
        matchLabels:
          {{- include "live-stream-packager.selectorLabels" $root | nindent 10 }}
          app.kubernetes.io/component: cubemap
{{- end }}
{{- end -}}
{{- end }}
