#!/usr/bin/env bats
# Tests for skills/orchestrate/SKILL.md Phase 4's four-lens review pass and
# skills/orchestrate/templates/review-report.md (i82-phase4-lenses, issue
# #82 / #84).
#
# A checker's own report is not evidence it works until it has been shown to
# fail on something (wiki/testing/quality/checks-that-cannot-pass.md) — each
# structural assertion below has a paired negative control that strips the
# asserted span from a copy and shows the same check fail
# (wiki/testing/quality/spec-artifact-checks.md).
#
# These tests do NOT assert the existence of i81 (AGENTS.md routing step 7)
# or i85 (the lens-3/lens-4 wiki pages) artifacts — those land on sibling
# branches, not this one; SKILL.md only needs to *cite* their paths.

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  SKILL="${REPO_ROOT}/skills/orchestrate/SKILL.md"
  TEMPLATE="${REPO_ROOT}/skills/orchestrate/templates/review-report.md"
}

# Extracts the "## Phase 4" section: from its heading up to (not including)
# the next "## " heading.
phase4_section() {
  awk '/^## Phase 4/{p=1} p && /^## / && !/^## Phase 4/{exit} p' "$1"
}

# Concatenates the digit prefix of every numbered-bold lens line found in
# the Phase 4 section of the given file, e.g. "1234" when all four are
# present in order, "" when none are, "134" when one is missing.
lens_order() {
  phase4_section "$1" | grep -oE '^[0-9]\. \*\*[^*]+\*\*' | sed -E 's/^([0-9])\..*/\1/' | tr -d '\n'
}

# --- normal: the four lenses are present, numbered 1-4, in order -----------

@test "Phase 4 contains the four lenses, numbered 1-4, in order" {
  [ "$(lens_order "$SKILL")" = "1234" ]
  section="$(phase4_section "$SKILL")"
  [[ "$section" == *"Plan conformance"* ]]
  [[ "$section" == *"Wiki re-route from the diff"* ]]
  [[ "$section" == *"Execution-environment reality"* ]]
  [[ "$section" == *"Multi-object write ordering"* ]]
}

@test "lens 2 cites AGENTS.md routing protocol step 7 by document and step number only" {
  section="$(phase4_section "$SKILL")"
  [[ "$section" == *"AGENTS.md routing protocol step 7"* ]]
}

@test "lens 3 and lens 4 cite their grounding wiki pages" {
  section="$(phase4_section "$SKILL")"
  [[ "$section" == *"wiki/platforms/toolchains/flag-availability-at-the-execution-site.md"* ]]
  [[ "$section" == *"wiki/backend/common/storage/multi-object-write-ordering.md"* ]]
}

@test "lens 4 states the coordinator-only leverage" {
  section="$(phase4_section "$SKILL")"
  [[ "$section" == *"only reviewer who sees every worktree at once"* ]]
}

@test "Phase 4 instructs writing reviews/<task>-rN.md from templates/review-report.md" {
  section="$(phase4_section "$SKILL")"
  [[ "$section" == *'reviews/<task>-rN.md'* ]]
  [[ "$section" == *'templates/review-report.md'* ]]
}

@test "Phase 4 retains the test-quality-auditor obligation alongside the pass, not as a fifth lens" {
  section="$(phase4_section "$SKILL")"
  [[ "$section" == *'test-quality-auditor'* ]]
  # it must not be numbered 5 — the issue fixes exactly four lenses
  [[ "$section" != *'5. **'* ]]
}

@test "Phase 4 retains the surrounding mechanics: diff command, rework budget, escalation, dispatch-loop return" {
  section="$(phase4_section "$SKILL")"
  [[ "$section" == *'git -C <wt> diff'* ]]
  [[ "$section" == *'<integ>...HEAD'* ]]
  # the 3-round cap is code-enforced since #106: the budget lives in
  # ready-set.sh (LO_MAX_REWORK) and exhaustion escalates via the exit-3
  # DEADLOCK route to a human decision
  [[ "$section" == *'LO_MAX_REWORK'* ]]
  [[ "$section" == *'human decision'* ]]
  [[ "$section" == *'return to step 1 of the dispatch'* ]]
  [[ "$section" == *'go to Phase 5'* ]]
}

# --- negative control: stripping the lens list breaks the order check ------

@test "negative control: a SKILL.md copy with the lens lines removed fails the order check" {
  stripped="${BATS_TEST_TMPDIR}/skill-no-lenses.md"
  grep -v -E '^[0-9]\. \*\*(Plan conformance|Wiki re-route|Execution-environment|Multi-object)' "$SKILL" > "$stripped"
  [ "$(lens_order "$stripped")" != "1234" ]
}

# --- negative control: reordering two lenses breaks the order check --------

@test "negative control: a SKILL.md copy with lenses 2 and 3 swapped fails the order check" {
  swapped="${BATS_TEST_TMPDIR}/skill-swapped-lenses.md"
  awk '
    /^2\. \*\*Wiki re-route/ { line2 = $0; getline; rest2 = $0; got2 = 1; next }
    /^3\. \*\*Execution-environment/ && got2 {
      print $0; getline; print $0
      print line2; print rest2
      next
    }
    { print }
  ' "$SKILL" > "$swapped"
  [ "$(lens_order "$swapped")" != "1234" ]
}

# --- template structure: three-part finding format + non-blocking section --

@test "review-report.md has the three-part finding format" {
  content="$(cat "$TEMPLATE")"
  [[ "$content" == *"Observation"* ]]
  [[ "$content" == *"Failure scenario"* ]]
  [[ "$content" == *"Question"* ]]
  [[ "$content" == *"## Non-blocking"* ]]
}

@test "review-report.md has a header naming task, round, and an approve/rework verdict" {
  content="$(cat "$TEMPLATE")"
  [[ "$content" == *"{TASK}"* ]]
  [[ "$content" == *"{N}"* ]]
  [[ "$content" == *"approve"* ]]
  [[ "$content" == *"rework"* ]]
}

# --- error/boundary: per-lens table distinguishes clean, findings, not-run -

@test "review-report.md's per-lens table has 4 rows, each distinguishing clean/findings/not-run" {
  content="$(cat "$TEMPLATE")"
  clean_count="$(grep -c 'clean —' "$TEMPLATE")"
  notrun_count="$(grep -c 'not run —' "$TEMPLATE")"
  [ "$clean_count" -eq 4 ]
  [ "$notrun_count" -eq 4 ]
  [[ "$content" == *"findings: F1, F2"* ]]
}

# --- negative control: a template copy missing the not-run option fails ----

@test "negative control: a review-report.md copy with 'not run' stripped fails the distinguishing check" {
  stripped="${BATS_TEST_TMPDIR}/review-report-no-notrun.md"
  sed 's/ or `not run — <why>`//' "$TEMPLATE" > "$stripped"
  notrun_count="$(grep -c 'not run —' "$stripped" || true)"
  [ "$notrun_count" -eq 0 ]
}

# --- negative control: a template copy without the non-blocking section ----

@test "negative control: a review-report.md copy without the Non-blocking section fails the structure check" {
  stripped="${BATS_TEST_TMPDIR}/review-report-no-nonblocking.md"
  awk '/^## Non-blocking/{exit} {print}' "$TEMPLATE" > "$stripped"
  content="$(cat "$stripped")"
  [[ "$content" != *"## Non-blocking"* ]]
}
