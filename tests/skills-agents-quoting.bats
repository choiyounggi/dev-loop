#!/usr/bin/env bats
# Regression guard for issue #322: every ${CLAUDE_PLUGIN_ROOT}/<path> in the
# markdown under skills/ and agents/ must be its own double-quoted word.
# Claude Code replaces ${CLAUDE_PLUGIN_ROOT} with the literal plugin root when
# it loads a skill or agent body, so a model copies the path as written, and a
# root containing a space splits a bare path into two words. Sibling of
# tests/hooks-json-quoting.bats (#313). A mention with no path segment after
# the variable is prose and is not matched.

setup() {
  ROOT="${BATS_TEST_DIRNAME}/.."
  RE='(^|[^"])\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9._-]'
  SHAPE='"\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9._/-]*"'
}

# Print file:line:text for each bare ${CLAUDE_PLUGIN_ROOT}/<path> in the *.md
# files under the DIR operands. Returns 0 when one is found, 1 when none, and 2
# when no operand is given, an operand is missing, or grep cannot run. The
# operand check is ours because grep --include drops a missing operand
# silently (BSD grep returns 1 for it).
_bare_paths() {
  local d
  [ "$#" -gt 0 ] || { echo "_bare_paths: no directory given" >&2; return 2; }
  for d in "$@"; do
    [ -d "$d" ] || { echo "_bare_paths: no such directory: $d" >&2; return 2; }
  done
  grep -rnE --include='*.md' -- "$RE" "$@"
}

# Print each line in the *.md files under the DIR operands that opens a quoted
# "${CLAUDE_PLUGIN_ROOT}/ path but does not close the quote right after the
# path word. Returns 0 when one is found, 1 when none.
_misquoted() {
  grep -rnF --include='*.md' -- '"${CLAUDE_PLUGIN_ROOT}/' "$@" | grep -vE -- "$SHAPE"
}

# Replace ${CLAUDE_PLUGIN_ROOT} in RAW with a root whose path has a space and
# holds a stub scripts/resolve-tools.sh, then run it with sh, as a model that
# copied the snippet would. Sets $status and $output by hand instead of `run`:
# the bare control's expected 127 would raise bats warning BW01.
_run_with_space_root() {
  local raw="$1" root="$BATS_TEST_TMPDIR/root with space" pat='${CLAUDE_PLUGIN_ROOT}' cmd
  mkdir -p "$root/scripts"
  printf '%s\n' 'printf "PROBE_OK %s\n" "$*"' > "$root/scripts/resolve-tools.sh"
  cmd="${raw//"$pat"/"$root"}"
  status=0
  output=$(env -u CLAUDE_PLUGIN_ROOT sh -c "$cmd" 2>&1) || status=$?
}

@test "normal: skills and agents markdown has no bare plugin-root path" {
  cd "$ROOT"
  run grep -rlF --include='*.md' -- 'CLAUDE_PLUGIN_ROOT' skills agents
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -ge 1 ]
  run _bare_paths skills agents
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "normal: every quoted plugin-root path in skills and agents closes right after the path word" {
  cd "$ROOT"
  run grep -rlF --include='*.md' -- '"${CLAUDE_PLUGIN_ROOT}/' skills agents
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -ge 1 ]
  run _misquoted skills agents
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "error: a bare plugin-root path in a fixture is reported with its file and line" {
  mkdir -p "$BATS_TEST_TMPDIR/bad"
  printf '%s\n' 'sh ${CLAUDE_PLUGIN_ROOT}/scripts/probe.sh --x' > "$BATS_TEST_TMPDIR/bad/a.md"
  cd "$BATS_TEST_TMPDIR"
  run _bare_paths bad
  [ "$status" -eq 0 ]
  [ "$output" = 'bad/a.md:1:sh ${CLAUDE_PLUGIN_ROOT}/scripts/probe.sh --x' ]
}

@test "error: a missing directory or no directory is an error, not a clean scan" {
  cd "$BATS_TEST_TMPDIR"
  run _bare_paths missing
  [ "$status" -eq 2 ]
  [ "$output" = "_bare_paths: no such directory: missing" ]
  run _bare_paths
  [ "$status" -eq 2 ]
  [ "$output" = "_bare_paths: no directory given" ]
}

@test "error: a quote closed after the flags is reported, a well-formed one is not" {
  mkdir -p "$BATS_TEST_TMPDIR/shape"
  printf '%s\n' 'sh "${CLAUDE_PLUGIN_ROOT}/scripts/probe.sh --x"' 'sh "${CLAUDE_PLUGIN_ROOT}/scripts/ok.sh" --y' > "$BATS_TEST_TMPDIR/shape/c.md"
  cd "$BATS_TEST_TMPDIR"
  run _misquoted shape
  [ "$status" -eq 0 ]
  [ "$output" = 'shape/c.md:1:sh "${CLAUDE_PLUGIN_ROOT}/scripts/probe.sh --x"' ]
}

@test "normal: a quoted plugin-root path in a fixture is not reported" {
  mkdir -p "$BATS_TEST_TMPDIR/good"
  printf '%s\n' 'sh "${CLAUDE_PLUGIN_ROOT}/scripts/probe.sh" --x' > "$BATS_TEST_TMPDIR/good/b.md"
  cd "$BATS_TEST_TMPDIR"
  run _bare_paths good
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "boundary: an empty dir, a file with no mention, and variable-only or root-only mentions are not reported" {
  mkdir -p "$BATS_TEST_TMPDIR/empty" "$BATS_TEST_TMPDIR/plain" "$BATS_TEST_TMPDIR/vonly"
  printf '%s\n' 'no plugin root here' > "$BATS_TEST_TMPDIR/plain/n.md"
  printf '%s\n' 'NOT `${CLAUDE_PLUGIN_ROOT}`.' '**`${CLAUDE_PLUGIN_ROOT}/`**' > "$BATS_TEST_TMPDIR/vonly/v.md"
  cd "$BATS_TEST_TMPDIR"
  run _bare_paths empty
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run _bare_paths plain
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run _bare_paths vonly
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "smoke: the quoted configure snippet runs from a plugin root containing a space" {
  raw=$(grep -F 'resolve-tools.sh" --summary' "$ROOT/skills/configure/SKILL.md" | head -1 | sed 's/^ *//')
  [ "$raw" = 'sh "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-tools.sh" --summary' ]
  _run_with_space_root "$raw"
  [ "$status" -eq 0 ]
  [ "$output" = "PROBE_OK --summary" ]
}

@test "error: the bare form of the same snippet fails from a plugin root containing a space" {
  _run_with_space_root 'sh ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-tools.sh --summary'
  [ "$status" -ne 0 ]
  [[ "$output" != *PROBE_OK* ]]
}
