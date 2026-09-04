#!/usr/bin/env bats
# Doc-gates for the graphify `explore` role — a freshness-gated, lead-not-evidence
# orientation layer (wiki/infrastructure/agent-orchestration/
# code-graph-as-orientation-layer.md). Each gate asserts the span that makes the
# coordinator/worker behave, scoped to the section that owns it, and is paired
# with a negative control that strips the span from a fixture copy and shows the
# same check failing (checks-that-cannot-pass,
# wiki/testing/quality/checks-that-cannot-pass.md).
#
# Covered files:
#   skills/orchestrate/SKILL.md          Preflight gate, Phase 2 leads, Phase 3 brief row
#   skills/orchestrate/templates/brief.md tools_guidance explore row
#   skills/wiki-plan/SKILL.md            A2 paired-evidence rule       (task 04)
#   skills/loop-implement/SKILL.md       step 1 / step 6 graph leads   (task 04)

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  SKILL="${REPO_ROOT}/skills/orchestrate/SKILL.md"
  BRIEF="${REPO_ROOT}/skills/orchestrate/templates/brief.md"
  WIKI_PLAN="${REPO_ROOT}/skills/wiki-plan/SKILL.md"
  LOOP="${REPO_ROOT}/skills/loop-implement/SKILL.md"
  SCRIPT="${REPO_ROOT}/scripts/graph-freshness.sh"
}

WIKI_SLUG='wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md'

# Collapse hard-wrapped prose to one line so substring checks survive wrapping
# (same technique as tests/orchestrate-token-budget.bats).
normalize_ws() {
  printf '%s' "$1" | tr '\n' ' ' | tr -s ' '
}

# The body of one `## ` section of a file — a file-wide grep would pass
# vacuously when the phrase also appears elsewhere.
section_body() { # <file> <heading prefix>
  awk -v h="$2" '
    index($0, h) == 1 { f=1; next }
    /^## / { f=0 }
    f' "$1"
}

flat_section() { normalize_ws "$(section_body "$1" "$2")"; }

# --- Preflight: freshness gate + consent-gated update (D4) --------------------

@test "doc-gate: Preflight runs graph-freshness.sh and gates the update on a chooser" {
  flat="$(flat_section "$SKILL" '## Preflight')"
  [[ "$flat" == *'graph-freshness.sh'* ]]
  [[ "$flat" == *'Asking the user'* ]]
  [[ "$flat" == *'graphify update <root>'* ]]
  [[ "$flat" == *'never runs a full'* ]]
  [[ "$flat" == *'never loads the graphify skill'* ]]
  [[ "$flat" == *"$WIKI_SLUG"* ]]
}

@test "doc-gate can fail: a Preflight without the freshness paragraph does not match" {
  fixture="${BATS_TEST_TMPDIR}/no-freshness.md"
  grep -v 'graph-freshness.sh' "$SKILL" > "$fixture"
  flat="$(flat_section "$fixture" '## Preflight')"
  count="$(printf '%s' "$flat" | grep -cF 'graph-freshness.sh' || true)"
  [ "$count" -eq 0 ]
}

@test "doc-gate: Preflight branches on every exit code of the freshness contract" {
  flat="$(flat_section "$SKILL" '## Preflight')"
  [[ "$flat" == *'`fresh`'* ]]
  [[ "$flat" == *'`stale <N>`'* ]]
  [[ "$flat" == *'`absent`'* ]]
  [[ "$flat" == *'cannot-evaluate'* ]]
}

@test "doc-gate can fail: a Preflight without the stale branch does not match" {
  fixture="${BATS_TEST_TMPDIR}/no-stale.md"
  grep -v 'stale <N>' "$SKILL" > "$fixture"
  flat="$(flat_section "$fixture" '## Preflight')"
  count="$(printf '%s' "$flat" | grep -cF '`stale <N>`' || true)"
  [ "$count" -eq 0 ]
}

@test "state: the script Preflight names exists and is executable" {
  [ -x "$SCRIPT" ]
}

# --- Phase 2: graph leads, paired evidence, bounded output (D5, D6) ------------

