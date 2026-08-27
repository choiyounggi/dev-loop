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

# Paint a pane that looks like the CLI holding an unsubmitted paste, with the
# marker deliberately 7 non-empty lines from the bottom (issue #145's capture).
mk_unsubmitted_box() {
  tmux send-keys -t "$S" -l -- "clear; printf '%s\\n' \
    '────────────────────────' \
    '> [Pasted text #10]tail-of-the-paste' \
    'second line of the paste remainder' \
    'third line of the paste remainder' \
    'fourth line of the paste remainder' \
    'fifth line of the paste remainder' \
    '────────────────────────' \
    '                    /rc' \
    'bypass permissions on'"
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

# ------------------------------- state/wait: unsubmitted verdict (issue #145)
#
# D6: one token/exit (unsubmitted/9), shared by state and wait. D7: state stays
# read-only. D8: wait returns 9 immediately, it does not poll to the deadline.
# D9: the target's own busy/queued indicator outranks the parked-paste check.

@test "state: a pane holding an unsubmitted pasted prompt reports unsubmitted, exit 9" {
  mk_session
  mk_unsubmitted_box
  run --separate-stderr sh "$SP" state "$S"
  [ "$status" -eq 9 ]
  [ "$output" = "unsubmitted" ]
}

@test "wait: a pane holding an unsubmitted pasted prompt reports unsubmitted, exit 9, promptly" {
  # timeout=6 rather than the 180s default: a regression that polls to the
  # deadline (D8) shows up as a slow test, not a silent pass.
  mk_session
  mk_unsubmitted_box
  run --separate-stderr sh "$SP" wait "$S" 6
  [ "$status" -eq 9 ]
  [ "$output" = "unsubmitted" ]
}

@test "boundary: state on a pane both busy and holding the marker reports busy, not unsubmitted" {
  # D9: the busy/queued indicator outranks the parked-paste check — a paste
  # sitting in the box while the worker is mid-turn is a queued next prompt,
  # not a stall.
  mk_session
  tmux send-keys -t "$S" -l -- "printf '%s\\n' 'BUSYMARK_T3' \
    '────────────────────────' \
    '> [Pasted text #9]' \
    '────────────────────────'; sleep 6"
  tmux send-keys -t "$S" Enter
  sleep 1
  run --separate-stderr env LO_QUEUED_PATTERN=BUSYMARK_T3 sh "$SP" state "$S"
  [ "$status" -eq 4 ]
  [ "$output" = "busy" ]
}

@test "boundary: state on a plain idle session with no box chrome or marker is still ready" {
  # D5's no-regression guard, re-proven against the new unsubmitted check.
  mk_session
  run --separate-stderr sh "$SP" state "$S"
  [ "$status" -eq 0 ]
  [ "$output" = "ready" ]
}

@test "error: state on a session that does not exist still reports gone, unchanged" {
  run --separate-stderr sh "$SP" state "$S"
  [ "$status" -eq 3 ]
  [ "$output" = "gone" ]
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

@test "send: a pane that shows no reaction at all is lost after a failed auto-resend" {
  # Terminal echo off: the keys go nowhere observable, no fingerprint, no busy
  # marker, no diff — this is exactly case B (D3/D4), not the old catch-all
  # "unconfirmed". "delivered" must never be the default when nothing is known,
  # and this specific nothing-at-all shape is the one the issue calls lost.
  mk_session
  tmux send-keys -t "$S" -l -- "stty -echo; sleep 8; stty echo"
  tmux send-keys -t "$S" Enter
  sleep 1
  run --separate-stderr env LO_STABLE_TRIES=0 LO_CONFIRM_DELAY=1 LO_LOST_CONFIRM_DELAY=1 \
    sh "$SP" send "$S" 'echo T3_INVISIBLE'
  [ "$status" -eq 8 ]
  [ "$output" = "lost" ]
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
  # LO_STABLE_TRIES=0: the new D5 pre-send stabilization guard consumes extra
  # capture-pane calls of its own — off here so this test's scripted capture
  # sequence (before/after/retry) keeps its original meaning.
  run --separate-stderr env LO_STABLE_TRIES=0 sh "$SP" send "$S" 'echo T3_PASTE'
  [ "$status" -eq 0 ]
  [ "$output" = "delivered" ]
  # submit Enter + exactly one retry Enter, never more once the placeholder clears
  [ "$(_enter_count)" -eq 2 ]
}

@test "send: a [Pasted text] placeholder that never clears is unconfirmed, not delivered" {
  _use_fake_tmux_send
  printf '%s\n' 'READY>' '[Pasted text #1]' '[Pasted text #1]' '[Pasted text #1]' '[Pasted text #1]' \
    > "$FAKE_CAPTURES"
  run --separate-stderr env LO_STABLE_TRIES=0 sh "$SP" send "$S" 'echo T3_STUCK'
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
  run --separate-stderr env LO_STABLE_TRIES=0 sh "$SP" send "$S" 'echo T3_BOTH'
  [ "$status" -eq 4 ]
  [ "$output" = "queued" ]
  [ "$(_enter_count)" -eq 1 ]
}

# ------------------------------ box-anchored pasted-marker detection (#145) -
#
# D1/D2: the pasted-marker scan is anchored on the CLI's input box (the region
# between the last two horizontal rules of a FULL pane capture), not a fixed
# tail window — an unsubmitted paste renders its own remainder below the
# marker, so the marker's distance from the bottom grows with the payload and
# defeats any fixed `tail -N`. Real tmux sessions running a plain /bin/sh, per
# testing-mocking-destructive-operations-on-shared-daemons.

@test "send: box-anchored pasted marker (7 lines from bottom) is not reported delivered" {
  mk_session
  mk_unsubmitted_box
  run --separate-stderr sh "$SP" send "$S" 'echo T1_BOX'
  [ "$output" != "delivered" ]
  [ "$status" -ne 0 ]
}

@test "boundary: a pasted marker only 2 lines from the bottom is still detected" {
  # Proves the box scan did not just trade one fixed window for another: a
  # short paste (marker close to the bottom) must still be caught.
  mk_session
  tmux send-keys -t "$S" -l -- "clear; printf '%s\\n' \
    '────────────────────────' \
    '> [Pasted text #2]' \
    '────────────────────────'"
  tmux send-keys -t "$S" Enter
  sleep 1
  run --separate-stderr sh "$SP" send "$S" 'echo T1_NEAR'
  [ "$output" != "delivered" ]
  [ "$status" -ne 0 ]
}

@test "error: a pasted marker with no box chrome at all still reaches the degraded fallback" {
  # D4: when the chrome is not locatable (fewer than two rules), fall back to
  # the last LO_PASTED_TAIL_LINES non-empty lines, and advertise the degraded
  # path on stderr — "could not look" and "nothing found" are different answers.
  mk_session
  tmux send-keys -t "$S" -l -- "clear; printf '%s\\n' '[Pasted text #1]tail'"
  tmux send-keys -t "$S" Enter
  sleep 1
  run --separate-stderr sh "$SP" send "$S" 'echo T1_NOCHROME'
  [ "$output" != "delivered" ]
  [ "$status" -ne 0 ]
  case "$stderr" in *"degraded check"*) : ;; *) return 1 ;; esac
}

