# orchestrate ready-set 스케줄러 (PR 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** orchestrate의 Wave 배리어를 의존 그래프 + 슬롯 회계로 교체해, 의존이 충족된 task를 빈 슬롯만큼 즉시 흘려보낸다.

**Architecture:** Phase 2가 기계 판독용 `.orchestration/graph.json`을 쓰고, 새 `ready-set.sh`가 그래프 + `.orchestration/status/*.json`을 읽어 "지금 던져도 되는 task id"를 종료코드로 판정한다. 판단(슬롯 수, 어떤 task부터)은 코디네이터가 유지한다. tmux 기판의 `watch-status.sh`는 스캔 대상을 task 집합으로 좁히는 `--tasks` 옵션을 얻어 "추적 중인 것 중 아무나 하나 도달"을 표현할 수 있게 된다.

**Tech Stack:** POSIX sh, jq, bats-core. 새 의존성 없음.

## Global Constraints

- 스펙 정본: `docs/superpowers/specs/2026-08-07-orchestrate-ready-set-scheduler-design.md`. 각 task는 해당 절을 권위로 한다.
- deps 충족 기준은 `approved` 이상이다 — `impl_done`이 아니다 (스펙 §3.1).
- 슬롯은 디스패치된 순간부터 종료 상태까지 점유한다. `plan_ready`·`impl_done`(리뷰 대기)도 점유로 센다 (스펙 §3.1).
- 종료 상태 = `approved | merged | done | failed`. 그 중 `failed`는 "완료"가 아니라 교착 사유다.
- 새 스크립트는 POSIX `sh`로 쓰고 `set -u`를 켠다. `jq` 부재는 exit 127 (`watch-status.sh`·`orca-wait.sh`와 동일).
- `/tmp`·`$TMPDIR`에 실행 파일을 만들지 않는다. 테스트용 실행 파일이 필요하면 레포 안 `.claude/tmp/`를 쓴다 (`tests/orca-wait.bats`의 `REPO_TMP()` 선례).
- 기존 387개 bats는 전부 그린을 유지한다. PR 통과 조건이다.
- 분할 경로(스펙 §3.5)는 PR 2다. 이 계획에서 구현하지 않는다.
- 커밋 author는 `Younggi Choi <74581798+choiyounggi@users.noreply.github.com>` (공개 레포 관례).
- **`skills/orchestrate/SKILL.md`에 넣는 모든 문장은 영어다.** 현재 이 파일은 한글이 0자이며, 배포되는 스킬 본문의 관례다(guardrails v1.2.0이 배포 메시지를 한국어→영어로 바꾼 것과 같은 이유). `docs/` 아래 스펙·계획 문서만 한국어를 쓴다. SKILL.md를 grep하는 테스트도 영어 문자열을 대상으로 한다.

---

## File Structure

**신규**

- `skills/orchestrate/scripts/ready-set.sh` — 그래프 + status를 읽어 디스패치 가능 집합을 판정. 이 PR의 유일한 신규 실행 파일. 순수 판정만 하고 아무것도 실행하지 않는다.
- `tests/ready-set.bats` — 위 스크립트의 계약 고정.

**수정**

- `skills/orchestrate/scripts/watch-status.sh` — `--tasks <csv>` 옵션 추가 (스캔 대상 축소). 기존 위치 인자 계약은 그대로.
- `tests/scripts.bats` — `--tasks` 신규 테스트 + 기존 all-N 무회귀.
- `skills/orchestrate/SKILL.md` — Phase 2(graph.json 산출 + 슬롯 제안), Phase 3+4(디스패치 루프), 재진입.
- `tests/send-prompt.bats` — SKILL.md 앵커 테스트가 있는 파일. Phase 재작성으로 앵커가 깨지지 않는지 확인하고, 필요하면 갱신.

---

### Task 1: `ready-set.sh` — 디스패치 가능 집합 판정

**Files:**
- Create: `skills/orchestrate/scripts/ready-set.sh`
- Test: `tests/ready-set.bats`

**Interfaces:**
- Consumes: `.orchestration/graph.json` (이 task가 스키마를 정의), `.orchestration/status/<task>.json`의 `.phase` 필드 (`status-update.sh`가 쓰는 기존 형식).
- Produces: CLI 계약 `ready-set.sh <graph.json> <status-dir> <cap>` — stdout은 디스패치할 task id 한 줄에 하나. 종료코드 0/2/3/4/5. Task 3·4의 SKILL.md가 이 계약을 인용한다.

**graph.json 스키마** (이 task가 정본):

```json
{ "tasks": [
    { "id": "t1", "deps": [],     "files": ["src/auth/**"], "outputs": ["AuthToken"] },
    { "id": "t3", "deps": ["t1"], "files": ["src/api/**"],  "consumes": ["AuthToken"] }
] }
```

