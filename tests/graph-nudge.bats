#!/usr/bin/env bats
# Tests for hooks/graph-nudge.sh — SessionStart advisory nudge for the
# configured code-graph workspace. Never runs graphify or pipx; only reports.

setup() {
  HOOK="${BATS_TEST_DIRNAME}/../hooks/graph-nudge.sh"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export GIT_CONFIG_GLOBAL=/dev/null
  export GRAPHIFY_BIN=true

  TOOLS_JSON="$BATS_TEST_TMPDIR/tools.json"
  export DEV_LOOP_CONFIG_HOME="$TOOLS_JSON"
  export DEV_LOOP_CONFIG_PROJECT=/nonexistent
  export LOOP_ORCH_CONFIG_HOME=/nonexistent
  export LOOP_ORCH_CONFIG_PROJECT=/nonexistent

  SHIM="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$SHIM"
  SHIM_LOG="$BATS_TEST_TMPDIR/shim.log"
  cat > "$SHIM/graphify" <<EOF
#!/bin/sh
echo "\$0 \$*" >> "$SHIM_LOG"
exit 0
EOF
  cp "$SHIM/graphify" "$SHIM/pipx"
  chmod +x "$SHIM/graphify" "$SHIM/pipx"
  export PATH="$SHIM:$PATH"

  WS="$BATS_TEST_TMPDIR/ws"
}

mkrepo() {
  dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" -c user.name=t -c user.email=t@t.example commit -q --allow-empty -m init
}

assert_no_shim_calls() {
  [ ! -s "$SHIM_LOG" ]
}

@test "normal: absent-graph repo in the configured workspace triggers a nudge and sets the marker" {
  mkrepo "$WS/a"
  printf '{"workspace":{"roots":["%s"],"depth":2}}' "$WS" > "$TOOLS_JSON"

  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.hookEventName')" = "SessionStart" ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  [[ "$ctx" == *"ws/a"* ]] || [[ "$ctx" == *"$WS/a"* ]]
  [[ "$ctx" == *"graph-setup"* ]]
  [ -f "$HOME/.dev-loop/.graph-nudged" ]
  assert_no_shim_calls
}

@test "error: no tools.json configured -> silent, no marker" {
  mkrepo "$WS/a"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f "$HOME/.dev-loop/.graph-nudged" ]
  assert_no_shim_calls
}

@test "boundary: a fresh weekly marker suppresses the nudge" {
  mkrepo "$WS/a"
  printf '{"workspace":{"roots":["%s"],"depth":2}}' "$WS" > "$TOOLS_JSON"
  mkdir -p "$HOME/.dev-loop"
  touch "$HOME/.dev-loop/.graph-nudged"

  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  assert_no_shim_calls
}

@test "boundary: DEV_LOOP_GRAPH_NUDGE=0 silences the hook and touches no marker" {
  mkrepo "$WS/a"
  printf '{"workspace":{"roots":["%s"],"depth":2}}' "$WS" > "$TOOLS_JSON"
  export DEV_LOOP_GRAPH_NUDGE=0

  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f "$HOME/.dev-loop/.graph-nudged" ]
  assert_no_shim_calls
}

@test "boundary: DEV_LOOP_GRAPH_NUDGE=off also silences the hook" {
  mkrepo "$WS/a"
  printf '{"workspace":{"roots":["%s"],"depth":2}}' "$WS" > "$TOOLS_JSON"
  export DEV_LOOP_GRAPH_NUDGE=off

  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  assert_no_shim_calls
}

@test "boundary: a fully healthy workspace (fresh graph, hooks ok) stays silent and sets no marker" {
  mkrepo "$WS/a"
  mkdir -p "$WS/a/graphify-out"
  printf '{"nodes":[]}' > "$WS/a/graphify-out/graph.json"
  printf '{"workspace":{"roots":["%s"],"depth":2}}' "$WS" > "$TOOLS_JSON"

  hooks_dir="$WS/a/$(cd "$WS/a" && git rev-parse --git-path hooks)"
  printf '#!/bin/sh\n# graphify-hook-start\nexit 0\n' > "$hooks_dir/post-commit"
  chmod +x "$hooks_dir/post-commit"
  printf '#!/bin/sh\n# graphify-checkout-hook-start\nexit 0\n' > "$hooks_dir/post-checkout"
  chmod +x "$hooks_dir/post-checkout"
  run bash "${BATS_TEST_DIRNAME}/../scripts/graph-hooks.sh" install "$WS/a"
  [ "$status" -eq 0 ]

  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f "$HOME/.dev-loop/.graph-nudged" ]
  assert_no_shim_calls
}

