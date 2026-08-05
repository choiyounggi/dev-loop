#!/usr/bin/env bats
# Tests for send-prompt.sh — verified coordinator->worker prompt delivery.
#
# The script is POSIX sh, so every invocation here uses `sh`, never `bash`:
# `bash script.sh` overrides the shebang and would let a bashism pass CI and
# then fail under dash in production.
#
# Every test creates its own tmux session and kills it in teardown (which bats
# runs on failure too). No test touches a session it did not create.

# `run --separate-stderr` keeps the advisory stderr out of $output so the
# one-token stdout contract can be asserted exactly.
bats_require_minimum_version 1.5.0

setup() {
  SP="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/send-prompt.sh"
  TPL="${BATS_TEST_DIRNAME}/../skills/orchestrate/templates/session-prompt.md"
  S="t3s-$$-${BATS_TEST_NUMBER}"
}

teardown() {
  tmux kill-session -t "$S" 2>/dev/null || true
}

# Start a throwaway session running a plain shell. A plain shell is enough to
# exercise the send/confirm mechanism; no Claude CLI is needed.
#
# The shell is pinned to /bin/sh rather than the login shell: macOS defaults to
# zsh, which does NOT treat a leading '#' as a comment interactively
# (INTERACTIVE_COMMENTS is off), while Ubuntu CI defaults to bash, which does.
# Pinning removes that divergence so the same assertions hold on both runners.
mk_session() {
  tmux new-session -d -s "$S" -x 80 -y 15 /bin/sh
  sleep 1
}

# Make the pane deliberately busy for <n> seconds, printing a marker that stands
# in for the worker CLI's queued indicator. The trailing `clear` repaints the
# pane, which is how a TUI drops its indicator once the queue drains.
mk_busy() {
  tmux send-keys -t "$S" -l -- "printf 'BUSYMARK_T3\\n'; sleep $1; clear"
  tmux send-keys -t "$S" Enter
  sleep 1
}

# ---------------------------------------------------------------- state

@test "state: an idle live session is ready" {
  mk_session
  run sh "$SP" state "$S"
  [ "$status" -eq 0 ]
  [ "$output" = "ready" ]
}

@test "state: a session that does not exist is gone" {
  run sh "$SP" state "$S"
  [ "$status" -eq 3 ]
  [ "$output" = "gone" ]
}

@test "state: a busy pane reports busy" {
  mk_session
  mk_busy 6
  run --separate-stderr env LO_QUEUED_PATTERN=BUSYMARK_T3 sh "$SP" state "$S"
  [ "$status" -eq 4 ]
  [ "$output" = "busy" ]
}

@test "state: negative control — the same query on an idle pane is ready, not busy" {
  # Proves the busy test above can fail: identical invocation, idle pane.
  mk_session
  run --separate-stderr env LO_QUEUED_PATTERN=BUSYMARK_T3 sh "$SP" state "$S"
  [ "$status" -eq 0 ]
  [ "$output" = "ready" ]
}

@test "state: LO_BUSY_PATTERN alone also reports busy (mid-turn, nothing queued)" {
  # The two markers answer different questions: LO_QUEUED_PATTERN means "a prompt
  # is waiting", LO_BUSY_PATTERN means "the worker is mid-turn". state reports
  # busy on either, so both arms need their own case.
  mk_session
  mk_busy 6
  run --separate-stderr env LO_QUEUED_PATTERN=NOSUCHMARKER LO_BUSY_PATTERN=BUSYMARK_T3 \
    sh "$SP" state "$S"
  [ "$status" -eq 4 ]
  [ "$output" = "busy" ]
}

