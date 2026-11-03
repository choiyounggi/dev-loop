#!/usr/bin/env bats
# Tests for hooks/harvest.js (the Stop-hook insight harvester).
#
# The harvester re-parses the whole session transcript on every Stop event, so it
# must dedupe against BOTH the session queue file and the processed store that
# knowledge-flush retires rows into. Without the second source, a flush that
# empties the session queue lets the next Stop re-append the same insight.
#
# Every test runs against a per-test HOME so the real ~/.dev-loop/queue is never
# touched.

setup() {
  HARVEST="${BATS_TEST_DIRNAME}/../hooks/harvest.js"

  command -v node >/dev/null || {
    echo "node is required to run the harvester tests"
    return 1
  }

  # Node's os.homedir() reads $HOME on POSIX, so this redirects the queue path.
  export HOME="${BATS_TEST_TMPDIR}/home"
  # The transcript-dir fallback reads CLAUDE_CONFIG_DIR; clear any value the
  # invoking shell exports so home-rooted cases stay home-rooted (#325).
  unset CLAUDE_CONFIG_DIR
  QDIR="$HOME/.dev-loop/queue"
  QFILE="$QDIR/s1.jsonl"
  PFILE="$QDIR/.processed.jsonl"
  mkdir -p "$QDIR"

  # The payload's cwd. Must not sit under $HOME/.dev-loop/repo, which the
  # harvester skips to avoid harvesting its own flush checkout.
  WORK="${BATS_TEST_TMPDIR}/work"
  mkdir -p "$WORK"

  TRANSCRIPT="${BATS_TEST_TMPDIR}/transcript.jsonl"
}

# Write a transcript holding one well-formed insight block. The \n sequences stay
# literal here and become real newlines when the harvester JSON-parses the line.
# The delimiter run is U+2500, matching BLOCK_RE in harvest.js.
_mk_transcript() {
  local body
  body="★ Insight ─────\ntrigger: a Stop hook re-parses the same transcript every turn\ndirective: seed the dedupe set from the processed store as well as the queue file\nwhy: an emptied queue file makes the parser look new again\nevidence: measured 46 duplicate rows out of 103\ndomain: testing\ntags: hooks, dedupe\n─────"
  printf '{"message":{"role":"assistant","content":"%s"}}\n' "$body" > "$TRANSCRIPT"
}

_mk_transcript_without_insight() {
  printf '{"message":{"role":"assistant","content":"Just a normal reply with no block."}}\n' > "$TRANSCRIPT"
}

_run_harvest() { # [cwd]
  printf '{"cwd":"%s","session_id":"s1","transcript_path":"%s"}' \
    "${1:-$WORK}" "$TRANSCRIPT" | node "$HARVEST"
}

# Non-blank line count of the session queue file; 0 when it does not exist.
# awk is used rather than `grep -c` so an empty file yields "0" on a single line
# with exit status 0 — `grep -c` exits 1 there, which would print 0 twice.
_queue_lines() {
  [ -f "$QFILE" ] || { echo 0; return; }
  awk 'NF { c++ } END { print c + 0 }' "$QFILE"
}

# Retire the queue file's rows the way knowledge-flush does: append to the
# processed store, then truncate the session file.
_flush_queue() {
  cat "$QFILE" >> "$PFILE"
  : > "$QFILE"
}

@test "normal: a new insight block is harvested into the session queue" {
  _mk_transcript
  run _run_harvest
  [ "$status" -eq 0 ]
  [ "$(_queue_lines)" -eq 1 ]

  # The row must carry a usable dedupe key, not just exist.
  hash="$(node -e 'const l=require("fs").readFileSync(process.argv[1],"utf8").trim();process.stdout.write(JSON.parse(l).hash||"")' "$QFILE")"
  [ -n "$hash" ]
  [ "${#hash}" -eq 16 ]
}

