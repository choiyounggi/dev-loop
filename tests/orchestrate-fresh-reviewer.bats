#!/usr/bin/env bats
# Tests for the P1 fresh-context integration-reviewer agent and the P2
# append-only blackboard protocol (issue #152, task t2-review-blackboard).
#
# A checker's own report is not evidence it works until it has been shown to
# fail on something (wiki/testing/quality/checks-that-cannot-pass.md) — each
# structural assertion below has a paired negative control that strips the
# asserted span from a copy and shows the same check fail
# (wiki/testing/quality/spec-artifact-checks.md).

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  SKILL="${REPO_ROOT}/skills/orchestrate/SKILL.md"
  TPL="${REPO_ROOT}/skills/orchestrate/templates/session-prompt.md"
  AGENT="${REPO_ROOT}/agents/integration-reviewer.md"
  AGENT2="${REPO_ROOT}/agents/test-quality-auditor.md"
  AGENT3="${REPO_ROOT}/agents/task-reviewer.md"
  AGENT4="${REPO_ROOT}/agents/task-planner.md"
}

# Collapses embedded newlines to a single space so a substring assertion
# survives prose hard-wrapped across physical lines (same technique as
# tests/orchestrate-token-budget.bats).
normalize_ws() {
  printf '%s' "$1" | tr '\n' ' ' | tr -s ' '
}

# Extracts the "## Phase 5" section: from its heading up to (not including)
# the next "## " heading.
phase5_section() {
  awk '/^## Phase 5/{p=1} p && /^## / && !/^## Phase 5/{exit} p' "$1"
}

# Extracts the "## Guardrails" section — the last section in the file.
guardrails_section() {
  awk '/^## Guardrails$/{p=1;next} p' "$1"
}

# Extracts the "## Phase 1" section: from its heading up to (not including)
# the next "## " heading.
phase1_section() {
  awk '/^## Phase 1/{p=1} p && /^## / && !/^## Phase 1/{exit} p' "$1"
}

# Extracts the "## Blackboard" section: from its heading up to (not
# including) the next "## " heading.
blackboard_section() {
  awk '/^## Blackboard/{p=1} p && /^## / && !/^## Blackboard/{exit} p' "$1"
}

# Extracts §2's body (between the "## (2) Implement" and "## (3)" headings).
section2_body() {
  awk '/^## \(2\) Implement/{p=1;next} /^## /{p=0} p' "$1"
}

# Extracts §O2's body (between the "## (O2) Implement" and "## (O3)" headings).
sectionO2_body() {
  awk '/^## \(O2\) Implement/{p=1;next} /^## /{p=0} p' "$1"
}

# Extracts the tmux worker protocol block.
tmux_protocol_section() {
  awk '/^## tmux worker protocol/{p=1} p && /^\*\*Orca substrate/{exit} p' "$1"
}

# Extracts the Orca worker protocol block.
orca_protocol_section() {
  awk '/^## Orca worker protocol/{p=1} p && /^## Subagent usage protocol/{exit} p' "$1"
}

# --- 1: agent file exists, frontmatter pins name and carries NO model pin --

@test "agents/integration-reviewer.md exists with name and NO model pin (issue #200)" {
  [ -f "$AGENT" ]
  head -10 "$AGENT" | grep -qF 'name: integration-reviewer'
  run sh -c "head -10 '$AGENT' | grep -q '^model:'"
  [ "$status" -ne 0 ]
}

@test "negative control: a frontmatter copy WITH a model pin fails the no-pin check" {
  pinned="${BATS_TEST_TMPDIR}/agent-pinned.md"
  awk '/^name:/{print; print "model: fable"; next} {print}' "$AGENT" > "$pinned"
  run sh -c "head -10 '$pinned' | grep -q '^model:'"
  [ "$status" -eq 0 ]
}

# --- 2: agent body is read-only with the fixed VERDICT/FINDINGS contract ---

@test "agent body states read-only and the VERDICT/FINDINGS output contract" {
  content="$(cat "$AGENT")"
  [[ "$content" == *"read-only"* ]]
  [[ "$content" == *"VERDICT: approve"* ]]
  [[ "$content" == *"rework"* ]]
  [[ "$content" == *"FINDINGS:"* ]]
}

