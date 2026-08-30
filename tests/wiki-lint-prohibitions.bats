#!/usr/bin/env bats
# Tests for scripts/wiki-lint-prohibitions.js (wiki-lint check 2).
#
# The checker's own report is not evidence it works until it has been shown to
# fail on something — a checker observed only ever returning 0 violations proves
# nothing (wiki/testing/quality/checks-that-cannot-pass.md). tests/fixtures/
# prohibitions/bad.md is that negative control: a bare prohibition the checker
# must catch. good.md is the paired-case control: every shape the rule allows
# (em-dash pairing, sentence pairing, an `Instead of` row, a hyphenated
# `never-fails` compound, and the D5 bare-2-word-cell blind spot) must NOT be
# reported as a violation.

setup() {
  CHECKER="${BATS_TEST_DIRNAME}/../scripts/wiki-lint-prohibitions.js"
  REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  FIXTURES="${BATS_TEST_DIRNAME}/fixtures/prohibitions"
}

# --- normal: the real corpus is already compliant ---------------------------

@test "real wiki: exits 0 with 0 violations and 75 directive units" {
  cd "$REPO_ROOT" || return 1
  run node "$CHECKER" wiki
  [ "$status" -eq 0 ]
  [[ "$output" == *"directives: 75"* ]]
  [[ "$output" == *"violations: 0"* ]]
}

# --- error: the negative control (D6) ---------------------------------------

@test "fixture dir: exits 1 and names bad.md as the sole violation" {
  run node "$CHECKER" "$FIXTURES"
  [ "$status" -eq 1 ]
  [[ "$output" == *"bad.md"* ]]
  # exactly one violation — the Sources quote (same file) must not inflate this.
  [[ "$output" == *"violations: 1"* ]]
}

# --- normal: every paired/permitted shape passes -----------------------------

@test "good.md alone: exits 0, no violations" {
  run node "$CHECKER" "$FIXTURES/good.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"violations: 0"* ]]
}

# --- boundary: `## Sources` is excluded (D4) ---------------------------------

@test "a Sources line quoting a bare prohibition is not flagged" {
  run node "$CHECKER" "$FIXTURES"
  [ "$status" -eq 1 ]
  # the Sources bullet repeats "Never log secrets" verbatim; if the Sources
  # exclusion broke, violations would be 2, not 1.
  [[ "$output" == *"violations: 1"* ]]
}

# --- boundary: the 2-word blind spot is reported at info, never error (D5) --

@test "a bare 2-word prohibition cell is reported under info, exit still 0" {
  run node "$CHECKER" "$FIXTURES/good.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"info: 1"* ]]
  [[ "$output" == *"--- info:"* ]]
  [[ "$output" == *"Never read"* ]]
}

# --- explicit DoD case: the single most common corpus shape (D3) ------------
# `wiki/backend/common/reliability/timeouts-and-retries.md` pairs a bare
# "Never retry" (2 words) with its reason via em-dash/semicolon. Because the
# prohibition clause itself is under the 3-word directive threshold, the unit
# falls out of `directives` entirely — it is never classified as a violation,
# compliant pair, or info row. rule 3 must still be read as PERMITTING this
# shape (it is never an error); this test is the checked-explicitly record for
# that DoD line, not a claim that the checker recognizes it as a directive.

@test "the DoD's cited row (bare 2-word prohibition + reason via em-dash/semicolon) is not a violation" {
  dir="${BATS_TEST_TMPDIR}/dod-example"
  mkdir -p "$dir"
  printf -- '---\ntitle: dod example\n---\n\n## Status codes\n| Codes | Behavior |\n|---|---|\n| 400/401/403/404/422 | Never retry — the request itself is wrong; the same bytes fail again |\n' > "$dir/row.md"
  run node "$CHECKER" "$dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"violations: 0"* ]]
}

# --- boundary: empty input ---------------------------------------------------

@test "an empty directory: exits 0, no crash" {
  empty_dir="${BATS_TEST_TMPDIR}/empty-wiki"
  mkdir -p "$empty_dir"
  run node "$CHECKER" "$empty_dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"directives: 0"* ]]
  [[ "$output" == *"violations: 0"* ]]
}

@test "a page with an empty body: exits 0, no crash" {
  empty_body_dir="${BATS_TEST_TMPDIR}/empty-body-wiki"
  mkdir -p "$empty_body_dir"
  printf -- '---\ntitle: empty\n---\n' > "$empty_body_dir/empty.md"
  run node "$CHECKER" "$empty_body_dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"directives: 0"* ]]
  [[ "$output" == *"violations: 0"* ]]
}

# --- error: bad directory argument -------------------------------------------

@test "a nonexistent directory: exits 2 with a stderr message" {
  run node "$CHECKER" "${BATS_TEST_TMPDIR}/does-not-exist"
  [ "$status" -eq 2 ]
  [[ "$output" == *"no such directory"* ]]
}

# --- syntax -------------------------------------------------------------------

@test "the script is syntactically valid" {
  run node --check "$CHECKER"
  [ "$status" -eq 0 ]
}