@test "regression: a hash already in the processed store is not re-queued" {
  _mk_transcript
  _run_harvest
  [ "$(_queue_lines)" -eq 1 ]

  # A flush retires the row and empties the session file...
  _flush_queue
  [ "$(_queue_lines)" -eq 0 ]

  # ...and the next Stop must not resurrect it from the unchanged transcript.
  run _run_harvest
  [ "$status" -eq 0 ]
  [ "$(_queue_lines)" -eq 0 ]
}

@test "preserved: the same insight is not duplicated within one session" {
  _mk_transcript
  _run_harvest
  _run_harvest
  [ "$(_queue_lines)" -eq 1 ]
}

@test "error: a corrupt line in the processed store is skipped, valid rows still dedupe" {
  _mk_transcript
  _run_harvest
  printf 'not json at all\n' > "$PFILE"
  cat "$QFILE" >> "$PFILE"
  printf '{"no_hash_field":true}\n' >> "$PFILE"
  : > "$QFILE"

  run _run_harvest
  [ "$status" -eq 0 ]
  [ "$(_queue_lines)" -eq 0 ]
}

@test "error: an absent processed store does not stop a new insight being harvested" {
  _mk_transcript
  rm -f "$PFILE"
  run _run_harvest
  [ "$status" -eq 0 ]
  [ "$(_queue_lines)" -eq 1 ]
}

@test "boundary: an empty processed store harvests normally" {
  _mk_transcript
  : > "$PFILE"
  run _run_harvest
  [ "$status" -eq 0 ]
  [ "$(_queue_lines)" -eq 1 ]
}

@test "boundary: a transcript with no insight block queues nothing" {
  _mk_transcript_without_insight
  run _run_harvest
  [ "$status" -eq 0 ]
  [ "$(_queue_lines)" -eq 0 ]
}

@test "preserved: a session inside the flush checkout is not harvested" {
  _mk_transcript
  run _run_harvest "$HOME/.dev-loop/repo"
  [ "$status" -eq 0 ]
  [ "$(_queue_lines)" -eq 0 ]
}

# Write a transcript with N distinct insight blocks (distinct triggers → distinct
# hashes) so cap behavior can be observed.
_mk_transcript_many() { # <count>
  local i body line=""
  for i in $(seq 1 "$1"); do
    body="★ Insight ─────\ntrigger: distinct runaway case number $i of a session\ndirective: enforce a backstop cap on the per-session queue file\nwhy: a runaway session should not queue dozens\nevidence: synthetic case $i\n─────"
    line="$line$body\n\n"
  done
  printf '{"message":{"role":"assistant","content":"%s"}}\n' "$line" > "$TRANSCRIPT"
}

@test "cap: a transcript with 12 insights queues at most 10 rows" {
  _mk_transcript_many 12
  run _run_harvest
  [ "$status" -eq 0 ]
  [ "$(_queue_lines)" -eq 10 ]
}

@test "cap boundary: 9 existing rows + 3 new appends only 1" {
  _mk_transcript_many 9
  _run_harvest
  [ "$(_queue_lines)" -eq 9 ]
  # New transcript with 3 different triggers (10..12) → only one fits the cap.
  local body line="" i
  for i in 10 11 12; do
    body="★ Insight ─────\ntrigger: distinct runaway case number $i of a session\ndirective: enforce a backstop cap on the per-session queue file\nwhy: a runaway session should not queue dozens\nevidence: synthetic case $i\n─────"
    line="$line$body\n\n"
  done
  printf '{"message":{"role":"assistant","content":"%s"}}\n' "$line" > "$TRANSCRIPT"
  run _run_harvest
  [ "$status" -eq 0 ]
  [ "$(_queue_lines)" -eq 10 ]
}

@test "cleanup: an empty session file left by a flush is removed when nothing is harvested" {
  : > "$QFILE"
  _mk_transcript_without_insight
  run _run_harvest
  [ "$status" -eq 0 ]
  [ ! -f "$QFILE" ]
}

