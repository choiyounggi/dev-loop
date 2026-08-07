#!/usr/bin/env bats
# Tests for status-update.sh and watch-status.sh

setup() {
  SU="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/status-update.sh"
  WS="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/watch-status.sh"
  export STATUS_DIR="${BATS_TEST_TMPDIR}/status"
}

@test "status-update: writes valid JSON with task/phase/extra" {
  run bash "$SU" task-1 plan_ready worktree=/some/wt
  [ "$status" -eq 0 ]
  [ "$(jq -r '.task'     "$STATUS_DIR/task-1.json")" = "task-1" ]
  [ "$(jq -r '.phase'    "$STATUS_DIR/task-1.json")" = "plan_ready" ]
  [ "$(jq -r '.worktree' "$STATUS_DIR/task-1.json")" = "/some/wt" ]
}

@test "status-update: missing phase arg errors" {
  run bash "$SU" task-1
  [ "$status" -ne 0 ]
}

@test "watch-status: exit 0 when all sessions reach target" {
  mkdir -p "$STATUS_DIR"
  printf '{"task":"a","phase":"done"}' > "$STATUS_DIR/a.json"
  printf '{"task":"b","phase":"done"}' > "$STATUS_DIR/b.json"
  run bash "$WS" "$STATUS_DIR" impl_done 2 5 1
  [ "$status" -eq 0 ]
}

@test "watch-status: exit 3 on a failed session" {
  mkdir -p "$STATUS_DIR"
  printf '{"task":"a","phase":"failed"}' > "$STATUS_DIR/a.json"
  run bash "$WS" "$STATUS_DIR" impl_done 1 5 1
  [ "$status" -eq 3 ]
}

@test "watch-status: exit 4 on unknown target phase (no false 'all done')" {
  mkdir -p "$STATUS_DIR"
  printf '{"task":"a","phase":"done"}' > "$STATUS_DIR/a.json"
  run bash "$WS" "$STATUS_DIR" bogusphase 1 2 1
  [ "$status" -eq 4 ]
}

@test "watch-status: exit 4 when status dir is missing" {
  run bash "$WS" "${BATS_TEST_TMPDIR}/does-not-exist" done 1 2 1
  [ "$status" -eq 4 ]
}

@test "status-update: ignores malformed extra and records worktree" {
  run bash "$SU" task-x implementing notakeyvalue good=1
  [ "$status" -eq 0 ]
  [ "$(jq -r '.good' "$STATUS_DIR/task-x.json")" = "1" ]
  [ "$(jq -r 'has("notakeyvalue")' "$STATUS_DIR/task-x.json")" = "false" ]
  [ "$(jq -r '.worktree | type' "$STATUS_DIR/task-x.json")" = "string" ]
}

@test "watch-status --tasks: only the named tasks are counted" {
  mkdir -p "$STATUS_DIR"
  printf '{"task":"old","phase":"approved"}' > "$STATUS_DIR/old.json"
  printf '{"task":"a","phase":"implementing"}' > "$STATUS_DIR/a.json"
  # `old` already passed the target, but it is not being tracked: without
  # scoping, expected=1 would be satisfied instantly and the wait would spin.
  run bash "$WS" --tasks a "$STATUS_DIR" impl_done 1 2 1
  [ "$status" -eq 2 ]
}

@test "watch-status --tasks: returns as soon as ANY tracked task reaches target" {
  mkdir -p "$STATUS_DIR"
  printf '{"task":"a","phase":"impl_done"}'    > "$STATUS_DIR/a.json"
  printf '{"task":"b","phase":"implementing"}' > "$STATUS_DIR/b.json"
  run bash "$WS" --tasks a,b "$STATUS_DIR" impl_done 1 5 1
  [ "$status" -eq 0 ]
}

@test "watch-status --tasks: an untracked failed task does not abort the wait" {
  mkdir -p "$STATUS_DIR"
  printf '{"task":"old","phase":"failed"}'     > "$STATUS_DIR/old.json"
  printf '{"task":"a","phase":"implementing"}' > "$STATUS_DIR/a.json"
  run bash "$WS" --tasks a "$STATUS_DIR" impl_done 1 2 1
  [ "$status" -eq 2 ]
}

@test "watch-status --tasks: an explicit timeout argument still outranks the env" {
  # --tasks is consumed before the positional count is taken; if argc were
  # captured before that, the 4th positional would stop being recognised and
  # LO_PHASE_TIMEOUTS would silently win.
  mkdir -p "$STATUS_DIR"
  printf '{"task":"a","phase":"implementing"}' > "$STATUS_DIR/a.json"
  run env LO_PHASE_TIMEOUTS="impl_done=999" bash "$WS" --tasks a "$STATUS_DIR" impl_done 1 2 1
  [[ "$output" == *"budget=2s"* ]]
  [[ "$output" == *"source=arg"* ]]
}

@test "watch-status: without --tasks every status file is still counted (no regression)" {
  mkdir -p "$STATUS_DIR"
  printf '{"task":"a","phase":"done"}' > "$STATUS_DIR/a.json"
  printf '{"task":"b","phase":"done"}' > "$STATUS_DIR/b.json"
  run bash "$WS" "$STATUS_DIR" impl_done 2 5 1
  [ "$status" -eq 0 ]
}

