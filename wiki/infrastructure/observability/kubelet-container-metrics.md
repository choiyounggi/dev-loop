---
id: infrastructure-observability-kubelet-container-metrics
domain: infrastructure
category: observability
applies_to: [kubernetes, prometheus]
confidence: verified
sources:
  - https://kubernetes.io/docs/reference/instrumentation/node-metrics/
  - https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/values.yaml
  - https://github.com/kubernetes-monitoring/kubernetes-mixin/blob/master/dashboards/resources/queries/pod.libsonnet
last_verified: 2026-07-15
related: [infrastructure-observability-logs-metrics-signals, infrastructure-containers-resource-limits-and-probes]
---

# Empty container_* Metrics Though Kubelet Targets Are Up (kube-prometheus-stack)

## When this applies

Prometheus (kube-prometheus-stack) shows every kubelet target as `up`, but
`container_cpu_*` / `container_memory_*` queries return nothing — typically on a
lightweight or embedded Kubernetes (OrbStack, k3s, kind, colima) whose kubelet
cAdvisor endpoint does not produce per-container series.

## Do this

1. Confirm what cAdvisor actually emits — target health cannot detect this,
   because the scrape itself succeeds while returning only `machine_*` series:

   ```sh
   kubectl get --raw /api/v1/nodes/<node>/proxy/metrics/cadvisor | grep -c '^container_'
   ```

   0 matches with a healthy target means the source is empty, not the scrape.

2. Scrape the kubelet's resource-metrics endpoint instead. In
   kube-prometheus-stack values, two lines:

   ```yaml
   kubelet:
     serviceMonitor:
       resource: true
       resourcePath: "/metrics/resource"
   ```

   `resourcePath` must be set explicitly: the chart default is the pre-1.18 path
   `/metrics/resource/v1alpha1` (the chart's own comment notes the rename), which
   404s on current kubelets and leaves the new target down.

3. Verify end to end: the `kubelet` target for the resource path is `up`, and
   `container_memory_working_set_bytes` returns live values in PromQL.

4. View these series on a custom dashboard (or panels without an `image` filter).
   `/metrics/resource` series carry a different label set than cAdvisor — notably
   no `image` label — and the bundled kubernetes-mixin "Compute Resources"
   dashboards filter on `image!=""`, which silently drops every resource-endpoint
   series.

## Edge cases

| Case | Then |
|------|------|
| PromQL returns data but the built-in dashboards stay blank | That is the `image!=""` (and `container!=""`) mixin filter, not a scrape problem — chart the same query without the image filter |
| cAdvisor emits `container_*` fine on the same cluster | Keep cAdvisor as the source; `/metrics/resource` has fewer series (CPU/memory only — no network, filesystem, or throttling metrics) |
| Recording rules / alerts reference cAdvisor label sets | Rules built on `image`/`id` labels will not match resource-endpoint series — rewrite them against the reduced label set before trusting the alerts |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Judge metric availability from target health (`up == 1`) | Curl the endpoint and count the series you need | A scrape can succeed while the exporter emits none of the series you care about |
| Debug the ServiceMonitor because dashboards are empty | Run the dashboard's PromQL by hand first | If data exists, the gap is the dashboard's label filter, not collection |
| Enable `resource: true` alone | Also set `resourcePath: "/metrics/resource"` | The chart default path is the removed v1alpha1 endpoint — the target 404s |

## Sources

- https://kubernetes.io/docs/reference/instrumentation/node-metrics/ — `/metrics/resource` is the current kubelet resource-metrics endpoint
- https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/values.yaml — `kubelet.serviceMonitor.resource` (default `false`) and `resourcePath` (default `/metrics/resource/v1alpha1`, comment: renamed in Kubernetes 1.18)
- https://github.com/kubernetes-monitoring/kubernetes-mixin/blob/master/dashboards/resources/queries/pod.libsonnet — pod resource queries filter `image!=""` and `container!=""`
- Field observation (OrbStack, 2026-07-14): kubelet cAdvisor endpoint served only `machine_*` series (`container_*` count 0, `machine_scrape_error` 0) while targets were `up`; after the two-line change, `container_memory_working_set_bytes` returned live per-pod values
