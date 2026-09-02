#!/usr/bin/env bats
# Tests for the {ORCH_DIR} absolute-path token (issue #87). Orchestration
# artifacts (briefs/plans/reviews) live outside every worker's worktree, so a
# bare `.orchestration/...` reference in a worker-facing template section
# resolves to nothing when a worker's cwd is its own worktree. These tests
# assert every such reference is expressed via {ORCH_DIR} instead, and that
# no bare form (including the ad-hoc `$(dirname {STATUS_DIR})/...` form) is
# left behind in the worker-facing sections. The one exception (issue #167):
# `STATUS_DIR=.orchestration/status` is a deliberately bare, worktree-relative
# path — workers write status/questions worker-locally now, never into the
# coordinator's checkout — so the negative gate below exempts that one string
# and nothing else.

setup() {
  SP_TEMPLATE="${BATS_TEST_DIRNAME}/../skills/orchestrate/templates/session-prompt.md"
  BRIEF_TEMPLATE="${BATS_TEST_DIRNAME}/../skills/orchestrate/templates/brief.md"
}

extract_section() {
  local heading="$1" file="$2"
  awk -v h="$heading" '
    index($0, h) == 1 { flag=1; next }
    /^## / { flag=0 }
    flag { print }
  ' "$file"
}

# Everything from the first numbered/lettered section onward — the text that
# actually gets delivered to a worker (§1-§4, §O1-§O4, and the protocol
# blocks appended to them). Excludes the leading coordinator-facing
# documentation (substrate notes, token legend, delivery mechanics).
worker_facing_region() {
  local file="$1"
  awk '/^## \(1\)/ { flag=1 } flag { print }' "$file"
}

# Collapses embedded newlines (and the whitespace runs they leave behind) to
# a single space so a substring assertion survives prose hard-wrapped across
# physical lines (wiki/testing/quality/checks-that-cannot-pass.md: a
# newline-split phrase reads as absent under a raw substring match).
normalize_ws() {
  printf '%s' "$1" | tr '\n' ' ' | tr -s ' '
}

# --- normal: §1/§O1 (plan) reference both briefs and plans via {ORCH_DIR} ---

@test "§1: briefs and plans are referenced via {ORCH_DIR}" {
  flat="$(normalize_ws "$(extract_section '## (1)' "$SP_TEMPLATE")")"
  [[ "$flat" == *'{ORCH_DIR}/briefs/{TASK}.md'* ]]
  [[ "$flat" == *'{ORCH_DIR}/plans/{TASK}.md'* ]]
}

@test "§O1: briefs and plans are referenced via {ORCH_DIR}" {
  flat="$(normalize_ws "$(extract_section '## (O1)' "$SP_TEMPLATE")")"
  [[ "$flat" == *'{ORCH_DIR}/briefs/{TASK}.md'* ]]
  [[ "$flat" == *'{ORCH_DIR}/plans/{TASK}.md'* ]]
}

# --- normal: §2/§O2 (implement) reference plans via {ORCH_DIR} -------------

@test "§2: plan is referenced via {ORCH_DIR}" {
  flat="$(normalize_ws "$(extract_section '## (2)' "$SP_TEMPLATE")")"
  [[ "$flat" == *'{ORCH_DIR}/plans/{TASK}.md'* ]]
}

@test "§O2: plan is referenced via {ORCH_DIR}" {
  flat="$(normalize_ws "$(extract_section '## (O2)' "$SP_TEMPLATE")")"
  [[ "$flat" == *'{ORCH_DIR}/plans/{TASK}.md'* ]]
}

# --- normal: §3/§O3 (rework) reference reviews via {ORCH_DIR}, no ad-hoc ---
# --- $(dirname {STATUS_DIR}) form left behind (D3) -------------------------

@test "§3: reviews are referenced via {ORCH_DIR}, ad-hoc dirname form is gone" {
  flat="$(normalize_ws "$(extract_section '## (3)' "$SP_TEMPLATE")")"
  [[ "$flat" == *'{ORCH_DIR}/reviews/{TASK}-r{N}.md'* ]]
  [[ "$flat" != *'$(dirname'* ]]
}

