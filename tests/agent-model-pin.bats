#!/usr/bin/env bats
# Issue #200: the two bundled review agents used to pin `model: fable` and
# died on a model-scoped 429, which a mandatory auditor turned into a hard
# stop. This file proves the pin is gone and that the 429-is-not-a-verdict
# retry rule (re-run with the Agent tool's model override: opus, then sonnet)
# is documented both where the auditor is invoked (loop-implement step 6.5)
# and in each agent's own body.
#
# Each structural assertion is paired with a negative control
# (wiki/testing/quality/checks-that-cannot-pass.md): a fixture with the
# asserted span stripped, shown to fail the same check.

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  SKILL="${REPO_ROOT}/skills/loop-implement/SKILL.md"
  AGENT1="${REPO_ROOT}/agents/integration-reviewer.md"
  AGENT2="${REPO_ROOT}/agents/test-quality-auditor.md"
  AGENT3="${REPO_ROOT}/agents/task-reviewer.md"
  AGENT4="${REPO_ROOT}/agents/task-planner.md"
}

# Extracts the "## Floor pre-gate + calling the auditor (step 6.5)" section:
# from its heading up to (not including) the next "## " heading.
step65_section() {
  awk '/^## Floor pre-gate/{p=1} p && /^## / && !/^## Floor pre-gate/{exit} p' "$1"
}

@test "review agents carry no model pin" {
  for f in "$AGENT1" "$AGENT2" "$AGENT3" "$AGENT4"; do
    run sh -c "head -10 '$f' | grep -q '^model:'"
    [ "$status" -ne 0 ]
  done
}

@test "loop-implement step 6.5 documents the model-scoped 429 retry with the opus then sonnet override" {
  section="$(step65_section "$SKILL" | tr '[:upper:]' '[:lower:]')"
  [[ "$section" == *"429"* ]]
  [[ "$section" == *"not a verdict"* ]]
  [[ "$section" == *"opus"*"sonnet"* ]]
}

@test "all four agent bodies carry the Coordinator note about the 429 override" {
  for f in "$AGENT1" "$AGENT2" "$AGENT3" "$AGENT4"; do
    content="$(cat "$f" | tr '[:upper:]' '[:lower:]')"
    [[ "$content" == *"429"* ]]
    [[ "$content" == *"not a verdict"* ]]
    [[ "$content" == *"opus"*"sonnet"* ]]
  done
}

@test "negative control: a SKILL.md copy with the 429 bullet removed fails the check" {
  stripped="${BATS_TEST_TMPDIR}/skill.md"
  grep -v '429' "$SKILL" > "$stripped"
  section="$(step65_section "$stripped" | tr '[:upper:]' '[:lower:]')"
  [ -n "$section" ]
  [[ "$section" == *"floor"* ]]
  [[ "$section" != *"429"* ]]
}

@test "empty section: an agent copy with the body stripped fails the note check" {
  frontmatter_only="${BATS_TEST_TMPDIR}/agent-frontmatter-only.md"
  awk '{print} /^---$/{n++} n==2{exit}' "$AGENT1" > "$frontmatter_only"
  [ -s "$frontmatter_only" ]
  content="$(cat "$frontmatter_only" | tr '[:upper:]' '[:lower:]')"
  [[ "$content" == *"integration-reviewer"* ]]
  [[ "$content" != *"not a verdict"* ]]
  [[ "$content" != *"opus"* ]]
}

@test "negative control: a task-reviewer copy with the 429 note removed fails the note check" {
  stripped="${BATS_TEST_TMPDIR}/task-reviewer-no-429.md"
  grep -v '429' "$AGENT3" > "$stripped"
  content="$(cat "$stripped" | tr '[:upper:]' '[:lower:]')"
  [ -s "$stripped" ]
  [[ "$content" != *"429"* ]]
}

@test "boundary: a task-reviewer copy pinned to a model fails the no-pin check" {
  pinned="${BATS_TEST_TMPDIR}/task-reviewer-pinned.md"
  awk '/^name:/{print; print "model: fable"; next} {print}' "$AGENT3" > "$pinned"
  run sh -c "head -10 '$pinned' | grep -q '^model:'"
  [ "$status" -eq 0 ]
}

@test "boundary: a task-planner copy pinned to a model fails the no-pin check" {
  pinned="${BATS_TEST_TMPDIR}/task-planner-pinned.md"
  awk '/^name:/{print; print "model: fable"; next} {print}' "$AGENT4" > "$pinned"
  run sh -c "head -10 '$pinned' | grep -q '^model:'"
  [ "$status" -eq 0 ]
}
