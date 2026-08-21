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
  # Per-test scratch root for the injected tmux fake (keys tests). Kept INSIDE
  # the repo (.claude/ is git-ignored), not under $BATS_TEST_TMPDIR: the fake
  # needs an exec bit and host EDR flags chmod +x under /tmp,$TMPDIR.
  STUB_ROOT="${BATS_TEST_DIRNAME}/../.claude/tmp/sp-$$-${BATS_TEST_NUMBER:-0}"
}

teardown() {
  [ -n "${STUB_ROOT:-}" ] && rm -rf "$STUB_ROOT"
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

# ------------------------------------ send: [Pasted text] guard (issue #96)
#
# cmd_send must never report "delivered" while the prompt sits as an
# unsubmitted "[Pasted text #N]" placeholder. A real tmux pane cannot be
# driven through an exact multi-call capture-pane sequence (before -> after ->
# after each retry) deterministically, so these cases use a scripted fake tmux
# on PATH — same technique as the `keys` fake below, extended with a captures
# script so each successive capture-pane call returns the next scripted line.

# $FAKE_CAPTURES holds one pane-snapshot per line; capture-pane returns the
# Nth line on its Nth call (clamped to the last line once exhausted), so a
# test can script exactly what cmd_send sees on the before-capture, the
# post-send capture, and each retry re-capture.
_use_fake_tmux_send() {
  mkdir -p "$STUB_ROOT/bin"
  FAKE_SEND_LOG="$STUB_ROOT/sends.log";      : > "$FAKE_SEND_LOG"
  FAKE_CAPTURE_N="$STUB_ROOT/capture_n";     echo 0 > "$FAKE_CAPTURE_N"
  FAKE_CAPTURES="$STUB_ROOT/captures";       : > "$FAKE_CAPTURES"
  FAKE_ALIVE_FILE="$STUB_ROOT/alive";        : > "$FAKE_ALIVE_FILE"
  export FAKE_SEND_LOG FAKE_CAPTURE_N FAKE_CAPTURES FAKE_ALIVE_FILE
  cat > "$STUB_ROOT/bin/tmux" <<'FAKE'
#!/bin/sh
verb="$1"; shift
case "$verb" in
  has-session)  [ -e "$FAKE_ALIVE_FILE" ]; exit $? ;;
  capture-pane)
    n=$(cat "$FAKE_CAPTURE_N")
    total=$(wc -l < "$FAKE_CAPTURES" | tr -d ' ')
    idx=$((n + 1))
    [ "$idx" -gt "$total" ] && idx="$total"
    sed -n "${idx}p" "$FAKE_CAPTURES"
    echo $((n + 1)) > "$FAKE_CAPTURE_N"
    exit 0 ;;
  send-keys)
    printf '%s\n' "$*" >> "$FAKE_SEND_LOG"
    exit 0 ;;
esac
exit 0
FAKE
  chmod +x "$STUB_ROOT/bin/tmux"
  PATH="$STUB_ROOT/bin:$PATH"; export PATH
}
_enter_count() { grep -cx -- "-t =$S: Enter" "$FAKE_SEND_LOG"; }

@test "send: a [Pasted text] placeholder cleared by one retry is delivered" {
  _use_fake_tmux_send
  printf '%s\n' 'READY>' '[Pasted text #1 +2 lines]' 'T3_PASTE_RAN' > "$FAKE_CAPTURES"
  run --separate-stderr sh "$SP" send "$S" 'echo T3_PASTE'
  [ "$status" -eq 0 ]
  [ "$output" = "delivered" ]
  # submit Enter + exactly one retry Enter, never more once the placeholder clears
  [ "$(_enter_count)" -eq 2 ]
}