@test "cleanup boundary: an empty session file is kept (and filled) when a new insight arrives" {
  : > "$QFILE"
  _mk_transcript
  run _run_harvest
  [ "$status" -eq 0 ]
  [ "$(_queue_lines)" -eq 1 ]
}

# --- cwd fallback without transcript_path (#325) ----------------------------

# The CLI's project-dir name for a path: every character outside A-Za-z0-9
# becomes '-'. ASCII-only oracle, same expansion as tests/send-prompt.bats.
_cli_name() { # path
  printf '%s' "${1//[^a-zA-Z0-9]/-}"
}

# Send a Stop payload with no transcript_path, so resolveTranscript has to
# derive the project dir from the cwd.
_run_harvest_fallback() { # cwd
  printf '{"cwd":"%s","session_id":"s1"}' "$1" | node "$HARVEST"
}

# Write the one-insight transcript into <dir>/s.jsonl.
_mk_project_transcript() { # dir
  mkdir -p "$1"
  _mk_transcript
  cp "$TRANSCRIPT" "$1/s.jsonl"
}

# A cwd whose mapped name is longer than 200 characters.
_long_cwd() {
  printf '%s/%s' "$WORK" "$(head -c 210 /dev/zero | tr '\0' L)"
}

@test "fallback: a cwd with a space resolves to the CLI-mapped dir under ~/.claude/projects (t325-01)" {
  cwd="$WORK/my proj"
  name="$(_cli_name "$cwd")"
  [[ "$name" == *-work-my-proj ]]
  _mk_project_transcript "$HOME/.claude/projects/$name"
  run _run_harvest_fallback "$cwd"
  [ "$status" -eq 0 ]
  [ "$(_queue_lines)" -eq 1 ]
}

@test "fallback: a cwd with an underscore resolves to the CLI-mapped dir (t325-02)" {
  cwd="$WORK/my_proj"
  name="$(_cli_name "$cwd")"
  [[ "$name" == *-work-my-proj ]]
  _mk_project_transcript "$HOME/.claude/projects/$name"
  run _run_harvest_fallback "$cwd"
  [ "$status" -eq 0 ]
  [ "$(_queue_lines)" -eq 1 ]
}

@test "fallback: with CLAUDE_CONFIG_DIR set, the dir under that root is used (t325-03)" {
  export CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/cfg"
  _mk_project_transcript "$CLAUDE_CONFIG_DIR/projects/$(_cli_name "$WORK")"
  [ ! -e "$HOME/.claude" ]
  run _run_harvest_fallback "$WORK"
  [ "$status" -eq 0 ]
  [ "$(_queue_lines)" -eq 1 ]
}

@test "preserved: with CLAUDE_CONFIG_DIR set, a transcript only under ~/.claude/projects is not used (t325-04)" {
  export CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/cfg"
  mkdir -p "$CLAUDE_CONFIG_DIR/projects"
  _mk_project_transcript "$HOME/.claude/projects/$(_cli_name "$WORK")"
  run _run_harvest_fallback "$WORK"
  [ "$status" -eq 0 ]
  [ "$(_queue_lines)" -eq 0 ]
}

@test "boundary: an empty CLAUDE_CONFIG_DIR counts as unset, so ~/.claude/projects is used (t325-05)" {
  export CLAUDE_CONFIG_DIR=""
  _mk_project_transcript "$HOME/.claude/projects/$(_cli_name "$WORK")"
  run _run_harvest_fallback "$WORK"
  [ "$status" -eq 0 ]
  [ "$(_queue_lines)" -eq 1 ]
}

@test "fallback: a mapped name over 200 characters resolves through the one first-200-dash dir (t325-06)" {
  cwd="$(_long_cwd)"
  name="$(_cli_name "$cwd")"
  [ "${#name}" -gt 200 ]
  _mk_project_transcript "$HOME/.claude/projects/${name:0:200}-h4sh"
  run _run_harvest_fallback "$cwd"
  [ "$status" -eq 0 ]
  [ "$(_queue_lines)" -eq 1 ]
}

