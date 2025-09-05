# PolicyStack ACM Policy Library Chart

A Helm chart library for creating and managing OpenShift Advanced Cluster Management (ACM) policies. This chart is meant to form that basis of the policy stack and enables you to define both configuration policies and operator policies and associate them with policy resources.
This library is mainly intended to be used in the PolicyStack GitOps implementation (hence why the configuration is under a `stack.<chartName>` dict)

## Usage

Add chart as a dependency in a `Chart.yaml`
```
dependencies:
  - name: policy-library
    version: "1.x.x"
    repository: "repo"
```

Create a template that calls the policy library `render` function.
`{{- include "policy-library.render" . -}}`

## Configuration Reference
### Root Chart Options
All of these will need to be at the root of the values file.  
| Parameter | Description | Required |
|-----------|-------------|----------|
| `selector` | If using default placements, the selector map can be used. More information [here](#selector-overview) | No |
| `policyNamespace` | Namespace that these policies will be created in | Yes |

### Root Component Options
All of these will need to be under the `stack.<chartName>` dict. The chart name is taken from the chart of the parent but camelCased.  
| Parameter | Description | Required |
|-----------|-------------|----------|
| `enabled` | Defines whether to template this component at all. This is for helm. | Yes |
| `default.standards` | Default standards for each policy | No |
| `default.controls` | Default controls for each policy | No |
| `default.categories` | Default categories for each policy | No |
| `disablePlacements` | By default, placementrules and placementbindings will be generated based on a `selector` key. Set to true to disable those placements to use your own. | No |
| `usePolicySetsPlacements` | By default, placementrules and placement bindings are generated for the policies directly. When this is set to true, the rules/bindings will be generated for the policySets instead of the policies themselves. | No |

### Custom Policy Options
All of these will need to be under the `stack.<chartName>` dict. The chart name is taken from the chart of the parent but camelCased.  
| Parameter | Description | Required |
|-----------|-------------|----------|
| `policies[].name` | Name of the policy | Yes |
| `policies[].enabled` | Whether the policy will be even templated or not. This is a helm variable. | Yes |
| `policies[].namespace` | Namespace for this policy | Yes |
| `policies[].description` | Description of the policy | No |
| `policies[].categories` | List of categories for the policy | No |
| `policies[].controls` | List of controls for the policy | No |
| `policies[].standards` | List of standards for the policy | No |
| `policies[].severity` | Severity level | No |
| `policies[].remediationAction` | Action to take when policy is violated | No |
| `policies[].disabled` | Whether the policy is disabled on the ACM side. | No |

### Configuration Policy Options
All of these will need to be under the `stack.<chartName>` dict. The chart name is taken from the chart of the parent but camelCased.  
| Parameter | Description | Required |
|-----------|-------------|----------|
| `configPolicies[].name` | Name of the configuration policy | Yes |
| `configPolicies[].enabled` | Enable or disable this configuration policy | Yes |
| `configPolicies[].description` | Description of the configuration policy | No |
| `configPolicies[].customMessage.compliant` | Custom message for compliant policies. If using GO templating inside this, the whole thing must be quoted. | No |
| `configPolicies[].customMessage.noncompliant` | Custom message for noncompliant policies. If using GO templating inside this, the whole thing must be quoted. | No |
| `configPolicies[].evaluationInterval.compliant` | Swap the policy to polling mode and define length between polls for compliant policies | No |
| `configPolicies[].evaluationInterval.noncompliant` | Swap the policy to polling mode and define length between polls for noncompliant policies | No |
| `configPolicies[].namespaceSelector` | Map of selectors. Used for namespaced objects that do not have a namespace specified. | No |
| `configPolicies[].disableTemplating` | Disable templating inside the policy. This is mainly used for when a manifest has a templating agent inside the manifest | No |
| `configPolicies[].policyRef` | Policy to bind this configuration to | Yes |
| `configPolicies[].severity` | Override severity level | No |
| `configPolicies[].remediationAction` | Override remediation action | No |
| `configPolicies[].complianceType` | Compliance type (musthave, mustnothave, mustonlyhave) | No |
| `configPolicies[].templateNames[].name` | Name of template file in converters directory w/o the .yaml | Yes |
| `configPolicies[].templateNames[].complianceType` | Compliance type for this specific file. Will default to musthave if the parent configPolicy complianceType is not set. | No |
| `configPolicies[].templateNames[].metadataComplianceType` | Compliance type for any metadata. This is independent of the complianceType value. | No |
| `configPolicies[].templateNames[].recordDiff` | Changes behavior of the diff in ACM | No |
| `configPolicies[].templateNames[].recreateOption` | Changes behavior of how the resources get recreated. | No |
| `configPolicies[].templateNames[].objectSelector` | Map that defines a label selector to select names of objects that are defined in an unnamed objectDefinition | No |
| `configPolicies[].enableTemplateParameters` | Boolean value that enables the use of the extra parameters. These will go under the .Parameters dict in the chart | No |
| `configPolicies[].templateParameters` | map of parameters that will be passed in each specific converter | No |

### Operator Policy Options
All of these will need to be under the `stack.<chartName>` dict. The chart name is taken from the chart of the parent but camelCased.  
| Parameter | Description | Required |
|-----------|-------------|----------|
| `operatorPolicies[].name` | Name of the operator policy | Yes |
| `operatorPolicies[].enabled` | Enable or disable this operator policy | Yes |
| `operatorPolicies[].description` | Description of the operator policy | No |
| `operatorPolicies[].policyRef` | Policy to bind this operator to (empty for default) | No |
| `operatorPolicies[].severity` | Override severity level | No |
| `operatorPolicies[].remediationAction` | Override remediation action | No |
| `operatorPolicies[].complianceType` | Compliance type (musthave, mustnothave, mustonlyhave) | No |
| `operatorPolicies[].namespace` | Namespace for operator installation | Yes |
| `operatorPolicies[].displayName` | Display name for status check | No |
| `operatorPolicies[].versions` | List of approved versions for policies to install. Recommend to set upgradeApproval to `Automatic` | No |
| `operatorPolicies[].operatorGroup.name` | Name of operator group | No |
| `operatorPolicies[].operatorGroup.targetNamespaces` | List of target namespaces | No |
| `operatorPolicies[].subscription.channel` | Channel for operator subscription | Yes |
| `operatorPolicies[].subscription.name` | Name of operator package | Yes |
| `operatorPolicies[].subscription.source` | Operator source | Yes |
| `operatorPolicies[].subscription.sourceNamespace` | Source namespace | Yes |
| `operatorPolicies[].subscription.startingCSV` | Starting CSV version | No |
| `operatorPolicies[].subscription.config.tolerations` | Tolerations for operator | No |
| `operatorPolicies[].upgradeApproval` | Upgrade approval (Automatic or None) | No |

### Certificate Policy Options
All of these will need to be under the `stack.<chartName>` dict. The chart name is taken from the chart of the parent but camelCased.  
| Parameter | Description | Required |
|-----------|-------------|----------|
| `certificatePolicies[].name` | Name of the certificate policy | Yes |
| `certificatePolicies[].enabled` | Enable or disable this certificate policy | Yes |
| `certificatePolicies[].description` | Description of the certificate policy | No |
| `certificatePolicies[].policyRef` | Policy to bind this certificate policy to | Yes |
| `certificatePolicies[].namespaceSelector` | Map of selectors. Used to select which certificates to manage | No |
| `certificatePolicies[].labelSelector` | Map of selectors. Used to select which certificates to manage by labels | No |
| `certificatePolicies[].remediationAction` | Override remediation action | No |
| `certificatePolicies[].severity` | Override severity level | No |
| `certificatePolicies[].minimumDuration` | Specifies the smallest duration (in hours) before a certificate is considered non-compliant | No |
| `certificatePolicies[].minimumCADuration` | Like minimumDuration but for CA certificates | No |
| `certificatePolicies[].maximumDuration` | Value to identify certificates that have been created with a duration that exceeds your limit | No |
| `certificatePolicies[].maximumCADuration` | Like maximumDuration but for CA certificates | No |
| `certificatePolicies[].allowedSANPattern` | regex taht must match every SAN entry that is defined in the certificates | No |
| `certificatePolicies[].disallowedSANPattern` | regex that must *not* match every SAN entry that is defined in the certificates | No |
| `certificatePolicies[].disableTemplating` | Disable templating inside the policy. This is mainly used for when a manifest has a templating agent inside the manifest | No |

### PolicySet Options
All of these will need to be under the `stack.<chartName>` dict. The chart name is taken from the chart of the parent but camelCased.  
| Parameter | Description | Required |
|-----------|-------------|----------|
| `certificatePolicies[].name` | Name of the PolicySet | Yes |
| `certificatePolicies[].enabled` | Whether helm will template this policy set | Yes |
| `certificatePolicies[].policies` | List of policies that will be applied to the PolicySet | Yes |


## Example: Deploying Multiple Policies

```yaml
# values.yaml
policyNamespace: open-cluster-management

selector:
  matchExpressions:
    environment:
      key: environment
      operator: In
      values:
        - dev

stack:
  parentChartName:
    default:
      categories:
        - CM Configuration Management
      controls:
        - CM-2 Baseline Configuration
      standards:
        - NIST SP 800-53

    policies:
      - name: security-policy
        enabled: true
        namespace: open-cluster-management
        description: "Security configurations"
        severity: high
        remediationAction: enforce

    configPolicies:
      - name: test-cm
        enabled: true
        disableTemplating: true
        description: "Test ConfigMap"
        policyRef: security-policy
        severity: medium
        remediationAction: enforce
        complianceType: musthave
        templateNames:
          - cm
        enableTemplateParameters: true
        templateParameters:
          name: testcm
          value1: somethingidk2

    operatorPolicies:
      - name: oadp-operator
        enabled: true
        description: "Operator policy for OpenShift ADP"
        displayName: "OADP Operator"
        policyRef: security-policy
        severity: medium
        remediationAction: enforce
        complianceType: musthave
        namespace: openshift-adp
        operatorGroup:
          name: openshift-adp-group  # Optional, defaults to subscription name if not provided
          targetNamespaces:
            - openshift-adp
        subscription:
          channel: stable
          name: redhat-oadp-operator
          source: redhat-operators
          sourceNamespace: openshift-marketplace
          startingCSV: oadp-operator.v1.5.0
        upgradeApproval: Automatic
        versions:
          - oadp-operator.v1.5.0
```
## Selector Overview
```yaml
selector:               #top level selector map
  matchExpressions:     #matches labels on managedCluster resources
    environment:        #Key for this specific label. Map is used to allow for stacking of these labels to fine tune cluster deployment.
      key: environment  #Label to match to
      operator: In      #Operator for label value
      values:           #List of values to match
        - dev
```
## Notes

- Policies without attached configuration or operator policies will not be created
- Templates in the `converters/` directory should be valid Kubernetes manifests
- The chart automatically adds namespace and status verification policies for operators
- For more reading on documentation. Please view the [ACM Policies Documentation](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.13/html/governance/governance#kubernetes-config-policy-controller)

## Resources Created

For each policy, the chart creates:
- A Policy resource
- A PlacementRule resource
- A PlacementBinding resource
- ConfigurationPolicy / OperatorPolicy / CertificatePolicy / PolicySet resources as defined
