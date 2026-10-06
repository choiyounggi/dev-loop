#!/usr/bin/env bats
# The `verify` capability role is the project's test / build / lint /
# typecheck / QA command (plans/excess-lens-and-lint-gate D8): configure's
# description and role table and tool-profile.md's role row all say so, and
# no file keeps the old test/build/QA-only wording.

setup() {
  CONFIGURE="${BATS_TEST_DIRNAME}/../skills/configure/SKILL.md"
  PROFILE="${BATS_TEST_DIRNAME}/../references/tool-profile.md"
}

@test "configure's description names verify as the test/build/lint/typecheck/QA command" {
  desc="$(awk '/^---$/{n++; next} n==1 && /^description: /' "$CONFIGURE")"
  [[ "$desc" == *'`verify` (your project'"'"'s test/build/lint/typecheck/QA command)'* ]]
}

@test "configure's role table maps verify to lint and typecheck scripts too" {
  content="$(cat "$CONFIGURE")"
  [[ "$content" == *'your project'"'"'s **test / build / lint / typecheck / QA** command'* ]]
  [[ "$content" == *'scripts (test, lint, typecheck)'* ]]
}

@test "tool-profile.md's verify row names lint and typecheck checks" {
  content="$(cat "$PROFILE")"
  [[ "$content" == *'running the project'"'"'s tests / build / lint / typecheck / QA checks'* ]]
}

@test "boundary: no file keeps the old test/build/QA-only wording" {
  run grep -c -e 'test/build/QA command' -e 'tests / build / QA checks' -e 'test / build / QA\*\*' "$CONFIGURE" "$PROFILE"
  [[ "$output" == *"SKILL.md:0"* ]]
  [[ "$output" == *"tool-profile.md:0"* ]]
}

@test "negative control: a configure copy without lint/typecheck fails the description check" {
  stripped="${BATS_TEST_TMPDIR}/configure-old.md"
  sed 's#test/build/lint/typecheck/QA#test/build/QA#' "$CONFIGURE" > "$stripped"
  desc="$(awk '/^---$/{n++; next} n==1 && /^description: /' "$stripped")"
  [[ "$desc" != *'test/build/lint/typecheck/QA command'* ]]
}
