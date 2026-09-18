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

# Extracts the "## 🚦 Gate 1" section: from its heading up to (not including)
# the next "## " heading.
gate1_section() {
  awk '/^## 🚦 Gate 1/{p=1;next} /^## /{p=0} p' "$1"
}

# Extracts the "## Phase 4" section: from its heading up to (not including)
# the next "## " heading (local copy of tests/orchestrate-review-pass.bats'
# extractor of the same name — bats loads each file in its own process).
phase4_section() {
  awk '/^## Phase 4/{p=1} p && /^## / && !/^## Phase 4/{exit} p' "$1"
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

# --- 11: SKILL.md step 2a confirms plan-gate evidence before dispatch -------
# (cycle-hardening design.md §4 row 6; t1-plan-gate's ledger-name convention
# and gate-check.sh --run verdict, consumed not re-created)

@test "step 2a requires the plan-A/plan-B gate ledgers and a gate-check.sh --run exit 0 before dispatch" {
  section="$(normalize_ws "$(step2a_section "$SKILL")")"
  [[ "$section" == *"plan-A-"* ]]
  [[ "$section" == *"plan-B-"* ]]
  [[ "$section" == *"gate-check.sh --run"* ]]
  [[ "$section" == *"exit 0"* ]]
}

@test "negative control: a step-2a copy without the gate-evidence paragraph fails the ledger check" {
  fixture="${BATS_TEST_TMPDIR}/skill-no-gate-evidence.md"
  grep -v 'plan-A-' "$SKILL" > "$fixture"
  section="$(normalize_ws "$(step2a_section "$fixture")")"
  [[ "$section" != *"plan-A-"* ]]
}

@test "step 2a treats a reasoned lite-mode ABANDON as passing and sends unevidenced plans back to the phase" {
  section="$(normalize_ws "$(step2a_section "$SKILL")")"
  [[ "$section" == *"ABANDON"* ]]
  [[ "$section" == *"UNMET"* ]]
  [[ "$section" == *"CLAIMED"* ]]
  [[ "$section" == *"must not be dispatched"* ]]
}

@test "negative control: a step-2a copy without the UNMET/CLAIMED clause fails the unevidenced-plan check" {
  fixture="${BATS_TEST_TMPDIR}/skill-no-unmet-clause.md"
  grep -v 'UNMET' "$SKILL" > "$fixture"
  section="$(normalize_ws "$(step2a_section "$fixture")")"
  [[ "$section" != *"UNMET"* ]]
}

# --- 12: risk tier (issue #192 stage 1) -------------------------------------

@test "Phase 2 defines the risk and risk_basis fields and states the scheduler pass-through" {
  section="$(normalize_ws "$(phase2_section "$SKILL")")"
  [[ "$section" == *"risk_basis"* ]]
  [[ "$section" == *"one of R0, R1, R2, R3"* ]]
  [[ "$section" == *"ready-set.sh reads only"* ]]
}

@test "negative control: a Phase 2 copy without the risk_basis lines fails the field check" {
  fixture="${BATS_TEST_TMPDIR}/skill-no-risk-basis.md"
  grep -v 'risk_basis' "$SKILL" > "$fixture"
  section="$(normalize_ws "$(phase2_section "$fixture")")"
  [[ "$section" != *"risk_basis"* ]]
}

@test "Phase 2 rubric is max-of-signals and never a sum" {
  section="$(normalize_ws "$(phase2_section "$SKILL")")"
  [[ "$section" == *"max-of-signals"* ]]
  [[ "$section" == *"never summed"* ]]
}

@test "negative control: a Phase 2 copy with max-of-signals renamed to sum-of-signals fails the rubric check" {
  fixture="${BATS_TEST_TMPDIR}/skill-sum-of-signals.md"
  sed 's/max-of-signals/sum-of-signals/' "$SKILL" > "$fixture"
  section="$(normalize_ws "$(phase2_section "$fixture")")"
  [[ "$section" != *"max-of-signals"* ]]
}

@test "Phase 2 states raise-only at step 2a, lower-only at Gate 1, and the blackboard Ruling line" {
  section="$(normalize_ws "$(phase2_section "$SKILL")")"
  [[ "$section" == *"may only RAISE"* ]]
  [[ "$section" == *"LOWERED only by the user"* ]]
  [[ "$section" == *"Ruling: risk"* ]]
}

@test "negative control: a Phase 2 copy without the Ruling line fails the movement-rule check" {
  fixture="${BATS_TEST_TMPDIR}/skill-no-ruling.md"
  grep -v 'Ruling: risk' "$SKILL" > "$fixture"
  section="$(normalize_ws "$(phase2_section "$fixture")")"
  [[ "$section" != *"Ruling: risk"* ]]
}

@test "Gate 1 briefing carries the five-column risk table without a new chooser question" {
  section="$(normalize_ws "$(gate1_section "$SKILL")")"
  [[ "$section" == *"| task | risk | basis | profile"* ]]
  [[ "$section" == *"rework budget |"* ]]
  [[ "$section" == *"adds no AskUserQuestion"* ]]
}

@test "negative control: a Gate 1 copy without the rework-budget column fails the risk-table check" {
  fixture="${BATS_TEST_TMPDIR}/skill-no-rework-budget.md"
  grep -v 'rework budget |' "$SKILL" > "$fixture"
  section="$(normalize_ws "$(gate1_section "$fixture")")"
  [[ "$section" != *"rework budget |"* ]]
}

@test "Phase 2 JSON example parses and every task carries a valid risk token" {
  json="$(awk '/^```json/{p=1;next} /^```/{p=0} p' <(phase2_section "$SKILL"))"
  run jq -e '[.tasks[].risk] | all(. as $r | ["R0","R1","R2","R3"] | index($r) != null)' <<< "$json"
  [ "$status" -eq 0 ]
}

@test "negative control: a task with risk R9 fails the valid-risk-token check" {
  json='{ "tasks": [ { "id": "t1", "risk": "R9" } ] }'
  run jq -e '[.tasks[].risk] | all(. as $r | ["R0","R1","R2","R3"] | index($r) != null)' <<< "$json"
  [ "$status" -ne 0 ]
}

# --- 13: tier profile (issue #192 stage 2) ----------------------------------

@test "Phase 2 carries the tier-to-profile table with the four tiers and the two model ids" {
  section="$(normalize_ws "$(phase2_section "$SKILL")")"
  [[ "$section" == *"Tier to pipeline profile"* ]]
  [[ "$section" == *"R0 trivial"* ]]
  [[ "$section" == *"R3 critical"* ]]
  [[ "$section" == *"claude-sonnet-5"* ]]
  [[ "$section" == *"claude-opus-5"* ]]
  [[ "$section" == *"1 and 3 only"* ]]
}

@test "negative control: a Phase 2 copy without the profile table fails the tier-profile check" {
  fixture="${BATS_TEST_TMPDIR}/skill-no-profile-table.md"
  grep -v 'Tier to pipeline profile' "$SKILL" > "$fixture"
  section="$(normalize_ws "$(phase2_section "$fixture")")"
  [[ "$section" != *"Tier to pipeline profile"* ]]
}

@test "step 2a applies the profile: lite for R0, plan-reviewer for R2+, per-call DEV_LOOP_WORKER_MODEL prefix" {
  section="$(normalize_ws "$(step2a_section "$SKILL")")"
  [[ "$section" == *"Apply the tier's profile"* ]]
  [[ "$section" == *"lite mode"* ]]
  [[ "$section" == *"plan-reviewer call required"* ]]
  [[ "$section" == *"DEV_LOOP_WORKER_MODEL=<id from the profile table>"* ]]
  [[ "$section" == *"never export it"* ]]
}

@test "negative control: a step-2a copy without the never-export clause fails the per-call-prefix check" {
  fixture="${BATS_TEST_TMPDIR}/skill-no-never-export.md"
  grep -v 'never export it' "$SKILL" > "$fixture"
  section="$(normalize_ws "$(step2a_section "$fixture")")"
  [[ "$section" != *"never export it"* ]]
}

@test "Phase 4 selects the lens set by tier and escalates an R0 second round" {
  section="$(normalize_ws "$(phase4_section "$SKILL")")"
  [[ "$section" == *"Lens set by tier"* ]]
  [[ "$section" == *"lenses 1 and 3 only"* ]]
  [[ "$section" == *"not run — R0 profile"* ]]
  [[ "$section" == *"instead of dispatching a second rework"* ]]
}

@test "negative control: a Phase 4 copy without the Lens-set-by-tier paragraph fails the lens-set check" {
  fixture="${BATS_TEST_TMPDIR}/skill-no-lens-set-by-tier.md"
  grep -v 'Lens set by tier' "$SKILL" > "$fixture"
  section="$(normalize_ws "$(phase4_section "$fixture")")"
  [[ "$section" != *"Lens set by tier"* ]]
}

@test "the profile table has exactly one rework-budget row with the sequence 1, 3, 3, 3" {
  n="$(phase2_section "$SKILL" | grep -c '| rework budget | 1 | 3 | 3 | 3 |')"
  [ "$n" -eq 1 ]
}

@test "the profile table's coordinator auditor cross-call row does not contradict the worker's mandatory step 6.5 auditor call" {
  section="$(normalize_ws "$(phase2_section "$SKILL")")"
  [[ "$section" == *"coordinator auditor cross-call"* ]]
  [[ "$section" == *"step 6.5 auditor call is unchanged at every tier"* ]]
}

@test "negative control: a Phase 2 copy without the coordinator-auditor-cross-call row fails the scoping check" {
  fixture="${BATS_TEST_TMPDIR}/skill-no-coordinator-auditor-crosscall.md"
  grep -v 'coordinator auditor cross-call' "$SKILL" > "$fixture"
  section="$(normalize_ws "$(phase2_section "$fixture")")"
  [[ "$section" != *"coordinator auditor cross-call"* ]]
}

@test "step 2a's operative launch command carries the DEV_LOOP_WORKER_MODEL prefix from the profile table" {
  section="$(normalize_ws "$(step2a_section "$SKILL")")"
  operative="${section#*this session either (Coordinator token budget, Known amplifier). Then}"
  [[ "$operative" == *"DEV_LOOP_WORKER_MODEL=<id from the profile table>"* ]]
  [[ "$operative" == *"scripts/launch-session.sh"* ]]
}

@test "negative control: a step-2a copy with only the operative prefix removed fails the operative-prefix check" {
  fixture="${BATS_TEST_TMPDIR}/skill-no-operative-prefix.md"
  awk '
    /this session either \(Coordinator token budget, Known amplifier\)\. Then$/ { print; getline; sub(/DEV_LOOP_WORKER_MODEL=<id from the profile table> /, ""); print; next }
    { print }
  ' "$SKILL" > "$fixture"
  section="$(normalize_ws "$(step2a_section "$fixture")")"
  operative="${section#*this session either (Coordinator token budget, Known amplifier). Then}"
  [[ "$operative" != *"DEV_LOOP_WORKER_MODEL=<id from the profile table>"* ]]
}

# --- 13: step 2a plans on the task-planner agent (issue #192 stage 5) ---

@test "step 2a plans on the task-planner agent and the coordinator reads only its fixed report" {
  section="$(normalize_ws "$(step2a_section "$SKILL")")"
  [[ "$section" == *"task-planner"* ]]
  [[ "$section" == *"Agent tool"* ]]
  [[ "$section" == *"fixed report"* ]]
  [[ "$section" == *'never `analysis.md`'* ]]
}

@test "negative control: a step-2a copy with task-planner stripped fails the agent check" {
  fixture="${BATS_TEST_TMPDIR}/step2a-no-task-planner.md"
  grep -v 'task-planner' "$SKILL" > "$fixture"
  section="$(normalize_ws "$(step2a_section "$fixture")")"
  [[ "$section" != *"task-planner"* ]]
}

@test "step 2a states the two-stage handshake: stop after design.md, coordinator-run plan-reviewer, review-verdict.md, SendMessage resume" {
  section="$(normalize_ws "$(step2a_section "$SKILL")")"
  [[ "$section" == *"Two-stage handshake"* ]]
  [[ "$section" == *"design.md"* ]]
  [[ "$section" == *"review-verdict.md"* ]]
  [[ "$section" == *"SendMessage"* ]]
  [[ "$section" == *"plan-reviewer"* ]]
}

@test "negative control: a step-2a copy without review-verdict.md fails the handshake check" {
  fixture="${BATS_TEST_TMPDIR}/step2a-no-review-verdict.md"
  grep -v 'review-verdict.md' "$SKILL" > "$fixture"
  section="$(normalize_ws "$(step2a_section "$fixture")")"
  [[ "$section" != *"review-verdict.md"* ]]
}

@test "step 2a keeps the planning model on the coordinator: the agent inherits the coordinator model" {
  section="$(normalize_ws "$(step2a_section "$SKILL")")"
  [[ "$section" == *"inherits the coordinator model"* ]]
  [[ "$section" == *"planning model is whatever model this coordinator session is running"* ]]
}

@test "negative control: a step-2a copy without the inherits sentence fails the planning-model check" {
  fixture="${BATS_TEST_TMPDIR}/step2a-no-inherits.md"
  grep -v 'inherits the coordinator model' "$SKILL" > "$fixture"
  section="$(normalize_ws "$(step2a_section "$fixture")")"
  [[ "$section" != *"inherits the coordinator model"* ]]
}

@test "boundary: the step-2a extractor still yields a non-empty section that stops before the watch-status line" {
  section="$(step2a_section "$SKILL")"
  [ "$(printf '%s\n' "$section" | wc -l)" -gt 20 ]
  [[ "$section" != *'3. `scripts/watch-status.sh'* ]]
  [[ "$section" == *"**2a. Plan it yourself"* ]]
}

@test "re-plan rounds route the gap report to the same task-planner agent via SendMessage" {
  section="$(normalize_ws "$(token_budget_section "$SKILL")")"
  [[ "$section" == *"same task-planner agent"* ]]
  [[ "$section" == *"SendMessage"* ]]
  [[ "$section" == *"re-plan loop"* ]]
}

@test "negative control: a token-budget copy without SendMessage fails the re-plan-route check" {
  fixture="${BATS_TEST_TMPDIR}/token-budget-no-sendmessage.md"
  grep -v 'SendMessage' "$SKILL" > "$fixture"
  section="$(normalize_ws "$(token_budget_section "$fixture")")"
  [[ "$section" != *"SendMessage"* ]]
}

@test "step 0 runs the wiki-plan invocation on the task-planner agent" {
  section="$(normalize_ws "$(step0_section "$SKILL")")"
  [[ "$section" == *"run step 2a's \`wiki-plan\` invocation for this task FIRST"* ]]
  [[ "$section" == *'(on the `task-planner` agent)'* ]]
}

@test "negative control: a step-0 copy without the task-planner clause fails the producer check" {
  fixture="${BATS_TEST_TMPDIR}/step0-no-task-planner.md"
  # The clause is hard-wrapped across two physical lines in SKILL.md, so a
  # per-line sed/grep can never match it — slurp the whole file and let \s+
  # absorb the line break (tests-that-cannot-fail: a per-line strip here
  # would silently no-op and the negative control would falsely pass).
  perl -0777 -pe 's/\(on the\s+`task-planner`\s+agent\)//' "$SKILL" > "$fixture"
  section="$(normalize_ws "$(step0_section "$fixture")")"
  [[ "$section" != *'(on the `task-planner` agent)'* ]]
}

@test "Re-plan ladder round 3 re-enters the two-stage handshake instead of passing gate-B on a stale verdict" {
  section="$(normalize_ws "$(token_budget_section "$SKILL")")"
  [[ "$section" == *"Round 3"* ]]
  [[ "$section" == *"goes through the two-stage handshake again"* ]]
  [[ "$section" == *"deletes its stale \`review-verdict.md\`"* ]]
  [[ "$section" == *"fresh STOP REPORT instead of a FINAL REPORT"* ]]
}

@test "negative control: a token-budget copy without the round-3 handshake re-entry fails the check" {
  fixture="${BATS_TEST_TMPDIR}/token-budget-no-round3-handshake.md"
  grep -v 'goes through the two-stage handshake again' "$SKILL" > "$fixture"
  section="$(normalize_ws "$(token_budget_section "$fixture")")"
  [[ "$section" != *"goes through the two-stage handshake again"* ]]
}
