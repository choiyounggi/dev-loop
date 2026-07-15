# Knowledge flush — 3 insight(s)

Drained 3 queued `★ Insight` candidates. Each was independently researched and
verified against primary sources before ingest. Two new pages created, one
existing page extended. No auto-merge — this PR is for review.

Cross-Check: each of the 3 candidates was verified by an independent research
subagent against primary sources (chart values.yaml / k8s docs / kubernetes-mixin;
Greg's Wiki + pipe(7) + Docker/bash manuals; GNU + FreeBSD date + POSIX strftime).
All three mechanisms VERIFIED; corrections folded in (mixin also pins
`job=cadvisor` not just `image!=""`; process-sub `$!` is bash 4.4+ not 5.1) and
field-observed specifics (OrbStack root cause, literal `3N`) labeled as such.

## Verified best-practice

### 1. Empty cAdvisor `container_*` metrics on a lightweight kubelet → scrape `/metrics/resource`
- **Claim:** With kube-prometheus-stack, pod CPU/memory series are empty though
  kubelet targets are UP; fix by enabling `kubelet.serviceMonitor.resource: true`
  and overriding `resourcePath: /metrics/resource`; mixin dashboards hide the
  resource series via `image!=""`.
- **Sources checked (real):**
  - kps chart values.yaml — confirms both keys, `resource` default **false**, and `resourcePath` default is the stale **`/metrics/resource/v1alpha1`**: https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/values.yaml
  - k8s metrics docs — `/metrics/resource` is the current STABLE endpoint; series carry `namespace`/`pod`/`container` only (no `image`): https://kubernetes.io/docs/reference/instrumentation/metrics/ , https://kubernetes.io/docs/concepts/cluster-administration/system-metrics/
  - k8s PR#86282 — the `v1alpha1` path was removed (404 on kubelet ≥1.20): https://github.com/kubernetes/kubernetes/pull/86282
  - kubernetes-mixin — Compute Resources dashboards select cAdvisor series with `image!=""` **and** `job="cadvisor"`/`metrics_path="/metrics/cadvisor"`: https://github.com/kubernetes-monitoring/kubernetes-mixin
- **Verification result:** mechanism + fix **VERIFIED** by primary sources. **Correction folded in:** `image!=""` is not the *only* reason the resource series are excluded — the mixin also pins `job=cadvisor`/`metrics_path=/metrics/cadvisor`, so a custom panel is required regardless (the page states this, not "just drop the image filter"). The OrbStack-specific root cause (cAdvisor emitting only `machine_*`) is **field-observed**, not documented upstream — labeled as such in the page and log.
- **Confidence: verified** (fix is kubelet-endpoint-level and independent of why cAdvisor is empty).

### 2. Container PID 1 entrypoint loses piped logs on exit → wait for tee in an EXIT trap
- **Claim:** `exec > >(tee -a file)` in a PID 1 bash entrypoint loses log output on
  container exit; capture `TEE_PID=$!` and `wait` it in an EXIT trap after closing
  fds; add `trap 'exit 143' TERM`.
- **Sources checked (real):**
  - Greg's Wiki — process substitution is an **unwaited** background subshell; bash sets `$!` to its PID so you can `wait`: https://mywiki.wooledge.org/ProcessSubstitution
  - Docker stop — SIGTERM then SIGKILL after grace period: https://docs.docker.com/reference/cli/docker/container/stop/
  - pipe(7) — a read sees EOF only when **all** write-end fds are closed: https://www.man7.org/linux/man-pages/man7/pipe.7.html
  - bash manual — signal-killed command exits 128+N (SIGTERM 15 → 143): https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html
  - PID 1 signal write-up — PID 1 ignores SIGTERM without a handler; orphans reaped only if PID 1 waits: https://petermalmgren.com/signal-handling-docker/
- **Verification result:** all four mechanisms **VERIFIED**. **Correction folded in:** capturing the process-substitution PID via `$!` is **bash 4.4+** (2016), NOT 5.1 as the raw candidate implied — the page states 4.4+ and gives a named-FIFO fallback for older bash. EOF caveat (all write ends must close) captured as an edge case.
- **Confidence: verified** (documented mechanism) — the original 10/10 capture measurement is noted as field evidence.

### 3. Feature-detect `date +%3N` by 3-digit output, not by `%N` support
- **Claim:** Detecting GNU vs BSD `date` by "does `%N` work" is wrong because modern
  macOS supports `%N`; check that `date +%3N` outputs three digits.
- **Sources checked (real):**
  - GNU coreutils — `%N` nanoseconds + numeric field-width form: https://www.gnu.org/software/coreutils/manual/html_node/Options-for-date.html
  - FreeBSD/macOS `date` — `%N` added in FreeBSD 14.1, GNU-compatible on modern macOS; no `%3N` width form documented: https://man.freebsd.org/cgi/man.cgi?query=date
  - POSIX strftime — an unrecognized conversion specification is **undefined** (BSD passes it through literally): https://pubs.opengroup.org/onlinepubs/9699919799/functions/strftime.html
- **Verification result:** core advice **VERIFIED and strengthened** — modern macOS returns real nanoseconds for `%N`, making it an even worse discriminator than the candidate claimed. Two specifics are **field-observed**: the exact `%3N` → literal `3N` output (consistent with POSIX "undefined", not documented as `3N`), and GNU `%3N` = "first 3 digits" (width mechanism documented; the truncation semantics universally relied on but not spelled out). The page frames `3N` as field-observed.
- **Confidence: verified** (recommendation robust; two specifics noted as field-observed).

## Existing-layer check

- Read all `infrastructure/observability/` pages (`logs-metrics-signals`,
  `alerting`) and all `infrastructure/containers/` pages (`image-builds`,
  `resource-limits-and-probes`), plus `platforms/tools/bsd-vs-gnu-cli`,
  `platforms/shells/portable-shell-scripts`, `platforms/environment/timezone-and-locale`.
- **#1 (kubelet metrics):** `logs-metrics-signals` covers *what/how to instrument*
  (signal choice, cardinality, golden signals) — a different trigger from "a
  specific series is empty despite a healthy scrape." Merging would blur that
  page's focus, so **created a new page** and cross-linked both ways
  (`related:`). No conflict.
- **#2 (PID 1 tee):** the decisive trigger condition is *container PID 1*, not OS
  portability, so it does not belong in `platforms/shells/portable-shell-scripts`
  (which already covers process substitution/`set -e`/EXIT traps for the
  portability case). **Created a new page** under `infrastructure/containers`
  (owns the PID 1 lifecycle artifact) and added a `related:` link both ways to
  the shell page. No conflict.
- **#3 (`date %3N`):** directly overlaps the existing `date` guidance in
  `bsd-vs-gnu-cli` → **merged** (one Do-table row + one Instead-of row + two
  sources + `last_verified` bump). No new page. No conflict with the existing
  "Relative date" row (distinct sub-case).

## Routing decision

| Insight | Target | Action |
|---------|--------|--------|
| #1 kubelet resource metrics | `infrastructure/observability/kubelet-resource-metrics.md` (new page) | Created; registered in `infrastructure/index.md` observability table; `related:` ↔ `logs-metrics-signals` |
| #2 PID 1 tee log flush | `infrastructure/containers/pid1-entrypoint-log-flush.md` (new page) | Created; registered in `infrastructure/index.md` containers table; `related:` ↔ `portable-shell-scripts`, → `resource-limits-and-probes`, `logs-metrics-signals` |
| #3 `date +%3N` detection | `platforms/tools/bsd-vs-gnu-cli.md` (existing) | Merged one Do-row + one Instead-of row; added GNU date + POSIX strftime sources; `last_verified` → 2026-07-15 |

No new category was needed — both new pages fit existing categories
(`infrastructure/observability`, `infrastructure/containers`). `log.md` has three
appended entries (2× ingest, 1× revise).