`id`와 `deps`만 이 스크립트가 읽는다. `files`/`outputs`/`consumes`는 코디네이터가 충돌 판정에 쓰는 필드이며 PR 2에서 사용한다.

- [ ] **Step 1: 실패하는 테스트를 쓴다 (정상 경로)**

`tests/ready-set.bats` 생성:

```bash
#!/usr/bin/env bats
# Tests for ready-set.sh — the Wave-barrier replacement. Given the dependency
# graph and each task's recorded phase, it answers exactly one question:
# which tasks may be dispatched right now. It never launches anything.

setup() {
  RS="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/ready-set.sh"
  G="${BATS_TEST_TMPDIR}/graph.json"
  S="${BATS_TEST_TMPDIR}/status"
  mkdir -p "$S"
}

graph() { printf '%s' "$1" > "$G"; }
phase() { printf '{"task":"%s","phase":"%s"}' "$1" "$2" > "$S/$1.json"; }

@test "no deps, empty status: every task is dispatchable up to the cap" {
  graph '{"tasks":[{"id":"t1","deps":[]},{"id":"t2","deps":[]},{"id":"t3","deps":[]}]}'
  run sh "$RS" "$G" "$S" 2
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | grep -c .)" -eq 2 ]
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `cd ~/Desktop/workspace/dev-loop && npx bats tests/ready-set.bats`
Expected: FAIL — `ready-set.sh` 가 없어서 `sh: ... No such file`.

- [ ] **Step 3: 최소 구현**

`skills/orchestrate/scripts/ready-set.sh` 생성:

```sh
#!/bin/sh
# ready-set.sh — which tasks may be dispatched right now?
#
# This is the Wave-barrier replacement. Waves made the whole batch wait for its
# slowest member; here a task is dispatchable the moment its own dependencies
# are approved and a slot is free, so a finished worker is refilled immediately.
#
# usage: ready-set.sh <graph.json> <status-dir> <cap>
#   <graph.json>  {"tasks":[{"id":"t1","deps":["t0"]}, ...]} — Phase 2 writes it.
#                 Only `id` and `deps` are read here; files/outputs/consumes are
#                 the coordinator's conflict-matrix fields.
#   <status-dir>  .orchestration/status — one <task>.json per task, `.phase`
#                 written by status-update.sh. A task with no file is `pending`.
#   <cap>         the coordinator's approved slot count. LO_MAX_SESSIONS, when
#                 set, is an UPPER BOUND on it, never a raise.
#
# exit 0  dispatch these (stdout: one task id per line, at most <free> of them)
# exit 2  nothing to dispatch, but tasks are in flight — wait for an event
# exit 3  nothing to dispatch, nothing in flight, unfinished tasks remain —
#         DEADLOCK (a failed dependency, or a cycle). Never wait on this: with
#         no worker running, no event can ever arrive. Report it.
# exit 4  the graph or the status dir could not be read, or an argument is
#         invalid — refuse rather than guess
# exit 5  every task is in a terminal state — the run is complete
# exit 127 jq not found
#
# A dependency counts as satisfied only at `approved` or higher, NOT at
# impl_done: a task that consumes an unreviewed interface has to be redone when
# rework changes that signature. This is the Wave model's "previous Wave fully
# approved" guarantee, narrowed from a global barrier to a per-task wait.
#
# env:
#   LO_MAX_SESSIONS  upper bound on <cap> (a tuning knob like LO_PHASE_TIMEOUTS)
set -u

JQ=$(command -v jq) || { echo "ready-set: jq not found" >&2; exit 127; }

graph="${1:-}"; sdir="${2:-}"; cap="${3:-}"
[ -n "$graph" ] && [ -n "$sdir" ] && [ -n "$cap" ] || {
  echo "usage: ready-set.sh <graph.json> <status-dir> <cap>" >&2; exit 4; }
[ -f "$graph" ] || { echo "ready-set: graph '$graph' not found" >&2; exit 4; }
[ -d "$sdir" ]  || { echo "ready-set: status dir '$sdir' not found" >&2; exit 4; }

case "$cap" in ''|*[!0-9]*) echo "ready-set: cap must be a positive integer" >&2; exit 4 ;; esac
[ "$cap" -gt 0 ] || { echo "ready-set: cap must be > 0" >&2; exit 4; }

# LO_MAX_SESSIONS caps the cap. It is a ceiling the operator sets, so it lowers
# the coordinator's proposal and never raises it.
if [ -n "${LO_MAX_SESSIONS:-}" ]; then
  case "$LO_MAX_SESSIONS" in
    ''|*[!0-9]*) echo "ready-set: LO_MAX_SESSIONS must be a positive integer" >&2; exit 4 ;;
  esac
  [ "$LO_MAX_SESSIONS" -gt 0 ] || { echo "ready-set: LO_MAX_SESSIONS must be > 0" >&2; exit 4; }
  [ "$LO_MAX_SESSIONS" -lt "$cap" ] && cap="$LO_MAX_SESSIONS"
