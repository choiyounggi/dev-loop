# Knowledge flush — 4 insight(s)

## Verified best-practice

**1. Container metrics empty while kubelet targets report up (OrbStack embedded k8s)**
Claim: when cAdvisor emits no `container_*` series, scrape kubelet `/metrics/resource` (kps values `kubelet.serviceMonitor.resource: true` + `resourcePath: "/metrics/resource"`), and expect bundled mixin dashboards to stay empty because of their `image!=""` filter.
Sources checked: Kubernetes resource-metrics-pipeline docs (fetched); kubelet source `pkg/kubelet/metrics/collectors/resource_metrics.go` (fetched — confirms the exact two series); kube-prometheus-stack `values.yaml` on main (fetched — `resource: false`, `resourcePath: "/metrics/resource/v1alpha1"` is STILL the default today, with the in-file "renamed in k8s 1.18" comment, so the override is required, not historical); kubernetes-mixin `dashboards/resources/queries/pod.libsonnet` + `rules/apps.libsonnet` (fetched — `image!=""` in queries and recording rules); orbstack/orbstack#2217 (corroborates the symptom class on OrbStack).
Verification outcome: 3 of 4 sub-claims confirmed against primary sources; the machine_*-only cAdvisor observation itself is a field measurement (2026-07-15, `kubectl get --raw .../metrics/cadvisor` → 0 `container_` series). **Confidence: verified** (field-only detail labeled as such in the page body). One correction folded in: the chart's v1alpha1 default is current, not merely historical.

**2. OpenAI-compatible completion validation (reasoning models, finish_reason=length, empty content)**
Claim: gate on `finish_reason == "length"` and blank `content` before using LLM output; use the reasoning field to disambiguate "reasoning consumed the budget".
Sources checked: OpenAI openapi.yaml (fetched — `length` = truncated by requested token limit, verbatim); OpenAI reasoning guide (fetched — reasoning can consume the whole output budget before any visible output); LiteLLM reasoning_content docs (fetched — normalizes to `message.reasoning_content`); vLLM reasoning outputs docs (fetched — field RENAMED `reasoning_content` → `reasoning`).
Verification outcome: core semantics verified; two provider-dependent caveats surfaced by research and added to the page: (a) vLLM's field rename — the page tells readers to check both spellings; (b) DeepSeek first-party API gives CoT a separate budget, so the empty-content failure mode is OpenAI-o-series/vLLM-style budgeting, not universal — added as an edge case. The exact observed combination (HTTP 200 + `length` + 0-char content + 8,173-char reasoning_content) is the session's own LiteLLM measurement (2026-07-28). **Confidence: field-tested.**

