{{/*
Function to pull in placement resources for Policies or PolicySets
*/}}
{{- define "policy-library.renderPlacements" -}}
{{/* Get component name - either passed in or derived from chart name */}}
{{- $componentName := .component | default (include "policy-library.componentName" .) -}}
{{- $root := . -}}

{{/* Access the component using the key */}}
{{- $component := index .Values.stack $componentName -}}

{{/* Get whether we should use policySets or bind placementbinding directly to the policies */}}
{{- $usePolicySetsPlacements := $component.usePolicySetsPlacements | default false }}
{{- if and $component $component.enabled -}}
{{- $policyNamespace := $root.Values.policyNamespace }}

{{/* Process custom policies */}}
{{- if not $component.disablePlacements | default false }}
---
apiVersion: apps.open-cluster-management.io/v1
kind: PlacementRule
metadata:
  name: placement-{{ $root.Release.Name }}
  namespace: {{ $policyNamespace }}
spec:
  clusterConditions:
    - status: "True"
      type: ManagedClusterConditionAvailable
  clusterSelector:
    matchExpressions:
    {{- range $name, $expression := $root.Values.selector.matchExpressions }}
    - key: {{ $expression.key }}
      operator: {{ $expression.operator }}
      values:
      {{- range $expression.values }}
      - {{ . }}
      {{- end }}
    {{- end }}
{{- $hasAnyPolicies := include "hasAnyPoliciesWithSubPolicies" (dict "component" $component "root" $root) -}}
{{- if eq $hasAnyPolicies "true" }}
---
apiVersion: policy.open-cluster-management.io/v1
kind: PlacementBinding
metadata:
  name: placement-{{ $root.Release.Name }}
  namespace: {{ $policyNamespace }}
placementRef:
  name: placement-{{ $root.Release.Name }}
  kind: PlacementRule
  apiGroup: apps.open-cluster-management.io
subjects:
{{- if $usePolicySetsPlacements }}
{{- range $component.policySets }}
{{- if and .enabled .policies }}
{{- $policySetName := .name }}
  - name: {{ $policySetName }}-{{ $root.Release.Name }}
    kind: PolicySet
    apiGroup: policy.open-cluster-management.io
{{- end }}
{{- end }}
{{- else if not $usePolicySetsPlacements }}
{{- range $component.policies }}
{{- if .enabled }}
{{- $policyName := .name }}
{{- $hasSubPolicies := include "hasPolicySubPolicies" (dict "policy" . "component" $component "root" $root) }}
{{- if eq $hasSubPolicies "true" }}
  - name: {{ $policyName }}-{{ $root.Release.Name }}
    kind: Policy
    apiGroup: policy.open-cluster-management.io
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}
