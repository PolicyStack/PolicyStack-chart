{{/*
Helper function to convert chart name to camelCase
*/}}
{{- define "policy-library.componentName" -}}
{{- .Chart.Name | replace "-" " " | replace "_" " " | title | nospace | untitle -}}
{{- end -}}

{{/*
Helper function to check if a policy has any enabled configPolicies or operatorPolicies
*/}}
{{- define "hasPolicySubPolicies" -}}
{{- $policy := .policy -}}
{{- $component := .component -}}
{{- $root := .root -}}
{{- $found := false -}}
{{- range $component.configPolicies -}}
  {{- if and .enabled (eq .policyRef $policy.name) -}}
    {{- $found = true -}}
  {{- end -}}
{{- end -}}
{{- range $component.operatorPolicies -}}
  {{- if and .enabled (eq .policyRef $policy.name) -}}
    {{- $found = true -}}
  {{- end -}}
{{- end -}}
{{- range $component.certificatePolicies -}}
  {{- if and .enabled (eq .policyRef $policy.name) -}}
    {{- $found = true -}}
  {{- end -}}
{{- end -}}
{{- $found -}}
{{- end -}}

{{/*
Helper function to check if any policy in the component has sub-policies
*/}}
{{- define "hasAnyPoliciesWithSubPolicies" -}}
{{- $component := .component -}}
{{- $root := .root -}}
{{- $found := false -}}
{{- range $component.policies -}}
  {{- if .enabled -}}
    {{- $hasSubPolicies := include "hasPolicySubPolicies" (dict "policy" . "component" $component "root" $root) -}}
    {{- if eq $hasSubPolicies "true" -}}
      {{- $found = true -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- $found -}}
{{- end -}}

{{/*
Wrapper template that can be called from consuming charts
*/}}
{{- define "policy-library.render" -}}
{{- include "policy-library.renderPolicies" . -}}
{{- include "policy-library.renderPlacements" . -}}
{{- include "policy-library.renderPolicySets" . -}}
{{- end -}}