fi

ids=$("$JQ" -r '.tasks[]?.id // empty' "$graph" 2>/dev/null) || {
  echo "ready-set: graph '$graph' is not valid JSON" >&2; exit 4; }

# `.tasks` absent is a malformed graph, not an empty one — tell them apart so a
# typo'd key cannot read as "nothing to do".
"$JQ" -e 'has("tasks") and (.tasks | type == "array")' "$graph" >/dev/null 2>&1 || {
  echo "ready-set: graph '$graph' has no .tasks array" >&2; exit 4; }

phase_of() { # $1 = task id -> its recorded phase, or "pending" when unrecorded
  f="$sdir/$1.json"
  [ -f "$f" ] || { echo pending; return; }
  p=$("$JQ" -r '.phase // "pending"' "$f" 2>/dev/null) || p=pending
  [ -n "$p" ] || p=pending
  echo "$p"
}

is_satisfied() { # $1 = phase -> 0 when a dependent may start on it
  case "$1" in approved|merged|done) return 0 ;; *) return 1 ;; esac
}
is_terminal() {  # $1 = phase -> 0 when the task will never occupy a slot again
  case "$1" in approved|merged|done|failed) return 0 ;; *) return 1 ;; esac
}

busy=0; unfinished=0; ready=""
for id in $ids; do
  ph=$(phase_of "$id")
  if is_terminal "$ph"; then
    # `failed` is terminal for scheduling but is NOT completion: it leaves its
    # dependents permanently unreachable, which is what exit 3 exists to report.
    [ "$ph" = failed ] && unfinished=$((unfinished + 1))
    continue
  fi
  unfinished=$((unfinished + 1))
  if [ "$ph" != pending ]; then busy=$((busy + 1)); continue; fi

  deps=$("$JQ" -r --arg id "$id" '.tasks[] | select(.id == $id) | .deps[]? // empty' "$graph" 2>/dev/null)
  ok=1
  for d in $deps; do
    # A dep naming a task the graph does not define is a malformed graph, not an
    # unsatisfied edge — refuse instead of silently blocking that task forever.
    echo "$ids" | grep -qx "$d" || { echo "ready-set: task '$id' depends on unknown '$d'" >&2; exit 4; }
    is_satisfied "$(phase_of "$d")" || { ok=0; break; }
  done
  [ "$ok" = 1 ] && ready="$ready $id"
done

[ "$unfinished" -eq 0 ] && { echo "[ready-set] all tasks terminal"; exit 5; }

free=$((cap - busy))
[ "$free" -lt 0 ] && free=0

n=0
for id in $ready; do
  [ "$n" -ge "$free" ] && break
  echo "$id"; n=$((n + 1))
done
[ "$n" -gt 0 ] && exit 0

[ "$busy" -gt 0 ] && { echo "[ready-set] nothing dispatchable, $busy in flight — wait" >&2; exit 2; }

echo "[ready-set] DEADLOCK: $unfinished task(s) unfinished, none dispatchable, none running — a failed dependency or a cycle. Inspect the graph and status; do not wait." >&2
exit 3
```

`chmod +x skills/orchestrate/scripts/ready-set.sh`

- [ ] **Step 4: 테스트 통과 확인**

Run: `npx bats tests/ready-set.bats`
Expected: PASS (1/1)

- [ ] **Step 5: 나머지 계약을 테스트로 고정한다**

`tests/ready-set.bats`에 이어서 추가:

```bash
@test "a dependent waits until its dep is approved, not merely impl_done" {
  graph '{"tasks":[{"id":"t1","deps":[]},{"id":"t2","deps":["t1"]}]}'
  phase t1 impl_done
  run sh "$RS" "$G" "$S" 4
  [ "$status" -eq 2 ]          # t1 busy (review pending), t2 not yet startable

  phase t1 approved
  run sh "$RS" "$G" "$S" 4
  [ "$status" -eq 0 ]
  [ "$output" = "t2" ]
}

@test "review-pending phases occupy a slot (plan_ready and impl_done both count)" {
  graph '{"tasks":[{"id":"a","deps":[]},{"id":"b","deps":[]},{"id":"c","deps":[]}]}'
  phase a plan_ready
  phase b impl_done
  run sh "$RS" "$G" "$S" 2
  [ "$status" -eq 2 ]          # cap 2 fully occupied by two review-waiting tasks
}

