# PolicyStack ACM Policy Library Chart

A Helm chart library for creating and managing OpenShift Advanced Cluster Management (ACM) policies. This chart is meant to form that basis of the policy stack and enables you to define both configuration policies and operator policies and associate them with policy resources.
This library is mainly intended to be used in the PolicyStack GitOps implementation (hence why the configuration is under a `stack.<chartName>` dict)

## Usage

Add chart as a dependency in a `Chart.yaml`
```
dependencies:
  - name: policy-library
    alias: stack
    version: "3.x.x"
    repository: "repo"
```

`alias: stack` turns on `values.schema.json`. Helm validates a dependency's schema only against the values under its name, so the alias points it at `stack`. Without it, nothing is validated. An unknown key or a wrong type then fails the render:

```
Error: values don't meet the specifications of the schema(s) in the following chart(s):
stack:
- at '/myComponent': additional properties 'enabeld' not allowed
```

The schema closes every key in the tables below and accepts `null` for any of them. `config`, `templateParameters`, the selectors and `subscription.config` take any keys, and `toggles` takes any name with a boolean value. It does not check the component name or the root chart options. Helm adds a `global` key under `stack`, so don't `range` over `.Values.stack`.

Create a template that calls the policy library `render` function.
`{{- include "policy-library.render" . -}}`