@test "negative control: an agent copy with the VERDICT line stripped fails the contract check" {
  stripped="${BATS_TEST_TMPDIR}/agent-no-verdict.md"
  grep -v 'VERDICT: approve' "$AGENT" > "$stripped"
  content="$(cat "$stripped")"
  [[ "$content" != *"VERDICT: approve"* ]]
}

# --- 3: SKILL.md Phase 5 names the agent, verdict+findings-only ingestion --

@test "Phase 5 runs the integration review via integration-reviewer, verdict+findings only" {
  section="$(normalize_ws "$(phase5_section "$SKILL")")"
  [[ "$section" == *"integration-reviewer"* ]]
  [[ "$section" == *"VERDICT"* ]]
  [[ "$section" == *"FINDINGS"* ]]
  [[ "$section" == *"MUST NOT read the full integration diff"* ]]
}

@test "negative control: a SKILL.md copy with Phase 5 stripped fails the agent-review check" {
  stripped="${BATS_TEST_TMPDIR}/skill-no-phase5.md"
  awk '/^## Phase 5/{exit} {print}' "$SKILL" > "$stripped"
  section="$(phase5_section "$stripped")"
  [ -z "$section" ]
}

# --- 4: Guardrails line names both bundled agents ---------------------------

@test "Guardrails names both bundled agents: test-quality-auditor and integration-reviewer" {
  section="$(guardrails_section "$SKILL")"
  [[ "$section" == *"test-quality-auditor"* ]]
  [[ "$section" == *"integration-reviewer"* ]]
  [[ "$section" == *"Bundled agents only"* ]]
}

@test "negative control: a Guardrails copy without integration-reviewer fails the both-agents check" {
  stripped="${BATS_TEST_TMPDIR}/skill-no-int-reviewer.md"
  sed 's/`test-quality-auditor`, `integration-reviewer`/`test-quality-auditor`/' "$SKILL" > "$stripped"
  section="$(guardrails_section "$stripped")"
  [[ "$section" != *"integration-reviewer"* ]]
}

# --- 4b: Guardrails states the git-stash prohibition for sessions and review agents (D5, issue #166) ---

@test "Guardrails states the git-stash prohibition for sessions and review agents" {
  section="$(guardrails_section "$SKILL")"
  [[ "$section" == *"git stash"* ]]
  [[ "$section" == *"refs/stash is repository-global"* ]]
}

@test "negative control: a Guardrails copy without the git-stash line fails the check" {
  stripped="${BATS_TEST_TMPDIR}/skill-no-stash-guardrail.md"
  sed '/No session or review agent may `git stash`/,+2d' "$SKILL" > "$stripped"
  section="$(guardrails_section "$stripped")"
  [[ "$section" != *"git stash"* ]]
}

# --- 5: SKILL.md names the blackboard file + append-only convention --------

@test "Blackboard section names .orchestration/notes/decisions.md as append-only" {
  section="$(blackboard_section "$SKILL")"
  [[ "$section" == *".orchestration/notes/decisions.md"* ]]
  [[ "$section" == *"APPEND-ONLY"* ]]
  [[ "$section" == *"- [<task-id>]"* ]]
}

@test "negative control: a SKILL.md copy without the Blackboard section fails the append-only check" {
  stripped="${BATS_TEST_TMPDIR}/skill-no-blackboard.md"
  awk '/^## Blackboard/{skip=1;next} /^## Phase 5/{skip=0} !skip{print}' "$SKILL" > "$stripped"
  section="$(blackboard_section "$stripped")"
  [ -z "$section" ]
}

# --- 6: session-prompt §2 has the blackboard read checkpoint ---------------

@test "session-prompt §2 reads the blackboard before self-review" {
  section="$(section2_body "$TPL")"
  [[ "$section" == *"notes/decisions.md"* ]]
  [[ "$section" == *"APPEND one line"* ]]
}