@test "send: a [Pasted text] placeholder that never clears is unconfirmed, not delivered" {
  _use_fake_tmux_send
  printf '%s\n' 'READY>' '[Pasted text #1]' '[Pasted text #1]' '[Pasted text #1]' '[Pasted text #1]' \
    > "$FAKE_CAPTURES"
  run --separate-stderr sh "$SP" send "$S" 'echo T3_STUCK'
  [ "$status" -eq 7 ]
  [ "$output" = "unconfirmed" ]
  # submit Enter + exactly 3 bounded retries — never an unbounded loop
  [ "$(_enter_count)" -eq 4 ]
}

@test "boundary: a placeholder alongside the queued indicator reports queued, not unconfirmed" {
  # Order is unchanged: the existing queued_pat check still wins over the new
  # placeholder guard, so no retry Enter is sent at all.
  _use_fake_tmux_send
  printf '%s\n' 'READY>' '[Pasted text #1] Press up to edit queued messages' > "$FAKE_CAPTURES"
  run --separate-stderr sh "$SP" send "$S" 'echo T3_BOTH'
  [ "$status" -eq 4 ]
  [ "$output" = "queued" ]
  [ "$(_enter_count)" -eq 1 ]
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
  # Bumped from 2594177116/1010 when rule [4] gained the token-hygiene item
  # (t2-skill-token-directives): bound tool output + delegate visual checks to
  # a subagent, citing wiki/infrastructure/agent-orchestration/session-context-
  # token-budget.md.
  run sh -c "sed -n '/^## Subagent usage protocol/,\$p' '$TPL' | cksum"
  [ "$status" -eq 0 ]
  [ "$output" = "4167093106 1552" ]
}

@test "template: negative control — the byte-identity guard fails on a reworded block" {
  # Proves the checksum above is actually comparing content, not just running.
  reworded="${BATS_TEST_TMPDIR}/reworded.md"
  sed 's/you MUST call the/you MAY call the/' "$TPL" > "$reworded"
  ! cmp -s "$TPL" "$reworded"   # the edit really changed something
  run sh -c "sed -n '/^## Subagent usage protocol/,\$p' '$reworded' | cksum"
  [ "$output" != "4167093106 1552" ]
}

@test "template: the Orca prompt set is byte-identical" {
  # Bumped from 1714004932/4937 when rule [4] gained the ask-timeout contract:
  # a timeout leaves the question pending, so the worker resumes it instead of
  # deciding it. Update in the SAME commit as any intentional edit, as above.
  # Bumped from 3932390147/5667 when O1 became adopt-the-coordinator's-plan
  # instead of author-your-own: planning moved to the coordinator so it runs on
  # the planning model, not on whatever tier the worker is pinned to.
  # Bumped from 4060540920/6077 when §O3 gained the fix-or-answer obligation:
  # per finding, fix it or answer its Question and leave it, recorded via an
  # Answer (r{N}) line in the review file; silence is not a valid resolution.
  # Bumped from 3269123258/6531 when every `.orchestration/briefs|plans|reviews/`
  # reference became `{ORCH_DIR}/...` (issue #87): a worker's cwd is its own
  # worktree, which does not contain `.orchestration/`, so the bare relative
  # form resolved to nothing.
  run sh -c "sed -n '/^\*\*Orca substrate\.\*\*/,/^## Subagent usage protocol/p' '$TPL' | cksum"
  [ "$status" -eq 0 ]
  [ "$output" = "2521059482 6502" ]
}

