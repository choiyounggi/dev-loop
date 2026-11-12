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
  # Issue #326: the orchestrate skill's {SKILL} placeholder (the coordinator
  # substitutes the skill dir) follows the same rule, with one measured
  # exception kept in SKILL_KEEP below.
  SKILL_RE='(^|[^"])\{SKILL\}/[A-Za-z0-9._-]'
  SKILL_SHAPE='"\{SKILL\}/[A-Za-z0-9._/-]*"'
  SKILL_RULED_QUOTED='"\{SKILL\}/scripts/(launch-session|send-prompt|watch-status|resolve-escalation)\.sh"'
  # Kept unquoted on purpose (issue #326, user decision 2026-11-03): these
  # four scripts are what skills/orchestrate/scripts/install-permission-rules.sh
  # allow-lists as `Bash(sh <abs>/scripts/<name>.sh *)` (rules r1-r4).
  # Measured with claude -p in default permission mode: `sh <abs>/x.sh arg`
  # matched such a rule, while `sh "<abs>/x.sh" arg` did not and fell to a
  # permission prompt. One entry per kept line, keyed file:exact-line-text
  # (no line number, so an edit elsewhere in the file does not shift it). A
  # new unquoted {SKILL}/ hit, or a kept line whose text changes, fails a test.
  SKILL_KEEP=(
    # SKILL.md tmux watch exit-5 playbook: resolve-escalation.sh is rule r4.
    'skills/orchestrate/SKILL.md:waiting: approve/deny, then `sh {SKILL}/scripts/resolve-escalation.sh <escdir>'
    # SKILL.md Orca watch exit-5 playbook: resolve-escalation.sh is rule r4.
    'skills/orchestrate/SKILL.md:  pending (approve/deny, then **`sh {SKILL}/scripts/resolve-escalation.sh'
    # session-prompt.md tmux delivery block: send-prompt.sh is rule r2 (send).
    'skills/orchestrate/templates/session-prompt.md:sh {SKILL}/scripts/send-prompt.sh send  <session> "<the one-line prompt>"'
    # session-prompt.md tmux delivery block: send-prompt.sh is rule r2 (wait).
    'skills/orchestrate/templates/session-prompt.md:sh {SKILL}/scripts/send-prompt.sh wait  <session> [timeout]'
    # session-prompt.md tmux delivery block: send-prompt.sh is rule r2 (state).
    'skills/orchestrate/templates/session-prompt.md:sh {SKILL}/scripts/send-prompt.sh state <session>'
    # session-prompt.md tmux delivery block: send-prompt.sh is rule r2 (keys).
    'skills/orchestrate/templates/session-prompt.md:sh {SKILL}/scripts/send-prompt.sh keys  <session> <key>...'
  )
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

# Print file:line:text for each bare {SKILL}/<path> in the *.md files under
# the DIR operands. Same exits and operand checks as _bare_paths.
_bare_skill_paths() {
  local d
  [ "$#" -gt 0 ] || { echo "_bare_skill_paths: no directory given" >&2; return 2; }
  for d in "$@"; do
    [ -d "$d" ] || { echo "_bare_skill_paths: no such directory: $d" >&2; return 2; }
  done
  grep -rnE --include='*.md' -- "$SKILL_RE" "$@"
}

# 0 when KEY (file:text) is a SKILL_KEEP entry, 1 otherwise.
_skill_kept() {
  local k
  for k in "${SKILL_KEEP[@]}"; do
    [ "$k" = "$1" ] && return 0
  done
  return 1
}

# Print each bare {SKILL}/<path> hit under the DIR operands that is not a
# SKILL_KEEP entry. Returns 0 when one is printed, 1 when none, and 2 on an
# operand error from _bare_skill_paths.
_unlisted_skill_paths() {
  local hits hit rc=0 found=1
  hits=$(_bare_skill_paths "$@") || rc=$?
  [ "$rc" -le 1 ] || return "$rc"
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    _skill_kept "${hit%%:*}:${hit#*:*:}" && continue
    printf '%s\n' "$hit"
    found=0
  done <<< "$hits"
  return "$found"
}

# Print each SKILL_KEEP entry that does not match exactly one bare hit under
# the DIR operands, with its match count. Returns 0 when one is printed, 1
# when none, and 2 on an operand error from _bare_skill_paths.
_stale_skill_keeps() {
  local hits keys k n rc=0 found=1
  hits=$(_bare_skill_paths "$@") || rc=$?
  [ "$rc" -le 1 ] || return "$rc"
  keys=$(printf '%s\n' "$hits" | sed -E 's/^([^:]*):[0-9]+:/\1:/')
  for k in "${SKILL_KEEP[@]}"; do
    n=$(printf '%s\n' "$keys" | grep -cxF -- "$k" || true)
    [ "$n" -eq 1 ] && continue
    printf '%s (matches: %s)\n' "$k" "$n"
    found=0
  done
  return "$found"
}

