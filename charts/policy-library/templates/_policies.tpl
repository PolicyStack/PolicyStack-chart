{{/*
Main policy processing template with templateParameters support
*/}}
{{- define "policy-library.renderPolicies" -}}
{{/* Get component name - either passed in or derived from chart name */}}
{{- $componentName := .component | default (include "policy-library.componentName" .) -}}
{{- $root := . -}}

{{/* Access the component using the key */}}
{{- $component := index .Values.stack $componentName -}}
{{- if $component -}}
{{- if $component.enabled -}}

{{/* Ordering: chain policies / policy-templates via ACM dependencies */}}
{{- $orderPolicies := $component.orderPolicies | default false -}}
{{- $prevPolicy := "" -}}

{{/* Process custom policies */}}
{{- range $component.policies }}
{{- if eq (include "policy-library.enabled" (dict "component" $component "entry" .)) "true" }}
{{- $policyName := .name }}
{{- $policyNamespace := $root.Values.policyNamespace }}
{{- $policyValues := . }}

{{/* orderManifests: component-level default, overridable per policy (including back to false) */}}
{{- $orderManifests := $component.orderManifests | default false }}
{{- if hasKey . "orderManifests" }}{{- $orderManifests = .orderManifests }}{{- end }}
{{- $prevManifest := dict }}

{{/* Policy-level dependencies: automatic ordering first, then any explicit entries */}}
{{- $policyDeps := list }}
{{- if and $orderPolicies $prevPolicy }}
{{- $policyDeps = append $policyDeps (dict "name" $prevPolicy "kind" "Policy") }}
{{- end }}
{{- $policyDeps = concat $policyDeps (.dependencies | default list) }}

{{/* Check if this policy has any configuration or operator policies */}}
{{- $hasSubPolicies := include "hasPolicySubPolicies" (dict "policy" . "component" $component "root" $root) }}
{{- if eq $hasSubPolicies "true" }}
---
apiVersion: policy.open-cluster-management.io/v1
kind: Policy
metadata:
  name: {{ $policyName }}-{{ $root.Release.Name }}
  namespace: {{ $policyNamespace }}
  annotations:
    {{- if .categories }}
    policy.open-cluster-management.io/categories: {{ .categories | join "," | quote }}
    {{- else if and $component.default $component.default.categories }}
    policy.open-cluster-management.io/categories: {{ $component.default.categories | join "," | quote }}
    {{- end }}
    {{- if .controls }}
    policy.open-cluster-management.io/controls: {{ .controls | join "," | quote }}
    {{- else if and $component.default $component.default.controls }}
    policy.open-cluster-management.io/controls: {{ $component.default.controls | join "," | quote }}
    {{- end }}
    {{- if .standards }}
    policy.open-cluster-management.io/standards: {{ .standards | join "," | quote }}
    {{- else if and $component.default $component.default.standards }}
    policy.open-cluster-management.io/standards: {{ $component.default.standards | join "," | quote }}
    {{- end }}
    {{- if .description }}
    description: {{ .description | quote }}
    {{- end }}