## Configuration Reference
### Root Chart Options
All of these will need to be at the root of the values file.  
| Parameter | Description | Required |
|-----------|-------------|----------|
| `selector` | Label selector for the generated Placement. More information [here](#placement-overview) | No |
| `placement` | Extra `Placement.spec` fields (claim/CEL selectors, tolerations, clusterSets, ...). More information [here](#placement-overview) | No |
| `policyNamespace` | Namespace that these policies will be created in | Yes |
| `global.remediationAction` | `inform` sets `remediationAction: inform` on every Policy, which overrides every template: a dry run. `enforce` is rejected, since it would also enforce templates that must only inform. | No |
| `global.catalogSources` | Map of `subscription.source` to the CatalogSource every operator uses instead, e.g. `redhat-operators: cs-redhat-operator-index-v4-20` for an oc-mirror catalog. | No |

### Root Component Options
All of these will need to be under the `stack.<chartName>` dict. The chart name is taken from the chart of the parent but camelCased.  
| Parameter | Description | Required |
|-----------|-------------|----------|
| `enabled` | Defines whether to template this component at all. This is for helm. | Yes |
| `default.standards` | Default standards for each policy | No |
| `default.controls` | Default controls for each policy | No |
| `default.categories` | Default categories for each policy | No |
| `disablePlacements` | By default, a Placement and PlacementBinding are generated from the `selector` and `placement` keys. Set to true to disable them and use your own. | No |
| `usePolicySetsPlacements` | By default, the PlacementBinding binds the policies directly. When this is set to true, it binds the policySets instead of the policies themselves. | No |
| `orderPolicies` | When true, each policy in `policies[]` gets an ACM dependency on the previous one, so they are applied in declaration order. See [Policy Dependencies](#policy-dependencies). | No |
| `orderManifests` | When true, the policy-templates inside each policy get `extraDependencies` chaining them in render order. Overridable per policy. | No |
| `toggles` | Map keyed by an entry's `name` that overrides that entry's `enabled`. See [Toggles](#toggles). | No |
| `config` | Element settings read by its own converters. Not validated. | No |
| `suffixTemplateNames` | When true, every ConfigurationPolicy, OperatorPolicy and CertificatePolicy name gets `-<cluster>` appended, where `<cluster>` is `Release.Name` minus `<chart>-`. Dependencies on template kinds follow. Use it when one release per cluster is placed on the same cluster (e.g. the hub), since ACM requires template names to be unique per cluster. | No |

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
| `policies[].dependencies` | List of [dependency entries](#policy-dependencies) rendered into `spec.dependencies`. The policy stays `Pending` until they are satisfied. | No |
| `policies[].orderManifests` | Overrides the component-level `orderManifests` for this policy (set to `false` to opt this policy out). | No |
| `policies[].hubTemplateOptions.serviceAccountName` | ServiceAccount in the policy namespace that resolves this policy's `{{hub ... hub}}` templates. Without it, hub lookups are limited to the policy namespace. | No |

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
| `configPolicies[].pruneObjectBehavior` | What happens to objects this policy created when the policy is deleted: `None` (ACM default), `DeleteIfCreated` or `DeleteAll` | No |
| `configPolicies[].templateNames[].name` | Name of template file in converters directory w/o the .yaml | Yes |
| `configPolicies[].templateNames[].complianceType` | Compliance type for this specific file. Will default to musthave if the parent configPolicy complianceType is not set. | No |
| `configPolicies[].templateNames[].metadataComplianceType` | Compliance type for any metadata. This is independent of the complianceType value. | No |
| `configPolicies[].templateNames[].recordDiff` | Changes behavior of the diff in ACM | No |
| `configPolicies[].templateNames[].recreateOption` | Changes behavior of how the resources get recreated. | No |
| `configPolicies[].templateNames[].objectSelector` | Map that defines a label selector to select names of objects that are defined in an unnamed objectDefinition | No |
| `configPolicies[].enableTemplateParameters` | Boolean value that enables the use of the extra parameters. These will go under the .Parameters dict in the chart | No |
| `configPolicies[].templateParameters` | map of parameters that will be passed in each specific converter | No |
| `configPolicies[].extraDependencies` | List of [dependency entries](#policy-dependencies) gating just this ConfigurationPolicy | No |
| `configPolicies[].waitForOperator` | Key (or list of keys) in `operatorPolicies`. Waits for the generated CSV status check before applying this configuration. | No |
| `configPolicies[].ignorePending` | Treat this template as compliant while it is waiting on its dependencies | No |
| `configPolicies[].rawTemplate` | Emit the converter under `object-templates-raw` instead of `object-templates`. Requires exactly one `templateNames` entry. See [Raw object templates](#raw-object-templates). | No |

### Operator Policy Options
`operatorPolicies` is a map keyed by entry name, so a values layer can set one field of one operator (e.g. `operatorPolicies.oadp.versions`) without restating the rest. The key is the name; rendered objects are `<policyRef>-<key>`.

All of these will need to be under the `stack.<chartName>` dict. The chart name is taken from the chart of the parent but camelCased.  
| Parameter | Description | Required |
|-----------|-------------|----------|
| `operatorPolicies.<key>.enabled` | Enable or disable this operator policy | Yes |
| `operatorPolicies.<key>.description` | Description of the operator policy | No |
| `operatorPolicies.<key>.policyRef` | Policy to bind this operator to. The render fails without it. | Yes |
| `operatorPolicies.<key>.severity` | Override severity level | No |
| `operatorPolicies.<key>.remediationAction` | Override remediation action | No |
| `operatorPolicies.<key>.complianceType` | `musthave` (default) or `mustnothave`, which uninstalls the operator. See [Removing an operator](#removing-an-operator). | No |
| `operatorPolicies.<key>.namespace` | Namespace for operator installation | Yes |
| `operatorPolicies.<key>.displayName` | Display name for status check | No |
| `operatorPolicies.<key>.versions` | Exact CSV names allowed to install. See [Version pinning](#version-pinning). | No |
| `operatorPolicies.<key>.operatorGroup` | Whole block is optional. Omit it to get an OperatorGroup named after the subscription, installed cluster-scoped. Set `name` to reuse a namespace's existing OperatorGroup (`global-operators` in `openshift-operators`) - a second OperatorGroup in one namespace breaks OLM. | No |
| `operatorPolicies.<key>.operatorGroup.name` | Name of operator group | No |
| `operatorPolicies.<key>.operatorGroup.targetNamespaces` | List of target namespaces | No |
| `operatorPolicies.<key>.subscription.channel` | Channel for operator subscription | Yes |
| `operatorPolicies.<key>.subscription.name` | Name of operator package | Yes |
| `operatorPolicies.<key>.subscription.source` | Operator source | Yes |
| `operatorPolicies.<key>.subscription.sourceNamespace` | Source namespace | Yes |
| `operatorPolicies.<key>.subscription.startingCSV` | CSV to install first. Needed when the pinned CSV is not the channel head. | No |
| `operatorPolicies.<key>.subscription.config.tolerations` | Tolerations for operator | No |
| `operatorPolicies.<key>.upgradeApproval` | `Automatic` (default) or `None`. `Manual` is not valid; ACM rejects `subscription.installPlanApproval`. | No |
| `operatorPolicies.<key>.removalBehavior` | `operatorGroups`, `subscriptions`, `clusterServiceVersions`, `customResourceDefinitions`, passed to the OperatorPolicy. Used with `mustnothave`. Unset fields take ACM's defaults: `DeleteIfUnused`, `Delete`, `Delete`, `Keep`. | No |
| `operatorPolicies.<key>.extraDependencies` | List of [dependency entries](#policy-dependencies) gating the OperatorPolicy object | No |
| `operatorPolicies.<key>.waitForOperator` | Key (or list of keys) in `operatorPolicies` to wait on before installing this operator | No |
| `operatorPolicies.<key>.ignorePending` | Treat the OperatorPolicy as compliant while it is waiting on its dependencies | No |

Disable an operator in a layer with `enabled: false` or `toggles.<key>: false`, not `null`. Entries that name it in `waitForOperator` must be disabled in the same layer, or the render fails. Disabling stops managing the operator; it does not uninstall it. A layer key without `policyRef`, such as a typo of an element key, fails the render.

### Removing an operator

`complianceType: mustnothave` uninstalls the operator. The OperatorPolicy deletes what `removalBehavior` says, by default the Subscription, the CSV and the OperatorGroup if nothing else uses it, and keeps CRDs and the namespace. The namespace template is not rendered, so other operators in a shared namespace such as `openshift-operators` are untouched. The `-status` template reports NonCompliant until the CSV is gone. An entry that names it in `waitForOperator` fails the render. Disable the operator's operands first, or OLM removes the operator while its custom resources still exist.

### Version pinning

| `upgradeApproval` | `versions` | Effect |
|---|---|---|
| `Automatic` | empty | Installs and follows the channel |
| `Automatic` | set | Installs and upgrades only to listed CSVs or `subscription.startingCSV` |
| `None` | any | Initial install only; never approves an upgrade, even a listed one |

- Entries are exact CSV names (`oadp-operator.v1.4.2`), no ranges or wildcards. Comma-separated entries need ACM 2.14+, templated entries 2.13+.
- Set `subscription.startingCSV` when the pin is not the channel head; without it OLM resolves the head, which `versions` does not allow.
- Bump in two steps: add the new CSV next to the old one, promote it through your layers, then remove the old one and move `startingCSV` to the new one.
- Unpin with `versions: []`.

```yaml
# values layer, e.g. prod
stack:
  myComponent:
    operatorPolicies:
      oadp:
        subscription:
          startingCSV: oadp-operator.v1.4.1
        versions:
          - oadp-operator.v1.4.1
```

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
| `certificatePolicies[].minimumDuration` | Smallest remaining validity before a certificate is non-compliant, as a duration string (`720h`) | No |
| `certificatePolicies[].minimumCADuration` | Like minimumDuration but for CA certificates | No |
| `certificatePolicies[].maximumDuration` | Value to identify certificates that have been created with a duration that exceeds your limit | No |
| `certificatePolicies[].maximumCADuration` | Like maximumDuration but for CA certificates | No |
| `certificatePolicies[].allowedSANPattern` | regex taht must match every SAN entry that is defined in the certificates | No |
| `certificatePolicies[].disallowedSANPattern` | regex that must *not* match every SAN entry that is defined in the certificates | No |
| `certificatePolicies[].disableTemplating` | Disable templating inside the policy. This is mainly used for when a manifest has a templating agent inside the manifest | No |
| `certificatePolicies[].extraDependencies` | List of [dependency entries](#policy-dependencies) gating this CertificatePolicy | No |
| `certificatePolicies[].waitForOperator` | Key (or list of keys) in `operatorPolicies` to wait on | No |
| `certificatePolicies[].ignorePending` | Treat this template as compliant while it is waiting on its dependencies | No |

### PolicySet Options
All of these will need to be under the `stack.<chartName>` dict. The chart name is taken from the chart of the parent but camelCased.  
| Parameter | Description | Required |
|-----------|-------------|----------|
| `policySets[].name` | Name of the PolicySet | Yes |
| `policySets[].enabled` | Whether helm will template this policy set | Yes |
| `policySets[].policies` | List of policies that will be applied to the PolicySet | Yes |

## Policy Dependencies

ACM can hold a policy (or a single policy-template) in a `Pending` state until other objects report a
given compliance state. The chart exposes this at both levels:

- `policies[].dependencies` &rarr; `Policy.spec.dependencies` — gates the whole policy
- `configPolicies[]`/`operatorPolicies.<key>`/`certificatePolicies[]` `.extraDependencies` &rarr; `policy-templates[].extraDependencies` — gates one template
- `.ignorePending` &rarr; `policy-templates[].ignorePending` — the template counts as compliant while it waits

### Dependency entry fields

| Field | Description | Default |
|-------|-------------|---------|
| `name` | Name of the object being depended on, **as written in your values file** — the chart applies the same naming rules it used to generate the object | Required |
| `kind` | `Policy`, `ConfigurationPolicy`, `OperatorPolicy` or `CertificatePolicy` | `Policy` under `dependencies`, `ConfigurationPolicy` under `extraDependencies` |
| `compliance` | Compliance state to wait for (`Compliant`, `NonCompliant`, `Pending`) | `Compliant` |
| `policyRef` | For the template kinds, the policy that owns the object being referenced | The policy the dependency is declared under |
| `release` | For `kind: Policy`, the Helm release that rendered it — use this to depend on another PolicyStack component | `.Release.Name` |
| `element` | For `kind: Policy`, the *element* that rendered it. Resolves to `<name>-<element>-<cluster>`, reusing this release's own cluster suffix — so unlike `release` it stays correct on every cluster. See [Depending on another component](#depending-on-another-component). | — |
| `raw` | Use `name` verbatim, skipping all prefixing/suffixing | `false` |
| `namespace` | Explicit namespace override | `policyNamespace` for `kind: Policy`, otherwise omitted |
| `apiVersion` | Explicit apiVersion override | Derived from `kind` |

Name resolution mirrors how the chart generates objects:

| Dependency kind | Resolves to |
|---|---|
| `Policy` | `<name>-<release>` in `policyNamespace` |
| `Policy` + `element` | `<name>-<element>-<cluster>` in `policyNamespace` |
| `ConfigurationPolicy` / `OperatorPolicy` / `CertificatePolicy` | `<policyRef>-<name>`, with **no namespace** |

> The namespace is deliberately left off for the template kinds. Those objects are replicated into
> each managed cluster's own namespace, and ACM resolves that at evaluation time. Setting a namespace
> there means the dependency can never match.

### Automatic ordering

Instead of writing the chain out by hand, set the ordering flags:

```yaml
stack:
  myComponent:
    orderPolicies: true    # each policy depends on the previous one in policies[]
    orderManifests: true   # each policy-template depends on the previous one in its policy
```

`orderPolicies` skips policies that produce no ACM object (a policy with no sub-policies attached is
never rendered, so the chain links straight past it). `orderManifests` can be turned back off for a
single policy with `policies[].orderManifests: false`. Automatic entries are emitted alongside any
explicit `dependencies`/`extraDependencies` — ACM requires all of them, so the two can be combined.
`operatorPolicies` chain in sorted key order. An operator that waits on another operator in the same
policy needs a key that sorts after it, or the chain deadlocks; otherwise put them in separate policies.

Operator policies render three objects, and under `orderManifests` they are chained as
`<policy>-<operator>-ns` &rarr; `OperatorPolicy` &rarr; `<policy>-<operator>-status`, so the next
manifest in the policy waits for the operator's CSV to actually reach `Succeeded`.

### Waiting for an operator

`waitForOperator` names a key in `operatorPolicies` and expands to a dependency on that
operator's generated CSV status check. The owning policy is looked up from the component, so the
operator does not have to live under the same parent policy, and a typo fails the render:

```yaml
stack:
  myComponent:
    policies:
      - name: operators
        enabled: true
      - name: backup
        enabled: true
        dependencies:
          - name: operators          # -> operators-<release>, kind Policy

    operatorPolicies:
      oadp:
        enabled: true
        policyRef: operators
        namespace: openshift-adp
        subscription:
          channel: stable
          name: redhat-oadp-operator
          source: redhat-operators
          sourceNamespace: openshift-marketplace

    configPolicies:
      - name: dpa
        enabled: true
        policyRef: backup
        waitForOperator: oadp        # -> operators-oadp-status, kind ConfigurationPolicy
        ignorePending: true
        templateNames:
          - name: dpa
```

### Depending on another component

Each PolicyStack component is its own Helm release named `<element>-<cluster>`, so a `Policy` in
another component differs only in the *element* half of that suffix. Use `element` — the chart
reuses this release's own cluster suffix, so one line is correct on every cluster and can live in a
shared values file:

```yaml
policies:
  - name: config
    enabled: true
    dependencies:
      - name: install
        element: cert-manager        # -> install-cert-manager-<this cluster>
```

Rendered from release `node-maintenance-prod-east-1`, that resolves to
`install-cert-manager-prod-east-1` in `policyNamespace`.

`release` still works when you need to pin an exact release, and `raw` for a policy the chart did
not generate. Precedence is `raw` > `release` > `element` > `.Release.Name`:

```yaml
      - name: cluster-bootstrap
        release: platform-base-prod-east-1   # -> cluster-bootstrap-platform-base-prod-east-1
      - name: hand-made-policy
        raw: true                            # -> hand-made-policy
```

`element` is only valid for `kind: Policy`. The template kinds are replicated into each managed
cluster's own namespace and carry no release suffix, so a cross-component dependency must target the
owning `Policy`; using `element` on one fails the render.

> The cluster suffix is derived by stripping the chart name from `Release.Name`, so the release must
> be named `<chart-name>-<cluster>` — which is exactly what PolicyStack's ApplicationSet does. A
> release named otherwise fails the render with an explanatory message rather than silently
> producing a dependency that can never match.

### Toggles

`policies[]`, `configPolicies[]`, `certificatePolicies[]` and `policySets[]` are lists, and Helm
**replaces** lists rather than merging them. Without help, turning one sub-feature on for one cluster
means restating the entire list in that cluster's values file. `operatorPolicies` is a map and merges,
so `operatorPolicies.<key>.enabled` works per layer; toggles apply to its keys as well.

`toggles` is a component-level map keyed by an entry's `name` (the key, for `operatorPolicies`). When a key is present it overrides
that entry's `enabled`:

```yaml
stack:
  certManager:
    enabled: true
    toggles:
      api-cert: true       # entry declared `enabled: false` -> rendered
      ingress-cert: false  # entry declared `enabled: true`  -> not rendered
```

Because it is a map it merges cleanly through the whole values cascade, so a per-cluster override is
one line. Toggles are applied everywhere `enabled` is evaluated — policy rendering, PlacementBinding
subjects, PolicySets, and the `waitForOperator` lookup — so a toggled-off entry disappears
completely rather than leaving a dangling reference. Entry names should be unique across the lists
within a component.

### Raw object templates

`object-templates-raw` is an ACM field that takes a single template string and *replaces*
`object-templates`. Use it when the manifest must emit a **variable number of objects** decided on
the managed cluster — an ACM `lookup` combined with a `range` — which `object-templates` cannot
express.

```yaml
configPolicies:
  - name: machinesets
    enabled: true
    policyRef: nodes
    rawTemplate: true        # exactly one templateNames entry
    templateNames:
      - name: machineset
```

The converter is rendered by Helm as usual and its output is emitted verbatim under
`object-templates-raw`, so it must produce the full list of `- complianceType: / objectDefinition:`
entries itself. Braces meant for ACM have to be escaped from Helm:

```yaml
{{- range $zone, $cfg := .Parameters.zones }}
- complianceType: musthave
  objectDefinition:
    apiVersion: machine.openshift.io/v1beta1
    kind: MachineSet
    metadata:
      name: {{ "{{" }} (lookup "config.openshift.io/v1" "Infrastructure" "" "cluster").status.infrastructureName {{ "}}" }}-{{ $zone }}
    spec:
      replicas: {{ $cfg.replicas }}
{{- end }}
```

Here the Helm `range` resolves at render time from values, while the escaped `lookup` survives to
the managed cluster for ACM to evaluate. Setting `rawTemplate: true` with more than one
`templateNames` entry fails the render.

Note this is unrelated to `disableTemplating`, which sets
`policy.open-cluster-management.io/disable-templates` and stops **ACM** from evaluating templates.
Escaping is what protects braces from Helm; `disableTemplating` is for manifests whose `{{ }}` is
meant for some other engine entirely.


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
      oadp-operator:
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
## Placement Overview
Each release renders one `cluster.open-cluster-management.io/v1beta1` Placement and, when there is at least one enabled
Policy (or PolicySet with `usePolicySetsPlacements`) to bind, one PlacementBinding. Both are named after the release and
created in `policyNamespace`.

```yaml
selector:               #top level selector map
  matchExpressions:     #matches labels on managedCluster resources
    environment:        #Key for this specific label. Map is used to allow for stacking of these labels to fine tune cluster deployment.
      key: environment  #Label to match to
      operator: In      #Operator for label value
      values:           #List of values to match
        - dev

placement:              #optional, top level. Merged into the Placement spec
  claimSelector:        #ANDed with selector: match ClusterClaims (e.g. platform.open-cluster-management.io)
    matchExpressions:
      - key: platform.open-cluster-management.io
        operator: In
        values:
          - AWS
  celSelector:          #ANDed with selector: CEL expressions against the ManagedCluster (ACM 2.14+)
    celExpressions:
      - managedCluster.metadata.labels["vendor"] == "OpenShift"
  # tolerations: []     #omit to tolerate the unreachable/unavailable taints (default); [] drops disconnected clusters
  predicates: []        #extra predicates, ORed with the generated one
  clusterSets:          #any other Placement.spec field (clusterSets, numberOfClusters, prioritizerPolicy, ...) is passed through verbatim
    - global
```

- `selector`, `claimSelector` and `celSelector` form a single predicate, so a cluster must match all of them. Entries
  in `placement.predicates` are ORed with it and widen the placement.
- When `tolerations` is not set (or null), the Placement tolerates `cluster.open-cluster-management.io/unreachable` and
  `cluster.open-cluster-management.io/unavailable`, so policies stay bound (with their status history) while a cluster is
  disconnected. Set `tolerations: []` to drop disconnected clusters from the placement instead.
- A Placement only selects clusters from ManagedClusterSets bound to its namespace. `policyNamespace` needs a
  ManagedClusterSetBinding (e.g. for the `global` set), plus one for each other set listed in `clusterSets`.
## Notes

- Policies without attached configuration or operator policies will not be created
- Templates in the `converters/` directory should be valid Kubernetes manifests
- Dependencies are evaluated on each managed cluster, so a policy can be `Pending` on one cluster and `Compliant` on another
- The chart automatically adds namespace and status verification policies for operators
- Every Policy sets `copyPolicyMetadata: false`, so ACM does not copy Argo CD's tracking labels and annotations onto the replicated Policies, which would otherwise let Argo CD prune them. Replicas keep the `policy.open-cluster-management.io/*` annotations but not `description`
- For more reading on documentation. Please view the [ACM Policies Documentation](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.13/html/governance/governance#kubernetes-config-policy-controller)

## Resources Created

For each release, the chart creates:
- A Policy resource per enabled policy
- A Placement resource
- A PlacementBinding resource, when there is at least one enabled Policy/PolicySet to bind
- ConfigurationPolicy / OperatorPolicy / CertificatePolicy / PolicySet resources as defined
