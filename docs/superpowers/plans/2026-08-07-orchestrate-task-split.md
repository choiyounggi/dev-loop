# orchestrate 실행 중 task 분할 (PR 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 실행 중 "이 task가 예상보다 크다"를 알게 됐을 때, 워커가 제안하고 코디네이터가 판정해 `graph.json`에 조각을 추가하는 경로를 연다.

**Architecture:** 워커는 기존 ask 채널로 **파일 범위를 붙여** 분할을 제안한다. 코디네이터가 충돌 매트릭스로 겹침을 판정해, 안 겹치면 새 노드를 추가하고(ready-set이 빈 슬롯에 집어간다 → 병렬 이득) 겹치면 `deps:[parent]`로 같은 워커에 순차 부착한다(리뷰 단위 축소 이득). 그래프 변경은 새 `graph-add.sh`가 전량 검증 후 원자적으로 쓰거나 아무것도 바꾸지 않는다.

**Tech Stack:** POSIX sh, jq, bats-core. 새 의존성 없음.

## Global Constraints

- 스펙 정본: `docs/superpowers/specs/2026-08-07-orchestrate-ready-set-scheduler-design.md` §3.5(분할)와 §4(graph 변경 방어). 각 task는 해당 절을 권위로 한다.
- **선행 조건: PR 1이 main에 머지된 상태에서 시작한다.** `skills/orchestrate/scripts/ready-set.sh`, `graph.json` 스키마, `watch-status.sh --tasks`가 이미 존재한다고 전제한다. 브랜치는 머지된 main에서 딴다.
- 분할 깊이는 1이다. 쪼개서 나온 조각(`split_of`를 가진 노드)은 다시 쪼갤 수 없다.
- 겹치는 분할에 **새 워크트리를 만들지 않는다.** 같은 워크트리·같은 워커에 후속 task로 붙인다. B가 A의 파일을 편집해야 하는데 A의 코드는 Phase 6 전까지 통합 브랜치에 없기 때문이다.
- 분할 승인은 코디네이터가 결정하고 즉시 보고한다. 사용자의 블로킹 승인을 받지 않는다.
- **거절도 명시적 `reply`여야 한다.** 답이 없으면 워커가 자체 판단으로 진행한다 (v1.4.1에서 고친 ask-타임아웃 문제의 재발).
- 새 스크립트는 POSIX `sh`로 쓰고 `set -u`를 켠다. `jq` 부재는 exit 127.
- 그래프 변경은 원자적이다. 검증에 하나라도 걸리면 **파일을 건드리지 않는다** — 반쯤 적용된 그래프가 남으면 재진입이 깨진다.
- `skills/orchestrate/SKILL.md`와 `skills/orchestrate/templates/brief.md`에 넣는 모든 문장은 **영어다**. 두 파일 모두 현재 한글이 0자이며 배포되는 스킬 본문의 관례다. 이 두 파일을 grep하는 테스트도 영어 문자열을 대상으로 한다. `docs/` 아래 스펙·계획만 한국어를 쓴다.
- `/tmp`·`$TMPDIR`에 실행 파일을 만들지 않는다. 테스트용 실행 파일이 필요하면 레포 안 `.claude/tmp/`를 쓴다.
- 기존 407개 bats는 전부 그린을 유지한다. PR 통과 조건이다.
- 커밋 author는 `Younggi Choi <74581798+choiyounggi@users.noreply.github.com>` (공개 레포 관례).

---

## File Structure

**신규**

- `skills/orchestrate/scripts/graph-add.sh` — `graph.json`에 노드 하나를 추가한다. 결과 그래프 전체를 검증하고, 통과하면 원자적으로 쓰고, 아니면 아무것도 바꾸지 않는다. 이 PR의 유일한 신규 실행 파일.
- `tests/graph-add.bats` — 위 스크립트의 계약 고정.

**수정**

