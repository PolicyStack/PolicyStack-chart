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
Resolve a list of dependency entries into ACM PolicyDependency YAML.

Each entry accepts: name (required), kind, apiVersion, namespace, compliance, release, policyRef, raw.
Names are resolved using the chart's own naming rules so values files can refer to policies and
sub-policies by the names they were declared with:
  - kind Policy         -> "<name>-<release>"      (release defaults to .Release.Name)
  - template kinds      -> "<policyRef>-<name>"    (policyRef defaults to the owning policy)
  - raw: true           -> name is used verbatim
Namespace is only emitted for kind Policy. Template kinds (ConfigurationPolicy, OperatorPolicy,
CertificatePolicy) live in the per-cluster namespace on the managed cluster, so ACM resolves that
itself and the field must be left off.

Args: dict "deps" <list> "root" <root context> "policyRef" <owning policy name> "defaultKind" <kind>
*/}}
{{- define "policy-library.dependencyList" -}}
{{- $root := .root -}}
{{- $policyRef := .policyRef -}}
{{- $defaultKind := .defaultKind | default "Policy" -}}
{{- $out := list -}}
{{- range .deps -}}
  {{- if not .name -}}
    {{- fail (printf "policy-library: dependency entry requires a 'name' (policy %q)" $policyRef) -}}
  {{- end -}}
  {{- $kind := .kind | default $defaultKind -}}
  {{- $apiVersion := .apiVersion -}}
  {{- if not $apiVersion -}}
    {{- if eq $kind "OperatorPolicy" -}}
      {{- $apiVersion = "policy.open-cluster-management.io/v1beta1" -}}
    {{- else if has $kind (list "Policy" "ConfigurationPolicy" "CertificatePolicy") -}}
      {{- $apiVersion = "policy.open-cluster-management.io/v1" -}}
    {{- else -}}
      {{- fail (printf "policy-library: unknown dependency kind %q on %q (policy %q) - set apiVersion explicitly" $kind .name $policyRef) -}}
    {{- end -}}
  {{- end -}}
  {{- $name := .name -}}
  {{- if not .raw -}}
    {{- if eq $kind "Policy" -}}
      {{- $name = printf "%s-%s" .name (.release | default $root.Release.Name) -}}
    {{- else -}}
      {{- $name = printf "%s-%s" (.policyRef | default $policyRef) .name -}}
    {{- end -}}
  {{- end -}}
  {{- $namespace := .namespace -}}
  {{- if and (not $namespace) (eq $kind "Policy") -}}
    {{- $namespace = $root.Values.policyNamespace -}}
  {{- end -}}
  {{- $entry := dict "apiVersion" $apiVersion "kind" $kind "name" $name "compliance" (.compliance | default "Compliant") -}}
  {{- if $namespace -}}
    {{- $_ := set $entry "namespace" $namespace -}}
  {{- end -}}
  {{- $out = append $out $entry -}}
{{- end -}}
{{- if $out -}}
{{- toYaml $out -}}
{{- end -}}
{{- end -}}

{{/*
Build the complete extraDependencies YAML for a single policy-template entry.
Combines, in order: the automatic ordering dependency (if any), waitForOperator shorthand, and the
sub-policy's own extraDependencies. ACM ANDs all entries, so concatenation is well defined.
Returns an empty string when there is nothing to emit.

waitForOperator names an entry in operatorPolicies[]; the owning policy is looked up from the
component, so an operator installed under a different policy still resolves correctly.

Args: dict "root" <root context> "component" <stack component> "policyRef" <owning policy name>
           "subPolicy" <config/operator/certificate policy entry, or an empty dict>
           "prev" <dict with name+kind to chain from, or an empty dict>
*/}}
{{- define "policy-library.subPolicyDependencies" -}}
{{- $root := .root -}}
{{- $component := .component -}}
{{- $policyRef := .policyRef -}}
{{- $sub := .subPolicy | default dict -}}
{{- $deps := list -}}
{{- if .prev -}}
  {{- $deps = append $deps (dict "name" .prev.name "kind" .prev.kind "raw" true) -}}
{{- end -}}
{{- $waitFor := $sub.waitForOperator | default list -}}
{{- if kindIs "string" $waitFor -}}
  {{- $waitFor = list $waitFor -}}
{{- end -}}
{{- range $operator := $waitFor -}}
  {{- $owners := list -}}
  {{- range $component.operatorPolicies -}}
    {{- if and .enabled (eq .name $operator) -}}
      {{- $owners = append $owners .policyRef -}}
    {{- end -}}
  {{- end -}}
  {{- if not $owners -}}
    {{- fail (printf "policy-library: waitForOperator %q on policy %q matches no enabled entry in operatorPolicies" $operator $policyRef) -}}
  {{- end -}}
  {{- $owner := first $owners -}}
  {{- if gt (len $owners) 1 -}}
    {{- if has $policyRef $owners -}}
      {{- $owner = $policyRef -}}
    {{- else -}}
      {{- fail (printf "policy-library: waitForOperator %q on policy %q is ambiguous (declared under %v) - use extraDependencies instead" $operator $policyRef $owners) -}}
    {{- end -}}
  {{- end -}}
  {{- $deps = append $deps (dict "name" (printf "%s-%s-status" $owner $operator) "kind" "ConfigurationPolicy" "raw" true) -}}
{{- end -}}
{{- $deps = concat $deps ($sub.extraDependencies | default list) -}}
{{- if $deps -}}
{{- include "policy-library.dependencyList" (dict "deps" $deps "root" $root "policyRef" $policyRef "defaultKind" "ConfigurationPolicy") -}}
{{- end -}}
{{- end -}}

{{/*
Emit the leading keys of a policy-templates[] list item, up to and including "objectDefinition:".
Collapses to the plain "- objectDefinition:" when the entry has neither dependencies nor
ignorePending, so values files that do not use these keys render exactly as before.

Args: dict "depsYaml" <output of policy-library.subPolicyDependencies> "ignorePending" <bool>
*/}}
{{- define "policy-library.policyTemplateHeader" -}}
{{- if .depsYaml -}}
- extraDependencies:
{{ .depsYaml | indent 4 }}
{{- if .ignorePending }}
  ignorePending: true
{{- end }}
  objectDefinition:
{{- else if .ignorePending -}}
- ignorePending: true
  objectDefinition:
{{- else -}}
- objectDefinition:
{{- end -}}
{{- end -}}

{{/*
Wrapper template that can be called from consuming charts
*/}}
{{- define "policy-library.render" -}}
{{- include "policy-library.renderPolicies" . -}}
{{- include "policy-library.renderPlacements" . -}}
{{- include "policy-library.renderPolicySets" . -}}
{{- end -}}