@test "negative control: a §2 copy without the blackboard checkpoint fails the read-check" {
  stripped="${BATS_TEST_TMPDIR}/tpl-no-s2-blackboard.md"
  sed '/^## (2) Implement/,/^## (3)/ s/notes\/decisions\.md//g' "$TPL" > "$stripped"
  section="$(section2_body "$stripped")"
  [[ "$section" != *"notes/decisions.md"* ]]
}

# --- 6b: both review agents prohibit git stash, with the refs/stash rationale (issue #166) ---

@test "all four agent files carry the git-stash prohibition and refs/stash rationale" {
  for f in "$AGENT" "$AGENT2" "$AGENT3" "$AGENT4"; do
    content="$(cat "$f")"
    [[ "$content" == *'NEVER `git stash`'* ]]
    [[ "$content" == *"refs/stash"* ]]
  done
}

@test "negative control: an agent copy without the git-stash prohibition fails the check" {
  stripped="${BATS_TEST_TMPDIR}/agent-no-stash.md"
  grep -v 'NEVER `git stash`' "$AGENT" > "$stripped"
  content="$(cat "$stripped")"
  [[ "$content" != *'NEVER `git stash`'* ]]
}

# --- 6c: both review agents' read-only claim is honest about temporary tree
# mutation during test/check runs (D2) ---

@test "all three agent files' read-only claim is qualified: repo-state only, checks may temporarily mutate the tree" {
  for f in "$AGENT" "$AGENT2" "$AGENT3"; do
    content="$(cat "$f")"
    [[ "$content" == *"read-only with respect to repo state"* ]]
    [[ "$content" == *"temporarily mutate the working tree"* ]]
  done
}

@test "negative control: an agent copy without the mutation caveat fails the honesty check" {
  stripped="${BATS_TEST_TMPDIR}/agent-no-caveat.md"
  sed 's/temporarily mutate the working tree//' "$AGENT" > "$stripped"
  content="$(cat "$stripped")"
  [[ "$content" != *"temporarily mutate the working tree"* ]]
}

# --- 7: session-prompt §O2 has the blackboard read checkpoint --------------

@test "session-prompt §O2 reads the blackboard before self-review" {
  section="$(sectionO2_body "$TPL")"
  [[ "$section" == *"notes/decisions.md"* ]]
  [[ "$section" == *"APPEND one line"* ]]
}

@test "negative control: a §O2 copy without the blackboard checkpoint fails the read-check" {
  stripped="${BATS_TEST_TMPDIR}/tpl-no-o2-blackboard.md"
  sed '/^## (O2) Implement/,/^## (O3)/ s/notes\/decisions\.md//g' "$TPL" > "$stripped"
  section="$(sectionO2_body "$stripped")"
  [[ "$section" != *"notes/decisions.md"* ]]
}

# --- 8: both worker protocol blocks carry the append-only rule -------------

@test "tmux worker protocol block states the blackboard is append-only" {
  section="$(tmux_protocol_section "$TPL")"
  [[ "$section" == *"append-only"* ]]
  [[ "$section" == *"[4]"* ]]
}

@test "negative control: a tmux protocol copy without the append-only rule fails the check" {
  stripped="${BATS_TEST_TMPDIR}/tpl-no-tmux-appendonly.md"
  awk '/^## tmux worker protocol/{p=1} p && /^\*\*Orca substrate/{p=0} p && /append-only/{next} {print}' "$TPL" > "$stripped"
  section="$(tmux_protocol_section "$stripped")"
  [[ "$section" != *"append-only"* ]]
}

# --- 9: Orca worker protocol block carries the matching append-only rule ---

@test "Orca worker protocol block states the blackboard is append-only" {
  section="$(orca_protocol_section "$TPL")"
  [[ "$section" == *"append-only"* ]]
  [[ "$section" == *"[7]"* ]]
}

@test "negative control: an Orca protocol copy without the append-only rule fails the check" {
  stripped="${BATS_TEST_TMPDIR}/tpl-no-orca-appendonly.md"
  awk '/^## Orca worker protocol/{p=1} p && /^## Subagent usage protocol/{p=0} p && /append-only/{next} {print}' "$TPL" > "$stripped"
  section="$(orca_protocol_section "$stripped")"
  [[ "$section" != *"append-only"* ]]
}