@test "error: a pasted marker only in the transcript above an empty box is not reported unsubmitted" {
  # D2's regression guard: a whole-pane grep would misread this as unsubmitted;
  # the box-anchored scan must not, because the box itself (between the two
  # rules) is empty.
  mk_session
  tmux send-keys -t "$S" -l -- "clear; printf '%s\\n' \
    '> [Pasted text #5] from earlier turn' \
    '────────────────────────' \
    '────────────────────────' \
    '                    /rc'"
  tmux send-keys -t "$S" Enter
  sleep 1
  run --separate-stderr sh "$SP" send "$S" 'echo T1_ABOVE'
  [ "$status" -eq 0 ]
  [ "$output" = "delivered" ]
}

@test "error: box-anchored detection still works under LC_ALL=C (locale regression guard, r1 F1)" {
  # F1 (review r1): a BRE interval applied directly to the multibyte rule
  # glyph is byte-oriented under a C locale, so the box locator silently
  # degrades to the 40-line fallback there — exactly the fixed-window
  # behaviour this whole change exists to remove. Re-run the transcript-above
  # regression guard under a hostile C locale to prove the locator still
  # resolves the box (and so still excludes the above-box marker) there too.
  mk_session
  tmux send-keys -t "$S" -l -- "clear; printf '%s\\n' \
    '> [Pasted text #5] from earlier turn' \
    '────────────────────────' \
    '────────────────────────' \
    '                    /rc'"
  tmux send-keys -t "$S" Enter
  sleep 1
  run --separate-stderr env LC_ALL=C sh "$SP" send "$S" 'echo T1_ABOVE_C'
  [ "$status" -eq 0 ]
  [ "$output" = "delivered" ]
}

