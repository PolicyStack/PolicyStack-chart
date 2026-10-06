# Test fixtures

`fixtures/policy-stack-test` is a throwaway consuming chart used to render `policy-library` locally.
Its chart name (`policy-stack-test`) camelCases to the `stack.policyStackTest` key.

```bash
cd tests/fixtures/policy-stack-test

# Pick up the local library chart (re-run after every change to charts/policy-library)
helm dependency update .

# Baseline: uses none of the dependency/ordering keys
helm template test .

# Every dependency / ordering key
helm template test . -f values-dependencies.yaml

# Every placement key (2.0.0)
helm template test . -f values-2.0.yaml

# suffixTemplateNames (2.1.0); needs a "<chart>-<cluster>" release name
helm template policy-stack-test-c1 . -f values-dependencies.yaml -f values-2.1.yaml

helm lint .
```

`values.yaml` is deliberately conservative — it is the backwards-compatibility baseline. Capture its
render before a change and diff it afterwards; anything that does not use the new keys should render
byte-identically:

```bash
git stash && helm dependency update . >/dev/null && helm template test . > /tmp/before.yaml
git stash pop && helm dependency update . >/dev/null && helm template test . > /tmp/after.yaml
diff -u /tmp/before.yaml /tmp/after.yaml
```
