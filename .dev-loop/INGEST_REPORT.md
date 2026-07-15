# Knowledge flush — 2 insight(s) (+1 retired as already flushed)

Cross-Check: 독립 서브에이전트 적대검증 1회 — date 페이지 CONFIRMED(GNU coreutils 컨테이너·macOS 26.5.1 양쪽 실측, case 패턴 분기 검증), entrypoint 페이지는 큐 원문의 TERM trap 근거가 실증상 반대(무trap SIGTERM에도 bash EXIT trap 실행; foreground 자식 뒤 TERM trap은 지연→SIGKILL 137, flush 0건)임을 적발 → background 자식+`wait`+시그널 포워딩 패턴으로 재작성 후 반영. 재현 아티팩트: bash 4.4/5.2 PID-1 docker 실험 각 10회.

## Decision Log

- **의도**: dev-loop 큐의 pending 인사이트를 검증·중복점검·라우팅해 위키에 반영 (knowledge-flush 파이프라인, 사용자가 flush 실행과 PR 1건 생성을 명시 지시).
- **배제한 대안**:
  - 인사이트(kubelet /metrics/resource)의 신규 페이지 생성 — **배제: 열려 있는 PR #2가 동일 인사이트를 `container-metrics-when-cadvisor-is-empty.md`로 이미 반영**(metrics_path 핀 + image!="" 복합 필터까지 커버 확인). 큐 row가 retire되지 않아 재등장한 것 — 이번 flush에서 재반영 없이 retire만 함. 작성했던 중복 페이지는 커밋 이력에서 제거.
  - 인사이트(PID-1 tee)를 `platforms/shells/portable-shell-scripts.md`에 병합 — 배제: 트리거가 셸 이식성이 아니라 PID-1 컨테이너 시맨틱이라 `infrastructure/containers` 신규 페이지가 맞음 (one case per page).
  - 큐 원문 directive(`trap 'exit 143' TERM` 단독) 그대로 반영 — 배제: 적대검증 실험에서 반박되어 교정 후 반영.
- **리뷰어가 볼 곳**: `entrypoint-log-capture.md` step 2(background-child+wait 패턴 — 교차검증으로 재작성된 부분)와 Sources의 두 독립 재현 기록, `bsd-vs-gnu-cli.md` 추가 행의 case 패턴 분기. `wiki/infrastructure/index.md`는 PR #2도 수정하므로 머지 순서에 따라 사소한 충돌 가능.
- [추정] RTB 팀 표준 리뷰어 3인은 이 개인 레포 collaborator가 아니어서 리뷰어 지정이 거부됨(gh 확인: `d43103-rsquare not found`) — 레포 소유자 리뷰(스킬 기본 모델)로 진행.

## Verified best-practice

**1. PID-1 entrypoint bash with `exec > >(tee -a f)` loses log output → EXIT-trap fd close + `wait "$TEE_PID"`; long foreground jobs need background-child + `wait` + TERM forwarding.**
Verified against:
- https://mywiki.wooledge.org/ProcessSubstitution — process substitution "will continue to run when your script exits (unless you manage your child processes)"; managed with `wait "$!"` since bash 4.4 (also confirmed in bash CHANGES, bash-4.4 section).
- https://tiswww.case.edu/php/chet/bash/bashref.html — 128+n exit status for signal-terminated commands (143 = SIGTERM); trap execution deferred until the running foreground command completes.
- Session reproduction (OrbStack container): without trap 0/10 runs captured output; with trap 10/10.
- Independent adversarial re-reproduction during this flush (docker, bash 4.4 and 5.2 as PID 1): 1/10 without trap vs 10/10 with; untrapped `docker stop` ran the EXIT trap (exit 143); `trap 'exit 143' TERM` behind a foreground child was deferred until SIGKILL (exit 137, no flush).
The queued candidate's original `trap 'exit 143' TERM` directive was **corrected during cross-check** — the page teaches the working background-child pattern instead. **confidence: verified.** (gnu.org bash manual rate-limited with HTTP 429 during this flush; the case.edu mirror + Wooledge are cited instead — no unverified URL included.)

**2. BSD/GNU `date` ms-timestamp feature detection → test the actual `%3N` output shape, not `%N` presence.**
Verified against:
- https://www.gnu.org/software/coreutils/manual/html_node/Time-conversion-specifiers.html — "%N nanoseconds … This is a GNU extension."
- https://www.gnu.org/software/coreutils/manual/html_node/Padding-and-other-flags.html — field width between `%` and the specifier is a GNU extension.
- Independent reproduction on a second machine during this flush (macOS 26.5.1, beyond the original 14.8.3 measurement): `date +%N` → digits, `date +%3N` → literal `3N`. Adversarial re-check additionally ran GNU coreutils (debian container): `date +%3N` → exactly 3 digits, and confirmed the `case … [0-9][0-9][0-9])` pattern takes the GNU path on GNU and falls through on macOS.
**confidence: verified.**

**Retired without re-ingesting**: the OrbStack kubelet `/metrics/resource` insight (hash `ab44b921a1f3f759`) — already flushed as open **PR #2** (`container-metrics-when-cadvisor-is-empty.md`) but never removed from its session queue file; verified PR #2's page already covers the chart defaults, the label-set difference, and the `metrics_path="/metrics/cadvisor"` + `image!=""` dashboard exclusion, so nothing new to add.

## Existing-layer check

Read: root `INDEX.md`, `wiki/infrastructure/index.md`, `wiki/platforms/index.md`, and every overlapping page: `observability/logs-metrics-signals.md`, `containers/resource-limits-and-probes.md`, `containers/image-builds.md`, `shells/portable-shell-scripts.md`, `tools/bsd-vs-gnu-cli.md`, plus open PR #2's `container-metrics-when-cadvisor-is-empty.md` (via the PR branch).

- Insight 1 (PID-1 tee): no overlap — `portable-shell-scripts` covers shell portability, `image-builds` covers Dockerfiles; neither covers PID-1 runtime log/signal behavior. No conflict. **Created new page**; related-linked both ways to `image-builds` and `portable-shell-scripts` (cross-domain), one-way to `logs-metrics-signals`.
- Insight 2 (date `%3N`): direct overlap with `platforms/tools/bsd-vs-gnu-cli.md` (same trigger family — its "Relative date" row already covers `date -d` vs `-v`). **Merged**: one command-table row (sub-second timestamp), one edge-case row (`%N` printing digits on macOS must not imply GNU), two sources, `last_verified` bumped to 2026-07-15. No new page.
- Kubelet insight: duplicate of open PR #2 → dropped (see Decision Log).

Conflicts flagged: none in content. Noted: `wiki/infrastructure/index.md` is also touched by open PR #2 (different rows) — trivial merge-order conflict possible.

## Routing decision

| Insight | Target | New category? |
|---------|--------|---------------|
| PID-1 tee log loss | `infrastructure/containers/entrypoint-log-capture.md` (new page) | No — containers owns container-runtime behavior; platforms/shells rejected because the trigger is PID-1 container semantics, not shell portability |
| date `%3N` detection | `platforms/tools/bsd-vs-gnu-cli.md` (merge) | No — exact existing page for BSD-vs-GNU flag differences |
| kubelet `/metrics/resource` | — (retired; already in open PR #2) | — |

Nothing left `unverified`. Queue rows retired to `~/.dev-loop/queue/.processed.jsonl` after PR creation.
