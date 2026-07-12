#!/usr/bin/env bash
# loop-orchestrator Stop hook — verification-loop integrity gate.
#
# Blocks a MANAGED session from ending while its verification loop is still
# incomplete, so a session can't quietly stop mid-loop (or after weakening
# tests) without reaching a terminal phase. No-op for any session that isn't
# under loop-orchestrator control. See design.md §8.4.
#
# Stop hook stdin is FLAT JSON (verified against real hook payloads):
#   { "cwd": "...", "session_id": "...", "transcript_path": "...",
#     "stop_hook_active": false }
# Block protocol: exit 2 + message on stderr → Claude keeps going.
set +e

INPUT=$(cat)
JQ=$(command -v jq)

if [ -n "$JQ" ]; then
  CWD=$(printf '%s' "$INPUT" | "$JQ" -r '.cwd // empty' 2>/dev/null)
  ACTIVE=$(printf '%s' "$INPUT" | "$JQ" -r '.stop_hook_active // false' 2>/dev/null)
else
  CWD="$PWD"; ACTIVE="false"
fi
[ -z "$CWD" ] && CWD="$PWD"
# Normalize to a physical path so /private, symlinks, and /var->/private/var
# differences don't break the worktree match (macOS).
CWD=$(cd "$CWD" 2>/dev/null && pwd -P || printf '%s' "$CWD")

# Already re-entered after a previous block → never loop forever.
[ "$ACTIVE" = "true" ] && exit 0
# Without jq we cannot read status JSON. jq is required for the whole
# orchestration (status-update needs it too), so a jq-less env can't run a
# managed session anyway → this no-op is harmless.
[ -z "$JQ" ] && exit 0

# Locate .orchestration/status by walking up from the session cwd.
dir="$CWD"; statusdir=""
while [ -n "$dir" ] && [ "$dir" != "/" ]; do
  if [ -d "$dir/.orchestration/status" ]; then
    statusdir="$dir/.orchestration/status"; break
  fi
  dir=$(dirname "$dir")
done
[ -z "$statusdir" ] && exit 0   # not a managed workspace

# Find the status entry whose worktree == this session's cwd; inspect its phase.
incomplete_phase=""
for f in "$statusdir"/*.json; do
  [ -e "$f" ] || continue
  wt=$("$JQ" -r '.worktree // empty' "$f" 2>/dev/null)
  ph=$("$JQ" -r '.phase // empty' "$f" 2>/dev/null)
  [ -n "$wt" ] && wt=$(cd "$wt" 2>/dev/null && pwd -P || printf '%s' "$wt")
  [ "$wt" = "$CWD" ] || continue
  case "$ph" in
    done|approved|merged|failed|"") : ;;   # terminal/unknown — allow stop
    *) incomplete_phase="$ph" ;;
  esac
  break   # one status entry per worktree; stop at the matched one
done

if [ -n "$incomplete_phase" ]; then
  echo "loop-orchestrator: verification loop incomplete (phase=${incomplete_phase})." >&2
  echo "Finish the loop-implement cycle — tests written, test-quality-auditor PASS, definition-of-done met — then emit the completion signal (status-update) before stopping." >&2
  exit 2
fi
exit 0
