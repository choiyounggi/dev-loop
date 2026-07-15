# Knowledge flush — 3 insight(s)

Cross-Check: 독립 서브에이전트 적대검증 1회 — date 페이지 CONFIRMED(GNU/macOS 양쪽 실측), kubelet 페이지는 대시보드 제외 원인이 `metrics_path="/metrics/cadvisor"` 핀 + `image!=""` 복합임을 적발(수정 반영, swap/start_time 노출도 보정), entrypoint 페이지는 TERM trap 근거가 실증상 반대(foreground 자식 뒤 trap은 지연→SIGKILL 137; 무trap SIGTERM에도 EXIT trap 실행)임을 적발 → background 자식+`wait`+시그널 포워딩 패턴으로 재작성. 재현 아티팩트: bash 4.4/5.2 PID-1 docker 실험, 업스트림 소스 대조.

## Verified best-practice

**1. Empty `container_*` metrics though kubelet targets are up → scrape `/metrics/resource` (kube-prometheus-stack).**
Claim: on OrbStack-style embedded k8s the kubelet cAdvisor endpoint emits no `container_*` series while scrapes stay healthy; the fix is `kubelet.serviceMonitor.resource: true` plus an explicit `resourcePath: "/metrics/resource"`, and the mixin Compute Resources dashboards will still drop these series because of their `image!=""` filter.
Verified against:
- https://kubernetes.io/docs/reference/instrumentation/node-metrics/ — `/metrics/resource` is the current kubelet resource-metrics endpoint (metrics-server ≥0.6 uses it).
- https://raw.githubusercontent.com/prometheus-community/helm-charts/main/charts/kube-prometheus-stack/values.yaml — confirmed `resource: false` default and `resourcePath: "/metrics/resource/v1alpha1"` default with the chart's own comment "From kubernetes 1.18, /metrics/resource/v1alpha1 renamed to /metrics/resource" — exactly the 404 trap the insight describes.
- kubernetes-mixin source read via `gh api` (`dashboards/resources/queries/pod.libsonnet`) — pod CPU/memory queries all carry `image!=""` (and `container!=""`); `/metrics/resource` series have no `image` label.
The OrbStack-specific behavior (cAdvisor emitting only `machine_*`) has no external doc; it is marked as a dated field observation in the page. Overall **confidence: verified** (mechanism fully doc-backed + session reproduction with PromQL round-trip).

**2. PID-1 entrypoint bash with `exec > >(tee -a f)` loses log output → EXIT-trap fd close + `wait "$TEE_PID"`; long foreground jobs need background-child + `wait` + TERM forwarding.**
Note: the queued candidate's original `trap 'exit 143' TERM` directive was **corrected during cross-check** — adversarial reproduction (bash 4.4/5.2 as PID 1) showed bash runs the EXIT trap on an untrapped SIGTERM anyway, while a TERM trap behind a foreground child is deferred until SIGKILL (exit 137, nothing flushed). The page teaches the working pattern instead.
Verified against:
- https://mywiki.wooledge.org/ProcessSubstitution — process substitution "will continue to run when your script exits (unless you manage your child processes)"; since bash 4.4 it can be managed with `wait "$!"`. In a container the PID-1 exit tears the orphan down before flush instead of letting it finish.
- https://tiswww.case.edu/php/chet/bash/bashref.html — 128+n exit status for signal-terminated commands (143 = SIGTERM).
- Session reproduction (OrbStack container): without trap 0/10 runs captured output; with trap 10/10.
**confidence: verified**. (gnu.org bash manual rate-limited me with HTTP 429 during the flush, so the mirror + Wooledge are cited instead — no unverified URL was included.)

**3. BSD/GNU `date` ms-timestamp feature detection → test the actual `%3N` output shape, not `%N` presence.**
Verified against:
- https://www.gnu.org/software/coreutils/manual/html_node/Time-conversion-specifiers.html — "%N nanoseconds … This is a GNU extension."
- https://www.gnu.org/software/coreutils/manual/html_node/Padding-and-other-flags.html — field width between `%` and the specifier is a GNU extension.
- **Independent reproduction on a second machine during this flush** (macOS 26.5.1, beyond the original 14.8.3 measurement): `date +%N` → `070788000`, `date +%3N` → literal `3N`. The trap is real: `%N` working makes naive detection pass, then `%3N` corrupts timestamps.
**confidence: verified**.

## Existing-layer check

Read: root `INDEX.md`, `wiki/infrastructure/index.md`, `wiki/platforms/index.md`, and every overlapping page: `observability/logs-metrics-signals.md`, `observability/alerting.md` (index line), `containers/resource-limits-and-probes.md`, `containers/image-builds.md`, `shells/portable-shell-scripts.md`, `tools/bsd-vs-gnu-cli.md`.

- Insight 1: no overlap — `logs-metrics-signals` covers instrumentation principles (signal choice, cardinality), not scrape-source configuration. No conflict. **Created new page**; related-linked both ways to `logs-metrics-signals` and `resource-limits-and-probes`.
- Insight 2: no overlap — `portable-shell-scripts` covers shell portability, `image-builds` covers Dockerfiles; neither covers PID-1 runtime log/signal behavior. No conflict. **Created new page**; related-linked both ways to `image-builds` and `portable-shell-scripts` (cross-domain), one-way to `logs-metrics-signals`.
- Insight 3: direct overlap with `platforms/tools/bsd-vs-gnu-cli.md` (same trigger, same directive family — its "Relative date" row already covers `date -d` vs `-v`). **Merged**: one command-table row (sub-second timestamp), one edge-case row (`%N` printing digits on macOS must not imply GNU), two sources, `last_verified` bumped to 2026-07-15. No new page.

Conflicts flagged: none.

## Routing decision

| Insight | Target | New category? |
|---------|--------|---------------|
| 1 — kubelet container metrics | `infrastructure/observability/kubelet-container-metrics.md` (new page) | No — observability already owns metrics collection; index "load when" added |
| 2 — PID-1 tee log loss | `infrastructure/containers/entrypoint-log-capture.md` (new page) | No — containers owns container-runtime behavior; platforms/shells was rejected because the trigger is PID-1 container semantics, not shell portability |
| 3 — date `%3N` detection | `platforms/tools/bsd-vs-gnu-cli.md` (merge) | No — exact existing page for BSD-vs-GNU flag differences |

Nothing left `unverified`. Queue rows retired to `~/.dev-loop/queue/.processed.jsonl` after PR creation.
