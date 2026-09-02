#!/bin/sh
# install-permission-rules.sh — consent-gated installer for the orchestrate
# coordinator's permission rules (see SKILL.md Preflight).
#
# NEVER run this without the user's explicit yes in the CURRENT conversation
# turn. A plugin silently widening permissions is the exact supply-chain
# escalation pattern guardrails exists to stop — the value of this script is
# that the widening happens in one reviewed, idempotent, backed-up step AFTER
# the user agrees, instead of ad-hoc hand edits. (A fresh explicit consent is
# also what lets an auto-mode permission classifier pass the write at all.)
#
# What it installs into a Claude Code settings.json:
#   - permissions.allow: four path rules for launch-session.sh /
#     send-prompt.sh / watch-status.sh / resolve-escalation.sh
#     (safe-cleanup.sh is deliberately absent — destructive verbs keep
#     their normal review)
#   - autoMode.allow: one context rule teaching the classifier why the
#     bypassPermissions worker spawn is sanctioned. On a fresh list it is
#     seeded as ["$defaults", <rule>]; an existing list only gets the rule
#     appended — a user who removed "$defaults" did so deliberately.
#
# usage: install-permission-rules.sh [--check] [target-settings-json]
#   default target: $HOME/.claude/settings.json (created if absent)
#   --check        read-only probe: never creates, writes, or backs up
#
# The path rules embed the real $HOME — permission rules do not expand ~.
# The cache glob (cache/*/dev-loop/*/) covers any marketplace and any
# plugin version, so the rules survive releases.
#
# exit 0   installed, or already present (--check: present)
# exit 1   usage error
# exit 3   target exists but is not valid JSON — REFUSED untouched (a
#          malformed settings file silently disables every setting in it,
#          so writing over one could hide real damage)
# exit 4   --check only: rules absent
# exit 127 jq not found
set -eu
JQ=$(command -v jq) || { echo "install-permission-rules: jq not found" >&2; exit 127; }

usage() { echo "usage: install-permission-rules.sh [--check] [target-settings-json]" >&2; exit 1; }

check=0
if [ "${1:-}" = "--check" ]; then check=1; shift; fi
case "${1:-}" in -*) usage ;; esac
target="${1:-$HOME/.claude/settings.json}"

base="$HOME/.claude/plugins/cache/*/dev-loop/*/skills/orchestrate/scripts"
r1="Bash(sh $base/launch-session.sh *)"
r2="Bash(sh $base/send-prompt.sh *)"
r3="Bash(sh $base/watch-status.sh *)"
r4="Bash(sh $base/resolve-escalation.sh *)"
am='Running the dev-loop orchestrate plugin'"'"'s worker-management scripts (launch-session.sh, send-prompt.sh, watch-status.sh, resolve-escalation.sh) is allowed, including launch-session.sh starting a tmux worker with `claude --permission-mode bypassPermissions` and resolve-escalation.sh clearing a guardrails escalation record and delivering the coordinator'"'"'s verdict to the waiting worker: the user sanctioned this orchestration workflow, and each worker worktree is sandboxed by groundwork guardrails, which still blocks dangerous commands in bypass mode and escalates `ask` rules to the coordinator. This does NOT extend to safe-cleanup.sh or other destructive commands, which keep their normal review.'

if [ -f "$target" ]; then
  if ! "$JQ" -e . "$target" >/dev/null 2>&1; then
    echo "install-permission-rules: REFUSE — '$target' is not valid JSON; fix it first (a malformed settings file silently disables all its settings)" >&2
    exit 3
  fi
  cur=$(cat "$target")
else
  cur='{}'
fi

installed=0
if printf '%s' "$cur" | "$JQ" -e --arg r1 "$r1" --arg r2 "$r2" --arg r3 "$r3" --arg r4 "$r4" --arg am "$am" '
    ((.permissions.allow // []) | (index($r1) != null and index($r2) != null and index($r3) != null and index($r4) != null))
    and ((.autoMode.allow // []) | index($am) != null)' >/dev/null 2>&1; then
  installed=1
fi

if [ "$check" = 1 ]; then
  if [ "$installed" = 1 ]; then
    echo "install-permission-rules: present in $target"
    exit 0
  fi
  echo "install-permission-rules: absent from $target"
  exit 4
fi

if [ "$installed" = 1 ]; then
  echo "install-permission-rules: already installed in $target — no changes"
  exit 0
fi

new=$(printf '%s' "$cur" | "$JQ" --arg r1 "$r1" --arg r2 "$r2" --arg r3 "$r3" --arg r4 "$r4" --arg am "$am" '
  .permissions.allow = ((.permissions.allow // []) + ([$r1, $r2, $r3, $r4] - (.permissions.allow // [])))
  | .autoMode.allow =
      (if (.autoMode.allow // []) == [] then ["$defaults", $am]
       elif (.autoMode.allow | index($am)) == null then .autoMode.allow + [$am]
       else .autoMode.allow end)')

mkdir -p "$(dirname "$target")"
# Backup only when there is a real prior file to protect, then land the new
# content atomically (tmp+mv) so a crash can never leave a half-written file.
if [ -f "$target" ]; then
  bak="$target.bak.$(date +%s)"
  cp "$target" "$bak"
else
  bak=""
fi
tmp="$target.tmp.$$"
trap 'rm -f "$tmp"' EXIT
printf '%s\n' "$new" > "$tmp"
# Paranoid post-check: never install something jq cannot re-read.
"$JQ" -e . "$tmp" >/dev/null 2>&1 || { echo "install-permission-rules: internal error — generated JSON invalid, aborting" >&2; exit 3; }
mv "$tmp" "$target"

if [ -n "$bak" ]; then
  echo "install-permission-rules: installed into $target (backup: $bak)"
else
  echo "install-permission-rules: installed into $target (new file)"
fi