# --- 10: Blackboard section prescribes the atomic printf append primitive --
# (r1 F3: Write/Edit is read-modify-write, so concurrent workers appending
# "simultaneously" can silently drop each other's line.)

@test "Blackboard section prescribes printf >> and forbids Write/Edit for appending" {
  section="$(blackboard_section "$SKILL")"
  [[ "$section" == *"printf '%s\\n'"* ]]
  [[ "$section" == *">>"* ]]
  [[ "$section" == *"Never use Write/Edit"* ]]
}

@test "negative control: a Blackboard copy without the Write/Edit prohibition fails the primitive check" {
  stripped="${BATS_TEST_TMPDIR}/skill-no-printf-primitive.md"
  sed '/^## Blackboard/,/^## Phase 5/ s/Never use Write\/Edit//' "$SKILL" > "$stripped"
  section="$(blackboard_section "$stripped")"
  [[ "$section" != *"Never use Write/Edit"* ]]
}

# --- 11: Phase 1 creates the blackboard file, not only the directory -------
# (r1 F2: an unconditional read of a possibly-absent file hands a Wave-1
# worker a spurious blocker.)

@test "Phase 1 touches the blackboard file, not only .orchestration/notes/" {
  section="$(phase1_section "$SKILL")"
  [[ "$section" == *"touch"* ]]
  [[ "$section" == *"notes/decisions.md"* ]]
}

@test "negative control: a Phase 1 copy without the touch step fails the bootstrap check" {
  stripped="${BATS_TEST_TMPDIR}/skill-no-touch.md"
  sed '/^## Phase 1/,/^## Phase 2/ s/touch/xxx/g' "$SKILL" > "$stripped"
  section="$(phase1_section "$stripped")"
  [[ "$section" != *"touch"* ]]
}

# --- 12: session-prompt §2/§O2 tolerate an absent blackboard file ----------
# (r1 F2, belt-and-suspenders alongside the Phase 1 touch above.)

@test "session-prompt §2 and §O2 both tolerate a not-yet-created blackboard file" {
  s2="$(section2_body "$TPL")"
  o2="$(sectionO2_body "$TPL")"
  [[ "$s2" == *"if it exists"* ]]
  [[ "$o2" == *"if it exists"* ]]
}

@test "negative control: a §2 copy without the if-it-exists guard fails the tolerance check" {
  stripped="${BATS_TEST_TMPDIR}/tpl-no-s2-ifexists.md"
  sed '/^## (2) Implement/,/^## (3)/ s/ if it exists//' "$TPL" > "$stripped"
  section="$(section2_body "$stripped")"
  [[ "$section" != *"if it exists"* ]]
}

# --- 7: task-reviewer agent (issue #192 stage 4) ---------------------------

@test "agents/task-reviewer.md exists with name and NO model pin" {
  [ -f "$AGENT3" ]
  head -10 "$AGENT3" | grep -qF 'name: task-reviewer'
  run sh -c "head -10 '$AGENT3' | grep -q '^model:'"
  [ "$status" -ne 0 ]
}

@test "task-reviewer body lists every explicit input and the first-line VERDICT contract" {
  content="$(normalize_ws "$(cat "$AGENT3")")"
  [[ "$content" == *"worktree path"* ]]
  [[ "$content" == *"integ ref"* ]]
  [[ "$content" == *"brief path"* ]]
  [[ "$content" == *"plan path"* ]]
  [[ "$content" == *"risk tier"* ]]
  [[ "$content" == *"floor result"* ]]
  [[ "$content" == *"review output path"* ]]
  [[ "$content" == *"VERDICT: approve"* ]]
  [[ "$content" == *"VERDICT: rework"* ]]
  [[ "$content" == *"ask for them rather than guessing"* ]]
}

@test "task-reviewer keys the lens set by tier with the three predicate rows" {
  content="$(cat "$AGENT3")"
  [[ "$content" == *"| R0 |"* ]]
  [[ "$content" == *"| R1 |"* ]]
  [[ "$content" == *"| R2 or R3 |"* ]]
  [[ "$content" == *"not run — R0 profile"* ]]
  [[ "$content" == *"not run — R1 profile"* ]]
}