@test "boundary: a marker pattern starting with a dash is matched, not parsed as a grep flag" {
  # LO_QUEUED_PATTERN is operator-supplied, so it can legitimately begin with
  # '-'. Without `grep -- "$pat"` this dies "unrecognized option" and every
  # busy worker silently reads as ready.
  mk_session
  tmux send-keys -t "$S" -l -- "printf -- '-dash-marker\\n'; sleep 6"
  tmux send-keys -t "$S" Enter
  sleep 1
  run --separate-stderr env LO_QUEUED_PATTERN=-dash-marker sh "$SP" state "$S"
  [ "$status" -eq 4 ]
  [ "$output" = "busy" ]
}

@test "state: stdout carries exactly one token (coordinator branches on it)" {
  mk_session
  run --separate-stderr sh "$SP" state "$S"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | wc -l | tr -d ' ')" = "0" ]
  [ "$(printf '%s' "$output" | wc -w | tr -d ' ')" = "1" ]
}

@test "state: advisory pane context goes to stderr, never into the stdout token" {
  # The coordinator branches on stdout+exit code; stderr is for humans. If the
  # advisory leaked into stdout, a string compare against the token would break.
  mk_session
  mk_busy 6
  run --separate-stderr env LO_QUEUED_PATTERN=BUSYMARK_T3 sh "$SP" state "$S"
  [ "$status" -eq 4 ]
  [ "$output" = "busy" ]
  case "$stderr" in *BUSYMARK_T3*) : ;; *) return 1 ;; esac
}

# ---------------------------------------------------------------- usage

@test "usage: an unknown subcommand exits 1" {
  run sh "$SP" frobnicate "$S"
  [ "$status" -eq 1 ]
}

@test "usage: no arguments at all exits 1" {
  run sh "$SP"
  [ "$status" -eq 1 ]
}

@test "usage: state without a session name exits 1" {
  run sh "$SP" state
  [ "$status" -eq 1 ]
}

# ------------------------------------------------- injection guard (session)

@test "injection: a session name with shell metacharacters is rejected" {
  run sh "$SP" state '; rm -rf ~'
  [ "$status" -eq 2 ]
  [ "$output" != "ready" ]
}

@test "injection: a session name with command substitution is rejected" {
  run sh "$SP" state '$(touch /tmp/t3-pwned)'
  [ "$status" -eq 2 ]
}

@test "injection: a session name starting with a dash cannot become a tmux flag" {
  # tmux parses a leading-dash argument as its own flag, so the name is rejected
  # before it ever reaches the command line.
  run sh "$SP" state '-X'
  [ "$status" -eq 2 ]
}

@test "boundary: an empty session name is rejected" {
  run sh "$SP" state ''
  [ "$status" -eq 2 ]
}

@test "boundary: a maximal valid session name is accepted (not rejected as invalid)" {
  # Every character class the allowlist permits, in one name.
  S="loT3-worker_9"
  mk_session
  run sh "$SP" state "$S"
  [ "$status" -eq 0 ]
  [ "$output" = "ready" ]
}

# ---------------------------------------------------------------- send

@test "send: an idle session accepts the prompt and actually runs it" {
  mk_session
  run --separate-stderr sh "$SP" send "$S" 'echo T3_HELLO'
  [ "$status" -eq 0 ]
  [ "$output" = "delivered" ]
  sleep 1
  # "delivered" must mean the pane really acted, not just that tmux returned 0.
  tmux capture-pane -t "=$S:" -p | grep -q '^T3_HELLO$'
}

@test "send: a prompt sent to a busy pane is reported queued, not delivered" {
  # The bug this script exists to remove: send-keys returns 0 while the worker
  # has only QUEUED the prompt. Measured in the field as a 55s invisible delay.
  mk_session
  mk_busy 8
  run --separate-stderr env LO_QUEUED_PATTERN=BUSYMARK_T3 sh "$SP" send "$S" 'echo T3_SECOND'
  [ "$status" -eq 4 ]
  [ "$output" = "queued" ]
}

