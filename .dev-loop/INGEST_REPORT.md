# Knowledge flush — 2 insight(s)

## Decision Log

- **의도**: dev-loop 큐의 pending 인사이트 2건(OrbStack kubelet 메트릭 소스 전환, host→pod 메모리 리밋 산정)을 1차 소스로 재검증해 위키에 반영. 이슈처럼 큰 변경이 아니라 지식 ingest — 페이지 1 신규 + 1 병합.
- **배제한 대안**:
  - insight 1을 `observability/logs-metrics-signals.md`에 병합 → 배제: 그 페이지는 "내 서비스 계측"이 트리거고, 이 건은 "클러스터 메트릭 수집 소스 선택"이라 트리거가 다름(one case per page 규칙).
  - insight 2를 신규 페이지로 생성 → 배제: `resource-limits-and-probes.md`가 이미 "OOMKilled + 측정 기반 리밋" 트리거를 소유 — 엣지케이스/Instead-of 행 병합이 중복 없는 형태.
  - PR #1의 `streaming-large-result-sets` 페이지로의 `related:` 링크 → 보류: PR #1 미머지 상태라 main에 없는 페이지로의 링크는 깨질 수 있음(본문 Existing-layer check에 플래그).
- **리뷰어가 볼 곳**: 신규 페이지의 4개 소스가 각 주장과 대응하는지(values.yaml 기본값, resource_metrics.go 라벨셋, mixin `image!=""`+cadvisorSelector, orbstack#1561), OrbStack 주장이 field-tested로 정직하게 표기됐는지, `resource-limits-and-probes.md` 추가 2행이 기존 규칙 4("measure, don't copy")와 중복이 아닌 보강인지.
- [추정] 없음 — 모든 메커니즘 주장은 이번 flush에서 라이브로 가져온 1차 소스로 검증됨(본문 Verified best-practice 참조).

Cross-Check: every mechanism claim was independently re-verified against primary
sources (chart values.yaml, kubernetes source, kubernetes-mixin source, psycopg2
docs) fetched live during this flush — not taken from the harvesting session.

Queue note: a third queued row (QueryPie streaming / fetchmany + write_only,
hash `637877dfc33bc0f0`) was already flushed as **PR #1** (open) but had not
been removed from its session queue file; it was retired without re-ingesting.

## Verified best-practice

### Insight 1 — container_* metrics empty on OrbStack k8s despite kubelet targets up

Claim chain and verification:

1. **kube-prometheus-stack ships the kubelet resource-metrics scrape disabled,
   with a stale default path.**
   Source: `charts/kube-prometheus-stack/values.yaml` (prometheus-community/helm-charts,
   fetched live) — `resource: false`, `resourcePath: "/metrics/resource/v1alpha1"`,
   with the in-file comment "From kubernetes 1.18, /metrics/resource/v1alpha1
   renamed to /metrics/resource". → **verified**
2. **`/metrics/resource` exposes `container_cpu_usage_seconds_total` and
   `container_memory_working_set_bytes` with labels `container, pod, namespace`
   only — no `image` label.**
   Source: `pkg/kubelet/metrics/collectors/resource_metrics.go` (kubernetes/kubernetes,
   fetched live; both metrics STABLE). → **verified**
3. **The bundled Compute Resources dashboards cannot show these series.**
   Source: `dashboards/resources/queries/pod.libsonnet` (kubernetes-monitoring/
   kubernetes-mixin, fetched live) — memory queries select `cadvisorSelector`
   (`metrics_path="/metrics/cadvisor"`) AND `image!=""`; the resource-endpoint
   series fail both. → **verified**
4. **OrbStack's kubelet cAdvisor endpoint emits only `machine_*`, zero
   `container_*`, while the scrape reports success.**
   First-hand probe (2026-07-14): `kubectl get --raw .../proxy/metrics/cadvisor`
   → 0 `container_` lines, `machine_scrape_error 0`; `/metrics/resource` →
   real working-set values. No official OrbStack doc states this; orbstack#1561
   corroborates the metrics-integration gap. → **field-tested** (marked as such
   in the page body; the page's other rows are verified).

### Insight 2 — "ran fine on the host" is not evidence a pod memory limit fits

1. **Exceeding a container memory limit ⇒ OOMKill; limits must come from
   measurement.** Already sourced on the existing page
   (kubernetes.io manage-resources-containers). → **verified** (pre-existing)
2. **A default (client-side) psycopg2 cursor loads the entire result set
   client-side, so memory scales with data size; server-side cursors transfer
   controlled amounts.** Source: https://www.psycopg.org/docs/usage.html#server-side-cursors,
   fetched live — "the Psycopg cursor usually fetches all the records returned
   by the backend … a proportionally large amount of memory will be allocated
   by the client" / "transfer to the client only a controlled amount of data".
   → **verified**
3. **Concrete failure/measurement**: 800k-row extract OOMKilled in a 1Gi pod
   after 20 min; measured 1.5Gi+ peak once raised to 3Gi (mac-server k8s
   migration, 2026-07-13). → **field-tested** context, used as the motivating
   example only.

## Existing-layer check

- Pages read: root `INDEX.md`, `infrastructure/index.md`,
  `infrastructure/containers/resource-limits-and-probes.md`,
  `infrastructure/observability/logs-metrics-signals.md`; PR #1's diff
  (`databases/query-optimization/streaming-large-result-sets.md`) reviewed for
  overlap with insight 2.
- **Insight 1**: no existing page covers scraping/metric-source selection for
  container metrics. `logs-metrics-signals` is about instrumenting your own
  service (different trigger) — not a duplicate. → new page, `related:` linked
  both ways with `resource-limits-and-probes` (its "set limits from
  measurement" rule depends on these very metrics) and one-way to
  `logs-metrics-signals`.
- **Insight 2**: same trigger family as `resource-limits-and-probes`
  ("pods OOMKilled") and same directive spirit ("measure, don't copy") → **merged**
  into that page (1 edge-case row + 1 instead-of row + psycopg2 source), no new
  page. The streaming *fix* itself lives in PR #1's databases page; a
  `related:` link to it was **deliberately not added** because that page is not
  on `main` yet (PR #1 unmerged) — flagged here instead so the owner can add
  the link when/if PR #1 merges.
- Conflicts: none found.

## Routing decision

- **Insight 1** → `infrastructure/observability/container-metrics-when-cadvisor-is-empty.md`
  (**new page**). Category `observability` fits (metrics collection/source
  selection); no new category needed. Registered in `infrastructure/index.md`
  with a load-when line keyed on "embedded/local k8s + container_* empty +
  targets up"; `log.md` ingest entry appended.
- **Insight 2** → `infrastructure/containers/resource-limits-and-probes.md`
  (**merge/revise**, no new page). Category `containers` already owns the
  OOMKill/limit-sizing trigger. `last_verified` bumped to 2026-07-14; `log.md`
  revise entry appended.