@test "negative control: a task-reviewer copy with the VERDICT lines stripped fails the contract check" {
  stripped="${BATS_TEST_TMPDIR}/task-reviewer-no-verdict.md"
  grep -v 'VERDICT:' "$AGENT3" > "$stripped"
  content="$(cat "$stripped")"
  [[ "$content" != *"VERDICT: approve"* ]]
}

@test "negative control: a task-reviewer copy without the R2 or R3 row fails the tier check" {
  stripped="${BATS_TEST_TMPDIR}/task-reviewer-no-r2r3.md"
  grep -v 'R2 or R3' "$AGENT3" > "$stripped"
  content="$(cat "$stripped")"
  [[ "$content" != *"| R2 or R3 |"* ]]
}

@test "boundary: a frontmatter-only task-reviewer copy fails the inputs check" {
  frontmatter_only="${BATS_TEST_TMPDIR}/task-reviewer-frontmatter-only.md"
  awk '{print} /^---$/{n++} n==2{exit}' "$AGENT3" > "$frontmatter_only"
  [ -s "$frontmatter_only" ]
  content="$(cat "$frontmatter_only")"
  [[ "$content" == *"task-reviewer"* ]]
  [[ "$content" != *"review output path"* ]]
}

@test "Guardrails names all three bundled agents including task-reviewer" {
  section="$(guardrails_section "$SKILL")"
  [[ "$section" == *"test-quality-auditor"* ]]
  [[ "$section" == *"integration-reviewer"* ]]
  [[ "$section" == *"task-reviewer"* ]]
  [[ "$section" == *"Bundled agents only"* ]]
}

@test "negative control: a Guardrails copy without task-reviewer fails the three-agents check" {
  stripped="${BATS_TEST_TMPDIR}/skill-no-task-reviewer-guardrails.md"
  sed 's/, `task-reviewer`//' "$SKILL" > "$stripped"
  section="$(guardrails_section "$stripped")"
  [[ "$section" != *"task-reviewer"* ]]
  [[ "$section" == *"integration-reviewer"* ]]
}

# --- r1 rework: two-dot working-tree diff + exact verdict match (F1/F2) -----

@test "task-reviewer diffs the two-dot working tree and lists untracked files separately" {
  content="$(normalize_ws "$(cat "$AGENT3")")"
  [[ "$content" == *"ls-files --others --exclude-standard"* ]]
  [[ "$content" == *"has not committed yet"* ]]
}

@test "negative control: a task-reviewer copy without the ls-files step fails the untracked-files check" {
  stripped="${BATS_TEST_TMPDIR}/task-reviewer-no-lsfiles.md"
  sed 's/ls-files --others --exclude-standard//' "$AGENT3" > "$stripped"
  content="$(cat "$stripped")"
  [[ "$content" != *"ls-files --others --exclude-standard"* ]]
}

@test "task-reviewer self-check requires an exact VERDICT match, rejecting the template placeholder" {
  content="$(normalize_ws "$(cat "$AGENT3")")"
  [[ "$content" == *"EXACTLY"* ]]
  [[ "$content" == *"unfilled template placeholder"* ]]
  [[ "$content" == *"not a prefix or substring match"* ]]
}

@test "negative control: a task-reviewer copy without the exact-match self-check fails the strict-verdict check" {
  stripped="${BATS_TEST_TMPDIR}/task-reviewer-no-exact.md"
  sed 's/not a prefix or substring match, and not the//' "$AGENT3" > "$stripped"
  content="$(cat "$stripped")"
  [[ "$content" != *"not a prefix or substring match"* ]]
}

# --- 8: task-planner agent (issue #192 stage 5) ---

@test "agents/task-planner.md exists with name, a tools line that includes Skill and Write and excludes Agent, and NO model pin" {
  [ -f "$AGENT4" ]
  head -10 "$AGENT4" | grep -qF 'name: task-planner'
  tools_line="$(head -10 "$AGENT4" | grep '^tools:')"
  [[ "$tools_line" == *"Skill"* ]]
  [[ "$tools_line" == *"Write"* ]]
  [[ "$tools_line" != *"Agent"* ]]
  run sh -c "head -10 '$AGENT4' | grep -q '^model:'"
  [ "$status" -ne 0 ]
}