@test "send: negative control — the identical send to an idle pane is delivered" {
  # Same command, same marker, only the pane's busyness differs. Without this,
  # the queued test could pass for the wrong reason.
  mk_session
  run --separate-stderr env LO_QUEUED_PATTERN=BUSYMARK_T3 sh "$SP" send "$S" 'echo T3_SECOND'
  [ "$status" -eq 0 ]
  [ "$output" = "delivered" ]
}

@test "send: a vanished session is reported gone, not delivered" {
  run --separate-stderr sh "$SP" send "$S" 'echo T3_NOPE'
  [ "$status" -eq 3 ]
  [ "$output" = "gone" ]
}

@test "send: a pane that shows no reaction is unconfirmed, never a false delivered" {
  # Terminal echo off while the pane is busy: the keys go nowhere observable.
  # "delivered" must be a positive finding, not the default when nothing is known.
  mk_session
  tmux send-keys -t "$S" -l -- "stty -echo; sleep 8; stty echo"
  tmux send-keys -t "$S" Enter
  sleep 1
  run --separate-stderr sh "$SP" send "$S" 'echo T3_INVISIBLE'
  [ "$status" -eq 7 ]
  [ "$output" = "unconfirmed" ]
}

@test "send: usage error when the prompt argument is missing" {
  run sh "$SP" send "$S"
  [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------- wait

@test "wait: returns picked-up once the worker drains its queue" {
  mk_session
  mk_busy 3
  run --separate-stderr env LO_QUEUED_PATTERN=BUSYMARK_T3 sh "$SP" wait "$S" 15
  [ "$status" -eq 0 ]
  [ "$output" = "picked-up" ]
}

@test "wait: a deadline that passes with the prompt still queued exits 5" {
  # The coordinator must be able to tell "still working" from "never received
  # it". Same setup as the picked-up case; only the deadline differs.
  mk_session
  mk_busy 30
  run --separate-stderr env LO_QUEUED_PATTERN=BUSYMARK_T3 sh "$SP" wait "$S" 4
  [ "$status" -eq 5 ]
  [ "$output" = "timeout" ]
}

@test "wait: a session that disappears is reported gone, not timeout" {
  run --separate-stderr sh "$SP" wait "$S" 4
  [ "$status" -eq 3 ]
  [ "$output" = "gone" ]
}

@test "wait: an idle session returns immediately" {
  mk_session
  run --separate-stderr env LO_QUEUED_PATTERN=BUSYMARK_T3 sh "$SP" wait "$S" 10
  [ "$status" -eq 0 ]
  [ "$output" = "picked-up" ]
}

@test "boundary: a deadline shorter than one poll interval still polls once" {
  # iters = timeout / interval floors to 0 here; it must floor UP to 1 so an
  # idle worker is never reported as a false timeout.
  mk_session
  run --separate-stderr env LO_PICKUP_INTERVAL=5 LO_QUEUED_PATTERN=BUSYMARK_T3 \
    sh "$SP" wait "$S" 1
  [ "$status" -eq 0 ]
  [ "$output" = "picked-up" ]
}

@test "boundary: a zero deadline is a usage error, not an instant timeout" {
  mk_session
  run sh "$SP" wait "$S" 0
  [ "$status" -eq 1 ]
}

@test "error: a non-numeric deadline is a usage error" {
  mk_session
  run sh "$SP" wait "$S" abc
  [ "$status" -eq 1 ]
}

@test "error: a negative deadline is a usage error" {
  mk_session
  run sh "$SP" wait "$S" -5
  [ "$status" -eq 1 ]
}

@test "usage: wait without a session name exits 1" {
  run sh "$SP" wait
  [ "$status" -eq 1 ]
}

# --------------------------------------------------- injection guard (prompt)

@test "injection: a prompt starting with a dash is sent literally, not parsed as a tmux flag" {
  # Without a '--' separator tmux rejects this with "unknown flag -n" and the
  # prompt is silently never delivered.
  mk_session
  run --separate-stderr sh "$SP" send "$S" '-n not-a-flag'
  [ "$status" -eq 0 ]
  [ "$output" = "delivered" ]
  tmux capture-pane -t "=$S:" -p | grep -q -- '-n not-a-flag'
}

@test "injection: send-prompt.sh never evaluates the prompt it carries" {
  # The payload is a shell COMMENT, so the pane's own shell will not run it.
  # That isolates the actor under test: if the marker file appears, it can only
  # be because send-prompt.sh expanded the string itself.
  mk_session
  pwned="${BATS_TEST_TMPDIR}/t3-pwned"
  run --separate-stderr sh "$SP" send "$S" "# T3_SAFE \$(touch $pwned) \`touch $pwned\` && rm -rf ~"
  [ "$status" -eq 0 ]
  [ "$output" = "delivered" ]
  [ ! -e "$pwned" ]
  sleep 1
  # ...and it arrived verbatim: the metacharacters are still literal in the pane.
  tmux capture-pane -t "=$S:" -p | grep -qF '$(touch'
}

@test "injection: a newline in the prompt is rejected (it would submit a partial prompt)" {
  mk_session
  run --separate-stderr sh "$SP" send "$S" "$(printf 'first line\nrm -rf ~')"
  [ "$status" -eq 2 ]
  [ "$output" != "delivered" ]
}

@test "injection: a carriage return in the prompt is rejected" {
  mk_session
  run --separate-stderr sh "$SP" send "$S" "$(printf 'first\rsecond')"
  [ "$status" -eq 2 ]
}

@test "boundary: an empty prompt is rejected" {
  mk_session
  run --separate-stderr sh "$SP" send "$S" ''
  [ "$status" -eq 2 ]
  [ "$output" != "delivered" ]
}

@test "boundary: a multibyte (Korean) prompt survives the control-character filter" {
  # The filter runs in the C locale, so it must reject only bytes 0x00-0x1F/0x7F
  # and leave UTF-8 continuation bytes alone. Real briefs contain Korean.
  mk_session
  run --separate-stderr sh "$SP" send "$S" 'echo 한글_프롬프트_안전'
  [ "$status" -eq 0 ]
  [ "$output" = "delivered" ]
}

@test "boundary: a long single-line prompt is accepted" {
  mk_session
  long=$(printf 'echo '; awk 'BEGIN{while(i++<600)printf "x"}')
  run --separate-stderr sh "$SP" send "$S" "$long"
  [ "$status" -eq 0 ]
  [ "$output" = "delivered" ]
}

# ---------------------------------------------------------------- template
#
# session-prompt.md carries invariants that nothing else in the repo checks:
# SKILL.md cites the section headings as substring anchors, the four tmux
# prompts are injected with `send-keys -l` and so MUST stay one line each, and
# the REQUIRED subagent block must survive verbatim. These are the first
# automated guards on that file.

# 0 when all four tmux prompt bodies are exactly one non-empty line.
# Written as a function so it can be run against a deliberately broken copy —
# a gate nobody has ever seen fail is not yet a gate.
tpl_sections_single_line() {
  f="$1"
  for n in 1 2 3 4; do
    ln=$(grep -n "^## ($n) " "$f" | cut -d: -f1)
    [ -n "$ln" ] || return 1
    body=$((ln + 2)); after=$((ln + 3))
    [ -n "$(sed -n "${body}p" "$f")" ] || return 1
    [ -z "$(sed -n "${after}p" "$f")" ] || return 1
  done
  return 0
}

@test "template: the four tmux prompts are each exactly one non-empty line" {
  tpl_sections_single_line "$TPL"
}

@test "template: negative control — the single-line guard fails on a wrapped prompt" {
  # Proves the guard above can fail. Without this it would pass even if it were
  # checking nothing at all.
  broken="${BATS_TEST_TMPDIR}/wrapped.md"
  cp "$TPL" "$broken"
  ln=$(grep -n '^## (2) ' "$broken" | cut -d: -f1)
  body=$((ln + 2))
  # Split section (2)'s single line into two.
  awk -v b="$body" 'NR==b{sub(/ /, "\n"); print; next} {print}' "$broken" > "$broken.tmp"
  mv "$broken.tmp" "$broken"
  run tpl_sections_single_line "$broken"
  [ "$status" -ne 0 ]
}

@test "template: the REQUIRED subagent block is byte-identical" {
  # Byte-level, not substring: a reword that keeps the keywords but changes the
  # rule ("you MAY call the auditor") would slip past a grep and still break the
  # protocol every worker depends on. cksum is POSIX, so this holds on both CI
  # runners. If this block is ever intentionally changed, update this number in
  # the SAME commit and say so in the PR.
  run sh -c "sed -n '/^## Subagent usage protocol/,\$p' '$TPL' | cksum"
  [ "$status" -eq 0 ]
  [ "$output" = "2594177116 1010" ]
}

@test "template: negative control — the byte-identity guard fails on a reworded block" {
  # Proves the checksum above is actually comparing content, not just running.
  reworded="${BATS_TEST_TMPDIR}/reworded.md"
  sed 's/you MUST call the/you MAY call the/' "$TPL" > "$reworded"
  ! cmp -s "$TPL" "$reworded"   # the edit really changed something
  run sh -c "sed -n '/^## Subagent usage protocol/,\$p' '$reworded' | cksum"
  [ "$output" != "2594177116 1010" ]
}

@test "template: the Orca prompt set is byte-identical (out of scope for this change)" {
  run sh -c "sed -n '/^\*\*Orca substrate\.\*\*/,/^## Subagent usage protocol/p' '$TPL' | cksum"
  [ "$status" -eq 0 ]
  [ "$output" = "1714004932 4937" ]
}

@test "template: the REQUIRED block still states its three rules" {
  # Complements the checksum: names WHICH rules must be present, so a future
  # intentional edit that drops one is obvious in the diff of this test.
  grep -qF 'you MUST call the `test-quality-auditor` subagent via the Agent tool' "$TPL"
  grep -qF 'you may delegate' "$TPL"
  grep -qF 'do not call any agent by name other than `test-quality-auditor`' "$TPL"
  grep -qF 'VERDICT: FAIL -> address REASONS by strengthening tests/code (NEVER weaken' "$TPL"
}

@test "template: documents the real tmux delivery path" {
  grep -qF 'send-prompt.sh send' "$TPL"
  grep -qF 'send-prompt.sh wait' "$TPL"
  grep -qF 'send-prompt.sh state' "$TPL"
  # launch-session.sh must still be named as the owner of the FIRST injection,
  # so nobody reimplements the trust-screen path in the delivery script.
  grep -qF 'launch-session.sh' "$TPL"
}

@test "template: the Orca prompts still carry their own reporting protocol" {
  # §O1-§O4 are out of scope for this change; assert they were not disturbed.
  for n in O1 O2 O3 O4; do
    grep -qF "## ($n) " "$TPL"
  done
  # `--` before the pattern: without it grep parses the leading dashes as flags
  # and dies "unrecognized option" — the same defect send-prompt.sh guards against.
  grep -qF -- '--type worker_done' "$TPL"
}

@test "template: SKILL.md's section anchors still resolve" {
  # SKILL.md cites these as substring anchors; renaming a heading breaks it
  # silently from the other file's side.
  for n in 1 2 3 4; do
    grep -qF "## ($n) " "$TPL"
  done
}

# ---------------------------------------------------------------- environment

@test "error: a missing tmux is reported as 127, not a false verdict" {
  run -127 --separate-stderr env PATH=/nonexistent /bin/sh "$SP" state "$S"
  [ "$status" -eq 127 ]
  # Assert the reason, not just the code: a missing *script* also exits 127, so
  # a bare status check would pass vacuously. The diagnosis belongs on stderr.
  case "$stderr" in *"tmux not found"*) : ;; *) return 1 ;; esac
  [ -z "$output" ]
}