# Print each line in the *.md files under the DIR operands that opens a quoted
# "{SKILL}/ path but does not close the quote right after the path word.
# Returns 0 when one is found, 1 when none.
_misquoted_skill_paths() {
  grep -rnF --include='*.md' -- '"{SKILL}/' "$@" | grep -vE -- "$SKILL_SHAPE"
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

@test "normal: skills and agents markdown has no bare skill-placeholder path outside the kept list" {
  cd "$ROOT"
  run grep -rlF --include='*.md' -- '{SKILL}/' skills agents
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -ge 1 ]
  run _unlisted_skill_paths skills agents
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "normal: every kept unquoted skill-placeholder line still matches exactly one real hit" {
  cd "$ROOT"
  [ "${#SKILL_KEEP[@]}" -eq 6 ]
  run _stale_skill_keeps skills agents
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "normal: every quoted skill-placeholder path closes right after the path word" {
  cd "$ROOT"
  run grep -rlF --include='*.md' -- '"{SKILL}/' skills agents
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -ge 1 ]
  run _misquoted_skill_paths skills agents
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "normal: no permission-ruled script is invoked through a quoted skill-placeholder path" {
  cd "$ROOT"
  run grep -rnE --include='*.md' -- "$SKILL_RULED_QUOTED" skills agents
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  mkdir -p "$BATS_TEST_TMPDIR/ruled"
  printf '%s\n' 'sh "{SKILL}/scripts/send-prompt.sh" state lo-1' > "$BATS_TEST_TMPDIR/ruled/r.md"
  cd "$BATS_TEST_TMPDIR"
  run grep -rnE --include='*.md' -- "$SKILL_RULED_QUOTED" ruled
  [ "$status" -eq 0 ]
  [ "$output" = 'ruled/r.md:1:sh "{SKILL}/scripts/send-prompt.sh" state lo-1' ]
}

@test "error: a bare skill-placeholder path in a fixture is reported with its file and line" {
  mkdir -p "$BATS_TEST_TMPDIR/bad"
  printf '%s\n' 'sh {SKILL}/scripts/probe.sh --x' > "$BATS_TEST_TMPDIR/bad/a.md"
  cd "$BATS_TEST_TMPDIR"
  run _unlisted_skill_paths bad
  [ "$status" -eq 0 ]
  [ "$output" = 'bad/a.md:1:sh {SKILL}/scripts/probe.sh --x' ]
}

@test "error: a new unquoted permission-ruled line beside a kept one is reported, the kept one is not" {
  mkdir -p "$BATS_TEST_TMPDIR/skills/orchestrate/templates"
  printf '%s\n' 'sh {SKILL}/scripts/send-prompt.sh state <session>' 'sh {SKILL}/scripts/send-prompt.sh keys lo-1 Escape' > "$BATS_TEST_TMPDIR/skills/orchestrate/templates/session-prompt.md"
  cd "$BATS_TEST_TMPDIR"
  run _unlisted_skill_paths skills
  [ "$status" -eq 0 ]
  [ "$output" = 'skills/orchestrate/templates/session-prompt.md:2:sh {SKILL}/scripts/send-prompt.sh keys lo-1 Escape' ]
}

@test "error: a kept entry with no matching line is reported as stale" {
  mkdir -p "$BATS_TEST_TMPDIR/skills/orchestrate"
  printf '%s\n' 'no placeholder here' > "$BATS_TEST_TMPDIR/skills/orchestrate/SKILL.md"
  cd "$BATS_TEST_TMPDIR"
  run _stale_skill_keeps skills
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 6 ]
  [ "${lines[0]}" = 'skills/orchestrate/SKILL.md:waiting: approve/deny, then `sh {SKILL}/scripts/resolve-escalation.sh <escdir> (matches: 0)' ]
}

@test "error: a skill-placeholder quote closed after the flags is reported, a well-formed one is not" {
  mkdir -p "$BATS_TEST_TMPDIR/shape"
  printf '%s\n' 'sh "{SKILL}/scripts/probe.sh --x"' 'sh "{SKILL}/scripts/ok.sh" --y' > "$BATS_TEST_TMPDIR/shape/c.md"
  cd "$BATS_TEST_TMPDIR"
  run _misquoted_skill_paths shape
  [ "$status" -eq 0 ]
  [ "$output" = 'shape/c.md:1:sh "{SKILL}/scripts/probe.sh --x"' ]
}

@test "error: a missing directory or no directory is an error for the skill-placeholder scan" {
  cd "$BATS_TEST_TMPDIR"
  run _unlisted_skill_paths missing
  [ "$status" -eq 2 ]
  [ "$output" = "_bare_skill_paths: no such directory: missing" ]
  run _unlisted_skill_paths
  [ "$status" -eq 2 ]
  [ "$output" = "_bare_skill_paths: no directory given" ]
  run _stale_skill_keeps missing
  [ "$status" -eq 2 ]
  [ "$output" = "_bare_skill_paths: no such directory: missing" ]
}

@test "boundary: an empty dir, placeholder-only and root-only mentions, and a quoted path are not reported" {
  mkdir -p "$BATS_TEST_TMPDIR/sempty" "$BATS_TEST_TMPDIR/sonly"
  printf '%s\n' '`{SKILL}` orchestrate skill dir abs path' '**`{SKILL}/`**' 'sh "{SKILL}/scripts/probe.sh" --x' > "$BATS_TEST_TMPDIR/sonly/s.md"
  cd "$BATS_TEST_TMPDIR"
  run _unlisted_skill_paths sempty
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run _unlisted_skill_paths sonly
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}
