{{/*
Extract unique repoURLs from ENABLED features
*/}}
{{- define "infra.repoURLs" -}}
  {{- $repos := dict -}}
  {{- range $key, $val := .Values.features -}}
    {{- /* Only process if enabled is explicitly true */ -}}
    {{- if $val.enabled -}}
      {{- if and $val.source $val.source.repoURL -}}
        {{- $_ := set $repos $val.source.repoURL "true" -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- keys $repos | sortAlpha | toJson -}}
{{- end -}}

{{/*
Extract unique namespaces from ENABLED features
*/}}
{{- define "infra.namespaces" -}}
  {{- $nsDict := dict -}}
  {{- range $key, $val := .Values.features -}}
    {{- /* Only process if enabled is explicitly true */ -}}
    {{- if $val.enabled -}}
      {{- if $val.namespace -}}
        {{- $_ := set $nsDict $val.namespace "true" -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- keys $nsDict | sortAlpha | toJson -}}
{{- end -}}