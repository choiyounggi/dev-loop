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

# --- 1: agent file exists, frontmatter pins name + model fable -------------

@test "agents/integration-reviewer.md exists with name + model: fable pinned" {
  [ -f "$AGENT" ]
  head -10 "$AGENT" | grep -qF 'name: integration-reviewer'
  head -10 "$AGENT" | grep -qF 'model: fable'
}

@test "negative control: a frontmatter copy without the model pin fails the check" {
  stripped="${BATS_TEST_TMPDIR}/agent-no-model.md"
  grep -v '^model: fable$' "$AGENT" > "$stripped"
  run sh -c "head -10 '$stripped' | grep -qF 'model: fable'"
  [ "$status" -ne 0 ]
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
