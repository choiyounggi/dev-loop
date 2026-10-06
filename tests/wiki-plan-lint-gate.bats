#!/usr/bin/env bats
# skills/wiki-plan/SKILL.md: A2 records every lint/typecheck command as a
# `- Lint:` bullet (gate-A lint-surveyed), and Phase C turns each bullet into
# a lint line in every task's Verify (plans/excess-lens-and-lint-gate D5-D7).
# Substring checks run on whitespace-normalized text, so a reflowed sentence
# still matches; each check has a negative control that strips its span.

setup() {
  SKILL="${BATS_TEST_DIRNAME}/../skills/wiki-plan/SKILL.md"
}

flat() { # <file>
  tr '\n' ' ' < "$1" | tr -s ' '
}

@test "A2 names the Lint bullet in both forms" {
  text="$(flat "$SKILL")"
  [[ "$text" == *'Lint: <command> -> rc=<n>'* ]]
  [[ "$text" == *'Lint: none — checked: <search command>'* ]]
}

@test "the gate-A ids line lists lint-surveyed" {
  ids="$(flat "$SKILL" | grep -oE 'Gate ids: `baseline-tests-ran`[^.]*\.')"
  [[ "$ids" == *'`lint-surveyed`'* ]]
}

@test "lite mode never abandons lint-surveyed" {
  text="$(flat "$SKILL")"
  [[ "$text" == *'`lint-surveyed` is never abandoned in lite mode'* ]]
}

@test "Phase C's Lint gating table covers the green, red-with-operands, and red-without-operands rows" {
  text="$(flat "$SKILL")"
  [[ "$text" == *'Lint gating in every task'* ]]
  [[ "$text" == *'&& echo LINT_OK'* ]]
  [[ "$text" == *'xargs -r'* ]]
  [[ "$text" == *'not gated — baseline rc=<n>'* ]]
  [[ "$text" == *'never adds a warning-promotion flag'* ]]
}

@test "boundary: a project with no lint command gets no lint line" {
  text="$(flat "$SKILL")"
  [[ "$text" == *'| `Lint: none — checked: ...` | no lint line |'* ]]
}

@test "the step-6 self-check verifies every task carries its lint lines" {
  text="$(flat "$SKILL")"
  [[ "$text" == *'every task'"'"'s Verify carries one lint line per `- Lint:` bullet'* ]]
}

@test "negative control: a copy without its LINT_OK lines fails the gating-table check" {
  stripped="${BATS_TEST_TMPDIR}/skill-no-lint-ok.md"
  grep -v 'LINT_OK' "$SKILL" > "$stripped"
  text="$(flat "$stripped")"
  [[ "$text" != *'&& echo LINT_OK'* ]]
}

@test "negative control: a copy with lint-surveyed renamed fails the gate-ids check" {
  renamed="${BATS_TEST_TMPDIR}/skill-renamed.md"
  sed 's/lint-surveyed/x/g' "$SKILL" > "$renamed"
  ids="$(flat "$renamed" | grep -oE 'Gate ids: `baseline-tests-ran`[^.]*\.')"
  [[ "$ids" != *'`lint-surveyed`'* ]]
}
