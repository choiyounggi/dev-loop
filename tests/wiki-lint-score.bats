#!/usr/bin/env bats
# Prose-pin tests for skills/wiki-lint/SKILL.md's Phase 0 discovery step and
# numeric health score (issue #75, partial adoption).
#
# Every @test here puts its deciding assertion as the final command — one
# assertion per test, or an `&&`-chained final compound — because a mid-test
# `[[ ]]` assertion is silently masked on macOS's bundled bash 3.2 (issue
# #114); only the exit status of the test's last command is honored.

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  SKILL="${REPO_ROOT}/skills/wiki-lint/SKILL.md"
}

# Extracts a "## <heading>" section: from the first line matching the given
# heading pattern up to (not including) the next "## " heading.
section_body() {
  awk -v pat="$2" '$0 ~ pat {p=1} p && /^## / && $0 !~ pat {exit} p' "$1"
}

# --- normal: Phase 0 exists, precedes Checks, names the three commands -----

@test "Phase 0 exists, precedes Checks, and names all four read-only command families" {
  p0="$(grep -n '^## Phase 0' "$SKILL" | head -1 | cut -d: -f1)"
  chk="$(grep -n '^## Checks' "$SKILL" | head -1 | cut -d: -f1)"
  section="$(section_body "$SKILL" '^## Phase 0')"
  [ -n "$p0" ] && [ -n "$chk" ] && [ "$p0" -lt "$chk" ] && [[ "$section" == *"wc -l"* ]] && [[ "$section" == *"wiki-lint-prohibitions.js"* ]] && [[ "$section" == *"wiki-structure-checks.js"* ]] && [[ "$section" == *"wiki-lint-model-era.js"* ]]
}

# --- normal: score formula constants are spelled out -----------------------

@test "Health score section states total_weight=25, weights 3/2/1, and the health: NN/100 format" {
  section="$(section_body "$SKILL" '^## Health score')"
  [[ "$section" == *"total_weight = 25"* ]] && [[ "$section" == *"| error | 3 |"* ]] && [[ "$section" == *"| warn | 2 |"* ]] && [[ "$section" == *"| info | 1 |"* ]] && [[ "$section" == *"health: NN/100 (errors E, warns W, infos I)"* ]]
}

# --- error/negative: the compliance clause must be present verbatim --------

@test "the Phase 0 compliance clause is present verbatim" {
  run grep -F "An assessment produced without the Phase 0 output pasted in its header is non-compliant." "$SKILL"
  [ "$status" -eq 0 ]
}

# --- boundary: the original log-line prefix is extended, not replaced ------

@test "the log.md append line keeps the original lint prefix and now includes health NN/100" {
  run grep -F 'lint | <n> errors fixed, <m> reported | health NN/100' "$SKILL"
  [ "$status" -eq 0 ]
}