# ------------------------------------------- send: rc=7 3-way split (issue #7)
#
# D1: busy marker outranks a pane diff. D2: the prompt's own fingerprint left
# sitting in an un-advanced pane self-heals the same way the placeholder does.
# D3/D4: "lost" requires two quiet observations AND one failed auto-resend —
# never a verdict from a single unchanged capture. D5: a wobbling pane is
# settled (two consecutive identical captures) before any key is typed.

@test "send: a busy marker alone is delivered(0), even with no pane diff at all" {
  # D1: the busy/queued indicator is stronger evidence than a text diff (pane-
  # delivery-confirmation's evidence table) — same before/after content, busy
  # marker present both times, must still classify as delivered, not lost.
  _use_fake_tmux_send
  printf '%s\n' 'WORKING... esc to interrupt' 'WORKING... esc to interrupt' > "$FAKE_CAPTURES"
  run --separate-stderr env LO_STABLE_TRIES=0 sh "$SP" send "$S" 'echo T3_BUSY_CASE'
  [ "$status" -eq 0 ]
  [ "$output" = "delivered" ]
}

@test "send: negative control — the same unchanged pane WITHOUT a busy marker is not delivered" {
  # Proves the busy case above can fail: identical before/after content, no
  # busy marker this time, no fingerprint either — falls into the lost path
  # (confirmed-quiet twice, resend also quiet), not delivered by the diff
  # check (which the D1 test alone couldn't rule out).
  _use_fake_tmux_send
  printf '%s\n' 'IDLE>' 'IDLE>' 'IDLE>' 'IDLE>' 'IDLE>' > "$FAKE_CAPTURES"
  run --separate-stderr env LO_STABLE_TRIES=0 LO_LOST_CONFIRM_DELAY=0 \
    sh "$SP" send "$S" 'echo T3_NEGCTRL'
  [ "$status" -eq 8 ]
  [ "$output" = "lost" ]
}

@test "send: the prompt's own fingerprint sitting unsubmitted self-heals via Enter, then delivers" {
  # D2: same trigger as the [Pasted text] case (buffered, not consumed) but
  # detected via the prompt's own tail bytes instead of the placeholder text —
  # covers CLIs that echo the literal prompt into an input box rather than
  # collapsing it to a "[Pasted text]" marker.
  _use_fake_tmux_send
  printf '%s\n' '> echo T3_FP_HEALCASE' '> echo T3_FP_HEALCASE' 'T3_FP_HEALCASE_RAN' \
    > "$FAKE_CAPTURES"
  run --separate-stderr env LO_STABLE_TRIES=0 sh "$SP" send "$S" 'echo T3_FP_HEALCASE'
  [ "$status" -eq 0 ]
  [ "$output" = "delivered" ]
  # submit Enter + exactly one self-heal retry Enter
  [ "$(_enter_count)" -eq 2 ]
}

