#!/usr/bin/env bash
# dev-loop — Stop hook: harvest ★ Insight blocks from this session's transcript
# into ~/.dev-loop/queue/<session>.jsonl. Non-blocking, offline, best-effort.
#
# It never edits the wiki and never opens a PR — promotion is the separate,
# on-demand /dev-loop:knowledge-flush skill (which researches + verifies + routes
# before any PR). Mirrors rtb-lore's harvest/promote split so a session end
# never waits on network or git.
set +e

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARVEST_JS="$HOOK_DIR/harvest.js"

# Read the Stop-hook stdin once and hand it to the node parser.
INPUT="$(cat)"

command -v node >/dev/null 2>&1 || exit 0
[ -f "$HARVEST_JS" ] || exit 0

# Background + disown so the Stop event returns immediately.
(
  printf '%s' "$INPUT" | node "$HARVEST_JS" >/dev/null 2>&1
) &
disown 2>/dev/null

exit 0