@test "template: the Orca ask rule forbids deciding a timed-out question" {
  # Names the rule the checksum above only pins, so a reword that keeps the
  # command but drops the obligation is visible in this test's diff.
  grep -qF 'A timeout is not an answer.' "$TPL"
  grep -qF 'ask --resume <message_id>' "$TPL"
  grep -qF 'Do NOT decide it yourself' "$TPL"
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

# ---------------------------------------------------------------- keys
#
# `keys` answers an interactive chooser with tmux key EVENTS. The properties
# under test — argv order of the sends, zero sends on any rejection, the exact
# invocation shape (no -l) — are invisible to a real pane, so these tests use a
# RECORDING tmux fake on PATH. One real-tmux smoke test keeps the fake honest.

# Install the recording fake for THIS test only. send-keys argv is logged on
# success; attempts are counted separately, so "validated but never sent"
# (attempts=0) and "sent then failed" (attempts>sends) are distinguishable.
# Liveness is the alive flag file. FAKE_SEND_FAIL_AT=N fails the Nth send-keys
# call; FAKE_KILL_ON_FAIL=1 additionally removes the alive file at that
# failure, modelling a session that died mid-sequence.
_use_fake_tmux() {
  mkdir -p "$STUB_ROOT/bin"
  FAKE_SEND_LOG="$STUB_ROOT/sends.log";  : > "$FAKE_SEND_LOG"
  FAKE_ATTEMPTS="$STUB_ROOT/attempts";   : > "$FAKE_ATTEMPTS"
  FAKE_ALIVE_FILE="$STUB_ROOT/alive";    : > "$FAKE_ALIVE_FILE"
  export FAKE_SEND_LOG FAKE_ATTEMPTS FAKE_ALIVE_FILE
  cat > "$STUB_ROOT/bin/tmux" <<'FAKE'
#!/bin/sh
verb="$1"; shift
case "$verb" in
  has-session)  [ -e "$FAKE_ALIVE_FILE" ]; exit $? ;;
  capture-pane) printf 'FAKE_PANE_LINE\n'; exit 0 ;;
  send-keys)
    echo x >> "$FAKE_ATTEMPTS"
    n=$(wc -l < "$FAKE_ATTEMPTS" | tr -d ' ')
    if [ -n "${FAKE_SEND_FAIL_AT:-}" ] && [ "$n" -eq "$FAKE_SEND_FAIL_AT" ]; then
      [ "${FAKE_KILL_ON_FAIL:-0}" = "1" ] && rm -f "$FAKE_ALIVE_FILE"
      exit 1
    fi
    printf '%s\n' "$*" >> "$FAKE_SEND_LOG"
    exit 0 ;;
esac
exit 0
FAKE
  chmod +x "$STUB_ROOT/bin/tmux"
  PATH="$STUB_ROOT/bin:$PATH"; export PATH
}
_send_count()    { wc -l < "$FAKE_SEND_LOG" | tr -d ' '; }
_attempt_count() { wc -l < "$FAKE_ATTEMPTS" | tr -d ' '; }

@test "keys: multi-key sequence is sent one event per key, in argv order" {
  _use_fake_tmux
  run --separate-stderr sh "$SP" keys "$S" Down Down Enter
  [ "$status" -eq 0 ]
  [ "$output" = "sent" ]
  [ "$(_send_count)" -eq 3 ]
  # Order is the contract: line 3 differing from lines 1-2 makes a reorder red.
  [ "$(sed -n '1p' "$FAKE_SEND_LOG")" = "-t =$S: Down" ]
  [ "$(sed -n '2p' "$FAKE_SEND_LOG")" = "-t =$S: Down" ]
  [ "$(sed -n '3p' "$FAKE_SEND_LOG")" = "-t =$S: Enter" ]
  # Named keys must be key EVENTS: with -l tmux would type the text "Down".
  ! grep -qF -- ' -l ' "$FAKE_SEND_LOG"
}

@test "keys: single key is sent (boundary)" {
  _use_fake_tmux
  run --separate-stderr sh "$SP" keys "$S" y
  [ "$status" -eq 0 ]
  [ "$output" = "sent" ]
  [ "$(_send_count)" -eq 1 ]
  [ "$(sed -n '1p' "$FAKE_SEND_LOG")" = "-t =$S: y" ]
}

@test "keys: real tmux smoke — digits land in the pane in order" {
  # Keeps the fake honest: real tmux must accept the allowlisted tokens as key
  # names and deliver them in argv order. '78' in the pane proves both (a swap
  # would echo '87'); the executed line then errors, which is fine — the keys
  # arriving is the behavior under test.
  mk_session
  run --separate-stderr sh "$SP" keys "$S" 7 8 Enter
  [ "$status" -eq 0 ]
  [ "$output" = "sent" ]
  sleep 1
  tmux capture-pane -t "=$S:" -p | grep -qF '78'
}

