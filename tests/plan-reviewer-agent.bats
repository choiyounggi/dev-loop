#!/usr/bin/env bats
# Tests for the plan-reviewer agent (task t2-plan-reviewer, cycle-hardening
# design.md §3 Phase B — independent review of a wiki-plan design doc).
#
# A checker's own report is not evidence it works until it has been shown to
# fail on something (wiki/testing/quality/checks-that-cannot-pass.md) — each
# structural assertion below has a paired negative control that mutates the
# asserted span in a copy and shows the same check fail
# (wiki/testing/quality/spec-artifact-checks.md).

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  AGENT="${REPO_ROOT}/agents/plan-reviewer.md"
}

# Extracts the YAML frontmatter body (between the two "---" lines).
frontmatter() {
  awk '/^---$/{n++; next} n==1' "$1"
}

# --- 1: normal case — frontmatter is complete and every DoD-required span
#        (frontmatter keys, 4 lenses, self-grading guard, output contract,
#        example) is present in the real file ------------------------------

@test "agents/plan-reviewer.md exists with name/description/tools frontmatter" {
  [ -f "$AGENT" ]
  fm="$(frontmatter "$AGENT")"
  [[ "$fm" == *"name: plan-reviewer"* ]]
  [[ "$fm" == *"description:"* ]]
  [[ "$fm" == *"tools: Read, Grep, Glob, Bash"* ]]
}

@test "negative control: a frontmatter copy missing the tools line fails the frontmatter check" {
  stripped="${BATS_TEST_TMPDIR}/agent-no-tools.md"
  grep -v '^tools:' "$AGENT" > "$stripped"
  fm="$(frontmatter "$stripped")"
  [[ "$fm" != *"tools: Read, Grep, Glob, Bash"* ]]
}

@test "agent body states all four review lenses (coverage, grounding, simpler alternative, constraints)" {
  content="$(cat "$AGENT")"
  [[ "$content" == *"Requirements coverage"* ]]
  [[ "$content" == *"Grounding exists"* ]]
  [[ "$content" == *"Simpler alternative"* ]]
  [[ "$content" == *"Constraints violated"* ]]
}

@test "negative control: a copy with the grounding lens removed fails the four-lenses check" {
  stripped="${BATS_TEST_TMPDIR}/agent-no-grounding-lens.md"
  sed '/Grounding exists/d' "$AGENT" > "$stripped"
  content="$(cat "$stripped")"
  [[ "$content" != *"Grounding exists"* ]]
}

@test "agent body states the self-grading guard and is read-only" {
  content="$(cat "$AGENT")"
  [[ "$content" == *"당신은 이 계획을 작성하지 않았다"* ]]
  [[ "$content" == *"read-only"* ]]
}

@test "negative control: a copy with the guard phrase stripped fails the self-grading-guard check" {
  stripped="${BATS_TEST_TMPDIR}/agent-no-guard.md"
  sed '/당신은 이 계획을 작성하지 않았다/d' "$AGENT" > "$stripped"
  content="$(cat "$stripped")"
  [[ "$content" != *"당신은 이 계획을 작성하지 않았다"* ]]
}

@test "agent body states the fixed VERDICT/FINDINGS/SUMMARY output contract with an example" {
  content="$(cat "$AGENT")"
  [[ "$content" == *"VERDICT: PASS | FAIL"* ]]
  [[ "$content" == *"FINDINGS:"* ]]
  [[ "$content" == *"SUMMARY:"* ]]
  [[ "$content" == *"blocking"* ]]
  [[ "$content" == *"## Example"* ]]
  # example block must itself contain a concrete VERDICT line (not just the
  # abstract contract line above it)
  [ "$(grep -c 'VERDICT' "$AGENT")" -ge 2 ]
}

@test "negative control: a copy with FINDINGS: removed fails the output-contract check" {
  stripped="${BATS_TEST_TMPDIR}/agent-no-findings.md"
  grep -v '^FINDINGS:$' "$AGENT" > "$stripped"
  content="$(cat "$stripped")"
  [[ "$content" != *$'\n'"FINDINGS:"$'\n'* ]]
}

# --- 2: error case — the read-only contract must never include Write/Edit --

@test "tools frontmatter excludes Write and Edit (read-only contract enforced)" {
  fm="$(frontmatter "$AGENT")"
  tools_line="$(echo "$fm" | grep '^tools:')"
  [[ "$tools_line" != *"Write"* ]]
  [[ "$tools_line" != *"Edit"* ]]
}

@test "negative control: a fixture copy with Write added to tools fails the read-only check" {
  fixture="${BATS_TEST_TMPDIR}/agent-with-write.md"
  sed 's/^tools: Read, Grep, Glob, Bash$/tools: Read, Grep, Glob, Bash, Write/' "$AGENT" > "$fixture"
  fm="$(frontmatter "$fixture")"
  tools_line="$(echo "$fm" | grep '^tools:')"
  [[ "$tools_line" == *"Write"* ]]
}

# --- 3: boundary case — empty frontmatter value detection -------------------

@test "no frontmatter value is empty on the real file (name/description/tools all populated)" {
  fm="$(frontmatter "$AGENT")"
  for key in name description tools; do
    line="$(echo "$fm" | grep "^${key}:")"
    [ -n "$line" ]
    value="$(echo "$line" | sed "s/^${key}: *//")"
    [ -n "$value" ]
  done
}

@test "negative control: a copy with an emptied tools value is caught as a blank frontmatter field" {
  fixture="${BATS_TEST_TMPDIR}/agent-empty-tools.md"
  sed 's/^tools: Read, Grep, Glob, Bash$/tools:/' "$AGENT" > "$fixture"
  fm="$(frontmatter "$fixture")"
  line="$(echo "$fm" | grep '^tools:')"
  value="$(echo "$line" | sed 's/^tools: *//')"
  [ -z "$value" ]
}
