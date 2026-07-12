#!/usr/bin/env bash
# dev-loop — SessionStart: gently nudge the user to configure the tool profile
# (knowledge=wiki, verify=test command, …) IF they haven't yet.
#
# Fires only when no tools.json is configured anywhere, and at most once a week
# (a marker suppresses it) so it never nags. Once configured, it goes silent.
# Disable entirely with DEV_LOOP_CONFIG_NUDGE=0.
set +e

[ "${DEV_LOOP_CONFIG_NUDGE:-1}" = "0" ] && exit 0

# Don't nudge inside the flush working checkout.
case "${CLAUDE_PROJECT_DIR:-$PWD}" in
  "$HOME/.dev-loop/repo"*) exit 0 ;;
esac

PROJ="${CLAUDE_PROJECT_DIR:-$PWD}"

# Already configured? (dev-loop or legacy path, global or per-repo, or env.)
configured=0
for f in \
  "$HOME/.claude/dev-loop/tools.json" \
  "$HOME/.claude/loop-orchestrator/tools.json" \
  "$PROJ/.dev-loop/tools.json" \
  "$PROJ/.loop-orchestrator/tools.json" \
  "${DEV_LOOP_CONFIG_HOME:-}" "${LOOP_ORCH_CONFIG_HOME:-}" \
  "${DEV_LOOP_CONFIG_PROJECT:-}" "${LOOP_ORCH_CONFIG_PROJECT:-}"; do
  [ -n "$f" ] && [ -f "$f" ] && { configured=1; break; }
done
[ "$configured" -eq 1 ] && exit 0

# Rate-limit: skip if nudged within the last 7 days.
MARK="$HOME/.dev-loop/.config-nudged"
if [ -f "$MARK" ] && [ -n "$(find "$MARK" -mtime -7 2>/dev/null)" ]; then
  exit 0
fi
mkdir -p "$HOME/.dev-loop" 2>/dev/null
touch "$MARK" 2>/dev/null

read -r -d '' MSG <<'EOF'
# dev-loop — optional one-time setup

dev-loop works with zero config, but you'll get more out of it by mapping its
capability roles to your real tools. Notably:
  • `verify`    → your project's actual test / build command (used in the loop's run step)
  • `knowledge` → your domain/team wiki or knowledge MCP (external facts — the bundled best-practice wiki needs no setup)
  • also: `explore` (code search), `tacit` (incidents), `design` (Figma)

Run **/dev-loop:configure** to set these up (writes ~/.claude/dev-loop/tools.json,
or <repo>/.dev-loop/tools.json for a team-shared, per-repo profile).

(This reminder shows at most weekly until you configure, then stops. Silence it
now with DEV_LOOP_CONFIG_NUDGE=0.)
EOF

printf '%s' "$MSG" | node -e '
const fs=require("fs");let s="";try{s=fs.readFileSync(0,"utf8")}catch{}
process.stdout.write(JSON.stringify({hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:s}}));
' 2>/dev/null

exit 0