@test "a failed dependency is a deadlock, never a quiet wait (the core guard)" {
  graph '{"tasks":[{"id":"t1","deps":[]},{"id":"t2","deps":["t1"]}]}'
  phase t1 failed
  run sh "$RS" "$G" "$S" 4
  [ "$status" -eq 3 ]
  [[ "$output" == *"DEADLOCK"* ]]
}

@test "a cycle surfaces as the same deadlock (boundary)" {
  graph '{"tasks":[{"id":"t1","deps":["t2"]},{"id":"t2","deps":["t1"]}]}'
  run sh "$RS" "$G" "$S" 4
  [ "$status" -eq 3 ]
}

@test "all tasks terminal: exit 5, the run is complete (boundary)" {
  graph '{"tasks":[{"id":"t1","deps":[]},{"id":"t2","deps":["t1"]}]}'
  phase t1 approved
  phase t2 merged
  run sh "$RS" "$G" "$S" 4
  [ "$status" -eq 5 ]
}

@test "an empty task array is complete, not a deadlock (boundary)" {
  graph '{"tasks":[]}'
  run sh "$RS" "$G" "$S" 4
  [ "$status" -eq 5 ]
}

@test "a graph with no .tasks array is refused, not read as empty (error)" {
  graph '{"nodes":[]}'
  run sh "$RS" "$G" "$S" 4
  [ "$status" -eq 4 ]
}

@test "malformed JSON is refused (error)" {
  graph '}{ not json'
  run sh "$RS" "$G" "$S" 4
  [ "$status" -eq 4 ]
}

@test "a dep naming an undefined task is refused, not blocked forever (error)" {
  graph '{"tasks":[{"id":"t1","deps":["ghost"]}]}'
  run sh "$RS" "$G" "$S" 4
  [ "$status" -eq 4 ]
}

@test "LO_MAX_SESSIONS lowers the cap but never raises it" {
  graph '{"tasks":[{"id":"a","deps":[]},{"id":"b","deps":[]},{"id":"c","deps":[]}]}'
  run env LO_MAX_SESSIONS=1 sh "$RS" "$G" "$S" 3
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | grep -c .)" -eq 1 ]

  run env LO_MAX_SESSIONS=9 sh "$RS" "$G" "$S" 2
  [ "$(echo "$output" | grep -c .)" -eq 2 ]
}

@test "a non-numeric or zero cap is refused (boundary)" {
  graph '{"tasks":[{"id":"a","deps":[]}]}'
  run sh "$RS" "$G" "$S" 0
  [ "$status" -eq 4 ]
  run sh "$RS" "$G" "$S" abc
  [ "$status" -eq 4 ]
}

@test "a missing graph or status dir is refused (error)" {
  run sh "$RS" "$BATS_TEST_TMPDIR/nope.json" "$S" 2
  [ "$status" -eq 4 ]
  graph '{"tasks":[]}'
  run sh "$RS" "$G" "$BATS_TEST_TMPDIR/nodir" 2
  [ "$status" -eq 4 ]
}
```

- [ ] **Step 6: 전체 실행**

Run: `npx bats tests/ready-set.bats`
Expected: PASS (13/13). 실패하면 스크립트를 고친다 — 테스트를 약화시키지 않는다.

- [ ] **Step 7: 커밋**

```bash
git add skills/orchestrate/scripts/ready-set.sh tests/ready-set.bats
git -c user.name="Younggi Choi" -c user.email="74581798+choiyounggi@users.noreply.github.com" \
  commit -m "feat(orchestrate): ready-set.sh — 의존 그래프 + 슬롯 회계로 디스패치 가능 집합 판정

Wave 배리어 교체의 판정 절반. deps 충족은 approved 이상에서만 성립하고,
리뷰 대기(plan_ready/impl_done)도 슬롯을 점유한다. 실패한 의존으로 인한
교착은 exit 3으로 즉시 드러나며 조용한 대기(exit 2)와 구분된다."
```

---

### Task 2: `watch-status.sh --tasks` — 추적 대상 축소

**Files:**
- Modify: `skills/orchestrate/scripts/watch-status.sh:36` (인자 파싱), `:129` (스캔 루프)
- Test: `tests/scripts.bats`

**Interfaces:**
- Consumes: 없음 (독립 변경)
- Produces: `watch-status.sh [--tasks <csv>] <dir> <target> <expected> [timeout] [interval]`. Task 4의 SKILL.md가 `--tasks <busy ids> impl_done 1` 형태로 인용한다.

**왜 새 모드가 아니라 스코프인가:** 슬롯 스케줄러가 필요한 건 "추적 중인 것 중 아무나 하나 도달"이다. `done_count`는 status 디렉토리 **전체**를 세므로, 이미 approved된 이전 task들 때문에 `expected=1`이 즉시 만족되어 스핀한다. 스캔을 현재 busy한 id로 좁히면 `expected=1`이 정확히 "아무나 하나"가 된다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/scripts.bats` 끝에 추가:

```bash
@test "watch-status --tasks: only the named tasks are counted" {
  mkdir -p "$STATUS_DIR"
  printf '{"task":"old","phase":"approved"}' > "$STATUS_DIR/old.json"
  printf '{"task":"a","phase":"implementing"}' > "$STATUS_DIR/a.json"
  # `old` already passed the target, but it is not being tracked: without
  # scoping, expected=1 would be satisfied instantly and the wait would spin.
  run bash "$WS" --tasks a "$STATUS_DIR" impl_done 1 2 1
  [ "$status" -eq 2 ]
}

@test "watch-status --tasks: returns as soon as ANY tracked task reaches target" {
  mkdir -p "$STATUS_DIR"
  printf '{"task":"a","phase":"impl_done"}'    > "$STATUS_DIR/a.json"
  printf '{"task":"b","phase":"implementing"}' > "$STATUS_DIR/b.json"
  run bash "$WS" --tasks a,b "$STATUS_DIR" impl_done 1 5 1
  [ "$status" -eq 0 ]
}

@test "watch-status --tasks: an untracked failed task does not abort the wait" {
  mkdir -p "$STATUS_DIR"
  printf '{"task":"old","phase":"failed"}'     > "$STATUS_DIR/old.json"
  printf '{"task":"a","phase":"implementing"}' > "$STATUS_DIR/a.json"
  run bash "$WS" --tasks a "$STATUS_DIR" impl_done 1 2 1
  [ "$status" -eq 2 ]
}

@test "watch-status --tasks: an explicit timeout argument still outranks the env" {
  # --tasks is consumed before the positional count is taken; if argc were
  # captured before that, the 4th positional would stop being recognised and
  # LO_PHASE_TIMEOUTS would silently win.
  mkdir -p "$STATUS_DIR"
  printf '{"task":"a","phase":"implementing"}' > "$STATUS_DIR/a.json"
  run env LO_PHASE_TIMEOUTS="impl_done=999" bash "$WS" --tasks a "$STATUS_DIR" impl_done 1 2 1
  [[ "$output" == *"budget=2s"* ]]
  [[ "$output" == *"source=arg"* ]]
}

@test "watch-status: without --tasks every status file is still counted (no regression)" {
  mkdir -p "$STATUS_DIR"
  printf '{"task":"a","phase":"done"}' > "$STATUS_DIR/a.json"
  printf '{"task":"b","phase":"done"}' > "$STATUS_DIR/b.json"
  run bash "$WS" "$STATUS_DIR" impl_done 2 5 1
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `npx bats tests/scripts.bats`
Expected: 새 테스트 4개 FAIL (`--tasks`가 디렉토리 인자로 읽혀 exit 4). 마지막 무회귀 테스트는 PASS.

- [ ] **Step 3: 인자 파싱을 고친다**

`watch-status.sh`에서 `argc=$#` 줄(현재 35–36행)을 다음으로 교체:

```sh
# --tasks scopes the scan to the given ids. The slot scheduler needs "any ONE of
# the tasks I am currently running reached the target"; counting the whole status
# dir would satisfy expected=1 from tasks approved in earlier rounds and spin.
only=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tasks) shift; only="${1:-}"; [ -n "$only" ] || { echo "watch-status: --tasks needs a comma-separated id list" >&2; exit 4; }; shift ;;
    --) shift; break ;;
    -*) echo "watch-status: unknown option '$1'" >&2; exit 4 ;;
    *) break ;;
  esac
done
# Captured AFTER option parsing: argc decides whether the 4th POSITIONAL was
# given, and options must not be counted toward it.
argc=$#
dir="$1"; target="$2"; expected="$3"; timeout="${4:-3600}"; interval="${5:-15}"
```

- [ ] **Step 4: 스캔 루프에 필터를 넣는다**

`for f in "$dir"/*.json; do` 바로 다음 `[ -f "$f" ] || continue` 아래에 추가:

```sh
    if [ -n "$only" ]; then
      base=${f##*/}; base=${base%.json}
      # Exact membership on a comma-delimited list: the commas around both sides
      # keep `t1` from matching `t12`.
      case ",$only," in *",$base,"*) : ;; *) continue ;; esac
    fi
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `npx bats tests/scripts.bats`
Expected: PASS (전부)

- [ ] **Step 6: 헤더 문서 갱신**

`watch-status.sh` 헤더의 usage 줄을 `watch-status.sh [--tasks <csv>] <dir> <target> <expected> [timeout] [interval]`로 고치고, `--tasks`의 목적(슬롯 스케줄러의 "아무나 하나" 대기)을 두 줄로 적는다.

- [ ] **Step 7: 전체 스위트 + 커밋**

Run: `npx bats tests/` → 실패 0, 통과 수가 이전보다 늘었는지 확인.

```bash
git add skills/orchestrate/scripts/watch-status.sh tests/scripts.bats
git -c user.name="Younggi Choi" -c user.email="74581798+choiyounggi@users.noreply.github.com" \
  commit -m "feat(orchestrate): watch-status --tasks — 추적 중인 집합으로 스캔 축소

