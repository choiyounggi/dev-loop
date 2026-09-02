#!/usr/bin/env bats
# resolve-escalation.sh — clears a guardrails escalation record for a task
# and optionally delivers the coordinator's verdict to the waiting worker.
#
# Matching is by the record's .taskId field (never by filename); a record
# jq cannot parse is left in place and named on stderr. Delivery goes
# through the sibling send-prompt.sh — tests stub it out to assert argv
# and to force a delivery failure.

bats_require_minimum_version 1.5.0

setup() {
  RES="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/resolve-escalation.sh"
  ESC="${BATS_TEST_TMPDIR}/escalations"
  mkdir -p "$ESC"
}

record() { # $1 = filename $2 = taskId
  printf '{"taskId":"%s","rule":"ask","ts":"2026-01-01T00:00:00Z"}' "$2" > "$ESC/$1"
}

# installs a stub send-prompt.sh (logging its argv, exiting $1) beside a
# copy of the real script, so resolve-escalation.sh's sibling-script lookup
# ($(dirname "$0")) finds the stub instead of the real send-prompt.sh
stub_send_prompt() {
  BIN="${BATS_TEST_TMPDIR}/bin"
  mkdir -p "$BIN"
  cp "$RES" "$BIN/resolve-escalation.sh"
  cat > "$BIN/send-prompt.sh" <<EOF
#!/bin/sh
printf '%s\n' "\$@" >> "${BATS_TEST_TMPDIR}/send-prompt.argv"
exit $1
EOF
}

@test "clears only the matching task's record, no delivery requested" {
  record "a.json" "task-a"
  record "b.json" "task-b"
  run sh "$RES" "$ESC" task-a
  [ "$status" -eq 0 ]
  [ "$output" = "cleared=1 delivered=0" ]
  [ ! -f "$ESC/a.json" ]
  [ -f "$ESC/b.json" ]
}

@test "no matching record: exit 3, records untouched" {
  record "a.json" "task-a"
  run sh "$RES" "$ESC" task-zzz
  [ "$status" -eq 3 ]
  printf '%s' "$output" | grep -q "cleared=0 delivered=0"
  [ -f "$ESC/a.json" ]
}

@test "missing args is a usage error (exit 2)" {
  run sh "$RES" "$ESC"
  [ "$status" -eq 2 ]
}

@test "invalid task-id characters is exit 2, record untouched" {
  record "a.json" "task-a"
  run sh "$RES" "$ESC" 'task a!'
  [ "$status" -eq 2 ]
  [ -f "$ESC/a.json" ]
}

@test "non-directory escalations-dir is exit 2" {
  run sh "$RES" "$ESC/not-a-dir" task-a
  [ "$status" -eq 2 ]
}

@test "delivery success: cleared and delivered, stub sees send <session> <message>" {
  record "a.json" "task-a"
  stub_send_prompt 0
  run sh "$BIN/resolve-escalation.sh" "$ESC" task-a lo-1 "approved -- continue"
  [ "$status" -eq 0 ]
  [ "$output" = "cleared=1 delivered=1" ]
  [ ! -f "$ESC/a.json" ]
  [ "$(sed -n '1p' "${BATS_TEST_TMPDIR}/send-prompt.argv")" = "send" ]
  [ "$(sed -n '2p' "${BATS_TEST_TMPDIR}/send-prompt.argv")" = "lo-1" ]
  [ "$(sed -n '3p' "${BATS_TEST_TMPDIR}/send-prompt.argv")" = "approved -- continue" ]
}

@test "delivery failure: record already cleared, exit 6, stderr names send-prompt's exit code" {
  record "a.json" "task-a"
  stub_send_prompt 3
  run sh "$BIN/resolve-escalation.sh" "$ESC" task-a lo-1 "denied -- try X"
  [ "$status" -eq 6 ]
  [ ! -f "$ESC/a.json" ]
  printf '%s' "$output" | grep -q "cleared=1 delivered=0"
  printf '%s' "$output" | grep -q "exit 3"
}

@test "unparseable record is skipped and left in place, named on stderr" {
  printf 'not json' > "$ESC/bad.json"
  record "a.json" "task-a"
  run sh "$RES" "$ESC" task-zzz
  [ "$status" -eq 3 ]
  [ -f "$ESC/bad.json" ]
  printf '%s' "$output" | grep -q "bad.json"
}

@test "no match found: delivery args given are not used (nothing pending to answer)" {
  record "a.json" "task-a"
  stub_send_prompt 0
  run sh "$BIN/resolve-escalation.sh" "$ESC" task-zzz lo-1 "would-be message"
  [ "$status" -eq 3 ]
  [ ! -f "${BATS_TEST_TMPDIR}/send-prompt.argv" ]
}

@test "missing jq exits 127 (boundary)" {
  record "a.json" "task-a"
  run -127 env PATH="/nonexistent" sh "$RES" "$ESC" task-a
  [ "$status" -eq 127 ]
}

@test "source-text wiring: SKILL.md and install-permission-rules.sh name resolve-escalation.sh" {
  SKILL_MD="${BATS_TEST_DIRNAME}/../skills/orchestrate/SKILL.md"
  IPR="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/install-permission-rules.sh"
  # Preflight's pasteable JSON snippet names the path rule
  grep -q 'resolve-escalation.sh \*)"' "$SKILL_MD"
  # the exit-5 watch playbook names the script
  grep -q 'scripts/resolve-escalation.sh <escdir>' "$SKILL_MD"
  # the installer itself names the script (r4 + autoMode sentence)
  grep -q "resolve-escalation.sh" "$IPR"
}