@test "doc-gate: Phase 2 uses explain/path as leads with the paired-evidence form" {
  flat="$(flat_section "$SKILL" '## Phase 2')"
  [[ "$flat" == *'head -40'* ]]
  [[ "$flat" == *'-> <N> connections;'* ]]
  [[ "$flat" == *'lead, not evidence'* ]]
  [[ "$flat" == *'--budget 800'* ]]
  [[ "$flat" == *'graph-derived:'* ]]
  [[ "$flat" == *'graphify path'* ]]
}

@test "doc-gate can fail: a Phase 2 without the graph-leads paragraph does not match" {
  fixture="${BATS_TEST_TMPDIR}/no-leads.md"
  grep -v 'connections;' "$SKILL" > "$fixture"
  flat="$(flat_section "$fixture" '## Phase 2')"
  count="$(printf '%s' "$flat" | grep -cF -- '-> <N> connections;' || true)"
  [ "$count" -eq 0 ]
}

@test "doc-gate: --budget is never attached to explain (it is a query-only option)" {
  flat="$(flat_section "$SKILL" '## Phase 2')"
  # Within one backticked command span: `explain ... --budget` would be the defect.
  count="$(printf '%s' "$flat" | grep -cE 'explain[^`]*--budget' || true)"
  [ "$count" -eq 0 ]
  # Non-vacuous: the section does talk about explain.
  [[ "$flat" == *'graphify explain'* ]]
}

@test "doc-gate: SKILL.md never invokes the graphify skill document" {
  count="$(grep -cF 'Skill(graphify' "$SKILL" || true)"
  [ "$count" -eq 0 ]
  count="$(grep -cF '/graphify query' "$SKILL" || true)"
  [ "$count" -eq 0 ]
  # Non-vacuous: graphify is mentioned at all.
  [ "$(grep -cF 'graphify' "$SKILL")" -ge 1 ]
}

# --- Phase 3 brief row + template (D7) ----------------------------------------

@test "doc-gate: Phase 3 step 2 writes the explore row with the main-checkout graph path" {
  flat="$(flat_section "$SKILL" '## Phase 3')"
  [[ "$flat" == *'<main-root>/graphify-out/graph.json'* ]]
  [[ "$flat" == *'explore: graphify'* ]]
  [[ "$flat" == *'integration base'* ]]
}

@test "doc-gate can fail: a Phase 3 without the explore row does not match" {
  fixture="${BATS_TEST_TMPDIR}/no-row.md"
  grep -v 'explore: graphify' "$SKILL" > "$fixture"
  flat="$(flat_section "$fixture" '## Phase 3')"
  count="$(printf '%s' "$flat" | grep -cF 'explore: graphify' || true)"
  [ "$count" -eq 0 ]
}

@test "doc-gate: brief.md tools_guidance shows the explore row and keeps the path in the main checkout" {
  line="$(grep -F '<tools_guidance>' "$BRIEF")"
  [[ "$line" == *'explore: graphify'* ]]
  [[ "$line" == *'<main-root>/graphify-out/graph.json'* ]]
  [[ "$line" == *'lead, not evidence'* ]]
}

@test "doc-gate can fail: a brief.md without the explore row does not match" {
  fixture="${BATS_TEST_TMPDIR}/brief-no-row.md"
  sed 's/explore: graphify//' "$BRIEF" > "$fixture"
  line="$(grep -F '<tools_guidance>' "$fixture")"
  [[ "$line" != *'explore: graphify'* ]]
}

# --- wiki-plan A2: paired evidence (D5) — task 04 --------------------------------

# The A2 span only: from the A2 heading to the A3 heading.
a2_span() { # <file>
  awk '/\*\*A2\. Ground truth\*\*/{f=1} /\*\*A3\./{f=0} f' "$1"
}

@test "doc-gate: wiki-plan A2 pairs a graph citation with a search in one bullet" {
  flat="$(normalize_ws "$(a2_span "$WIKI_PLAN")")"
  [[ "$flat" == *'graphify explain <Symbol> -> <N> connections; <search command> -> <n> hits'* ]]
  [[ "$flat" == *'as a lead'* ]]
  [[ "$flat" == *"$WIKI_SLUG"* ]]
}

