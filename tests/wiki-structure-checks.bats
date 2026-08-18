#!/usr/bin/env bats
# Tests for scripts/wiki-structure-checks.js — the mechanical duplicate +
# format gate for the bundled wiki (countable half of wiki-lint, CI-enforced).
#
# A checker observed only ever returning 0 findings proves nothing
# (wiki/testing/quality/checks-that-cannot-pass.md): tests/fixtures/
# wiki-structure/bad/ is the negative control — a mini-wiki carrying every
# defect class exactly where the assertions below expect it. good/ is the
# paired control: a fully-compliant mini-wiki that must stay at 0 findings.

setup() {
  CHECKER="${BATS_TEST_DIRNAME}/../scripts/wiki-structure-checks.js"
  REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  FIXTURES="${BATS_TEST_DIRNAME}/fixtures/wiki-structure"
}

# --- normal: the real corpus is compliant -----------------------------------

@test "real wiki: exits 0 with findings: 0" {
  cd "$REPO_ROOT" || return 1
  run node "$CHECKER" wiki
  [ "$status" -eq 0 ]
  [[ "$output" == *"findings: 0"* ]]
}

@test "good fixture: exits 0, summary counts pages and indexes" {
  run node "$CHECKER" "$FIXTURES/good"
  [ "$status" -eq 0 ]
  [ "$output" = "pages: 2, indexes: 1, findings: 0" ]
}

# --- error: every defect class is caught (negative control) -----------------

@test "bad fixture: exit 3 and every check class fires" {
  run node "$CHECKER" "$FIXTURES/bad"
  [ "$status" -eq 3 ]
  [[ "$output" == *"no-frontmatter:"* ]]
  [[ "$output" == *"missing-key:"* ]]
  [[ "$output" == *"frontmatter lacks 'related'"* ]]
  [[ "$output" == *"duplicate-id:"* ]]
  [[ "$output" == *"id-path-mismatch:"* ]]
  [[ "$output" == *"id 'alpha-cat-wrong' != path-derived 'alpha-cat-one'"* ]]
  [[ "$output" == *"domain-mismatch:"* ]]
  [[ "$output" == *"category-mismatch:"* ]]
  [[ "$output" == *"bad-confidence:"* ]]
  [[ "$output" == *"verified-no-sources:"* ]]
  [[ "$output" == *"broken-index-link:"* ]]
  [[ "$output" == *"cat/ghost.md"* ]]
  [[ "$output" == *"duplicate-index-row:"* ]]
  [[ "$output" == *"cross-domain-listing:"* ]]
  [[ "$output" == *"orphan-page:"* ]]
  [[ "$output" == *"bad-related:"* ]]
  [[ "$output" == *"related id 'no-such-id'"* ]]
}

@test "bad fixture: summary goes to stdout, findings go to stderr only" {
  run bash -c "node '$CHECKER' '$FIXTURES/bad' 2>/dev/null"
  [ "$status" -eq 3 ]
  [ "$output" = "pages: 4, indexes: 2, findings: 15" ]
  run bash -c "node '$CHECKER' '$FIXTURES/bad' 2>&1 >/dev/null"
  [ "$status" -eq 3 ]
  [[ "$output" != *"pages:"* ]]
  [[ "$output" == *"orphan-page:"* ]]
}

# --- boundary ---------------------------------------------------------------

@test "empty wiki root (no pages, no indexes): exits 0 vacuously" {
  mkdir -p "$BATS_TEST_TMPDIR/empty"
  run node "$CHECKER" "$BATS_TEST_TMPDIR/empty"
  [ "$status" -eq 0 ]
  [ "$output" = "pages: 0, indexes: 0, findings: 0" ]
}

# --- error: refusal paths ---------------------------------------------------

@test "no argument: exit 4, usage on stderr, nothing on stdout" {
  run bash -c "node '$CHECKER' 2>/dev/null"
  [ "$status" -eq 4 ]
  [ -z "$output" ]
}

@test "nonexistent root: exit 4" {
  run node "$CHECKER" "$BATS_TEST_TMPDIR/does-not-exist"
  [ "$status" -eq 4 ]
  [[ "$output" == *"not a readable directory"* ]]
}
