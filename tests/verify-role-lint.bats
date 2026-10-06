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

# --- READMEs (task 04b) ---

@test "README.md's role table names verify as test / build / lint / typecheck / QA" {
  content="$(cat "${BATS_TEST_DIRNAME}/../README.md")"
  [[ "$content" == *'your project'"'"'s **test / build / lint / typecheck / QA** command (the loop'"'"'s run step)'* ]]
}

@test "README.ko.md's role table names verify the same way" {
  content="$(cat "${BATS_TEST_DIRNAME}/../README.ko.md")"
  [[ "$content" == *'프로젝트의 **테스트 / 빌드 / 린트 / 타입체크 / QA** 명령 (루프의 실행 스텝)'* ]]
}

@test "negative control: a README.md copy with the old row fails the README check" {
  old="${BATS_TEST_TMPDIR}/readme-old.md"
  sed 's#test / build / lint / typecheck / QA#test / build / QA#' "${BATS_TEST_DIRNAME}/../README.md" > "$old"
  content="$(cat "$old")"
  [[ "$content" != *'**test / build / lint / typecheck / QA** command'* ]]
}

# --- loop-implement role list and example profile (task 04c) ---

@test "loop-implement's role list names verify as test / build / lint / typecheck / QA" {
  text="$(tr '\n' ' ' < "${BATS_TEST_DIRNAME}/../skills/loop-implement/SKILL.md" | tr -s ' ')"
  [[ "$text" == *'`verify` (the project'"'"'s test / build / lint / typecheck / QA command)'* ]]
}

@test "the example profile's verify how names lint and typecheck" {
  run jq -r '.verify.how' "${BATS_TEST_DIRNAME}/../examples/tools.example.json"
  [ "$status" -eq 0 ]
  [ "$output" = "run the project's test/build/lint/typecheck/QA command; report failures verbatim" ]
}

@test "negative control: a loop-implement copy with the old role wording fails the role-list check" {
  old="${BATS_TEST_TMPDIR}/loop-old.md"
  sed 's#test / build / lint /#test / build / QA#' "${BATS_TEST_DIRNAME}/../skills/loop-implement/SKILL.md" > "$old"
  text="$(tr '\n' ' ' < "$old" | tr -s ' ')"
  [[ "$text" != *'test / build / lint / typecheck / QA command'* ]]
}

# --- resolve-tools.sh default description (task 04d) ---

@test "unconfigured verify resolves to the test / build / lint / typecheck / QA description" {
  LOOP_ORCH_CONFIG_HOME="${BATS_TEST_TMPDIR}/none-home.json" \
  LOOP_ORCH_CONFIG_PROJECT="${BATS_TEST_TMPDIR}/none-proj.json" \
    run bash "${BATS_TEST_DIRNAME}/../scripts/resolve-tools.sh" --summary
  [ "$status" -eq 0 ]
  [[ "$output" == *'verify: default (built-in behavior)  [when: running tests / build / lint / typecheck / QA checks (step 5)]'* ]]
}

@test "negative control: a resolve-tools.sh copy with the old text prints the old line" {
  old="${BATS_TEST_TMPDIR}/resolve-tools-old.sh"
  sed 's#tests / build / lint / typecheck / QA checks#tests / build / QA checks#' \
    "${BATS_TEST_DIRNAME}/../scripts/resolve-tools.sh" > "$old"
  LOOP_ORCH_CONFIG_HOME="${BATS_TEST_TMPDIR}/none-home.json" \
  LOOP_ORCH_CONFIG_PROJECT="${BATS_TEST_TMPDIR}/none-proj.json" \
    run bash "$old" --summary
  [[ "$output" != *'lint / typecheck / QA checks'* ]]
}