@test "doc-gate can fail: an A2 without the graph citation rule does not match" {
  fixture="${BATS_TEST_TMPDIR}/wiki-plan-no-rule.md"
  grep -v 'graphify explain' "$WIKI_PLAN" > "$fixture"
  flat="$(normalize_ws "$(a2_span "$fixture")")"
  count="$(printf '%s' "$flat" | grep -cF 'graphify explain' || true)"
  [ "$count" -eq 0 ]
}

@test "state: plan-gate.sh is untouched by the A2 wording" {
  git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || skip "not a git checkout"
  run git -C "$REPO_ROOT" diff --quiet HEAD -- skills/wiki-plan/scripts/plan-gate.sh
  [ "$status" -eq 0 ]
}

# --- loop-implement step 1 / step 6 (D6, D8, D9) — task 04 --------------------

# The text of one loop step: from `<n>. ` at column 0 to the next step number.
loop_step() { # <file> <from-prefix> <to-prefix>
  awk -v a="$2" -v b="$3" '
    index($0, a) == 1 { f=1 }
    index($0, b) == 1 { f=0 }
    f' "$1"
}

@test "doc-gate: loop-implement step 1 runs explain/path before opening source when explore is graphify" {
  flat="$(normalize_ws "$(loop_step "$LOOP" '1. Analyze' '3. Write tests')")"
  [[ "$flat" == *'graphify explain'* ]]
  [[ "$flat" == *'head -40'* ]]
  [[ "$flat" == *'graphify path'* ]]
  [[ "$flat" == *'BEFORE opening source'* ]]
  [[ "$flat" == *'never evidence'* ]]
}

@test "doc-gate can fail: a step 1 without the graph lead does not match" {
  fixture="${BATS_TEST_TMPDIR}/loop-no-step1.md"
  grep -v 'BEFORE opening source' "$LOOP" > "$fixture"
  flat="$(normalize_ws "$(loop_step "$fixture" '1. Analyze' '3. Write tests')")"
  count="$(printf '%s' "$flat" | grep -cF 'BEFORE opening source' || true)"
  [ "$count" -eq 0 ]
}

@test "doc-gate: loop-implement step 6 names graph-derived assumptions on the NOTES line" {
  flat="$(normalize_ws "$(loop_step "$LOOP" '6. Self-review' '6.5')")"
  [[ "$flat" == *'graph-derived: <assumption>'* ]]
  [[ "$flat" == *'graph-derived: none'* ]]
  [[ "$flat" == *'NOTES line'* ]]
}

@test "doc-gate can fail: a step 6 without graph-derived does not match" {
  fixture="${BATS_TEST_TMPDIR}/loop-no-step6.md"
  grep -v 'graph-derived' "$LOOP" > "$fixture"
  flat="$(normalize_ws "$(loop_step "$fixture" '6. Self-review' '6.5')")"
  count="$(printf '%s' "$flat" | grep -cF 'graph-derived' || true)"
  [ "$count" -eq 0 ]
}

@test "doc-gate: loop-implement never loads the graphify skill document" {
  flat="$(normalize_ws "$(cat "$LOOP")")"
  [[ "$flat" == *'never load the graphify skill document'* ]]
  count="$(grep -cF 'Skill(graphify' "$LOOP" || true)"
  [ "$count" -eq 0 ]
}

@test "doc-gate can fail: a loop-implement without the never-load sentence does not match" {
  fixture="${BATS_TEST_TMPDIR}/loop-no-never.md"
  # The sentence is hard-wrapped in the file; strip by its single-line fragment.
  grep -v 'never load the graphify' "$LOOP" > "$fixture"
  flat="$(normalize_ws "$(cat "$fixture")")"
  count="$(printf '%s' "$flat" | grep -cF 'never load the graphify skill document' || true)"
  [ "$count" -eq 0 ]
}
