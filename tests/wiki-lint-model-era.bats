#!/usr/bin/env bats
# Tests for scripts/wiki-lint-model-era.js — the mechanical half of wiki-lint
# check 12 (model-era re-verification candidates): a model-coupled page whose
# `verified_model` frontmatter is absent or outside the current model
# generation is reported `revalidate:<file>: <reason>` on stderr, summary on
# stdout, exit 0 clean / 3 candidates / 4 usage.
#
# Every @test here puts its deciding assertion as the final command — one
# assertion per test, or an `&&`-chained final compound — because a mid-test
# `[[ ]]` assertion is silently masked on macOS's bundled bash 3.2 (issue
# #114); only the exit status of the test's last command is honored.

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  SCRIPT="${REPO_ROOT}/scripts/wiki-lint-model-era.js"
  FX="${REPO_ROOT}/tests/fixtures/model-era"
}

# --- normal: coupled page without the field is a candidate ------------------

@test "coupled+unstamped page: exit 3, counted, reason 'no verified_model'" {
  run node "$SCRIPT" "$FX/coupled-unstamped"
  [ "$status" -eq 3 ] && [[ "$output" == *"candidates: 1"* ]] && [[ "$output" == *"revalidate:"* ]] && [[ "$output" == *"model-coupled, no verified_model"* ]]
}

@test "index.md is never scanned: the coupled index.md in the same dir adds no candidate" {
  run node "$SCRIPT" "$FX/coupled-unstamped"
  [[ "$output" == *"pages: 1, model-coupled: 1, candidates: 1"* ]] && [[ "$output" != *"index.md"* ]]
}

# --- normal: current-generation stamp clears the page -----------------------

@test "coupled page stamped with a current-generation model: exit 0, no candidate" {
  run node "$SCRIPT" "$FX/coupled-stamped-current"
  [ "$status" -eq 0 ] && [[ "$output" == *"candidates: 0"* ]]
}

@test "coupled page stamped with an old-generation model: exit 3, reason 'not in current set'" {
  run node "$SCRIPT" "$FX/coupled-stamped-old"
  [ "$status" -eq 3 ] && [[ "$output" == *"not in current set"* ]] && [[ "$output" == *"claude-sonnet-3-7"* ]]
}

# --- override: --current flag and env var, CLI wins --------------------------

@test "--current makes the old stamp current: exit 0" {
  run node "$SCRIPT" "$FX/coupled-stamped-old" --current sonnet-3
  [ "$status" -eq 0 ] && [[ "$output" == *"candidates: 0"* ]]
}

@test "DEV_LOOP_CURRENT_MODELS env makes the old stamp current: exit 0" {
  DEV_LOOP_CURRENT_MODELS=sonnet-3 run node "$SCRIPT" "$FX/coupled-stamped-old"
  [ "$status" -eq 0 ] && [[ "$output" == *"candidates: 0"* ]]
}

@test "precedence: --current beats DEV_LOOP_CURRENT_MODELS" {
  DEV_LOOP_CURRENT_MODELS=sonnet-3 run node "$SCRIPT" "$FX/coupled-stamped-old" --current fable-5
  [ "$status" -eq 3 ] && [[ "$output" == *"not in current set"* ]]
}

# --- negative controls: pages that must NOT be flagged -----------------------

@test "page with no model keyword: not coupled, exit 0" {
  run node "$SCRIPT" "$FX/uncoupled"
  [ "$status" -eq 0 ] && [[ "$output" == *"model-coupled: 0"* ]]
}

@test "keyword only inside '## Sources': not coupled, exit 0" {
  run node "$SCRIPT" "$FX/sources-only"
  [ "$status" -eq 0 ] && [[ "$output" == *"model-coupled: 0"* ]]
}

@test "hyphen-prefixed page-id mention (…-llm-…) does not count as coupled" {
  run node "$SCRIPT" "$FX/hyphen-id"
  [ "$status" -eq 0 ] && [[ "$output" == *"model-coupled: 0"* ]]
}

# --- boundary: empty root ----------------------------------------------------

@test "empty directory: exit 0, pages: 0" {
  mkdir -p "$BATS_TEST_TMPDIR/empty"
  run node "$SCRIPT" "$BATS_TEST_TMPDIR/empty"
  [ "$status" -eq 0 ] && [[ "$output" == *"pages: 0, model-coupled: 0, candidates: 0"* ]]
}

# --- error: usage contract ---------------------------------------------------

@test "no arguments: exit 4 with usage on stderr" {
  run node "$SCRIPT"
  [ "$status" -eq 4 ] && [[ "$output" == *"usage"* ]]
}

@test "nonexistent root: exit 4" {
  run node "$SCRIPT" "$BATS_TEST_TMPDIR/does-not-exist"
  [ "$status" -eq 4 ]
}

@test "--current without a value: exit 4" {
  run node "$SCRIPT" "$FX/uncoupled" --current
  [ "$status" -eq 4 ]
}

@test "--current with an empty value: exit 4, never a silent fallback to the default set" {
  run node "$SCRIPT" "$FX/uncoupled" --current ""
  [ "$status" -eq 4 ] && [[ "$output" == *"current-model set is empty"* ]]
}

@test "unknown flag: exit 4" {
  run node "$SCRIPT" "$FX/uncoupled" --frobnicate
  [ "$status" -eq 4 ]
}

# --- the script parses -------------------------------------------------------

@test "the script is syntactically valid" {
  run node --check "$SCRIPT"
  [ "$status" -eq 0 ]
}
