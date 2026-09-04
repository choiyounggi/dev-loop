#!/usr/bin/env bats
# Tests for resolve-tools.sh — layered tool-profile resolution.

setup() {
  RT="${BATS_TEST_DIRNAME}/../scripts/resolve-tools.sh"
  HOME_CFG="${BATS_TEST_TMPDIR}/home.json"
  PROJ_CFG="${BATS_TEST_TMPDIR}/proj.json"
  # point both layers at the tmpdir; create per-test as needed
  export LOOP_ORCH_CONFIG_HOME="$HOME_CFG"
  export LOOP_ORCH_CONFIG_PROJECT="$PROJ_CFG"
}

@test "no config: every role resolves to default" {
  run bash "$RT" --json
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.intake.kind')"    = "default" ]
  [ "$(printf '%s' "$output" | jq -r '.knowledge.kind')" = "default" ]
  [ "$(printf '%s' "$output" | jq -r '.tacit.kind')"     = "default" ]
  [ "$(printf '%s' "$output" | jq -r '.verify.kind')"    = "default" ]
  [ "$(printf '%s' "$output" | jq -r '.explore.kind')"   = "default" ]
  [ "$(printf '%s' "$output" | jq -r '.design.kind')"    = "default" ]
}

@test "design role is configurable (visual-spec source)" {
  printf '{"design":{"kind":"mcp","ref":"rtb-figma"}}' > "$PROJ_CFG"
  run bash "$RT" --role design
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.ref')" = "rtb-figma" ]
}

@test "design role appears in summary (default when unset)" {
  run bash "$RT" --summary
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "design: default"
}

@test "intake role is configurable (issue-tracker entry)" {
  printf '{"intake":{"kind":"mcp","ref":"atlassian"}}' > "$PROJ_CFG"
  run bash "$RT" --role intake
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.ref')" = "atlassian" ]
}

@test "verify role is configurable like the others" {
  printf '{"verify":{"kind":"cli","ref":"pnpm test"}}' > "$PROJ_CFG"
  run bash "$RT" --role verify
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.ref')" = "pnpm test" ]
}

@test "home config: a configured role is used" {
  printf '{"knowledge":{"kind":"mcp","ref":"wiki-rag"}}' > "$HOME_CFG"
  run bash "$RT" --role knowledge
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.ref')" = "wiki-rag" ]
}

@test "project overrides home per role" {
  printf '{"verify":{"kind":"cli","ref":"home:test"}}'   > "$HOME_CFG"
  printf '{"verify":{"kind":"cli","ref":"proj:test"}}'   > "$PROJ_CFG"
  run bash "$RT" --role verify
  [ "$(printf '%s' "$output" | jq -r '.ref')" = "proj:test" ]
}

@test "merge is field-wise: project keeps home fields it does not set" {
  printf '{"knowledge":{"kind":"mcp","ref":"wiki-rag","how":"wiki_search"}}' > "$HOME_CFG"
  printf '{"knowledge":{"how":"wiki_query_context"}}'                        > "$PROJ_CFG"
  run bash "$RT" --role knowledge
  [ "$(printf '%s' "$output" | jq -r '.ref')" = "wiki-rag" ]            # inherited
  [ "$(printf '%s' "$output" | jq -r '.how')" = "wiki_query_context" ] # overridden
}

@test "invalid config layer fails open to lower layers (no crash)" {
  printf 'not json at all' > "$HOME_CFG"
  # stdout must stay pure JSON; the "invalid config" warning goes to stderr
  # (drop it so jq parses only the resolved object).
  run bash -c "bash '$RT' --role knowledge 2>/dev/null"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.kind')" = "default" ]
}

@test "invalid config: warning goes to stderr, not stdout" {
  printf 'not json at all' > "$HOME_CFG"
  run bash -c "bash '$RT' --role knowledge 2>/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" != *"ignoring invalid config"* ]]
}

@test "unknown arg errors" {
  run bash "$RT" --bogus
  [ "$status" -ne 0 ]
}

@test "summary prints one line per role with assertions" {
  printf '{"tacit":{"kind":"mcp","ref":"rtb-lore"}}' > "$PROJ_CFG"
  run bash "$RT" --summary
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "tacit: mcp rtb-lore"
  echo "$output" | grep -q "knowledge: default"
}

@test "research role appears in summary exactly once (default when unset)" {
  run bash "$RT" --summary
  [ "$status" -eq 0 ]
  count=$(printf '%s\n' "$output" | grep -c "^research:")
  [ "$count" -eq 1 ]
  echo "$output" | grep -q "^research: default (built-in behavior)"
}

@test "research role is configurable and shows as configured, not default" {
  printf '{"research":{"kind":"mcp","ref":"brave-search"}}' > "$PROJ_CFG"
  run bash "$RT" --role research
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.kind')" = "mcp" ]
  [ "$(printf '%s' "$output" | jq -r '.ref')" = "brave-search" ]
  run bash "$RT" --summary
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "^research: mcp brave-search"
}

@test "research role with an empty override object behaves like other roles: stays default" {
  printf '{"research":{}}' > "$PROJ_CFG"
  run bash "$RT" --role research
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.kind')" = "default" ]
}

# --- explore: graphify code graph as the optional orientation layer ----------
# (wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md)

@test "explore role is configurable as the graphify cli (lead-not-evidence orientation layer)" {
  printf '{"explore":{"kind":"cli","ref":"graphify","how":"graphify explain \\"<Symbol>\\" --graph <root>/graphify-out/graph.json | head -40"}}' > "$PROJ_CFG"
  run bash "$RT" --role explore
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.kind')" = "cli" ]
  [ "$(printf '%s' "$output" | jq -r '.ref')" = "graphify" ]
  [[ "$(printf '%s' "$output" | jq -r '.how')" == *'graphify explain'* ]]
}

@test "no config: explore default text points at the graphify option without changing kind" {
  run bash "$RT" --role explore
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.kind')" = "default" ]
  [[ "$(printf '%s' "$output" | jq -r '.when')" == *'graphify'* ]]
}
