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
