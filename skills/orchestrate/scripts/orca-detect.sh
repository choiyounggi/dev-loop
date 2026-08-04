#!/bin/sh
# orca-detect.sh — exit 0 iff Orca (the orchestration substrate) is installed,
# its orchestration skill is present, AND the runtime is reachable. Used to gate
# whether the orchestrator spawns/monitors workers via Orca (which handles the
# trust/TUI screen and tracks sessions natively) instead of raw tmux.
#
# env (also test hooks):
#   ORCA_BIN          orca executable (default: orca)
#   ORCA_SKILLS_DIR   orchestration skill dir (default: ~/.agents/skills/orchestration)
#   ORCA_STATUS_JSON  canned `orca status --json` output (skips the real call)
set -u

JQ=$(command -v jq) || exit 1
ORCA="${ORCA_BIN:-orca}"
skills_dir="${ORCA_SKILLS_DIR:-${HOME}/.agents/skills/orchestration}"

# 1) the user's orca orchestration skill must be installed
[ -d "$skills_dir" ] || exit 1

# 2) the runtime must be up and reachable
if [ -n "${ORCA_STATUS_JSON:-}" ]; then
  status="$ORCA_STATUS_JSON"
else
  command -v "$ORCA" >/dev/null 2>&1 || exit 1
  status=$("$ORCA" status --json 2>/dev/null) || exit 1
fi

reachable=$(printf '%s' "$status" | "$JQ" -r '.result.runtime.reachable // false' 2>/dev/null)
[ "$reachable" = "true" ] || exit 1
exit 0