spec:
  {{- if .remediationAction }}
  remediationAction: {{ .remediationAction }}
  {{- end }}
  disabled: {{ .disabled }}
  {{- if $policyDeps }}
  dependencies:
    {{- include "policy-library.dependencyList" (dict "deps" $policyDeps "root" $root "component" $component "policyRef" $policyName "defaultKind" "Policy") | nindent 4 }}
  {{- end }}
  {{- if $orderPolicies }}{{- $prevPolicy = $policyName }}{{- end }}
  policy-templates:
  {{- range $component.configPolicies -}}
  {{- if and (eq (include "policy-library.enabled" (dict "component" $component "entry" .)) "true") (eq .policyRef $policyName) -}}
  {{- $configName := include "policy-library.templateName" (dict "root" $root "component" $component "policyRef" $policyName "name" .name) }}
  {{- $severity := default "low" .severity }}
  {{- $complianceType := .complianceType }}
  {{- $remediationAction := default "inform" .remediationAction }}
  {{- $templateNames := .templateNames }}
  {{- $rawTemplate := .rawTemplate | default false }}
  {{/* Create context with parameters if enableTemplateParameters is true */}}
  {{- $templateContext := $root }}
  {{- if .enableTemplateParameters }}
    {{- if .templateParameters }}
      {{- $templateContext = merge (dict "Parameters" .templateParameters) $root }}
    {{- end -}}
  {{- end -}}
  {{- $depsYaml := include "policy-library.subPolicyDependencies" (dict "root" $root "component" $component "policyRef" $policyName "subPolicy" . "prev" (ternary $prevManifest dict $orderManifests)) -}}
  {{- $prevManifest = dict "name" $configName "kind" "ConfigurationPolicy" -}}
    # Configuration policies - necessary to prevent line issues
    {{- include "policy-library.policyTemplateHeader" (dict "depsYaml" $depsYaml "ignorePending" .ignorePending) | nindent 4 }}
        apiVersion: policy.open-cluster-management.io/v1
        kind: ConfigurationPolicy
        metadata:
          name: {{ $configName }}
          {{- if or .description .disableTemplating }}
          annotations:
            {{- if .description }}
            description: {{ .description | quote }}
            {{- end }}
            {{- if .disableTemplating }}
            policy.open-cluster-management.io/disable-templates: "true"
            {{- end }}
          {{- end }}
        spec:
          {{- if .namespaceSelector }}
          namespaceSelector: {{ nindent 12 (toYaml .namespaceSelector) }}
          {{- end }}
          {{- if .customMessage }}
          customMessage:
            {{- if .customMessage.compliant }}
            compliant: {{ .customMessage.compliant | quote }}
            {{- end }}
            {{- if .customMessage.noncompliant }}
            noncompliant: {{ .customMessage.noncompliant | quote }}
            {{- end }}
          {{- end }}
          {{- if .evaluationInterval }}
          evaluationInterval:
            {{- if .evaluationInterval.compliant }}
            compliant: {{ .evaluationInterval.compliant }}
            {{- end }}
            {{- if .evaluationInterval.noncompliant }}
            noncompliant: {{ .evaluationInterval.noncompliant }}
            {{- end }}
          {{- end }}
          {{- if .pruneObjectBehavior }}
          pruneObjectBehavior: {{ .pruneObjectBehavior }}
          {{- end }}
          remediationAction: {{ $remediationAction }}
          severity: {{ $severity }}
          {{- if $rawTemplate }}
          {{- /*
          object-templates-raw is a single string field that REPLACES object-templates, so it can
          only ever come from one converter. Use it when the manifest must emit a variable number of
          objects decided on the managed cluster (an ACM `lookup` + `range`), which object-templates
          cannot express. The converter keeps its ACM braces escaped Helm-side.
          */ -}}
          {{- if ne (len $templateNames) 1 }}
          {{- fail (printf "policy-library: configPolicy %q sets rawTemplate: true, which maps to the single-valued object-templates-raw field, so it needs exactly one templateNames entry (got %d)" $configName (len $templateNames)) }}
          {{- end }}
          {{- $rawEntry := first $templateNames }}
          {{- $rawName := "" }}
          {{- if kindIs "string" $rawEntry }}{{- $rawName = $rawEntry }}{{- else }}{{- $rawName = $rawEntry.name }}{{- end }}
          {{- $rawContent := tpl ($root.Files.Get (printf "converters/%s.yaml" $rawName)) $templateContext | trim }}
          {{- /*
          A raw converter driven by a values map renders to nothing when that map is empty. An empty
          object-templates-raw is not parseable, so emit an explicit empty list instead - the policy
          then simply has no objects to enforce rather than failing.
          */ -}}
          {{- if not $rawContent }}{{- $rawContent = "[]" }}{{- end }}
          object-templates-raw: |{{- $rawContent | nindent 12 }}
          {{- else }}
          object-templates:
          {{- range $templateNames -}}
          {{- $templatePath := printf "converters/%s.yaml" .name }}
          {{- $templateContent := tpl ($root.Files.Get $templatePath) $templateContext }}
              {{- if $complianceType }}
            - complianceType: {{ $complianceType }}
              {{- else }}
            - complianceType: {{ default "musthave" .complianceType }}
              {{- end }}
              {{- if .metadataComplianceType }}
              metadataComplianceType: {{ .metadataComplianceType }}
              {{- end }}
              {{- if .recordDiff }}
              recordDiff: {{ .recordDiff }}
              {{- end }}
              {{- if .recreateOption }}
              recreateOption: {{ .recreateOption }}
              {{- end }}
              {{- if .objectSelector }}
              objectSelector: {{ nindent 16 (toYaml .objectSelector)}}
              {{- end }}
              objectDefinition:{{- nindent 16 ( trim $templateContent) }}
          {{- end }}
          {{- end }}
  {{- end -}}{{- end -}}
  {{- range $component.operatorPolicies -}}
  {{- if and (eq (include "policy-library.enabled" (dict "component" $component "entry" .)) "true") (eq .policyRef $policyName) }}
  {{- $configName := include "policy-library.templateName" (dict "root" $root "component" $component "policyRef" $policyName "name" .name) }}
  {{- $severity := default $policyValues.severity .severity }}
  {{- $complianceType := default "musthave" .complianceType }}
  {{- $remediationAction := default $policyValues.remediationAction .remediationAction }}
  {{- /*
  Operator policies render three objects. Under orderManifests they are chained explicitly rather
  than by render position: ns -> OperatorPolicy -> status. Chaining in render position would make
  the OperatorPolicy wait on the CSV status check that only its own installation can satisfy.
  */ -}}
  {{- $nsRef := dict "name" (printf "%s-ns" $configName) "kind" "ConfigurationPolicy" }}
  {{- $opRef := dict "name" $configName "kind" "OperatorPolicy" }}
  {{- $statusRef := dict "name" (printf "%s-status" $configName) "kind" "ConfigurationPolicy" }}
  {{- $nsDeps := include "policy-library.subPolicyDependencies" (dict "root" $root "component" $component "policyRef" $policyName "subPolicy" dict "prev" (ternary $prevManifest dict $orderManifests)) }}
  {{- $opDeps := include "policy-library.subPolicyDependencies" (dict "root" $root "component" $component "policyRef" $policyName "subPolicy" . "prev" (ternary $nsRef dict $orderManifests)) }}
  {{- $statusDeps := include "policy-library.subPolicyDependencies" (dict "root" $root "component" $component "policyRef" $policyName "subPolicy" dict "prev" (ternary $opRef dict $orderManifests)) }}
  {{- $prevManifest = $statusRef }}
    {{- include "policy-library.policyTemplateHeader" (dict "depsYaml" $nsDeps) | nindent 4 }}
        apiVersion: policy.open-cluster-management.io/v1
        kind: ConfigurationPolicy
        metadata:
          name: {{ $configName }}-ns
        spec:
          remediationAction: {{ $remediationAction }}
          severity: {{ $severity }}
          object-templates:
            - complianceType: {{ $complianceType }}
              objectDefinition:
                apiVersion: v1
                kind: Namespace
                metadata:
                  name: {{ .namespace }}
    {{- include "policy-library.policyTemplateHeader" (dict "depsYaml" $statusDeps) | nindent 4 }}
        apiVersion: policy.open-cluster-management.io/v1
        kind: ConfigurationPolicy
        metadata:
          name: {{ $configName }}-status
        spec:
          remediationAction: inform
          severity: {{ $severity }}
          object-templates:
            - complianceType: {{ $complianceType }}
              objectDefinition:
                apiVersion: operators.coreos.com/v1alpha1
                kind: ClusterServiceVersion
                metadata:
                  namespace: {{ .namespace }}
                spec:
                  displayName: {{ .displayName | default .subscription.name }}
                status:
                  phase: Succeeded
    {{- include "policy-library.policyTemplateHeader" (dict "depsYaml" $opDeps "ignorePending" .ignorePending) | nindent 4 }}
        apiVersion: policy.open-cluster-management.io/v1beta1
        kind: OperatorPolicy
        metadata:
          name: {{ $configName }}
          {{- if .description }}
          annotations:
            description: {{ .description | quote }}
          {{- end }}
        spec:
          {{- if .versions }}
          versions: {{ nindent 12 (toYaml .versions) }}
          {{- end }}
          remediationAction: {{ $remediationAction }}
          severity: {{ $severity }}
          complianceType: {{ $complianceType }}
          {{- /*
          operatorGroup is optional: omitting it means "name defaults to the subscription name,
          install cluster-scoped". Parenthesised access keeps that working - a bare
          .operatorGroup.name panics when the whole map is absent.
          */}}
          operatorGroup:
            name: {{ (.operatorGroup).name | default .subscription.name }}
            namespace: {{ .namespace }}
            {{- with (.operatorGroup).targetNamespaces }}
            targetNamespaces:{{ nindent 14 (toYaml .) }}
            {{- end }}
          subscription:
            name: {{ .subscription.name }}
            {{- if .namespace }}
            namespace: {{ .namespace }}
            {{- end }}
            {{- if .subscription.channel }}
            channel: {{ .subscription.channel }}
            {{- end }}
            {{- if .subscription.source }}
            source: {{ .subscription.source }}
            {{- end }}
            {{- if .subscription.sourceNamespace }}
            sourceNamespace: {{ .subscription.sourceNamespace }}
            {{- end }}
            {{- if .subscription.startingCSV }}
            startingCSV: {{ .subscription.startingCSV }}
            {{- end }}
            {{- if .subscription.config }}
            config: {{ nindent 14 (toYaml .subscription.config) }}
            {{- end }}
          {{- if .upgradeApproval }}
          upgradeApproval: {{ .upgradeApproval }}
          {{- end }}
  {{- end -}}{{- end -}}
  {{- range $component.certificatePolicies -}}
  {{- if and (eq (include "policy-library.enabled" (dict "component" $component "entry" .)) "true") (eq .policyRef $policyName) }}
  {{- $configName := include "policy-library.templateName" (dict "root" $root "component" $component "policyRef" $policyName "name" .name) }}
  {{- $severity := default "low" .severity }}
  {{- $remediationAction := default "inform" .remediationAction }}
  {{- $depsYaml := include "policy-library.subPolicyDependencies" (dict "root" $root "component" $component "policyRef" $policyName "subPolicy" . "prev" (ternary $prevManifest dict $orderManifests)) }}
  {{- $prevManifest = dict "name" $configName "kind" "CertificatePolicy" }}
    {{- include "policy-library.policyTemplateHeader" (dict "depsYaml" $depsYaml "ignorePending" .ignorePending) | nindent 4 }}
        apiVersion: policy.open-cluster-management.io/v1
        kind: CertificatePolicy
        metadata:
          name: {{ $configName }}
          {{- if or .description .disableTemplating }}
          annotations:
            {{- if .description }}
            description: {{ .description | quote }}
            {{- end }}
            {{- if .disableTemplating }}
            policy.open-cluster-management.io/disable-templates: "true"
            {{- end }}
          {{- end }}
        spec:
          {{- if .namespaceSelector }}
          namespaceSelector: {{ nindent 12 (toYaml .namespaceSelector) }}
          {{- end }}
          {{- if .labelSelector }}
          labelSelector: {{ nindent 12 (toYaml .labelSelector) }}
          {{- end }}
          remediationAction: {{ $remediationAction }}
          severity: {{ $severity }}
          {{- if .minimumDuration }}
          minimumDuration: {{ .minimumDuration }}
          {{- end }}
          {{- if .minimumCADuration }}
          minimumCADuration: {{ .minimumCADuration }}
          {{- end }}
          {{- if .maximumDuration }}
          maximumDuration: {{ .maximumDuration }}
          {{- end }}
          {{- if .maximumCADuration }}
          maximumCADuration: {{ .maximumCADuration }}
          {{- end }}
          {{- if .allowedSANPattern }}
          allowedSANPattern: {{ .allowedSANPattern | quote }}
          {{- end }}
          {{- if .disallowedSANPattern }}
          disallowedSANPattern: {{ .disallowedSANPattern | quote }}
          {{- end }}
  {{- end -}}
  {{- end -}}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}