슬롯 스케줄러는 '지금 돌리는 것 중 아무나 하나 도달'이 필요한데, status 디렉토리
전체를 세면 이전 라운드의 approved가 expected=1을 즉시 만족시켜 스핀한다.
argc는 옵션 파싱 뒤에 잡아 4번째 위치 인자 판정이 깨지지 않게 한다."
```

---

### Task 3: SKILL.md Phase 2 — graph.json 산출 + 슬롯 제안

**Files:**
- Modify: `skills/orchestrate/SKILL.md:73-107` (Phase 2 + Gate 1)
- Test: `tests/scripts.bats` (문서 계약 grep — `tests/send-prompt.bats:467`의 앵커 테스트 선례를 따른다)

**Interfaces:**
- Consumes: Task 1의 `graph.json` 스키마와 `ready-set.sh` CLI 계약.
- Produces: Gate 1 보고서 형식(슬롯 수 + 근거). Task 4의 디스패치 루프가 이 승인된 cap을 소비한다.

- [ ] **Step 1: 문서 계약 테스트를 먼저 쓴다**

`tests/scripts.bats` 끝에 추가:

```bash
@test "SKILL.md Phase 2: graph.json artifact and the slot proposal are documented" {
  SKILL="${BATS_TEST_DIRNAME}/../skills/orchestrate/SKILL.md"
  grep -qF '.orchestration/graph.json' "$SKILL"
  grep -qF 'LO_MAX_SESSIONS' "$SKILL"
  # The cap must never be a bare number again: the report has to name what it
  # protects, or "dynamic" degrades back into a hardcoded 4.
  grep -qF 'coordinator attention' "$SKILL"
  ! grep -qF 'concurrent-session cap** (default 4)' "$SKILL"
}
```

- [ ] **Step 2: 실패 확인**

Run: `npx bats tests/scripts.bats`
Expected: FAIL — `graph.json`이 SKILL.md에 없음.

- [ ] **Step 3: Phase 2를 고쳐 쓴다**

`## Phase 2 — Decompose`에서 `Apply a **concurrent-session cap** (default 4) — if a Wave exceeds it, split it or ask. Tasks in the same Wave are independent (parallel); a later Wave starts only after the previous Wave is approved.` 문장을 삭제하고, 그 자리에 넣는다:

```markdown
Write BOTH artifacts: `conflict-matrix.md` for humans and
`.orchestration/graph.json` for the scheduler. A markdown table is not machine
readable.

```json
{ "tasks": [
    { "id": "t1", "deps": [],     "files": ["src/auth/**"], "outputs": ["AuthToken"] },
    { "id": "t3", "deps": ["t1"], "files": ["src/api/**"],  "consumes": ["AuthToken"] }
] }
```

Waves are **an illustration in the Gate 1 report, not an execution unit.**
Execution is decided by `ready-set.sh`: a task runs as soon as its dependencies
are `approved` and a slot is free. Still topologically sort — the result shows
the user the expected flow — but nothing waits on a Wave boundary.

**Propose the slot count.** Pick the number from the task count, their size, and
their risk, and **say what the number protects**: this cap guards **coordinator
attention** and **API usage/budget**, not machine resources. Neither is
queryable, which is why it is a judgement rather than a computation. A slot is
held from dispatch until the task reaches a terminal state — `plan_ready` and
`impl_done` (review pending) count as held, because a pile of unreviewed tasks
next to a stream of new ones makes the cap meaningless. When `LO_MAX_SESSIONS`
is set it is an upper bound and overrides the proposal.
```

`graph.json`을 쓴 직후 검증한다는 문장을 덧붙인다:

```markdown
After writing it, run `scripts/ready-set.sh <graph> <status-dir> <cap>` once and
confirm it does **not** exit 4 — malformed JSON, a missing `.tasks` array, and a
dependency naming an undefined task are all caught here.
```

- [ ] **Step 4: Gate 1 보고 항목을 고친다**

`## 🚦 Gate 1` 의 `Report the task list, Waves, session count, and a rough cost note.` 를 다음으로 교체:

```markdown
Report the task list, the dependency graph (showing the expected flow as Waves is
fine), the proposed **slot count with its rationale and what it protects**, and a
rough cost note.
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `npx bats tests/scripts.bats`
Expected: PASS

- [ ] **Step 6: 커밋**

```bash
git add skills/orchestrate/SKILL.md tests/scripts.bats
git -c user.name="Younggi Choi" -c user.email="74581798+choiyounggi@users.noreply.github.com" \
  commit -m "docs(orchestrate): Phase 2 — graph.json 산출 + 근거 있는 슬롯 제안