- `skills/orchestrate/templates/brief.md` — 분할 제안 시 파일 범위를 필수로 요구하는 규칙.
- `skills/orchestrate/SKILL.md` — 코디네이터의 분할 판정 절차(겹침 → 두 갈래), 거절 시 명시적 reply, 깊이 2 시도의 에스컬레이션.
- `tests/scripts.bats` — 문서 계약 grep.

**`split_of` 필드 (이 PR이 추가하는 스키마 확장)**

```json
{ "id": "t3b", "deps": ["t3"], "files": ["src/auth/session.ts"], "outputs": ["SessionStore"], "split_of": "t3" }
```

`split_of`는 "이 노드는 어느 task를 쪼개서 나왔는가"를 기록한다. 깊이 제한은 이 필드 하나로 집행된다 — `split_of`를 가진 노드를 다시 쪼개려는 시도는 거부된다. `ready-set.sh`는 이 필드를 읽지 않으므로 PR 1의 동작은 바뀌지 않는다.

---

### Task 1: `graph-add.sh` — 검증된 원자적 그래프 확장

**Files:**
- Create: `skills/orchestrate/scripts/graph-add.sh`
- Test: `tests/graph-add.bats`

**Interfaces:**
- Consumes: `.orchestration/graph.json` (PR 1이 정의한 스키마: `{"tasks":[{"id","deps","files","outputs","consumes"}]}`).
- Produces: CLI 계약 `graph-add.sh <graph.json> <node-json>` — 종료코드 0/3/4/127. Task 3의 SKILL.md가 이 계약을 인용한다.

- [ ] **Step 1: 실패하는 테스트를 쓴다 (정상 경로)**

`tests/graph-add.bats` 생성:

```bash
#!/usr/bin/env bats
# Tests for graph-add.sh — the only writer of graph.json after Phase 2.
# It adds ONE node and validates the RESULTING graph. A rejected add must
# leave the file byte-identical: a half-applied graph breaks re-entry.

setup() {
  GA="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/graph-add.sh"
  G="${BATS_TEST_TMPDIR}/graph.json"
}

graph() { printf '%s' "$1" > "$G"; }

@test "a valid split child is appended and the parent is untouched" {
  graph '{"tasks":[{"id":"t1","deps":[],"files":["a.ts"],"outputs":["A"]}]}'
  run sh "$GA" "$G" '{"id":"t1b","deps":["t1"],"files":["b.ts"],"outputs":["B"],"split_of":"t1"}'
  [ "$status" -eq 0 ]
  [ "$(jq -r '.tasks | length' "$G")" = "2" ]
  [ "$(jq -r '.tasks[1].split_of' "$G")" = "t1" ]
  [ "$(jq -r '.tasks[0].outputs[0]' "$G")" = "A" ]
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `cd ~/Desktop/workspace/dev-loop && npx bats tests/graph-add.bats`
Expected: FAIL — `graph-add.sh` 가 없어서 `sh: ... No such file`.

- [ ] **Step 3: 최소 구현**

`skills/orchestrate/scripts/graph-add.sh` 생성:

```sh
#!/bin/sh
# graph-add.sh — add ONE task node to graph.json, or change nothing.
#
# Phase 2 writes graph.json once; this is the only thing that may grow it
# afterwards, when a worker's split proposal is accepted. Every check runs
# against the RESULTING graph rather than the node alone, because the defects
# that matter are relational: a cycle, a second producer of the same output, a
# split of a split. A rejected add leaves the file byte-identical — a
# half-applied graph would make re-entry read a state that never existed.
#
# usage: graph-add.sh <graph.json> <node-json>
#   <node-json>  {"id","deps":[],"files":[],"outputs":[],"split_of":"<parent>"}
#                `split_of` is what enforces the depth-1 rule: a node carrying
#                it is a split child and can never be split again.
#
# exit 0  added (file rewritten atomically)
# exit 3  REJECTED — the resulting graph would be invalid. Nothing was written;
#         the reason is printed. Fix the proposal, do not retry unchanged.
# exit 4  the graph or the node could not be read — refuse rather than guess
# exit 127 jq not found
set -u