@test "keys: unknown key is rejected with nothing sent" {
  # validate-all-before-send-any: the bad key sits AFTER a valid one, so a
  # validate-as-you-send implementation would leak the first Down.
  _use_fake_tmux
  run --separate-stderr sh "$SP" keys "$S" Down frobnicate Enter
  [ "$status" -eq 2 ]
  [ "$output" != "sent" ]
  [ "$(_attempt_count)" -eq 0 ]
  case "$stderr" in *frobnicate*) : ;; *) return 1 ;; esac
}

@test "keys: allowlist is case-sensitive — lowercase 'down' is rejected" {
  # tmux would accept 'down' as a key name, but the contract fixes exact
  # tokens; a case-folding allowlist would silently widen the surface.
  _use_fake_tmux
  run --separate-stderr sh "$SP" keys "$S" down
  [ "$status" -eq 2 ]
  [ "$(_attempt_count)" -eq 0 ]
}

@test "keys: a key that looks like a tmux flag is rejected, never sent" {
  _use_fake_tmux
  run --separate-stderr sh "$SP" keys "$S" -l
  [ "$status" -eq 2 ]
  [ "$(_attempt_count)" -eq 0 ]
}

@test "keys: invalid session name is rejected with nothing sent" {
  _use_fake_tmux
  run --separate-stderr sh "$SP" keys '; rm -rf ~' Enter
  [ "$status" -eq 2 ]
  [ "$output" != "sent" ]
  [ "$(_attempt_count)" -eq 0 ]
}

@test "keys: gone session reports gone before any send" {
  _use_fake_tmux
  rm "$FAKE_ALIVE_FILE"
  run --separate-stderr sh "$SP" keys "$S" Enter
  [ "$status" -eq 3 ]
  [ "$output" = "gone" ]
  [ "$(_attempt_count)" -eq 0 ]
}

@test "boundary: keys with an empty key list is a usage error" {
  run sh "$SP" keys "$S"
  [ "$status" -eq 1 ]
}

@test "usage: keys without any argument exits 1" {
  run sh "$SP" keys
  [ "$status" -eq 1 ]
}

@test "keys: mid-sequence send failure on a live session exits 6" {
  _use_fake_tmux
  run --separate-stderr env FAKE_SEND_FAIL_AT=2 sh "$SP" keys "$S" Down Up Enter
  [ "$status" -eq 6 ]
  [ -z "$output" ]
  # Only the first key landed; the loop stopped AT the failure, not after it.
  [ "$(_send_count)" -eq 1 ]
  [ "$(_attempt_count)" -eq 2 ]
  # The failure names the exact key that did not land.
  case "$stderr" in *"'Up'"*) : ;; *) return 1 ;; esac
}

@test "keys: mid-sequence failure because the session died reports gone" {
  # Same failure point as the exit-6 case; only the session's survival differs.
  # Mirrors cmd_send: a failed send is re-diagnosed before being reported.
  _use_fake_tmux
  run --separate-stderr env FAKE_SEND_FAIL_AT=2 FAKE_KILL_ON_FAIL=1 \
    sh "$SP" keys "$S" Down Up Enter
  [ "$status" -eq 3 ]
  [ "$output" = "gone" ]
}

@test "keys: stdout carries exactly one token; advisory pane line on stderr" {
  _use_fake_tmux
  run --separate-stderr sh "$SP" keys "$S" Enter
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | wc -l | tr -d ' ')" = "0" ]
  [ "$(printf '%s' "$output" | wc -w | tr -d ' ')" = "1" ]
  # The trailing note_pane advisory: pane context for the caller's log.
  case "$stderr" in *FAKE_PANE_LINE*) : ;; *) return 1 ;; esac
}
