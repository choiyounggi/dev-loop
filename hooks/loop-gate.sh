#!/usr/bin/env bash
# loop-orchestrator Stop hook — verification-loop integrity gate.
#
# Two independent gates, both enforced at session stop:
#
# GATE 1 (phase, managed sessions only): blocks a MANAGED worker session from
# ending while its recorded phase is pending|planning|implementing|rework —
# mid-loop abandonment. Every other phase (done/approved/merged/failed/
# plan_ready/impl_done, or an unknown/unset value) is terminal or an
# instructed wait-phase and allows the stop. Blocking additionally requires
# THIS session to be the managed worker: when the matched status entry has a
# non-empty .session, only a tmux session whose name equals it is blocked — a
# coordinator visiting the same worktree, or any non-tmux session, is never
# blocked. Records without .session (pre-launch-session.sh) fall back to
# cwd-match only. See design.md §8.4. The phase value is SELF-REPORTED by the
# worker (status-update), which is why gate 2 exists.
#
# GATE 2 (gates ledger, any session): if the workspace has gates ledgers
# (.dev-loop/gates/*.md — written by loop-implement step 0), parse them via
# gate-check.sh --status (parse only, NEVER executes CHECK commands) and
# block while any gate is UNMET or CLAIMED (checked box without evidence) or
# a ledger is malformed. Unlike gate 1 this does not trust a self-reported
# phase — it reads the machine-checkable evidence ledger itself. To avoid
# trapping a session forever, a per-session no-progress counter releases the
# gate after MAX_GATE_BLOCKS consecutive blocks with an unchanged ledger
# state (progress = the ledger content hash changed, which resets the count).
# Gate 2 therefore runs even when stop_hook_active=true.
#
# Stop hook stdin is FLAT JSON (verified against real hook payloads):
#   { "cwd": "...", "session_id": "...", "transcript_path": "...",
#     "stop_hook_active": false }
# Block protocol: exit 2 + message on stderr → Claude keeps going.
set +e

MAX_GATE_BLOCKS=6
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)
GATE_CHECK="${LOOP_GATE_CHECK:-$SCRIPT_DIR/../skills/loop-implement/scripts/gate-check.sh}"

INPUT=$(cat)
JQ=$(command -v jq)

if [ -n "$JQ" ]; then
  CWD=$(printf '%s' "$INPUT" | "$JQ" -r '.cwd // empty' 2>/dev/null)
  ACTIVE=$(printf '%s' "$INPUT" | "$JQ" -r '.stop_hook_active // false' 2>/dev/null)
  SESSION_ID=$(printf '%s' "$INPUT" | "$JQ" -r '.session_id // empty' 2>/dev/null)
else
  CWD="$PWD"; ACTIVE="false"; SESSION_ID=""
fi
[ -z "$CWD" ] && CWD="$PWD"
[ -z "$SESSION_ID" ] && SESSION_ID="anonymous"
# Normalize to a physical path so /private, symlinks, and /var->/private/var
# differences don't break the worktree match (macOS).
CWD=$(cd "$CWD" 2>/dev/null && pwd -P || printf '%s' "$CWD")

# Without jq we can read neither status JSON nor the gate-hook state. jq is
# required for the whole orchestration (status-update needs it too), so a
# jq-less env can't run a managed session anyway → this no-op is harmless.
[ -z "$JQ" ] && exit 0