@test "SKILL.md Phase 2: graph.json artifact and the slot proposal are documented" {
  SKILL="${BATS_TEST_DIRNAME}/../skills/orchestrate/SKILL.md"
  grep -qF '.orchestration/graph.json' "$SKILL"
  grep -qF 'LO_MAX_SESSIONS' "$SKILL"
  # The cap must never be a bare number again: the report has to name what it
  # protects, or "dynamic" degrades back into a hardcoded 4.
  grep -qF 'coordinator attention' "$SKILL"
  ! grep -qF 'concurrent-session cap** (default 4)' "$SKILL"
}

@test "SKILL.md: the dispatch loop structure pins step order and error handling" {
  SKILL="${BATS_TEST_DIRNAME}/../skills/orchestrate/SKILL.md"
  # Step 1 must run ready-set.sh first to decide what is dispatchable.
  grep -qF '1. `scripts/ready-set.sh' "$SKILL"
  # Step 1 exit codes 3 and 4 must explicitly return to step 1, not just report
  # errors. Look for phrases showing re-entry after human intervention or fix.
  grep -q 'return to' "$SKILL" && grep -q 'step 1' "$SKILL"
  grep -q 're-run step' "$SKILL"
  # Step 3 must deliver the implement prompt (was missing in v1); check that
  # both tmux and Orca paths are mentioned.
  grep -qF 'deliver §2 (implement)' "$SKILL"
  grep -qF 'send-prompt.sh send' "$SKILL"
  # Step 4 must wait, scoped to running ids via --tasks to avoid spin.
  grep -qF 'watch-status.sh --tasks' "$SKILL"
  # Step 5 must close the loop by returning to step 1 on approval.
  grep -q 'approval' "$SKILL" && grep -q 'return to' "$SKILL"
  # Exit code 3 must be DEADLOCK and documented as "do not wait".
  grep -qF 'DEADLOCK' "$SKILL"
  # Waves must no longer be described as an execution barrier.
  ! grep -qF 'A later Wave launches only after' "$SKILL"
}

# Shipped skill content is English-only, and this is how we check it — NOT with
# a `[가-힣]` character range, which is not portable and produced a green macOS
# run beside a red Linux one. Measured 2026-08-07 on GNU grep 3.12: in the C
# locale that range is read as a range of BYTES, so it matches the continuation
# bytes of ordinary UTF-8 punctuation — every em-dash in the file counts (136
# lines in SKILL.md), and under C.UTF-8 grep refuses it outright with "Invalid
# collation character". BSD grep matches nothing at all, which is why the broken
# assertion still passed locally.
#
# Count UTF-8 lead bytes EA-ED instead. The Hangul syllable block U+AC00-U+D7A3
# encodes with exactly those lead bytes, and nothing in Latin text or its
# punctuation does. Verified byte-identical on macOS and Ubuntu: 0 for the two
# English files, 2782 for README.ko.md.
hangul_bytes() { LC_ALL=C od -An -tx1 "$1" | tr ' ' '\n' | grep -c '^e[a-d]$'; }

@test "negative control: the Hangul check actually detects Hangul" {
  # The assertion this guards is `== 0`, which any detector that finds nothing
  # satisfies. That is precisely how the previous version shipped green on macOS
  # and red on Linux, so pin the other direction too: a file that IS Korean must
  # come back non-zero, on whatever platform is running.
  KO="${BATS_TEST_DIRNAME}/../README.ko.md"
  [ "$(hangul_bytes "$KO")" -gt 0 ]
}

@test "brief template: a split proposal must carry its file scope" {
  BRIEF="${BATS_TEST_DIRNAME}/../skills/orchestrate/templates/brief.md"
  grep -qF 'split proposal' "$BRIEF"
  # Without the file list the coordinator cannot run the overlap test, so the
  # requirement has to be stated where the worker reads it, not only in SKILL.md.
  grep -qF 'files it would touch' "$BRIEF"
  grep -qF 'split_of' "$BRIEF"
  # The template ships to users; it stays English-only like SKILL.md.
  [ "$(hangul_bytes "$BRIEF")" -eq 0 ]
}

@test "SKILL.md: the split decision procedure is documented and always replies" {
  SKILL="${BATS_TEST_DIRNAME}/../skills/orchestrate/SKILL.md"
  grep -qF 'scripts/graph-add.sh' "$SKILL"
  # The overlap test is the decision; both branches must be spelled out or the
  # coordinator has to invent one.
  grep -qF 'overlap' "$SKILL"
  # Match "same worker" with optional markdown bold formatting.
  grep -qE '\*\*same\s+worker\*\*|same\s+worker' "$SKILL"
  # A rejection that is never sent reproduces the v1.4.1 ask-timeout bug: the
  # worker decides for itself.
  grep -qF 'reply either way' "$SKILL"
  # Exit 4 handling must be documented with explicit coordinator actions.
  grep -qE 'On \*\*4\*\*|exit 4' "$SKILL"
  [ "$(hangul_bytes "$SKILL")" -eq 0 ]
}