**3. Code defaults naming gateway-resolved model aliases (re-verify at review/merge)**
Claim: defaults resolved by an external serving catalog can die between PR verification and merge while code/tests/builds stay green; re-query the live catalog (`GET /v1/models`) at review/merge time and fail-fast-validate load-bearing defaults at startup.
Sources checked: OpenAI models-list API reference (fetched — lists currently available model IDs); LiteLLM model_discovery docs (fetched — `/v1/models` reflects configured `model_list`; live upstream checking is opt-in, which strengthens the page's "confirm with one real call" row); vLLM quickstart (fetched — `/v1/models` on the OpenAI-compatible server); GitHub merge-queue docs (fetched — the staleness rationale: validation done earlier must be redone against current state); fail-fast startup-validation references (confirmed via search).
Verification outcome: the endpoint claim fully verified; the practice itself is a field lesson (PR review 2026-07-28: default summarization alias removed from the LiteLLM catalog between PR verification and review → `/chat/completions` 400 while the PR's e2e evidence was genuinely true at write time) supported by general drift/staleness references, not a documented named practice. **Confidence: field-tested.**

**4. Reading other pods' cgroup v2 stats from inside a container**
Claim: mounting host `/sys/fs/cgroup` is insufficient — you need the host cgroup namespace (`docker --cgroupns=host`; k8s privileged or hostPID + `nsenter -t 1 -C`).
Sources checked: cgroup_namespaces(7) man page (fetched); docker run reference (fetched — `--cgroupns=host`; private is the cgroup v2 default); nsenter(1) (fetched — `-C/--cgroup`); kubernetes/kubernetes#103363 (fetched — no first-class pod hostCgroup option; nsenter workaround as used by Cilium).
Verification outcome: directive verified against docs + the session's own A/B reproduction (2026-07-22 OrbStack: identical `-v` mount, `kubepods` absent without / fully present with `--cgroupns=host`). Research CORRECTED the harvested mechanism: the cgroupfs view is fixed at MOUNT time by the mounting process's cgroup namespace (the runtime creates the container's cgroup mount inside the private ns) — not dynamically filtered per reader; the page states the corrected mechanism. Research bonus added: `nsdelegate` write-restriction edge case (files visible, writes EPERM — a distinct failure mode). **Confidence: field-tested.**

## Existing-layer check

Read: root `INDEX.md`; domain indexes for `infrastructure` and `backend`; candidate-overlap pages in full — `infrastructure/observability/logs-metrics-signals.md`, `infrastructure/containers/resource-limits-and-probes.md`, `backend/common/reliability/timeouts-and-retries.md`, `infrastructure/config/environment-config.md`, `qa/process/release-gates.md` (+ skimmed `qa/process/post-release-verification.md`). Repo-wide grep for `reasoning_content|cadvisor|cgroup|/metrics/resource|v1/models|finish_reason` found no page owning any of these topics (hits were incidental substrings).

- **Overlaps found:** none that owns the new triggers. `logs-metrics-signals` owns instrumenting a service (emitting signals), not collecting cluster metrics; `resource-limits-and-probes` owns manifests/limits (it *consumes* `container_memory_working_set_bytes`, hence a related-link, not a merge); `timeouts-and-retries` owns transport-level outbound failures, not semantic response validation; `environment-config` owns config shape/startup validation (its "no dev-friendly defaults" rule is adjacent to insight 3, but the trigger — external catalog drift at review time — is new); `release-gates` owns the release checklist process.
- **Merged vs created:** 0 merged, 4 new pages created (all four triggers are new).
- **Conflicts flagged:** none — no existing directive contradicts the new pages.
- **Related links added (both ways):** `missing-container-metrics` ↔ `logs-metrics-signals`, ↔ `resource-limits-and-probes`; `host-cgroup-visibility` ↔ `resource-limits-and-probes`, ↔ `missing-container-metrics`; `completion-response-validation` ↔ `gateway-model-alias-defaults`, ↔ `timeouts-and-retries`; `gateway-model-alias-defaults` ↔ `environment-config`, ↔ `release-gates`.

## Routing decision

| Insight | Target | Page |
|---------|--------|------|
| 1 (kubelet metrics) | `infrastructure/observability` (existing category) | `missing-container-metrics.md` — new page, new trigger |
| 4 (cgroup namespace) | `infrastructure/containers` (existing category) | `host-cgroup-visibility.md` — new page, new trigger |
| 2 (completion validation) | `backend/common/llm` (**new category**) | `completion-response-validation.md` |
| 3 (catalog-resolved defaults) | `backend/common/llm` (**new category**) | `gateway-model-alias-defaults.md` |

**New category justification (`backend/common/llm`):** both insights concern consuming OpenAI-compatible LLM gateways from server-side code. Existing backend/common categories don't cover the trigger: `api-design` owns designing *your own* API; `reliability` owns transport-level outbound failure handling (timeouts/retries/backoff), while these pages gate on *semantic* response validity (finish_reason/reasoning fields) and external-catalog identifier drift — HTTP-success-but-unusable-output is outside its tables. LLM-gateway consumption is a recurring concern with its own vocabulary, so a dedicated category beats stretching `reliability`. Insight 3 generalizes beyond LLMs (any externally-resolved alias); that generality is stated in the page's "When this applies" while the page stays anchored to its concrete, evidenced instance. Plumbing updated: `backend/index.md` (new `### llm` section + concern list), root `INDEX.md` backend route line, `infrastructure/index.md` (two new load-when rows), `log.md` (two ingest entries).
