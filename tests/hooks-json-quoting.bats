#!/usr/bin/env bats
# Regression guard for issue #313: every hooks/hooks.json command must quote
# the ${CLAUDE_PLUGIN_ROOT} expansion, or a plugin root containing a space
# (e.g. ~/Library/Application Support/...) splits into two words and the hook
# never runs. Assertions are simple commands ([ ], grep -q) because a mid-test
# [[ ]] is ignored by macOS bash 3.2 (wiki/testing/quality/tests-that-cannot-fail.md).

setup() {
  HOOKS_JSON="${BATS_TEST_DIRNAME}/../hooks/hooks.json"
  PREFLIGHT="${BATS_TEST_DIRNAME}/../hooks/preflight.sh"
}

# Print every "command" value in the manifest FILE, one per line.
_commands() {
  jq -r '.. | objects | select(has("command")) | .command' "$1"
}

# Print the commands in FILE that expand CLAUDE_PLUGIN_ROOT without a
# preceding double quote; prints nothing (exit 0) when there are none.
_unquoted() {
  _commands "$1" | grep -E '(^|[^"])\$\{?CLAUDE_PLUGIN_ROOT' || true
}

# Copy preflight.sh under a root whose path has a space, replace the literal
# ${CLAUDE_PLUGIN_ROOT} in RAW with that root, and run it the way the harness
# does (a shell), with no inherited CLAUDE_PLUGIN_ROOT to mask a failed
# substitution. Sets $status and $output like bats `run` (not used here, so
# the expected 127 of the negative control raises no BW01 warning).
_run_with_space_root() {
  local raw="$1" root="$BATS_TEST_TMPDIR/root with space" pat='${CLAUDE_PLUGIN_ROOT}' cmd
  mkdir -p "$root/hooks"
  cp "$PREFLIGHT" "$root/hooks/preflight.sh"
  cmd="${raw//"$pat"/"$root"}"
  status=0
  output=$(env -u CLAUDE_PLUGIN_ROOT sh -c "$cmd" 2>&1) || status=$?
}

@test "normal: hooks.json parses and declares exactly 13 hook commands" {
  run jq -e . "$HOOKS_JSON"
  [ "$status" -eq 0 ]
  run _commands "$HOOKS_JSON"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 13 ]
}

@test "normal: every hooks.json command has the quoted shape bash \"\${CLAUDE_PLUGIN_ROOT}/hooks/<name>.sh\"" {
  run _commands "$HOOKS_JSON"
  [ "$status" -eq 0 ]
  bad=$(printf '%s\n' "$output" | grep -vE '^bash "\$\{CLAUDE_PLUGIN_ROOT\}/hooks/[a-z-]+\.sh"$' || true)
  [ -z "$bad" ]
}

@test "normal: no hooks.json command expands CLAUDE_PLUGIN_ROOT unquoted" {
  run _unquoted "$HOOKS_JSON"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "error: the unquoted detector flags a manifest with one unquoted command" {
  jq '.hooks.Stop[0].hooks[0].command = "bash ${CLAUDE_PLUGIN_ROOT}/hooks/probe.sh"' "$HOOKS_JSON" > "$BATS_TEST_TMPDIR/hooks.json"
  run _unquoted "$BATS_TEST_TMPDIR/hooks.json"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qxF 'bash ${CLAUDE_PLUGIN_ROOT}/hooks/probe.sh'
}

@test "boundary: manifests with no CLAUDE_PLUGIN_ROOT mention or no commands are not flagged" {
  printf '%s\n' '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo hi"}]}]}}' > "$BATS_TEST_TMPDIR/plain.json"
  printf '%s\n' '{}' > "$BATS_TEST_TMPDIR/empty.json"
  run _unquoted "$BATS_TEST_TMPDIR/plain.json"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run _commands "$BATS_TEST_TMPDIR/empty.json"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run _unquoted "$BATS_TEST_TMPDIR/empty.json"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "smoke: the manifest's preflight command runs from a plugin root containing a space" {
  raw=$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$HOOKS_JSON")
  printf '%s\n' "$raw" | grep -qF '/hooks/preflight.sh'
  _run_with_space_root "$raw"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qF 'LOOP_JQ='
}

@test "error: the unquoted preflight command fails from a plugin root containing a space" {
  _run_with_space_root 'bash ${CLAUDE_PLUGIN_ROOT}/hooks/preflight.sh'
  [ "$status" -eq 127 ]
  printf '%s\n' "$output" | grep -qF 'No such file or directory'
}