@test "§O3: reviews are referenced via {ORCH_DIR}, ad-hoc dirname form is gone" {
  flat="$(normalize_ws "$(extract_section '## (O3)' "$SP_TEMPLATE")")"
  [[ "$flat" == *'{ORCH_DIR}/reviews/{TASK}-r{N}.md'* ]]
  [[ "$flat" != *'$(dirname'* ]]
}

# --- normal: the coordinator-facing token legend documents {ORCH_DIR} ------

@test "token legend documents {ORCH_DIR}" {
  legend="$(sed -n '1,15p' "$SP_TEMPLATE")"
  [[ "$legend" == *'{ORCH_DIR}'* ]]
}

# --- boundary: brief.md's <plan> line and header note use {ORCH_DIR} -------

@test "brief.md: <plan> line uses {ORCH_DIR}" {
  line="$(grep -F '<plan>' "$BRIEF_TEMPLATE")"
  [[ "$line" == *'{ORCH_DIR}/plans/{TASK}.md'* ]]
  [[ "$line" != *'.orchestration/'* ]]
}

@test "brief.md: header note uses {ORCH_DIR}" {
  header="$(sed -n '1,10p' "$BRIEF_TEMPLATE")"
  [[ "$header" == *'{ORCH_DIR}/briefs/{TASK}.md'* ]]
}

# --- error/negative: no bare .orchestration/ path in worker-facing text ----

@test "negative gate: no bare .orchestration/ path in session-prompt.md worker-facing sections, other than the sanctioned worker-local STATUS_DIR" {
  # issue #167: workers now write status/questions worker-locally via a
  # RELATIVE `STATUS_DIR=.orchestration/status` (their own worktree cwd
  # resolves it) — that is the one sanctioned bare `.orchestration/`
  # reference. Every other one (briefs/plans/reviews/escalations, which live
  # in the coordinator's checkout) must still go through {ORCH_DIR}.
  region="$(worker_facing_region "$SP_TEMPLATE")"
  stripped="$(printf '%s\n' "$region" | sed 's#\.orchestration/status##g')"
  count="$(printf '%s\n' "$stripped" | grep -cF '.orchestration/' || true)"
  [ "$count" -eq 0 ]
}

@test "negative control: the sanctioned-path gate still fires on an unrelated bare .orchestration/ path" {
  # Proves the strip above only exempts .orchestration/status, not every path.
  stripped="${BATS_TEST_TMPDIR}/bad-section.md"
  cat > "$stripped" <<'EOF'
## (1) Plan

Read .orchestration/reviews/{TASK}-r1.md before you start.
EOF
  region="$(cat "$stripped")"
  count="$(printf '%s\n' "$region" | sed 's#\.orchestration/status##g' | grep -cF '.orchestration/' || true)"
  [ "$count" -gt 0 ]
}

@test "negative gate: no bare .orchestration/ path anywhere in brief.md, other than the sanctioned worker-local STATUS_DIR" {
  # Same exemption as session-prompt.md's gate above: brief.md's
  # <output_contract> line uses STATUS_DIR=.orchestration/status (issue #167).
  stripped="$(sed 's#\.orchestration/status##g' "$BRIEF_TEMPLATE")"
  count="$(printf '%s\n' "$stripped" | grep -cF '.orchestration/' || true)"
  [ "$count" -eq 0 ]
}

# --- negative control: the gate above fires on a fixture that still has ----
# --- a bare path, proving it can fail (checks-that-cannot-pass) ------------

@test "negative control: the bare-path gate fires on a stripped fixture" {
  stripped="${BATS_TEST_TMPDIR}/stripped-section.md"
  cat > "$stripped" <<'EOF'
## (3) Rework — injected when review requests changes

Address the issues in .orchestration/reviews/{TASK}-r{N}.md via the loop-implement skill.
EOF
  count="$(grep -cF '.orchestration/' "$stripped" || true)"
  [ "$count" -gt 0 ]
}