@test "negative control: a task-planner copy with Agent added to tools fails the no-Agent check" {
  fixture="${BATS_TEST_TMPDIR}/task-planner-with-agent.md"
  sed 's/^tools: Read, Grep, Glob, Bash, Write, Edit, Skill$/tools: Read, Grep, Glob, Bash, Write, Edit, Skill, Agent/' "$AGENT4" > "$fixture"
  tools_line="$(head -10 "$fixture" | grep '^tools:')"
  [[ "$tools_line" == *"Agent"* ]]
}

@test "task-planner body lists every explicit input, the two-stage handshake, and the fixed report fields" {
  content="$(normalize_ws "$(cat "$AGENT4")")"
  [[ "$content" == *"task id"* ]]
  [[ "$content" == *"brief path"* ]]
  [[ "$content" == *"plan dir"* ]]
  [[ "$content" == *"gates dir"* ]]
  [[ "$content" == *"risk tier"* ]]
  [[ "$content" == *"wiki root"* ]]
  [[ "$content" == *"integ ref"* ]]
  [[ "$content" == *"ask for them rather than guessing"* ]]
  [[ "$content" == *"Two-stage handshake"* ]]
  [[ "$content" == *"review-verdict.md"* ]]
  [[ "$content" == *"SendMessage"* ]]
  [[ "$content" == *"plan path:"* ]]
  [[ "$content" == *"size:"* ]]
  [[ "$content" == *"gate-A rc:"* ]]
  [[ "$content" == *"gate-B rc:"* ]]
  [[ "$content" == *"no-wiki count:"* ]]
  [[ "$content" == *"contradiction:"* ]]
}

@test "negative control: a task-planner copy with review-verdict.md stripped fails the handshake check" {
  stripped="${BATS_TEST_TMPDIR}/task-planner-no-verdict.md"
  grep -v 'review-verdict.md' "$AGENT4" > "$stripped"
  content="$(normalize_ws "$(cat "$stripped")")"
  [[ "$content" != *"review-verdict.md"* ]]
}

@test "task-planner write scope: plan dir and gate ledgers only, never status-update.sh, no tracked repo file" {
  content="$(normalize_ws "$(cat "$AGENT4")")"
  [[ "$content" == *'never call `status-update.sh`'* ]]
  [[ "$content" == *"edit no tracked repo file"* ]]
  [[ "$content" == *".dev-loop/gates/plan-A-<task>.md"* ]]
  [[ "$content" == *"{ORCH_DIR}/plans/<task>.md"* ]]
}

@test "boundary: a frontmatter-only task-planner copy fails the inputs check" {
  fm="${BATS_TEST_TMPDIR}/task-planner-frontmatter-only.md"
  awk '{print} /^---$/{n++} n==2{exit}' "$AGENT4" > "$fm"
  content="$(normalize_ws "$(cat "$fm")")"
  [[ "$content" != *"brief path"* ]]
}

@test "task-planner round-3 full re-plan re-enters the two-stage handshake: deletes review-verdict.md and STOPs with a fresh STOP REPORT" {
  content="$(normalize_ws "$(cat "$AGENT4")")"
  [[ "$content" == *"Round 3"* ]]
  [[ "$content" == *"re-enters the two-stage handshake"* ]]
  [[ "$content" == *"delete \`<plan"*"review-verdict.md\`"* ]]
  [[ "$content" == *"STOP with a fresh STOP REPORT"* ]]
  [[ "$content" == *"never a FINAL REPORT"* ]]
}

@test "negative control: a task-planner copy without the round-3 handshake re-entry fails the check" {
  stripped="${BATS_TEST_TMPDIR}/task-planner-no-round3-handshake.md"
  grep -v 're-enters the two-stage handshake' "$AGENT4" > "$stripped"
  content="$(normalize_ws "$(cat "$stripped")")"
  [[ "$content" != *"re-enters the two-stage handshake"* ]]
}
