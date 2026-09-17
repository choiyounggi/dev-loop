#!/usr/bin/env bats
# Tests for skills/graph-setup/SKILL.md — source-text wiring assertions:
# each site the skill's prose must consume verbatim is pinned, with a
# negative control proving the assertion actually depends on the text.

setup() {
  SKILL="${BATS_TEST_DIRNAME}/../skills/graph-setup/SKILL.md"
  content=$(cat "$SKILL")
}

@test "frontmatter: name is graph-setup and description states loading conditions" {
  [[ "$content" == *"name: graph-setup"* ]]
  descline=$(grep '^description:' "$SKILL")
  [[ "$descline" == *"Use when"* ]]
}

@test "site: pipx install graphifyy is the exact install command" {
  [[ "$content" == *"pipx install graphifyy"* ]]
}

@test "site: resolve-tools.sh --role workspace is consumed" {
  [[ "$content" == *"resolve-tools.sh --role workspace"* ]]
}

@test "site: graph-workspace.sh --status is consumed" {
  [[ "$content" == *"graph-workspace.sh --status"* ]]
}

@test "site: graph-hooks.sh install is consumed" {
  [[ "$content" == *"graph-hooks.sh install"* ]]
}

@test "site: graphify hook install is consumed" {
  [[ "$content" == *"graphify hook install"* ]]
}

@test "site: graphify update is consumed" {
  [[ "$content" == *"graphify update"* ]]
}

@test "consent ordering: AskUserQuestion appears before the first pipx install graphifyy" {
  before="${content%%pipx install graphifyy*}"
  [[ "$before" == *"AskUserQuestion"* ]]
}

@test "the update-vs-full-build sentence is present verbatim" {
  [[ "$content" == *"graphify update is AST-only (no LLM) and preserves semantic nodes from an"* ]]
  [[ "$content" == *"earlier full run while replacing only code nodes, so the result is not"* ]]
  [[ "$content" == *"identical to a full /graphify build."* ]]
}

@test ".gitignore is mentioned only alongside never" {
  while IFS= read -r line; do
    [[ "$line" == *.gitignore* ]] || continue
    [[ "$line" == *never* ]] || [[ "$line" == *Never* ]]
  done <<< "$content"
}

@test "the plugin manifest lists no skills key (skills are auto-discovered)" {
  run jq -e 'has("skills") | not' "${BATS_TEST_DIRNAME}/../.claude-plugin/plugin.json"
  [ "$status" -eq 0 ]
}

@test "negative control: deleting the graph-hooks.sh install line fails only that site check" {
  BROKEN="$BATS_TEST_TMPDIR/SKILL-broken.md"
  grep -v 'graph-hooks.sh install' "$SKILL" > "$BROKEN"
  broken_content=$(cat "$BROKEN")
  [[ "$broken_content" != *"graph-hooks.sh install"* ]]
  [[ "$broken_content" == *"graphify hook install"* ]]
}

@test "hooks/graph-nudge.sh is not the installer: no pipx, no AskUserQuestion" {
  hook_content=$(cat "${BATS_TEST_DIRNAME}/../hooks/graph-nudge.sh")
  [[ "$hook_content" != *"pipx"* ]]
  [[ "$hook_content" != *"AskUserQuestion"* ]]
}

# --- wiki actor-boundary rows (task 05) ---------------------------------------

@test "wiki: the code-graph page's When-this-applies and the index row both carry the who-may-build clause" {
  page_content=$(cat "${BATS_TEST_DIRNAME}/../wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md")
  index_content=$(cat "${BATS_TEST_DIRNAME}/../wiki/infrastructure/index.md")
  [[ "$page_content" == *"who may build or refresh the graph"* ]]
  [[ "$index_content" == *"who may build or refresh the graph"* ]]
}

@test "negative control: stripping the clause from a copy of the index row fails the check" {
  BROKEN="$BATS_TEST_TMPDIR/index-broken.md"
  sed 's/; deciding who may build or refresh the graph (an agent versus a user-installed git hook)//' \
    "${BATS_TEST_DIRNAME}/../wiki/infrastructure/index.md" > "$BROKEN"
  broken_content=$(cat "$BROKEN")
  [[ "$broken_content" != *"who may build or refresh the graph"* ]]
  # sanity: the real file still carries it
  index_content=$(cat "${BATS_TEST_DIRNAME}/../wiki/infrastructure/index.md")
  [[ "$index_content" == *"who may build or refresh the graph"* ]]
}