@test "normal: a fresh graph with hooks: none still triggers a nudge (independent of the absent branch)" {
  mkrepo "$WS/a"
  mkdir -p "$WS/a/graphify-out"
  printf '{"nodes":[]}' > "$WS/a/graphify-out/graph.json"
  printf '{"workspace":{"roots":["%s"],"depth":2}}' "$WS" > "$TOOLS_JSON"

  # sanity: the freshness is actually "fresh", not "absent" — a mutation to the
  # hits grep that drops the hooks:(none|partial) alternative must survive on
  # this line's \tfresh\thooks: none shape, or this test is worthless.
  run bash "${BATS_TEST_DIRNAME}/../scripts/graph-freshness.sh" "$WS/a"
  [ "$status" -eq 0 ]
  [ "$output" = "fresh" ]
  run bash "${BATS_TEST_DIRNAME}/../scripts/graph-hooks.sh" status "$WS/a"
  [ "$output" = "none" ]

  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  [[ "$ctx" == *"hooks: none"* ]]
  [ -f "$HOME/.dev-loop/.graph-nudged" ]
  assert_no_shim_calls
}

@test "normal: a fresh graph with hooks: partial still triggers a nudge (independent of the absent branch)" {
  mkrepo "$WS/a"
  mkdir -p "$WS/a/graphify-out"
  printf '{"nodes":[]}' > "$WS/a/graphify-out/graph.json"
  printf '{"workspace":{"roots":["%s"],"depth":2}}' "$WS" > "$TOOLS_JSON"

  # only the dev-loop post-merge block is installed; graphify's post-commit/
  # post-checkout markers are absent, so graph-hooks.sh status reports partial.
  run bash "${BATS_TEST_DIRNAME}/../scripts/graph-hooks.sh" install "$WS/a"
  [ "$status" -eq 0 ]
  run bash "${BATS_TEST_DIRNAME}/../scripts/graph-hooks.sh" status "$WS/a"
  [ "$output" = "partial" ]

  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  [[ "$ctx" == *"hooks: partial"* ]]
  [ -f "$HOME/.dev-loop/.graph-nudged" ]
  assert_no_shim_calls
}

@test "normal: an absent graph with hooks: ok still triggers a nudge (independent of the hooks branch)" {
  mkrepo "$WS/a"
  printf '{"workspace":{"roots":["%s"],"depth":2}}' "$WS" > "$TOOLS_JSON"

  # hooks fully installed (ok), but no graphify-out/graph.json — the graph
  # itself is absent. A mutation dropping the \t(absent|cannot-evaluate)
  # alternative from the hits grep must survive on this line's shape, or this
  # test is worthless.
  hooks_dir="$WS/a/$(cd "$WS/a" && git rev-parse --git-path hooks)"
  printf '#!/bin/sh\n# graphify-hook-start\nexit 0\n' > "$hooks_dir/post-commit"
  chmod +x "$hooks_dir/post-commit"
  printf '#!/bin/sh\n# graphify-checkout-hook-start\nexit 0\n' > "$hooks_dir/post-checkout"
  chmod +x "$hooks_dir/post-checkout"
  run bash "${BATS_TEST_DIRNAME}/../scripts/graph-hooks.sh" install "$WS/a"
  [ "$status" -eq 0 ]
  run bash "${BATS_TEST_DIRNAME}/../scripts/graph-hooks.sh" status "$WS/a"
  [ "$output" = "ok" ]
  run bash "${BATS_TEST_DIRNAME}/../scripts/graph-freshness.sh" "$WS/a"
  [ "$output" = "absent" ]

  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  [[ "$ctx" == *"absent"* ]]
  [ -f "$HOME/.dev-loop/.graph-nudged" ]
  assert_no_shim_calls
}

@test "boundary: empty roots array -> silent" {
  printf '{"workspace":{"roots":[]}}' > "$TOOLS_JSON"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  assert_no_shim_calls
}

@test "error: a missing workspace root reports cannot-evaluate and sets the marker" {
  printf '{"workspace":{"roots":["%s/nonexistent"],"depth":2}}' "$WS" > "$TOOLS_JSON"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  ctx=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
  [[ "$ctx" == *"cannot-evaluate"* ]]
  assert_no_shim_calls
}

@test "negative control: without the hits grep, the hook never nudges even on a triggering workspace" {
  mkrepo "$WS/a"
  printf '{"workspace":{"roots":["%s"],"depth":2}}' "$WS" > "$TOOLS_JSON"

  BROKEN="$BATS_TEST_TMPDIR/graph-nudge-broken.sh"
  sed 's/^hits=\$(grep.*/hits=/' "$HOOK" > "$BROKEN"
  chmod +x "$BROKEN"

  run bash "$BROKEN"
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  # sanity: the real hook DOES nudge on the same input, proving the grep matters
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}