@test "send: two quiet observations with a failed auto-resend is lost, exit 8" {
  # D3+D4: no queued/pasted/fingerprint/busy marker, no diff, confirmed twice
  # (LO_LOST_CONFIRM_DELAY apart), one automatic full resend also finds
  # nothing — only THEN is it reported lost. Never on the first unchanged
  # capture ("Resend on the first unchanged capture" — the exact anti-pattern
  # pane-delivery-confirmation names).
  _use_fake_tmux_send
  printf '%s\n' 'IDLE>' 'IDLE>' 'IDLE>' 'IDLE>' 'IDLE>' > "$FAKE_CAPTURES"
  run --separate-stderr env LO_STABLE_TRIES=0 LO_CONFIRM_DELAY=0 LO_LOST_CONFIRM_DELAY=0 \
    sh "$SP" send "$S" 'echo T3_LOST_CASE'
  [ "$status" -eq 8 ]
  [ "$output" = "lost" ]
  # exactly one resend: 2 sends (initial -l + Enter) + 2 sends (the one resend)
  [ "$(grep -cx -- "-t =$S: -l -- echo T3_LOST_CASE" "$FAKE_SEND_LOG")" -eq 2 ]
  [ "$(_enter_count)" -eq 2 ]
}

@test "send: a resend that succeeds is delivered, not lost" {
  # D4's other branch: same lost-candidate setup, but the auto-resend produces
  # a real diff, so it reports delivered instead of exhausting to lost.
  _use_fake_tmux_send
  printf '%s\n' 'IDLE>' 'IDLE>' 'IDLE>' 'T3_RESEND_RAN' > "$FAKE_CAPTURES"
  run --separate-stderr env LO_STABLE_TRIES=0 LO_CONFIRM_DELAY=0 LO_LOST_CONFIRM_DELAY=0 \
    sh "$SP" send "$S" 'echo T3_RESEND_OK'
  [ "$status" -eq 0 ]
  [ "$output" = "delivered" ]
  [ "$(grep -cx -- "-t =$S: -l -- echo T3_RESEND_OK" "$FAKE_SEND_LOG")" -eq 2 ]
}

@test "send: a wobbling pane is settled to two identical captures before any key is typed" {
  # D5: the pane changes twice, then stabilizes; only the settled snapshot is
  # used as "before", and no send-keys call happens until stabilization ends.
  _use_fake_tmux_send
  printf '%s\n' 'WOBBLE1' 'WOBBLE2' 'STABLE' 'STABLE' 'STABLE_DONE' > "$FAKE_CAPTURES"
  run --separate-stderr env LO_STABLE_DELAY=0 LO_STABLE_TRIES=3 \
    sh "$SP" send "$S" 'echo T3_STABLE_CASE'
  [ "$status" -eq 0 ]
  [ "$output" = "delivered" ]
  # 4 stabilization captures (WOBBLE1/WOBBLE2/STABLE/STABLE) + 1 post-send
  # capture (STABLE_DONE) = 5 capture-pane calls total, all BEFORE any send.
  [ "$(cat "$FAKE_CAPTURE_N")" -eq 5 ]
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
  # Bumped from 2521059482/6502 when Orca rule [3] gained the
  # escalation-record-cleanup obligation.
  # Bumped from 3279716624/6776 (t2-review-blackboard, issue #152 P2): §O2
  # gained the blackboard read-then-append checkpoint, and rule [7] added the
  # append-only obligation for {ORCH_DIR}/notes/decisions.md.
  # Bumped from 56586708/7358 (t2-review-blackboard r1 rework, F2/F3): §O2's
  # read checkpoint tolerates an absent file ("if it exists"), and both the
  # §O2 append instruction and rule [7] now prescribe the atomic
  # `printf ... >>` shell primitive instead of Write/Edit, which is
  # read-modify-write and can drop a concurrent worker's line.
  # Bumped from 568847008/7627 (t2-review-blackboard r1 rework, N1): §O2 now
  # opens "Approved. First read …" instead of "First read … . Approved.",
  # same non-blocking wording fix applied to §2.
  run sh -c "sed -n '/^\*\*Orca substrate\.\*\*/,/^## Subagent usage protocol/p' '$TPL' | cksum"
  [ "$status" -eq 0 ]
  [ "$output" = "3082668569 7627" ]
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

# ---------------------------------------------------- drift guard (issue #145)

@test "drift guard: input_box() is byte-identical in send-prompt.sh and launch-session.sh" {
  LS="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/launch-session.sh"
  a=$(awk '/^input_box\(\) \{/,/^\}$/' "$SP")
  b=$(awk '/^input_box\(\) \{/,/^\}$/' "$LS")
  [ -n "$a" ]
  [ -n "$b" ]
  [ "$a" = "$b" ]
}