@test "error: two dirs sharing the 200-character prefix return no transcript and exit 0 (t325-07)" {
  cwd="$(_long_cwd)"
  name="$(_cli_name "$cwd")"
  [ "${#name}" -gt 200 ]
  _mk_project_transcript "$HOME/.claude/projects/${name:0:200}-aaaa"
  _mk_project_transcript "$HOME/.claude/projects/${name:0:200}-bbbb"
  run _run_harvest_fallback "$cwd"
  [ "$status" -eq 0 ]
  [ "$(_queue_lines)" -eq 0 ]
}

@test "boundary: a dir named exactly the first 200 characters, with no dash suffix, is not a match (t325-08)" {
  cwd="$(_long_cwd)"
  name="$(_cli_name "$cwd")"
  [ "${#name}" -gt 200 ]
  _mk_project_transcript "$HOME/.claude/projects/${name:0:200}"
  run _run_harvest_fallback "$cwd"
  [ "$status" -eq 0 ]
  [ "$(_queue_lines)" -eq 0 ]
}

@test "error: a long name with no projects root returns no transcript and exits 0 (t325-09)" {
  cwd="$(_long_cwd)"
  [ ! -e "$HOME/.claude" ]
  run _run_harvest_fallback "$cwd"
  [ "$status" -eq 0 ]
  [ "$(_queue_lines)" -eq 0 ]
}

@test "boundary: a mapped name of exactly 200 characters is used verbatim (t325-10)" {
  base="$(_cli_name "$WORK/")"
  pad=$((200 - ${#base}))
  [ "$pad" -gt 0 ]
  cwd="$WORK/$(head -c "$pad" /dev/zero | tr '\0' L)"
  name="$(_cli_name "$cwd")"
  [ "${#name}" -eq 200 ]
  _mk_project_transcript "$HOME/.claude/projects/$name"
  run _run_harvest_fallback "$cwd"
  [ "$status" -eq 0 ]
  [ "$(_queue_lines)" -eq 1 ]
}

@test "preserved: transcript_path in the payload wins over the derived dir (t325-11)" {
  export CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/cfg"
  d="$CLAUDE_CONFIG_DIR/projects/$(_cli_name "$WORK")"
  mkdir -p "$d"
  printf '{"message":{"role":"assistant","content":"Just a normal reply with no block."}}\n' > "$d/s.jsonl"
  _mk_transcript
  run _run_harvest
  [ "$status" -eq 0 ]
  [ "$(_queue_lines)" -eq 1 ]
}

@test "parity: harvest.js reads the dir transcript-dir.sh derives for the same cwd (t325-12)" {
  command -v jq >/dev/null || { echo "jq is required for the parity test"; return 1; }
  export CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/cfg"
  cwd="$WORK/a b_c@d"
  . "${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/transcript-dir.sh"
  transcript_dir_derive "$cwd"
  [ "$td_root" = "$CLAUDE_CONFIG_DIR/projects" ]
  [ "$td_name" = "$(_cli_name "$cwd")" ]
  _mk_project_transcript "$td_root/$td_name"
  run _run_harvest_fallback "$cwd"
  [ "$status" -eq 0 ]
  [ "$(_queue_lines)" -eq 1 ]
}

@test "boundary: a regular file sharing the 200-character prefix does not count as a second match (t325-13)" {
  cwd="$(_long_cwd)"
  name="$(_cli_name "$cwd")"
  [ "${#name}" -gt 200 ]
  _mk_project_transcript "$HOME/.claude/projects/${name:0:200}-h4sh"
  : > "$HOME/.claude/projects/${name:0:200}-file"
  run _run_harvest_fallback "$cwd"
  [ "$status" -eq 0 ]
  [ "$(_queue_lines)" -eq 1 ]
}