# ---------------------------------------------------------------- GATE 1 --
# Re-entry after a previous block skips only the phase gate (its block
# message is a one-shot instruction); the ledger gate below has its own
# bounded no-progress release and keeps running.
if [ "$ACTIVE" != "true" ]; then
  # Locate .orchestration/status by walking up from the session cwd.
  dir="$CWD"; statusdir=""
  while [ -n "$dir" ] && [ "$dir" != "/" ]; do
    if [ -d "$dir/.orchestration/status" ]; then
      statusdir="$dir/.orchestration/status"; break
    fi
    dir=$(dirname "$dir")
  done

  if [ -n "$statusdir" ]; then
    # Find the status entry whose worktree == this session's cwd.
    incomplete_phase=""
    for f in "$statusdir"/*.json; do
      [ -e "$f" ] || continue
      wt=$("$JQ" -r '.worktree // empty' "$f" 2>/dev/null)
      ph=$("$JQ" -r '.phase // empty' "$f" 2>/dev/null)
      sess=$("$JQ" -r '.session // empty' "$f" 2>/dev/null)
      [ -n "$wt" ] && wt=$(cd "$wt" 2>/dev/null && pwd -P || printf '%s' "$wt")
      [ "$wt" = "$CWD" ] || continue

      # Session identity: only the managed tmux worker is blockable. A record
      # without .session (pre-launch-session.sh) falls back to cwd-match alone.
      if [ -n "$sess" ]; then
        is_worker=0
        if [ -n "$TMUX" ]; then
          tmux_bin="${LOOP_GATE_TMUX:-tmux}"
          cur_sess=$("$tmux_bin" display-message -p '#S' 2>/dev/null)
          [ -n "$cur_sess" ] && [ "$cur_sess" = "$sess" ] && is_worker=1
        fi
        [ "$is_worker" -eq 1 ] || break   # coordinator, or non-matching/non-tmux
      fi

      case "$ph" in
        pending|planning|implementing|rework) incomplete_phase="$ph" ;;
        *) : ;;   # terminal, instructed-wait, or unrecognized — allow stop
      esac
      break   # one status entry per worktree; stop at the matched one
    done

    if [ -n "$incomplete_phase" ]; then
      echo "loop-orchestrator: verification loop incomplete (phase=${incomplete_phase})." >&2
      echo "Finish the loop-implement cycle — tests written, test-quality-auditor PASS, definition-of-done met — then emit the completion signal (status-update) before stopping." >&2
      exit 2
    fi
  fi
fi

# ---------------------------------------------------------------- GATE 2 --
# Locate the nearest .dev-loop/gates dir by walking up from the session cwd.
dir="$CWD"; gatesdir=""
while [ -n "$dir" ] && [ "$dir" != "/" ]; do
  if [ -d "$dir/.dev-loop/gates" ]; then
    gatesdir="$dir/.dev-loop/gates"; break
  fi
  dir=$(dirname "$dir")
done
[ -z "$gatesdir" ] && exit 0            # no ledgers — nothing to enforce

ledgers=$(find "$gatesdir" -maxdepth 1 -name '*.md' -type f 2>/dev/null | sort)
[ -z "$ledgers" ] && exit 0
[ -x "$GATE_CHECK" ] || [ -f "$GATE_CHECK" ] || exit 0   # checker missing — never trap

# Parse-only status; NEVER executes CHECK commands from a Stop hook.
# shellcheck disable=SC2086
STATUS_OUT=$(printf '%s\n' "$ledgers" | tr '\n' '\0' | xargs -0 bash "$GATE_CHECK" --status 2>&1)
STATUS_CODE=$?
if [ "$STATUS_CODE" -eq 0 ]; then
  # All gates met/abandoned — clear this session's counter state.
  STATE_FILE="$(dirname "$gatesdir")/gate-hook-state.json"
  [ -f "$STATE_FILE" ] && rm -f "$STATE_FILE" 2>/dev/null
  exit 0
fi

# Unmet/claimed gates or a malformed ledger. Bounded no-progress release:
# hash the ledger contents; a changed hash means progress and resets blocks.
STATE_FILE="$(dirname "$gatesdir")/gate-hook-state.json"
SESSION_KEY=$(printf '%s' "$SESSION_ID" | cksum | cut -d' ' -f1)
# shellcheck disable=SC2086
CONTENT_HASH=$(printf '%s\n' "$ledgers" | tr '\n' '\0' | xargs -0 cat 2>/dev/null | cksum | cut -d' ' -f1)

BLOCKS=1
if [ -f "$STATE_FILE" ]; then
  prev_hash=$("$JQ" -r --arg k "$SESSION_KEY" '.sessions[$k].hash // empty' "$STATE_FILE" 2>/dev/null)
  prev_blocks=$("$JQ" -r --arg k "$SESSION_KEY" '.sessions[$k].blocks // 0' "$STATE_FILE" 2>/dev/null)
  case "$prev_blocks" in ''|*[!0-9]*) prev_blocks=0 ;; esac
  if [ "$prev_hash" = "$CONTENT_HASH" ]; then
    BLOCKS=$((prev_blocks + 1))
  fi
fi

TMP_STATE=$(mktemp)
if [ -f "$STATE_FILE" ]; then
  "$JQ" --arg k "$SESSION_KEY" --arg h "$CONTENT_HASH" --argjson b "$BLOCKS" \
    '.sessions[$k] = {hash: $h, blocks: $b}' "$STATE_FILE" > "$TMP_STATE" 2>/dev/null \
    || printf '{"sessions":{"%s":{"hash":"%s","blocks":%s}}}\n' "$SESSION_KEY" "$CONTENT_HASH" "$BLOCKS" > "$TMP_STATE"
else
  printf '{"sessions":{"%s":{"hash":"%s","blocks":%s}}}\n' "$SESSION_KEY" "$CONTENT_HASH" "$BLOCKS" > "$TMP_STATE"
fi
mv "$TMP_STATE" "$STATE_FILE" 2>/dev/null

if [ "$BLOCKS" -gt "$MAX_GATE_BLOCKS" ]; then
  echo "loop-gate: releasing after $MAX_GATE_BLOCKS blocks without ledger progress; unmet gates remain." >&2
  exit 0
fi

UNMET_LIST=$(printf '%s\n' "$STATUS_OUT" | grep -E '^(UNMET|CLAIMED|PARSE)' | head -5)
echo "loop-gate: gates ledger has unmet items — the done-claim is not yet proven:" >&2
printf '%s\n' "$UNMET_LIST" >&2
echo "Run: sh <plugin>/skills/loop-implement/scripts/gate-check.sh --run ${gatesdir}/*.md to execute CHECK commands and record evidence. A checked box with EVIDENCE: pending counts as unmet (a claim is not proof). If a gate is genuinely impossible, add 'ABANDON: <id> <reason>' and surface it in the task report." >&2
exit 2
