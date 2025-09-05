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

{{/* Process custom policies */}}
{{- range $component.policies }}
{{- if .enabled }}
{{- $policyName := .name }}
{{- $policyNamespace := $root.Values.policyNamespace }}
{{- $policyValues := . }}

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
  policy-templates:
  {{- range $component.configPolicies -}}
  {{- if and .enabled (eq .policyRef $policyName) -}}
  {{- $configName := printf "%s-%s" $policyName .name }}
  {{- $severity := default "low" .severity }}
  {{- $complianceType := .complianceType }}
  {{- $remediationAction := default "inform" .remediationAction }}
  {{- $templateNames := .templateNames }}
  {{/* Create context with parameters if enableTemplateParameters is true */}}
  {{- $templateContext := $root }}
  {{- if .enableTemplateParameters }}
    {{- if .templateParameters }}
      {{- $templateContext = merge (dict "Parameters" .templateParameters) $root }}
    {{- end -}}
  {{- end -}}
    # Configuration policies - necessary to prevent line issues
    - objectDefinition:
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
          {{- end -}}
  {{- end -}}{{- end -}}
  {{- range $component.operatorPolicies -}}
  {{- if and .enabled (eq .policyRef $policyName) }}
  {{- $configName := printf "%s-%s" $policyName .name }}
  {{- $severity := default $policyValues.severity .severity }}
  {{- $complianceType := default "musthave" .complianceType }}
  {{- $remediationAction := default $policyValues.remediationAction .remediationAction }}
    - objectDefinition:
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
    - objectDefinition:
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
    - objectDefinition:
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
          operatorGroup:
            name: {{ .operatorGroup.name | default .subscription.name }}
            namespace: {{ .namespace }}
            {{- if .operatorGroup.targetNamespaces }}
            targetNamespaces:
              {{ .operatorGroup.targetNamespaces }}
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
  {{- if and .enabled (eq .policyRef $policyName) }}
  {{- $configName := printf "%s-%s" $policyName .name }}
  {{- $severity := default "low" .severity }}
  {{- $remediationAction := default "inform" .remediationAction }}
    - objectDefinition:
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
