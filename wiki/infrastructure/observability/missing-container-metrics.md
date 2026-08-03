---
id: infrastructure-observability-missing-container-metrics
domain: infrastructure
category: observability
applies_to: [kubernetes, kube-prometheus-stack]
confidence: verified
sources:
  - https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/
  - https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/values.yaml
  - https://raw.githubusercontent.com/kubernetes-monitoring/kubernetes-mixin/master/dashboards/resources/queries/pod.libsonnet
  - https://github.com/orbstack/orbstack/issues/2217
last_verified: 2026-07-28
related: [infrastructure-observability-logs-metrics-signals, infrastructure-containers-resource-limits-and-probes]
---

# Container Metrics Empty While Kubelet Scrape Targets Report Up

## When this applies

Monitoring pod CPU/memory with Prometheus (e.g. kube-prometheus-stack) and
`container_*` series are empty or dashboards show nothing, while every kubelet
scrape target is healthy ("up"). Common on embedded/VM Kubernetes distributions
(observed on OrbStack) whose kubelet cAdvisor endpoint emits only `machine_*`
series.

## Do this

1. Diagnose by series presence, not target health — a successful scrape of an
   endpoint that emits no `container_*` series still shows "up":

```
kubectl get --raw /api/v1/nodes/<node>/proxy/metrics/cadvisor | grep -c '^container_'
kubectl get --raw /api/v1/nodes/<node>/proxy/metrics/resource | grep -c '^container_'
```

2. When cAdvisor emits no `container_*` series but `/metrics/resource` does,
   scrape the kubelet resource endpoint instead. It serves
   `container_cpu_usage_seconds_total` and `container_memory_working_set_bytes`
   (defined in kubelet's resource-metrics collector). In kube-prometheus-stack
   values:

```yaml
kubelet:
  serviceMonitor:
    resource: true
    resourcePath: "/metrics/resource"
```

   Both lines are required: the chart's default `resourcePath` is still
   `/metrics/resource/v1alpha1` (renamed in Kubernetes 1.18), which 404s on
   modern kubelets — enabling `resource: true` alone produces a down target.

3. Expect the bundled "Compute Resources" dashboards to stay empty even after
   the data arrives: kubernetes-mixin dashboard queries and recording rules
   filter with `image!=""`, and `/metrics/resource` series carry no `image`
   label (only container/pod/namespace). Build a custom dashboard or recording
   rules against the resource-endpoint series directly.

## Edge cases

| Case | Then |
|------|------|
| You need per-container filesystem, network, or throttling metrics | `/metrics/resource` carries only CPU and memory; those richer series exist only in cAdvisor — fix or replace the runtime's cAdvisor support instead |
| Dashboards empty but PromQL on the raw series returns data | You are hitting the `image!=""` filter, not a collection gap — adjust the queries, not the scrape |
| Verifying the fix | Query `container_memory_working_set_bytes{container!=""}` directly in Prometheus and compare one pod against `kubectl top pod` |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Conclude "metrics are being collected" from all-green scrape targets | Count the specific series you need at the source endpoint | Scrape health checks the HTTP exchange, not whether the series you consume exist |
| Enable `kubelet.serviceMonitor.resource: true` and stop | Also set `resourcePath: "/metrics/resource"` | The chart default still points at the pre-1.18 `v1alpha1` path, which 404s |

## Sources

- https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/ — kubelet `/metrics/resource` endpoint in the resource metrics pipeline
- https://raw.githubusercontent.com/kubernetes/kubernetes/master/pkg/kubelet/metrics/collectors/resource_metrics.go — the endpoint's exact series: `container_cpu_usage_seconds_total`, `container_memory_working_set_bytes`
- https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/values.yaml — `kubelet.serviceMonitor.resource` (default false) and `resourcePath` (default `/metrics/resource/v1alpha1`, comment: renamed in k8s 1.18)
- https://raw.githubusercontent.com/kubernetes-monitoring/kubernetes-mixin/master/dashboards/resources/queries/pod.libsonnet — `container_memory_working_set_bytes{..., image!=""}` filter; same pattern in `rules/apps.libsonnet` recording rules
- https://github.com/orbstack/orbstack/issues/2217 — corroborates node-level metrics working while container-level silently missing on OrbStack embedded k8s (the machine_*-only cAdvisor observation itself is field-tested, 2026-07-15)