하드코딩 4를 없애고, 캡이 보호하는 자원(코디네이터 주의력/API 예산)을 보고에
명시하게 한다. LO_MAX_SESSIONS가 상한."
```

---

### Task 4: SKILL.md Phase 3+4 → 디스패치 루프, 재진입

**Files:**
- Modify: `skills/orchestrate/SKILL.md:109-141` (Phase 3 서두), `:188-213` (O4), `:332-350` (Phase 4), `:378-400` (재진입)
- Test: `tests/scripts.bats`

**Interfaces:**
- Consumes: Task 1의 `ready-set.sh` 종료코드 0/2/3/4/5, Task 2의 `watch-status.sh --tasks`, Task 3의 승인된 cap.
- Produces: 없음 (PR 1의 마지막 task)

- [ ] **Step 1: 문서 계약 테스트를 먼저 쓴다**

```bash
@test "SKILL.md: the dispatch loop cites ready-set exit codes and --tasks" {
  SKILL="${BATS_TEST_DIRNAME}/../skills/orchestrate/SKILL.md"
  grep -qF 'scripts/ready-set.sh' "$SKILL"
  grep -qF '--tasks' "$SKILL"
  # exit 3 is the guard this design turns on; it must be spelled out as
  # "do not wait", or it degrades into the silent stall it exists to prevent.
  grep -qF 'DEADLOCK' "$SKILL"
  # Waves must no longer be described as an execution barrier.
  ! grep -qF 'A later Wave launches only after' "$SKILL"
}
```

- [ ] **Step 2: 실패 확인**

Run: `npx bats tests/scripts.bats` → FAIL

- [ ] **Step 3: Phase 3+4을 하나의 디스패치 루프로 통합한다**

`**Phases 3–4 repeat per Wave in `## Waves` order.** A later Wave launches only after the previous Wave is fully approved; `<N>` below = the *current* Wave's task count. Single-Wave splits run everyone in parallel (the original behavior).` 를 삭제하고, 그 자리에 다음을 넣는다:

```markdown
**Phases 3–4 are one dispatch loop, not a per-Wave repeat.** Each round:

1. `scripts/ready-set.sh .orchestration/graph.json .orchestration/status <cap>`
   → **0** dispatch the printed ids, **2** nothing dispatchable but work is in
   flight (go wait for an event), **3** **DEADLOCK** — a failed dependency or a
   cycle: **do not wait**, report it and get a human decision (with no worker
   running, no event can ever arrive); after the human intervenes, return to
   step 1 to re-run the check, **4** the graph or status could not be read —
   refuse, do not guess; fix the error then re-run step 1, **5** every task is
   in a terminal state → go to Phase 5.
2. For each dispatched task (`<N>` = the number of tasks in this round):
   - tmux: **0** (Preceding-interface injection) + steps **1–3** below (setup,
     brief, launch, watch plan_ready). Orca: **O1–O5**.
   - **1** `scripts/setup-worktrees.sh <integ> <root> <base> <branch>...` then
     verify with `git worktree list`.
   - **2** Per task: write `briefs/<task>.md` (templates/brief.md) — fill
     `<tools_guidance>` and `<design_spec>` — then launch session and watch
     until `plan_ready` (step 3 below). **Write the brief at dispatch time.**
     It only needs the signatures this task consumes, and by then those are
     `approved`, so they're settled.
   - **3** Collect `plans/<task>.md` when each session reaches `plan_ready`.
3. For each planned task, deliver §2 (implement) with `scripts/send-prompt.sh
   send lo-<n> "<prompt>"` (tmux, see Phase 4 for exit-code branch logic), or
   `orca orchestration task-create` the implement Task then
   `scripts/orca-worker-start --task <impl_task> --terminal <handle>` (Orca).
   On delivery failure, re-run step 3 after fixing the error.
4. Wait for event. tmux: `scripts/watch-status.sh --tasks <running ids>
   <status-dir> impl_done <N>` — without `--tasks` the tasks approved in
   earlier rounds satisfy `expected=<N>` immediately and the wait spins. Orca:
   `scripts/orca-wait.sh` with the implement Task ids, already event-driven.
5. On wake, handle that task: review each worktree diff (`git -C <wt> diff
   <integ>...HEAD`). If tests weak, audit with `test-quality-auditor`. On
   approval, return to step 1 — whatever dependency it released shows up in the
   next `ready-set.sh` round and the freed slot refills immediately. On rework
   needed, write `reviews/<task>-rN.md` and re-deliver with `send-prompt.sh
   send` (or new Orca Task on same terminal); after 3 failed rounds, escalate.
   When `ready-set.sh` returns **5**, go to Phase 5.
```

