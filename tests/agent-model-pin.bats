#!/usr/bin/env bats
# Issue #200: the two bundled review agents used to pin `model: fable` and
# died on a model-scoped 429, which a mandatory auditor turned into a hard
# stop. The pins are back on purpose: each tier-graded agent now pins the model
# and effort orchestrate's Tier to pipeline profile table names. This file
# proves those pins, the analysis/design/QA floor (claude-opus-5-5 or
# claude-fable-5-1, effort high or above, on every base, -r1 copy and
# plan-reviewer), and that the 429-is-not-a-verdict retry rule (re-run once
# with the Agent tool's model override on whichever of opus and fable the 429
# does not name, never sonnet) is documented both where the auditor is invoked
# (loop-implement step 6.5) and in each agent's own body.
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
  AGENT5="${REPO_ROOT}/agents/task-analyst.md"
}

# frontmatter of an agent file: the lines between the first two '---'
frontmatter() {
  awk '/^---$/{n++; next} n==1' "$1"
}

# Extracts the "## Floor pre-gate + calling the auditor (step 6.5)" section:
# from its heading up to (not including) the next "## " heading.
step65_section() {
  awk '/^## Floor pre-gate/{p=1} p && /^## / && !/^## Floor pre-gate/{exit} p' "$1"
}

@test "each tier-graded agent pins the profile table's model and R3/R2 effort" {
  # name|model|effort — the base (R3/R2) column of the Tier to pipeline profile
  for row in \
    "task-analyst|claude-fable-5-1|xhigh" \
    "task-planner|claude-opus-5-5|high" \
    "test-quality-auditor|claude-fable-5-1|high" \
    "task-reviewer|claude-fable-5-1|high" \
    "integration-reviewer|claude-fable-5-1|max"; do
    IFS='|' read -r name model effort <<< "$row"
    fm="$(frontmatter "${REPO_ROOT}/agents/${name}.md")"
    [[ "$fm" == *$'\n'"model: ${model}"$'\n'* ]]
    [[ "$fm" == *$'\n'"effort: ${effort}"* ]]
  done
}

# meets_floor <agent file>: true when the frontmatter pins claude-opus-5-5 or
# claude-fable-5-1 and an effort of high, xhigh or max.
meets_floor() {
  local fm
  fm="$(frontmatter "$1")"
  [[ "$fm" == *$'\n'"model: claude-opus-5-5"$'\n'* || "$fm" == *$'\n'"model: claude-fable-5-1"$'\n'* ]] || return 1
  [[ "$fm" =~ (^|$'\n')effort:\ (high|xhigh|max)($'\n'|$) ]]
}

@test "plan-reviewer pins claude-opus-5-5 at high effort" {
  fm="$(frontmatter "${REPO_ROOT}/agents/plan-reviewer.md")"
  [[ "$fm" == *$'\n'"model: claude-opus-5-5"$'\n'* ]]
  [[ "$fm" =~ (^|$'\n')effort:\ high($'\n'|$) ]]
}

@test "plan-reviewer and wiki-plan's review step carry the 429 retry, never sonnet" {
  agent="$(tr '[:upper:]' '[:lower:]' < "${REPO_ROOT}/agents/plan-reviewer.md" | tr '\n' ' ')"
  [[ "$agent" == *"not a verdict"* ]]
  [[ "$agent" == *"whichever of \`opus\` and \`fable\` the 429 does not name"* ]]
  review="$(awk '/^\*\*Independent review\*\*/{p=1} p && /^\*\*gate-B\*\*/{exit} p' "${REPO_ROOT}/skills/wiki-plan/SKILL.md" | tr '\n' ' ')"
  [[ "$review" == *"plan-reviewer"* ]]
  [[ "$review" == *"whichever of \`opus\` and \`fable\` the 429 does not name"* ]]
  [[ "$review" == *"never retry on \`sonnet\`"* ]]
}

@test "negative control: a plan-reviewer copy with effort highfoo fails the anchored effort check" {
  bad="${BATS_TEST_TMPDIR}/plan-reviewer-highfoo.md"
  sed 's/^effort: .*/effort: highfoo/' "${REPO_ROOT}/agents/plan-reviewer.md" > "$bad"
  fm="$(frontmatter "$bad")"
  [[ "$fm" == *"effort: highfoo"* ]]
  ! [[ "$fm" =~ (^|$'\n')effort:\ high($'\n'|$) ]]
}

@test "every analysis, design and QA agent, -r1 copies included, meets the opus-5.5-high floor" {
  checked=0
  for f in "${REPO_ROOT}"/agents/*.md; do
    meets_floor "$f"
    checked=$((checked + 1))
  done
  # 5 bases + 5 -r1 copies + plan-reviewer: an empty glob must not pass
  [ "$checked" -eq 11 ]
}

@test "negative control: an agent copy dropped to effort medium fails the floor check" {
  low="${BATS_TEST_TMPDIR}/task-planner-medium.md"
  sed 's/^effort: .*/effort: medium/' "$AGENT4" > "$low"
  [ -s "$low" ]
  ! meets_floor "$low"
}

@test "negative control: an agent copy moved to a sonnet model fails the floor check" {
  sonnet="${BATS_TEST_TMPDIR}/task-reviewer-sonnet.md"
  sed 's/^model: .*/model: claude-sonnet-5-5/' "$AGENT3" > "$sonnet"
  [ -s "$sonnet" ]
  ! meets_floor "$sonnet"
}

@test "loop-implement step 6.5 documents the model-scoped 429 retry on opus or fable, never sonnet" {
  section="$(step65_section "$SKILL" | tr '[:upper:]' '[:lower:]')"
  [[ "$section" == *"429"* ]]
  [[ "$section" == *"not a verdict"* ]]
  [[ "$section" == *"whichever of \`opus\` and \`fable\` the 429 does not name"* ]]
  [[ "$section" == *"never retry on \`sonnet\`"* ]]
}

@test "all five agent bodies carry the Coordinator note about the 429 override" {
  for f in "$AGENT1" "$AGENT2" "$AGENT3" "$AGENT4" "$AGENT5"; do
    content="$(cat "$f" | tr '[:upper:]' '[:lower:]')"
    [[ "$content" == *"429"* ]]
    [[ "$content" == *"not a verdict"* ]]
    [[ "$content" == *"whichever of \`opus\` and \`fable\` the 429 does not name"* ]]
    [[ "$content" == *"never below opus"* ]]
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

@test "boundary: a plan-reviewer copy with no model or effort pin fails the floor check" {
  unpinned="${BATS_TEST_TMPDIR}/plan-reviewer-unpinned.md"
  grep -vE '^(model|effort):' "${REPO_ROOT}/agents/plan-reviewer.md" > "$unpinned"
  [ -s "$unpinned" ]
  ! meets_floor "$unpinned"
}

@test "negative control: a task-analyst copy without its model pin fails the pin check" {
  unpinned="${BATS_TEST_TMPDIR}/task-analyst-unpinned.md"
  grep -v '^model:' "$AGENT5" > "$unpinned"
  [ -s "$unpinned" ]
  fm="$(frontmatter "$unpinned")"
  [[ "$fm" != *$'\n'"model: claude-fable-5-1"$'\n'* ]]
}
