---
id: infrastructure-observability-kubelet-resource-metrics
domain: infrastructure
category: observability
applies_to: [kubernetes]
confidence: verified
sources:
  - https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/values.yaml
  - https://kubernetes.io/docs/reference/instrumentation/metrics/
  - https://kubernetes.io/docs/concepts/cluster-administration/system-metrics/
  - https://github.com/kubernetes/kubernetes/pull/86282
  - https://github.com/kubernetes-monitoring/kubernetes-mixin
last_verified: 2026-07-15
related: [infrastructure-observability-logs-metrics-signals, infrastructure-containers-resource-limits-and-probes]
---

# Empty cAdvisor `container_*` Metrics on a Lightweight Kubelet

## When this applies

You installed kube-prometheus-stack and pod CPU/memory series
(`container_cpu_usage_seconds_total`, `container_memory_working_set_bytes`) are
empty in Prometheus/Grafana, yet every kubelet scrape target shows UP. Common on
lightweight kubelets (OrbStack, kind, k3s) whose cAdvisor endpoint scrapes fine
but emits no per-container series.

## Do this

A scrape target being UP means the endpoint answered — not that it produced the
series you expected. Confirm the series with a PromQL query, not the target list.

1. Verify the gap at the series level: query `container_memory_working_set_bytes`
   directly. If cAdvisor (`/metrics/cadvisor`) returns only `machine_*` and no
   `container_*`, the fix is to scrape the kubelet's separate resource-metrics
   endpoint instead of relying on cAdvisor.
2. Enable `/metrics/resource` in the kube-prometheus-stack Helm values — and
   override the path, because the chart default is stale:

| Value | Set to | Why |
|-------|--------|-----|
| `kubelet.serviceMonitor.resource` | `true` | Default is `false` ("container metrics are already exposed by cAdvisor" — which is the assumption that fails here) |
| `kubelet.serviceMonitor.resourcePath` | `/metrics/resource` | Chart default `/metrics/resource/v1alpha1` was removed in Kubernetes 1.20 and returns 404 on any modern kubelet — leaving that default makes the new target go down |

3. Read the resource series with a custom query/dashboard. The `/metrics/resource`
   endpoint labels series with `namespace`, `pod`, `container` only — there is **no
   `image` label**. The bundled kubernetes-mixin "Compute Resources" dashboards
   select cAdvisor series with `job="cadvisor"`, `metrics_path="/metrics/cadvisor"`,
   and `image!=""`, so they exclude the resource-endpoint series entirely — build a
   custom panel rather than expecting the stock dashboard to light up.

## Edge cases

| Case | Then |
|------|------|
| Target UP but `container_*` count is 0 | Scrape success ≠ series creation — switch to `/metrics/resource`; do not trust the target list as a metrics-health signal |
| New resource target shows DOWN (404) | `resourcePath` is still the default `/metrics/resource/v1alpha1`; set it to `/metrics/resource` |
| Root cause of the empty cAdvisor is unknown (e.g. OrbStack — field-observed, not documented upstream) | Apply the fix anyway; `/metrics/resource` is an independent kubelet endpoint and does not depend on why cAdvisor is empty |
| Stock "Compute Resources" dashboard still blank after enabling resource | Its `image!=""`/`job="cadvisor"` selectors also exclude the series — query the raw metric in a custom panel |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Conclude metrics are healthy because kubelet targets are UP | Query the actual series in PromQL | A successful scrape does not guarantee the series were generated |
| Fix a blank mixin dashboard by dropping only the `image!=""` filter | Query `/metrics/resource` series in a custom panel | The mixin also pins `job="cadvisor"`/`metrics_path="/metrics/cadvisor"`, so the series stay excluded |
| Trust the chart's default `resourcePath` | Set `resourcePath: /metrics/resource` explicitly | The default points at the v1alpha1 path removed in k8s 1.20 (404) |

## Sources

- https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/values.yaml — `kubelet.serviceMonitor.resource` (default false) and `resourcePath` (default `/metrics/resource/v1alpha1`)
- https://kubernetes.io/docs/reference/instrumentation/metrics/ — `/metrics/resource` metrics and their `namespace`/`pod`/`container` labels (no `image`)
- https://kubernetes.io/docs/concepts/cluster-administration/system-metrics/ — kubelet `/metrics/resource` endpoint
- https://github.com/kubernetes/kubernetes/pull/86282 — removal of the `/metrics/resource/v1alpha1` path
- https://github.com/kubernetes-monitoring/kubernetes-mixin — Compute Resources dashboards select cAdvisor series with `image!=""` / `job="cadvisor"`
