---
id: infrastructure-observability-container-metrics-when-cadvisor-is-empty
domain: infrastructure
category: observability
applies_to: [kubernetes, prometheus, local-dev]
confidence: verified
sources:
  - https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/values.yaml
  - https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/metrics/collectors/resource_metrics.go
  - https://github.com/kubernetes-monitoring/kubernetes-mixin/blob/master/dashboards/resources/queries/pod.libsonnet
  - https://github.com/orbstack/orbstack/issues/1561
last_verified: 2026-07-14
related: [infrastructure-containers-resource-limits-and-probes, infrastructure-observability-logs-metrics-signals]
---

# Collecting Container Metrics When the Kubelet cAdvisor Endpoint Is Empty

## When this applies

Running kube-prometheus-stack (or any Prometheus scraping the kubelet) on an
embedded/local Kubernetes distribution (OrbStack; potentially other
lightweight runtimes) and per-container `container_*` series are absent —
while every kubelet scrape target reports **up** and dashboards render only
node-level panels.

## Do this

1. Confirm the gap at the source, not via target health — a cAdvisor endpoint
   that returns only `machine_*` series is still a *successful* scrape:

   ```sh
   kubectl get --raw /api/v1/nodes/<node>/proxy/metrics/cadvisor | grep -c '^container_'
   kubectl get --raw /api/v1/nodes/<node>/proxy/metrics/resource | grep -c '^container_'
   ```

   If cAdvisor shows 0 but `/metrics/resource` shows real values, switch the
   scrape source instead of debugging the scrape.

2. Enable the kubelet resource-metrics scrape in kube-prometheus-stack values,
   and override the path — the chart's default still points at the pre-1.18
   versioned path, which 404s on current kubelets:

   ```yaml
   kubelet:
     serviceMonitor:
       resource: true
       resourcePath: "/metrics/resource"   # chart default is /metrics/resource/v1alpha1
   ```

3. Chart these series on a custom dashboard, not the bundled
   "Compute Resources" dashboards. `/metrics/resource` exposes
   `container_cpu_usage_seconds_total` and `container_memory_working_set_bytes`
   with only `container, pod, namespace` labels (no `image`), while the bundled
   kubernetes-mixin queries select `metrics_path="/metrics/cadvisor"` and filter
   `image!=""` — both conditions exclude the resource-endpoint series.

4. Treat `/metrics/resource` as the core-usage subset it is: CPU seconds and
   working-set bytes per container/pod/node (it is what metrics-server reads).
   Filesystem, network, and throttling detail exists only in cAdvisor; if you
   need those on such a cluster, they are simply unavailable from the kubelet.

## Edge cases

| Case | Then |
|------|------|
| Resource-metrics target shows **down** with 404 after enabling `resource: true` | The path override was missed — set `resourcePath: "/metrics/resource"` (the unversioned GA path) |
| Bundled dashboards stay empty after the scrape works | Expected — mixin queries require `metrics_path="/metrics/cadvisor"` and `image!=""`; build panels that query the series without those selectors |
| Verifying whether the same gap exists on another local distro | Run the two `kubectl get --raw` probes from step 1 first; only the endpoint contents distinguish "scrape broken" from "endpoint empty" |
| Production/managed cluster (EKS/GKE/AKS) missing `container_*` | Different failure — cAdvisor works there; check kubelet scrape auth, relabeling drops, and job selectors before touching `resourcePath` |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Debug the scrape because targets are up but `container_*` is empty | Probe the endpoint bodies with `kubectl get --raw` (step 1) | A cAdvisor endpoint emitting only `machine_*` scrapes "successfully"; target health cannot detect an empty metric family |
| Enable `resource: true` alone and trust the chart default path | Also set `resourcePath: "/metrics/resource"` | The chart default `/metrics/resource/v1alpha1` predates the k8s 1.18 rename and 404s on current kubelets |
| Wait for the bundled Compute Resources dashboards to light up | Build a custom dashboard on the resource-endpoint series | Mixin queries hard-filter on `metrics_path="/metrics/cadvisor"` and `image!=""`, which the resource endpoint's label set can never satisfy |

## Notes on evidence

The mechanism rows above are verified against the primary sources below. The
OrbStack-specific claim — its kubelet cAdvisor endpoint emits `machine_*` but
zero `container_*` series — is **field-tested** (first-hand probe on OrbStack
1.x, 2026-07-14: cAdvisor `container_` count 0 with `machine_scrape_error 0`,
`/metrics/resource` returning real working-set values), corroborated by the
OrbStack tracker discussion of missing metrics integrations.

## Sources

- https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/values.yaml — `kubelet.serviceMonitor.resource` disabled by default; `resourcePath` default `/metrics/resource/v1alpha1` with the "renamed in 1.18" comment
- https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/metrics/collectors/resource_metrics.go — `/metrics/resource` exposes `container_cpu_usage_seconds_total` / `container_memory_working_set_bytes` with labels `container, pod, namespace` only (STABLE)
- https://github.com/kubernetes-monitoring/kubernetes-mixin/blob/master/dashboards/resources/queries/pod.libsonnet — bundled dashboard queries select `cadvisorSelector` + `image!=""`
- https://github.com/orbstack/orbstack/issues/1561 — OrbStack metrics-server/cAdvisor integration gaps (corroboration)