JQ=$(command -v jq) || { echo "graph-add: jq not found" >&2; exit 127; }

graph="${1:-}"; node="${2:-}"
[ -n "$graph" ] && [ -n "$node" ] || {
  echo "usage: graph-add.sh <graph.json> <node-json>" >&2; exit 4; }
[ -f "$graph" ] || { echo "graph-add: graph '$graph' not found" >&2; exit 4; }

"$JQ" -e 'has("tasks") and (.tasks | type == "array")' "$graph" >/dev/null 2>&1 || {
  echo "graph-add: graph '$graph' is not a valid task graph" >&2; exit 4; }

printf '%s' "$node" | "$JQ" -e 'type == "object" and (.id | type == "string") and (.id | length > 0)' \
  >/dev/null 2>&1 || { echo "graph-add: node must be a JSON object with a non-empty string id" >&2; exit 4; }

# Build the candidate graph in memory. Nothing touches the file until every
# check below has passed.
cand=$(printf '%s' "$node" | "$JQ" --slurpfile g "$graph" '$g[0] | .tasks += [.]' 2>/dev/null) || {
  echo "graph-add: could not build the candidate graph" >&2; exit 4; }

reject() { echo "graph-add: REJECTED — $1" >&2; exit 3; }

nid=$(printf '%s' "$node" | "$JQ" -r '.id')

# 1. The id must be new. Overwriting a live task would orphan its worker.
printf '%s' "$graph" >/dev/null
"$JQ" -e --arg id "$nid" '[.tasks[] | select(.id == $id)] | length == 0' "$graph" >/dev/null 2>&1 \
  || reject "task id '$nid' already exists"

