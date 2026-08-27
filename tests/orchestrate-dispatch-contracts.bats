#!/usr/bin/env bats
# Doc gates for t3-dispatch-contracts (issue #152, P4+P5): contract-first
# dispatch (shared-surface stubs committed before dispatch) and the
# size-verdict + bounded re-plan ladder.
#
# A checker's own report is not evidence it works until it has been shown to
# fail on something (wiki/testing/quality/checks-that-cannot-pass.md) — each
# assertion below has a paired negative control that strips the asserted span
# from a copy and shows the same check fail
# (wiki/testing/quality/spec-artifact-checks.md).

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  SKILL="${REPO_ROOT}/skills/orchestrate/SKILL.md"
  BRIEF="${REPO_ROOT}/skills/orchestrate/templates/brief.md"
  WIKIPLAN="${REPO_ROOT}/skills/wiki-plan/SKILL.md"
}

# Collapses embedded newlines to a single space so a substring assertion
# survives prose hard-wrapped across physical lines (same technique as
# tests/orchestrate-token-budget.bats).
normalize_ws() {
  printf '%s' "$1" | tr '\n' ' ' | tr -s ' '
}

# Extracts Phase 3 step 0's body: from the "0. **Preceding-interface
# injection" line up to (not including) the "1. `scripts/setup-worktrees.sh"
# line that starts step 1.
step0_section() {
  awk '
    /^0\. \*\*Preceding-interface injection/ { p=1 }
    p && /^1\. `scripts\/setup-worktrees\.sh/ { exit }
    p { print }
  ' "$1"
}

# Extracts Phase 3 step 2a's body: from "**2a. Plan it yourself" up to (not
# including) the "3. `scripts/watch-status.sh" line that starts step 3.
step2a_section() {
  awk '
    /\*\*2a\. Plan it yourself/ { p=1 }
    p && /^3\. `scripts\/watch-status\.sh/ { exit }
    p { print }
  ' "$1"
}

# Extracts the "## Phase 2" section: from its heading up to (not including)
# the next "## " heading.
phase2_section() {
  awk '/^## Phase 2/{p=1;next} /^## /{p=0} p' "$1"
}

# Extracts the "## Coordinator token budget" section (same extractor as
# tests/orchestrate-token-budget.bats' section_body()).
token_budget_section() {
  awk '/^## Coordinator token budget$/{p=1;next} /^## /{p=0} p' "$1"
}

# Extracts the dependencies block of brief.md (between <dependencies> and
# </dependencies>, comment included since the comment sits just above it —
# widen to the whole file region bounded by <context> close and <objective>).
brief_dependencies_region() {
  awk '/<\/context>/{p=1} p{print} /<\/dependencies>/{exit}' "$1"
}

# --- 1: SKILL.md Phase 3 step 0 names the contract-first dispatch mechanism -

@test "step 0 names contract-first dispatch: temp integ worktree + stub commit before dispatch" {
  section="$(normalize_ws "$(step0_section "$SKILL")")"
  [[ "$section" == *"Contract-first dispatch"* ]]
  [[ "$section" == *".worktrees/integ-stubs"* ]]
  [[ "$section" == *"chore(orchestrate): contract stubs for"* ]]
  [[ "$section" == *"IMPLEMENTS the stub in place"* ]]
}

@test "negative control: a step-0 copy without Contract-first dispatch fails the stub-mechanism check" {
  fixture="${BATS_TEST_TMPDIR}/skill-no-contract-first.md"
  grep -v 'Contract-first dispatch' "$SKILL" > "$fixture"
  section="$(normalize_ws "$(step0_section "$fixture")")"
  [[ "$section" != *"Contract-first dispatch"* ]]
}

# --- 2: SKILL.md step 0 states signature-change = plan gap + blackboard -----

@test "step 0 states a stub signature change is a plan gap notified via the blackboard" {
  section="$(normalize_ws "$(step0_section "$SKILL")")"
  [[ "$section" == *"plan gap"* ]]
  [[ "$section" == *"blackboard"* ]]
}

@test "negative control: a step-0 copy without the plan-gap sentence fails the signature-change check" {
  fixture="${BATS_TEST_TMPDIR}/skill-no-plan-gap.md"
  sed '/^0\. \*\*Preceding-interface injection/,/^1\. `scripts\/setup-worktrees\.sh/ s/plan gap/xxx/' "$SKILL" > "$fixture"
  section="$(normalize_ws "$(step0_section "$fixture")")"
  [[ "$section" != *"plan gap"* ]]
}

# --- r1 F1: step 0 states the producer ordering exception (plan before stub --
# --- before worktree) so the stub never quotes an unwritten plan and never --
# --- precedes the producer's own worktree -----------------------------------

@test "step 0 states the producer ordering exception: plan (2a) first, then stub, then worktree (step 1)" {
  section="$(normalize_ws "$(step0_section "$SKILL")")"
  [[ "$section" == *"ordering exception"* ]]
  [[ "$section" == *"run step 2a's \`wiki-plan\` invocation for this task FIRST"* ]]
  [[ "$section" == *"do not launch yet"* ]]
  [[ "$section" == *"THEN step 1"* ]]
  [[ "$section" == *"needs no reordering"* ]]
}

@test "negative control: a step-0 copy without the ordering exception fails the producer-sequencing check" {
  fixture="${BATS_TEST_TMPDIR}/skill-no-ordering-exception.md"
  grep -v 'ordering exception' "$SKILL" > "$fixture"
  section="$(normalize_ws "$(step0_section "$fixture")")"
  [[ "$section" != *"ordering exception"* ]]
}

# --- 3: SKILL.md Phase 2 marks shared surfaces ------------------------------

@test "Phase 2 marks shared surfaces from outputs/consumes at decompose time" {
  section="$(normalize_ws "$(phase2_section "$SKILL")")"
  [[ "$section" == *"shared surface"* ]]
  [[ "$section" == *"outputs"* ]]
  [[ "$section" == *"consumes"* ]]
  [[ "$section" == *"contract stub"* ]]
}

@test "negative control: a Phase 2 copy without the shared-surface sentence fails the marking check" {
  fixture="${BATS_TEST_TMPDIR}/skill-no-shared-surface.md"
  grep -v 'shared surface' "$SKILL" > "$fixture"
  section="$(normalize_ws "$(phase2_section "$fixture")")"
  [[ "$section" != *"shared surface"* ]]
}

# --- 4: brief.md carries the stub attribute + repo-relative note -----------

@test "brief.md dependencies block carries the stub attribute and a repo-relative note" {
  region="$(brief_dependencies_region "$BRIEF")"
  [[ "$region" == *'stub="'* ]]
  [[ "$region" == *"repo-relative"* ]]
}

@test "negative control: a brief.md copy without the stub attribute fails the dependencies check" {
  fixture="${BATS_TEST_TMPDIR}/brief-no-stub.md"
  sed 's/ stub="{repo-relative path, omit if none}"//' "$BRIEF" > "$fixture"
  region="$(brief_dependencies_region "$fixture")"
  [[ "$region" != *'stub="'* ]]
}

# --- 5: brief.md guarded lines stay intact (token-hygiene + {ORCH_DIR}) -----

@test "brief.md still carries the token-hygiene line and the {ORCH_DIR} plan line untouched" {
  grep -qF 'token hygiene' "$BRIEF"
  line="$(grep -F '<plan>' "$BRIEF")"
  [[ "$line" == *'{ORCH_DIR}/plans/{TASK}.md'* ]]
  [[ "$line" != *'.orchestration/'* ]]
}

@test "negative control: a brief.md copy with the token-hygiene line stripped fails the guard check" {
  fixture="${BATS_TEST_TMPDIR}/brief-no-hygiene.md"
  grep -v 'token hygiene' "$BRIEF" > "$fixture"
  count="$(grep -cF 'token hygiene' "$fixture" || true)"
  [ "$count" -eq 0 ]
}

# --- 6: wiki-plan SKILL.md requires ## Size verdict + large->split fields ---

@test "wiki-plan step 5 requires a ## Size verdict section with small/medium/large and the large-split fields" {
  content="$(cat "$WIKIPLAN")"
  [[ "$content" == *"## Size verdict"* ]]
  [[ "$content" == *"REQUIRED, not optional"* ]]
  [[ "$content" == *"small"* ]]
  [[ "$content" == *"medium"* ]]
  [[ "$content" == *"large"* ]]
  [[ "$content" == *"\`files\`"* ]]
  [[ "$content" == *"\`outputs\`"* ]]
}

@test "negative control: a wiki-plan copy without the Size verdict section fails the requirement check" {
  fixture="${BATS_TEST_TMPDIR}/wikiplan-no-verdict.md"
  grep -v 'Size verdict' "$WIKIPLAN" > "$fixture"
  content="$(cat "$fixture")"
  [[ "$content" != *"## Size verdict"* ]]
}

# --- 7: wiki-plan step 6 self-check gains the Size-verdict-consistency line -

@test "wiki-plan step 6 self-check asks whether the Size verdict is present and consistent with the task table" {
  section="$(awk '/^6\. \*\*Self-check/{p=1} p && /^## Execution handoff/{exit} p' "$WIKIPLAN")"
  flat="$(normalize_ws "$section")"
  [[ "$flat" == *"Size verdict"* ]]
  [[ "$flat" == *"consistent with the task table"* ]]
}

@test "negative control: a wiki-plan copy without the self-check line fails the consistency check" {
  fixture="${BATS_TEST_TMPDIR}/wikiplan-no-selfcheck.md"
  sed '/^6\. \*\*Self-check/,/^## Execution handoff/ s/consistent with the task table//' "$WIKIPLAN" > "$fixture"
  section="$(awk '/^6\. \*\*Self-check/{p=1} p && /^## Execution handoff/{exit} p' "$fixture")"
  [[ "$(normalize_ws "$section")" != *"consistent with the task table"* ]]
}

# --- 8: SKILL.md step 2a reads the Size verdict and runs the pre-dispatch --
# --- split before launching -------------------------------------------------

@test "step 2a reads the Size verdict and holds launch on a large verdict" {
  section="$(normalize_ws "$(step2a_section "$SKILL")")"
  [[ "$section" == *"Size verdict"* ]]
  [[ "$section" == *"do NOT launch"* ]]
  [[ "$section" == *"large"* ]]
}

@test "negative control: a step-2a copy without the Size-verdict read fails the pre-dispatch-split check" {
  fixture="${BATS_TEST_TMPDIR}/skill-no-verdict-read.md"
  grep -v 'Read the Size verdict' "$SKILL" > "$fixture"
  section="$(normalize_ws "$(step2a_section "$fixture")")"
  [[ "$section" != *"Read the Size verdict"* ]]
}

# --- 9: SKILL.md step 2a's split names graph-drop.sh and both exit branches -

@test "step 2a's large-verdict split names graph-drop.sh, exit 0 (independent pieces) and exit 3 (overlap-split fallback)" {
  section="$(normalize_ws "$(step2a_section "$SKILL")")"
  [[ "$section" == *"graph-drop.sh"* ]]
  [[ "$section" == *"exit 0"* ]]
  [[ "$section" == *"exit 3"* ]]
  [[ "$section" == *"independent node"* ]]
  [[ "$section" == *"overlap-split semantics"* ]]
}

@test "negative control: a step-2a copy without graph-drop.sh fails the drop-then-split check" {
  fixture="${BATS_TEST_TMPDIR}/skill-no-graph-drop.md"
  grep -v 'graph-drop.sh' "$SKILL" > "$fixture"
  section="$(normalize_ws "$(step2a_section "$fixture")")"
  [[ "$section" != *"graph-drop.sh"* ]]
}

# --- 10: SKILL.md re-plan ladder names scoped-patch rounds + the single ----
# --- full re-plan and the escalation, never a round 4 -----------------------

@test "re-plan ladder names rounds 1-2 as scoped patches, round 3 as the single full re-plan, and the escalation" {
  section="$(normalize_ws "$(token_budget_section "$SKILL")")"
  [[ "$section" == *"Re-plan ladder"* ]]
  [[ "$section" == *"SCOPED PATCHES"* ]]
  [[ "$section" == *"full re-plan"* ]]
  [[ "$section" == *"deadlock-grade escalation"* ]]
  [[ "$section" == *"never a round 4"* ]]
}

@test "negative control: a token-budget copy without the Re-plan ladder fails the bounded-loop check" {
  fixture="${BATS_TEST_TMPDIR}/skill-no-replan-ladder.md"
  grep -v 'Re-plan ladder' "$SKILL" > "$fixture"
  section="$(normalize_ws "$(token_budget_section "$fixture")")"
  [[ "$section" != *"Re-plan ladder"* ]]
}
