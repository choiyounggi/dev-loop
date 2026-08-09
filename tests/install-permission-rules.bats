#!/usr/bin/env bats
# install-permission-rules.sh — consent-gated coordinator permission installer.
#
# The script merges the orchestrate coordinator's permission rules (three
# path allows + one autoMode classifier rule) into a Claude Code settings.json.
# It must be idempotent, refuse malformed targets, back up before writing, and
# never touch the file in --check mode. HOME is overridden per test so the
# generated rule strings are deterministic and the real user settings can
# never be read or written by a test run.

setup() {
  IPR="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/install-permission-rules.sh"
  WORK="${BATS_TEST_TMPDIR}/work"
  mkdir -p "$WORK"
  TARGET="$WORK/settings.json"
  FAKE_HOME="${BATS_TEST_TMPDIR}/home"
  mkdir -p "$FAKE_HOME"
}

# helper: the launch-session path rule the script must generate for FAKE_HOME
expected_rule1() {
  printf 'Bash(sh %s/.claude/plugins/cache/*/dev-loop/*/skills/orchestrate/scripts/launch-session.sh *)' "$FAKE_HOME"
}

@test "fresh install: missing target file is created with all rules and valid JSON" {
  run env HOME="$FAKE_HOME" sh "$IPR" "$TARGET"
  [ "$status" -eq 0 ]
  [ -f "$TARGET" ]
  jq -e . "$TARGET" >/dev/null
  # three path rules present, keyed on the real (fake) home dir
  [ "$(jq -r '.permissions.allow | length' "$TARGET")" -eq 3 ]
  jq -e --arg r "$(expected_rule1)" '.permissions.allow | index($r) != null' "$TARGET" >/dev/null
  # autoMode gets $defaults first, then our context rule
  [ "$(jq -r '.autoMode.allow[0]' "$TARGET")" = '$defaults' ]
  jq -e '.autoMode.allow[1] | contains("bypassPermissions")' "$TARGET" >/dev/null
  jq -e '.autoMode.allow[1] | contains("safe-cleanup.sh")' "$TARGET" >/dev/null
}

@test "idempotent: second run reports already installed, changes nothing, makes no backup" {
  env HOME="$FAKE_HOME" sh "$IPR" "$TARGET"
  before=$(cat "$TARGET")
  run env HOME="$FAKE_HOME" sh "$IPR" "$TARGET"
  [ "$status" -eq 0 ]
  printf '%s' "$output" | grep -q "already installed"
  [ "$(cat "$TARGET")" = "$before" ]
  # a no-op run must not leave a backup
  [ "$(find "$WORK" -name 'settings.json.bak.*' | wc -l | tr -d ' ')" -eq 0 ]
}

@test "merge: existing allow rules and settings keys are preserved, missing rules appended" {
  printf '{"permissions":{"allow":["Bash(git:*)"],"defaultMode":"default"},"model":"opus"}' > "$TARGET"
  run env HOME="$FAKE_HOME" sh "$IPR" "$TARGET"
  [ "$status" -eq 0 ]
  # pre-existing entries survive, in place
  [ "$(jq -r '.permissions.allow[0]' "$TARGET")" = 'Bash(git:*)' ]
  [ "$(jq -r '.permissions.defaultMode' "$TARGET")" = 'default' ]
  [ "$(jq -r '.model' "$TARGET")" = 'opus' ]
  [ "$(jq -r '.permissions.allow | length' "$TARGET")" -eq 4 ]
}

@test "merge: existing autoMode.allow gets our rule appended without injecting \$defaults" {
  # a user who removed $defaults did so deliberately — the installer must not re-add it
  printf '{"autoMode":{"allow":["my custom rule"]}}' > "$TARGET"
  run env HOME="$FAKE_HOME" sh "$IPR" "$TARGET"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.autoMode.allow | length' "$TARGET")" -eq 2 ]
  [ "$(jq -r '.autoMode.allow[0]' "$TARGET")" = 'my custom rule' ]
  run jq -e '.autoMode.allow | index("$defaults")' "$TARGET"
  [ "$status" -ne 0 ]
}

@test "malformed target is refused untouched with exit 3 and no backup" {
  printf '{ not json' > "$TARGET"
  run env HOME="$FAKE_HOME" sh "$IPR" "$TARGET"
  [ "$status" -eq 3 ]
  printf '%s' "$output" | grep -qi "refuse"
  [ "$(cat "$TARGET")" = '{ not json' ]
  [ "$(find "$WORK" -name 'settings.json.bak.*' | wc -l | tr -d ' ')" -eq 0 ]
}

@test "backup: a modifying run leaves exactly one timestamped backup of the prior content" {
  printf '{"permissions":{"allow":["Bash(git:*)"]}}' > "$TARGET"
  run env HOME="$FAKE_HOME" sh "$IPR" "$TARGET"
  [ "$status" -eq 0 ]
  [ "$(find "$WORK" -name 'settings.json.bak.*' | wc -l | tr -d ' ')" -eq 1 ]
  bak=$(find "$WORK" -name 'settings.json.bak.*')
  [ "$(cat "$bak")" = '{"permissions":{"allow":["Bash(git:*)"]}}' ]
}

@test "--check: reports absent (4) without creating or writing anything" {
  run env HOME="$FAKE_HOME" sh "$IPR" --check "$TARGET"
  [ "$status" -eq 4 ]
  [ ! -e "$TARGET" ]
}

@test "--check: reports present (0) after an install, file untouched" {
  env HOME="$FAKE_HOME" sh "$IPR" "$TARGET"
  before=$(cat "$TARGET")
  run env HOME="$FAKE_HOME" sh "$IPR" --check "$TARGET"
  [ "$status" -eq 0 ]
  [ "$(cat "$TARGET")" = "$before" ]
}

@test "--check on a malformed target is absent-with-refusal (3), never a crash" {
  printf 'nope' > "$TARGET"
  run env HOME="$FAKE_HOME" sh "$IPR" --check "$TARGET"
  [ "$status" -eq 3 ]
}

@test "missing jq exits 127 (boundary)" {
  run env HOME="$FAKE_HOME" PATH="/nonexistent" sh "$IPR" "$TARGET"
  [ "$status" -eq 127 ]
}

@test "default target: no argument installs into \$HOME/.claude/settings.json" {
  run env HOME="$FAKE_HOME" sh "$IPR"
  [ "$status" -eq 0 ]
  [ -f "$FAKE_HOME/.claude/settings.json" ]
  [ "$(jq -r '.permissions.allow | length' "$FAKE_HOME/.claude/settings.json")" -eq 3 ]
}

@test "usage: an unknown flag is rejected with exit 1" {
  run env HOME="$FAKE_HOME" sh "$IPR" --frobnicate "$TARGET"
  [ "$status" -eq 1 ]
  printf '%s' "$output" | grep -q "usage"
}