- [ ] **Step 4: 재진입 절을 고친다**

`## Re-entry (resume)` 의 첫 문장 뒤에 추가:

```markdown
There is no intermediate state such as a Wave index to restore. Reading
`.orchestration/graph.json` plus `status/*.json` and running `ready-set.sh` IS
the restored state — the same inputs always yield the same answer.
```

- [ ] **Step 5: 강화된 테스트를 작성한다**

`tests/scripts.bats` 의 contract test를 다음으로 교체해서 루프 구조를 검증한다:

```bash
@test "SKILL.md: the dispatch loop structure pins step order and error handling" {
  SKILL="${BATS_TEST_DIRNAME}/../skills/orchestrate/SKILL.md"
  # Step 1 must run ready-set.sh first to decide what is dispatchable.
  grep -qF '1. `scripts/ready-set.sh' "$SKILL"
  # Step 1 exit codes must document what happens: exit 3/4 return to step 1,
  # not "get a human decision" and vanish.
  grep -qF 'after the human intervenes, return to step 1' "$SKILL"
  grep -qF 'fix the error then re-run step 1' "$SKILL"
  # Step 3 must deliver the implement prompt (was missing in v1); it is keyed
  # off `send-prompt.sh send` on tmux or `task-create` on Orca.
  grep -qF 'deliver §2 (implement)' "$SKILL"
  grep -qF 'send-prompt.sh send' "$SKILL"
  # Step 4 must wait, scoped to running ids via --tasks to avoid spin.
  grep -qF 'watch-status.sh --tasks' "$SKILL"
  # Step 5 must return to step 1 on approval, closing the loop.
  grep -qF 'return to step 1' "$SKILL"
  # Exit code 3 must be DEADLOCK and documented as "do not wait".
  grep -qF 'DEADLOCK' "$SKILL"
  # Waves must no longer be described as an execution barrier.
  ! grep -qF 'A later Wave launches only after' "$SKILL"
}
```

- [ ] **Step 6: 테스트 + 전체 스위트**

Run: `npx bats tests/scripts.bats` + `npx bats tests/`
Expected: 실패 0.

- [ ] **Step 7: 커밋**

```bash
git add skills/orchestrate/SKILL.md tests/scripts.bats
git -c user.name="Younggi Choi" -c user.email="74581798+choiyounggi@users.noreply.github.com" \
  commit -m "docs(orchestrate): Phase 3+4를 디스패치 루프로, 재진입 단순화

Wave 배리어를 없애고 ready-set 판정 → 빈 슬롯 충전 → 이벤트 대기 루프로 바꾼다.
exit 3(교착)은 대기 금지로 명시했다 — 실행 중인 워커가 없으면 이벤트도 오지 않는다."
```

---

## Self-Review

**1. 스펙 커버리지**

| 스펙 절 | 담당 task |
|---|---|
| §3.1 그래프 + 슬롯 회계, deps=approved, 슬롯 점유 범위 | Task 1 |
| §3.2 슬롯 제안 + `LO_MAX_SESSIONS` 상한 | Task 1(집행), Task 3(제안·보고) |
| §3.3 한도/stall 반응 | **기존 동작으로 충족** — `watch-status` exit 7 / `orca-worker-stalled.sh`가 이미 stall을 보고하고, 디스패치 루프는 그때 1번으로 돌아가지 않으므로 큐 투입이 자연히 멈춘다. 새 코드 없음 |
| §3.4 디스패치 루프, brief 주입 시점, `--tasks`, 재진입 | Task 2, Task 4 |
| §4 실패 처리 (exit 0/2/3/4/5, 그래프 검증) | Task 1(전부), Task 3(Phase 2 쓰기 직후 검증 호출) |
| §5 테스트 | Task 1·2의 bats |
| §3.5 분할 | **범위 밖 (PR 2)** — 의도적 |

§4의 "분할로 인한 변경 시점 검증"은 PR 2 소관이라 여기 없다. 최초 작성 시점 검증은 Task 3 Step 3이 커버한다.

**2. 플레이스홀더 스캔** — TBD/TODO 없음. 모든 코드 스텝에 실제 코드가 있고, 문서 스텝은 교체할 원문과 새 문장을 모두 적었다.

**3. 타입/이름 일관성** — `ready-set.sh <graph.json> <status-dir> <cap>` 시그니처가 Task 1 정의, Task 3 Step 3, Task 4 Step 3에서 동일하다. 종료코드 0/2/3/4/5의 의미가 세 곳에서 동일하다. `--tasks <csv>`가 Task 2 정의와 Task 4 인용에서 동일하다. `LO_MAX_SESSIONS`는 Task 1(집행)과 Task 3(문서)에서 같은 의미(상한)로 쓰인다.