# 2. Every dependency must name a task the graph defines, otherwise the new node
#    is unreachable forever and ready-set.sh would refuse the whole graph.
missing=$(printf '%s' "$cand" | "$JQ" -r --arg id "$nid" '
  (.tasks | map(.id)) as $ids
  | .tasks[] | select(.id == $id) | .deps[]? | select(. as $d | ($ids | index($d)) | not)')
[ -z "$missing" ] || reject "dependency '$missing' names no task in the graph"

# 3. Depth 1: a split child may not itself be split. This is what stops a worker
#    from deferring work by recursive subdivision, and keeps the graph readable.
sof=$(printf '%s' "$node" | "$JQ" -r '.split_of // empty')
if [ -n "$sof" ]; then
  "$JQ" -e --arg p "$sof" '[.tasks[] | select(.id == $p)] | length == 1' "$graph" >/dev/null 2>&1 \
    || reject "split_of '$sof' names no task in the graph"
  "$JQ" -e --arg p "$sof" '[.tasks[] | select(.id == $p) | select(has("split_of"))] | length == 0' \
    "$graph" >/dev/null 2>&1 || reject "'$sof' is itself a split child — splitting a split is refused (depth 1)"
fi

# 4. One producer per output. Phase 2 already assigns a single producer; a split
#    child therefore declares only what IT newly produces. Moving an output off a
#    parent is a re-decomposition, not an add — that goes back to the user.
dup=$(printf '%s' "$cand" | "$JQ" -r '[.tasks[].outputs[]?] | group_by(.) | map(select(length > 1) | .[0]) | .[]?')
[ -z "$dup" ] || reject "output '$dup' would have two producers"

# 5. No cycle. Repeatedly strip tasks whose deps are all outside the remaining
#    set; whatever will not strip is a cycle.
printf '%s' "$cand" | "$JQ" -e '
  def acyclic:
    def step($rem):
      ($rem | map(.id)) as $ids
      | ($rem | map(select([.deps[]? | select(. as $d | $ids | index($d))] | length == 0))) as $free
      | if ($free | length) == 0 then ($rem | length) == 0
        else step($rem - $free) end;
    step(.tasks);
  acyclic' >/dev/null 2>&1 || reject "the resulting graph contains a dependency cycle"

# Atomic: write beside the target and rename, so a reader never sees a partial
# file (the same tmp+mv shape ask-coordinator.sh uses for question records).
tmp="$graph.tmp.$$"
printf '%s\n' "$cand" > "$tmp" || { rm -f "$tmp"; echo "graph-add: could not write $tmp" >&2; exit 4; }
mv "$tmp" "$graph" || { rm -f "$tmp"; echo "graph-add: could not replace $graph" >&2; exit 4; }
echo "graph-add: added '$nid'"
```

`chmod +x skills/orchestrate/scripts/graph-add.sh`

- [ ] **Step 4: 테스트 통과 확인**

Run: `npx bats tests/graph-add.bats`
Expected: PASS (1/1)

- [ ] **Step 5: 나머지 계약을 테스트로 고정한다**

`tests/graph-add.bats`에 이어서 추가:

```bash
@test "splitting a split is refused (depth 1) and the file is untouched" {
  graph '{"tasks":[{"id":"t1","deps":[],"outputs":["A"]},{"id":"t1b","deps":["t1"],"outputs":["B"],"split_of":"t1"}]}'
  before=$(cat "$G")
  run sh "$GA" "$G" '{"id":"t1c","deps":["t1b"],"outputs":["C"],"split_of":"t1b"}'
  [ "$status" -eq 3 ]
  [[ "$output" == *"depth 1"* ]]
  [ "$(cat "$G")" = "$before" ]
}

@test "a duplicate output is refused — one producer per output (error)" {
  graph '{"tasks":[{"id":"t1","deps":[],"outputs":["AuthToken"]}]}'
  before=$(cat "$G")
  run sh "$GA" "$G" '{"id":"t2","deps":[],"outputs":["AuthToken"]}'
  [ "$status" -eq 3 ]
  [[ "$output" == *"two producers"* ]]
  [ "$(cat "$G")" = "$before" ]
}

@test "a node that would close a cycle is refused (boundary)" {
  graph '{"tasks":[{"id":"t1","deps":["t2"],"outputs":["A"]}]}'
  before=$(cat "$G")
  run sh "$GA" "$G" '{"id":"t2","deps":["t1"],"outputs":["B"]}'
  [ "$status" -eq 3 ]
  [[ "$output" == *"cycle"* ]]
  [ "$(cat "$G")" = "$before" ]
}

@test "a duplicate task id is refused, never an overwrite (error)" {
  graph '{"tasks":[{"id":"t1","deps":[],"outputs":["A"]}]}'
  before=$(cat "$G")
  run sh "$GA" "$G" '{"id":"t1","deps":[],"outputs":["Z"]}'
  [ "$status" -eq 3 ]
  [[ "$output" == *"already exists"* ]]
  [ "$(cat "$G")" = "$before" ]
}

@test "a dependency on an undefined task is refused (error)" {
  graph '{"tasks":[{"id":"t1","deps":[],"outputs":["A"]}]}'
  run sh "$GA" "$G" '{"id":"t2","deps":["ghost"],"outputs":["B"]}'
  [ "$status" -eq 3 ]
  [[ "$output" == *"ghost"* ]]
}

@test "split_of naming an undefined parent is refused (error)" {
  graph '{"tasks":[{"id":"t1","deps":[],"outputs":["A"]}]}'
  run sh "$GA" "$G" '{"id":"t2","deps":[],"outputs":["B"],"split_of":"ghost"}'
  [ "$status" -eq 3 ]
  [[ "$output" == *"ghost"* ]]
}

@test "a node with no outputs is fine — not every split produces an interface (boundary)" {
  graph '{"tasks":[{"id":"t1","deps":[],"outputs":["A"]}]}'
  run sh "$GA" "$G" '{"id":"t1b","deps":["t1"],"files":["b.ts"],"split_of":"t1"}'
  [ "$status" -eq 0 ]
  [ "$(jq -r '.tasks | length' "$G")" = "2" ]
}

@test "an empty graph accepts a first node (boundary)" {
  graph '{"tasks":[]}'
  run sh "$GA" "$G" '{"id":"t1","deps":[],"outputs":["A"]}'
  [ "$status" -eq 0 ]
  [ "$(jq -r '.tasks[0].id' "$G")" = "t1" ]
}

@test "malformed node JSON is refused with 4, not 3 (error)" {
  graph '{"tasks":[]}'
  run sh "$GA" "$G" '}{ not json'
  [ "$status" -eq 4 ]
}

@test "a node without an id is refused with 4 (boundary)" {
  graph '{"tasks":[]}'
  run sh "$GA" "$G" '{"deps":[]}'
  [ "$status" -eq 4 ]
}

@test "a missing graph file is refused with 4 (error)" {
  run sh "$GA" "$BATS_TEST_TMPDIR/nope.json" '{"id":"t1","deps":[]}'
  [ "$status" -eq 4 ]
}

@test "a graph with no .tasks array is refused with 4, not read as empty (error)" {
  graph '{"nodes":[]}'
  run sh "$GA" "$G" '{"id":"t1","deps":[]}'
  [ "$status" -eq 4 ]
}

@test "the written graph is valid input for ready-set.sh (integration boundary)" {
  # The only consumer of this file. An add that ready-set.sh cannot parse would
  # strand the whole run, and the rejection codes differ (3 here, 4 there).
  RS="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/ready-set.sh"
  S="${BATS_TEST_TMPDIR}/status"; mkdir -p "$S"
  graph '{"tasks":[{"id":"t1","deps":[],"outputs":["A"]}]}'
  run sh "$GA" "$G" '{"id":"t1b","deps":["t1"],"outputs":["B"],"split_of":"t1"}'
  [ "$status" -eq 0 ]
  printf '{"task":"t1","phase":"approved"}' > "$S/t1.json"
  run sh "$RS" "$G" "$S" 4
  [ "$status" -eq 0 ]
  [ "$output" = "t1b" ]
}
```

- [ ] **Step 6: 전체 실행**

Run: `npx bats tests/graph-add.bats`
Expected: PASS (14/14). 실패하면 스크립트를 고친다 — 테스트를 약화시키지 않는다.

- [ ] **Step 7: 커밋**

```bash
git add skills/orchestrate/scripts/graph-add.sh tests/graph-add.bats
git -c user.name="Younggi Choi" -c user.email="74581798+choiyounggi@users.noreply.github.com" \
  commit -m "feat(orchestrate): graph-add.sh — 검증된 원자적 그래프 확장

분할 제안이 승인됐을 때 graph.json을 늘리는 유일한 경로. 결과 그래프 전체를
검증한다(중복 id, 미정의 의존, 분할 깊이 1, 중복 output, 사이클). 하나라도
걸리면 파일을 건드리지 않는다 — 반쯤 적용된 그래프는 재진입을 깨뜨린다."
```

---

### Task 2: brief 템플릿 — 분할 제안에 파일 범위 필수

**Files:**
- Modify: `skills/orchestrate/templates/brief.md`
- Test: `tests/scripts.bats`

**Interfaces:**
- Consumes: Task 1의 `split_of` 스키마 (워커가 제안할 때 어떤 필드를 채워야 하는지).
- Produces: 워커 제안의 형식. Task 3의 코디네이터 절차가 이 형식을 받는다고 전제한다.

**왜 필수인가:** 코디네이터의 판정은 파일 겹침 검사 한 번이다. 파일 범위가 없는 제안은 판정 자체가 불가능해서 되묻는 왕복이 한 번 더 생긴다 — 그 사이 워커는 멈춰 있다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/scripts.bats` 끝에 추가:

```bash
@test "brief template: a split proposal must carry its file scope" {
  BRIEF="${BATS_TEST_DIRNAME}/../skills/orchestrate/templates/brief.md"
  grep -qF 'split proposal' "$BRIEF"
  # Without the file list the coordinator cannot run the overlap test, so the
  # requirement has to be stated where the worker reads it, not only in SKILL.md.
  grep -qF 'files it would touch' "$BRIEF"
  grep -qF 'split_of' "$BRIEF"
  # The template ships to users; it stays English-only like SKILL.md.
  [ "$(grep -c '[가-힣]' "$BRIEF")" -eq 0 ]
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `npx bats tests/scripts.bats`
Expected: FAIL — `split proposal` 문자열이 템플릿에 없음.

- [ ] **Step 3: 템플릿에 규칙을 넣는다**

`skills/orchestrate/templates/brief.md`의 `</task_brief>` 닫는 태그 **바로 앞**에 추가:

```markdown
  <!-- If this task turns out to be much larger than the brief assumed, you may
       propose splitting it instead of silently running long. A split proposal
       MUST carry, for each proposed piece, the files it would touch and the
       outputs it would newly produce — the coordinator decides by testing those
       files for overlap against every other running task, and a proposal
       without them cannot be judged at all. Name the parent as `split_of`.
       Propose once, then wait: the coordinator replies either way, and a
       rejection is an answer, not silence. A piece that came from a split can
       never itself be split. -->
  <split_proposal_rule>propose a split with per-piece `files`, `outputs`, and `split_of`; wait for the reply</split_proposal_rule>
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `npx bats tests/scripts.bats`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add skills/orchestrate/templates/brief.md tests/scripts.bats
git -c user.name="Younggi Choi" -c user.email="74581798+choiyounggi@users.noreply.github.com" \
  commit -m "feat(orchestrate): brief 템플릿 — 분할 제안에 파일 범위 필수

코디네이터의 판정은 파일 겹침 검사다. 범위 없는 제안은 판정 불가라 왕복이
한 번 더 생기고 그 사이 워커는 멈춰 있다. 워커가 읽는 자리에 요구사항을 둔다."
```

---

### Task 3: SKILL.md — 코디네이터의 분할 판정 절차

**Files:**
- Modify: `skills/orchestrate/SKILL.md` (Phase 4 뒤, Phase 5 앞에 새 절)
- Test: `tests/scripts.bats`

**Interfaces:**
- Consumes: Task 1의 `graph-add.sh <graph.json> <node-json>` 계약(0 추가됨 / 3 거부 / 4 못 읽음), Task 2의 워커 제안 형식.
- Produces: 없음 (PR 2의 마지막 task)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/scripts.bats` 끝에 추가:

```bash
@test "SKILL.md: the split decision procedure is documented and always replies" {
  SKILL="${BATS_TEST_DIRNAME}/../skills/orchestrate/SKILL.md"
  grep -qF 'scripts/graph-add.sh' "$SKILL"
  # The overlap test is the decision; both branches must be spelled out or the
  # coordinator has to invent one.
  grep -qF 'overlap' "$SKILL"
  grep -qF 'same worker' "$SKILL"
  # A rejection that is never sent reproduces the v1.4.1 ask-timeout bug: the
  # worker decides for itself.
  grep -qF 'reply either way' "$SKILL"
  [ "$(grep -c '[가-힣]' "$SKILL")" -eq 0 ]
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `npx bats tests/scripts.bats`
Expected: FAIL — `scripts/graph-add.sh` 가 SKILL.md에 없음.

- [ ] **Step 3: 새 절을 추가한다**

`skills/orchestrate/SKILL.md`에서 `## Phase 5 — Integration test loop` 바로 **앞**에 추가:

```markdown
## Splitting a task mid-run

A worker may report that its task is much larger than the brief assumed. It
proposes; **you decide**, and you reply either way — a rejection that is never
sent is indistinguishable from silence, and a worker that hears nothing decides
for itself.

The proposal must carry, per piece, the `files` it would touch and the `outputs`
it would newly produce. Without them there is nothing to judge; ask for them
rather than guessing, and say the worker should hold.

**The decision is one overlap test.** Compare the proposed pieces' `files`
against every task that is currently dispatched and every task still pending in
`graph.json`:

- **No overlap** — add it as an independent node. `scripts/graph-add.sh
  .orchestration/graph.json '<node-json>'` with `split_of` naming the parent and
  `deps` carrying whatever the piece genuinely consumes. It enters the ready set
  and the next free slot picks it up, so the split buys real parallelism.
- **Overlap** — add it with `deps: ["<parent>"]` and give it to the **same
  worker** in the **same worktree** when the parent settles (Orca:
  `worker-start --task <new> --terminal <handle>`; tmux: `send-prompt.sh send
  lo-<n>`). Do **not** create a second worktree: the parent's code is not on the
  integration branch until Phase 6, so a second checkout would be editing files
  it cannot see. This split buys a smaller review and rework unit, not
  parallelism — say so when you report it.

`graph-add.sh` returns **0** added, **3** REJECTED with the reason and the file
untouched, **4** the graph or the node could not be read. On **3**, reply to the
worker with the reason; do not retry the same node. A rejection for `depth 1`
means the proposal came from a piece that was itself a split — that is a signal
Phase 2's decomposition was wrong, so bring it to the user rather than working
around it.

You decide this without a user gate, but **report it immediately** — the task
list the user approved at Gate 1 just grew, and they need the overlap verdict
and the schedule change to intervene if they disagree.
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `npx bats tests/scripts.bats`
Expected: PASS

- [ ] **Step 5: 전체 스위트**

Run: `npx bats tests/`
Expected: 실패 0.

- [ ] **Step 6: 커밋**

```bash
git add skills/orchestrate/SKILL.md tests/scripts.bats
git -c user.name="Younggi Choi" -c user.email="74581798+choiyounggi@users.noreply.github.com" \
  commit -m "docs(orchestrate): 실행 중 task 분할 판정 절차

워커가 제안하고 코디네이터가 겹침 판정으로 결정한다. 안 겹치면 새 노드로
병렬, 겹치면 같은 워커에 순차 부착(파일이 통합 브랜치에 없으므로 두 번째
워크트리를 만들 수 없다). 거절도 반드시 reply — 침묵은 워커의 자체 판단을 부른다."
```

---

## Self-Review

**1. 스펙 커버리지**

| 스펙 절 | 담당 task |
|---|---|
| §3.5 트리거는 기존 ask 채널 | Task 2(워커 쪽 규칙), Task 3(코디네이터 쪽 수신) — 새 채널 없음 |
| §3.5 파일 범위 필수 | Task 2 |
| §3.5 겹침 → 같은 워커 순차 / 안 겹침 → 새 노드 병렬 | Task 3 |
| §3.5 분할 깊이 1 | Task 1(`split_of`로 집행), Task 3(깊이 2는 사용자에게) |
| §3.5 거절도 명시적 reply | Task 2(워커가 기다림), Task 3(코디네이터가 반드시 보냄) |
| §3.5 코디네이터 결정 + 즉시 보고 | Task 3 |
| §4 graph 변경 방어(사이클·깊이·중복 output), 무변경 롤백 | Task 1 |

§4의 "Phase 2 최초 작성 시점 검증"은 PR 1에서 이미 착지했다(Phase 2가 `ready-set.sh`를 한 번 돌려 exit 4를 확인한다). 여기서 다시 하지 않는다.

**2. 플레이스홀더 스캔** — TBD/TODO 없음. 모든 코드 스텝에 실제 코드가 있고, 문서 스텝은 삽입 위치와 새 문장을 모두 적었다.

**3. 타입/이름 일관성** — `graph-add.sh <graph.json> <node-json>`와 종료코드 0/3/4가 Task 1 정의와 Task 3 인용에서 동일하다. `split_of`가 Task 1(집행), Task 2(워커 제안), Task 3(코디네이터 사용)에서 같은 의미로 쓰인다. Task 1의 통합 테스트는 PR 1의 `ready-set.sh`를 실제로 호출해 두 스크립트의 계약이 어긋나지 않음을 고정한다.
