#!/usr/bin/env bats
# scripts/gen-agent-tier-variants.sh: each tier-graded agent has a base file
# (R3/R2) and a generated -r1 copy (R1/R0) one effort step lower, never below
# high, because the Agent tool overrides `model` per call but never `effort`.
# These tests prove
# the committed copies are in sync with their bases, that --check catches
# drift, and that a malformed base is refused.

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  GEN="${REPO_ROOT}/scripts/gen-agent-tier-variants.sh"
  WORK="${BATS_TEST_TMPDIR}/agents"
  mkdir -p "$WORK"
  cp "${REPO_ROOT}"/agents/*.md "$WORK/"
}

frontmatter() {
  awk '/^---$/{n++; next} n==1' "$1"
}

@test "committed -r1 copies are in sync with their base files" {
  run bash "$GEN" --check
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "each -r1 copy is the R1/R0 column: renamed, one effort step lower floored at high, same model, same body" {
  for row in \
    "task-analyst|claude-fable-5-1|high" \
    "task-planner|claude-opus-5-5|high" \
    "test-quality-auditor|claude-fable-5-1|high" \
    "task-reviewer|claude-fable-5-1|high" \
    "integration-reviewer|claude-fable-5-1|xhigh"; do
    IFS='|' read -r name model effort <<< "$row"
    copy="${REPO_ROOT}/agents/${name}-r1.md"
    fm="$(frontmatter "$copy")"
    [[ "$fm" == *"name: ${name}-r1"$'\n'* ]]
    [[ "$fm" == *$'\n'"model: ${model}"$'\n'* ]]
    [[ "$fm" == *$'\n'"effort: ${effort}"* ]]
    base_body="$(awk '/^---$/{n++; next} n>=2' "${REPO_ROOT}/agents/${name}.md")"
    copy_body="$(awk '/^---$/{n++; next} n>=2' "$copy" | grep -v '^<!-- GENERATED from ')"
    [[ "$(printf '%s' "$copy_body" | sed '/./,$!d')" == "$(printf '%s' "$base_body" | sed '/./,$!d')" ]]
  done
}

@test "--check fails when a base changes and its -r1 copy is not regenerated" {
  printf '\nA new rule added only to the base.\n' >> "$WORK/task-reviewer.md"
  run bash "$GEN" --check "$WORK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"task-reviewer-r1.md is stale"* ]]
}

@test "regenerating after a base change brings --check back to green" {
  printf '\nA new rule added only to the base.\n' >> "$WORK/task-reviewer.md"
  run bash "$GEN" "$WORK"
  [ "$status" -eq 0 ]
  run bash "$GEN" --check "$WORK"
  [ "$status" -eq 0 ]
  [[ "$(cat "$WORK/task-reviewer-r1.md")" == *"A new rule added only to the base."* ]]
}

@test "--check fails when an -r1 copy is missing" {
  rm "$WORK/integration-reviewer-r1.md"
  run bash "$GEN" --check "$WORK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"integration-reviewer-r1.md is stale"* ]]
}

@test "a missing base file is refused with exit 2" {
  rm "$WORK/task-analyst.md"
  run bash "$GEN" "$WORK"
  [ "$status" -eq 2 ]
  [[ "$output" == *"missing base"* ]]
}

@test "boundary: a base with no effort line in its frontmatter is refused with exit 2" {
  grep -v '^effort:' "${REPO_ROOT}/agents/task-planner.md" > "$WORK/task-planner.md"
  run bash "$GEN" "$WORK"
  [ "$status" -eq 2 ]
  [[ "$output" == *"needs one 'name: task-planner' and one 'effort:' line"* ]]
}
