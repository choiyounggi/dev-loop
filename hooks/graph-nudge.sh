#!/usr/bin/env bash
# dev-loop — SessionStart: advisory nudge to onboard the configured workspace
# onto the graphify code graph (a repo with an absent graph, a cannot-evaluate
# freshness/root, or hooks that are none/partial). Reports only — never builds
# a graph and never installs anything itself; the fix runs from
# /dev-loop:graph-setup after the user's explicit consent.
# Silent when no workspace is configured. Disable entirely with
# DEV_LOOP_GRAPH_NUDGE=0 (also accepts off/false).
set +e

case "${DEV_LOOP_GRAPH_NUDGE:-1}" in
  0|off|false) exit 0 ;;
esac

# Don't nudge inside the flush working checkout.
case "${CLAUDE_PROJECT_DIR:-$PWD}" in
  "$HOME/.dev-loop/repo"*) exit 0 ;;
esac

HERE=$(cd "$(dirname "$0")" && pwd -P)

ws=$(sh "$HERE/../scripts/resolve-tools.sh" --role workspace 2>/dev/null)
printf '%s' "$ws" | jq -e '(.roots? // []) | length > 0' >/dev/null 2>&1 || exit 0

# Rate-limit: skip if nudged within the last 7 days.
MARK="$HOME/.dev-loop/.graph-nudged"
if [ -f "$MARK" ] && [ -n "$(find "$MARK" -mtime -7 2>/dev/null)" ]; then
  exit 0
fi

depth=$(printf '%s' "$ws" | jq -r '.depth // 2')

excl=()
while IFS= read -r g; do
  [ -n "$g" ] && excl+=(--exclude "$g")
done < <(printf '%s' "$ws" | jq -r '.exclude[]? // empty')

roots=()
while IFS= read -r r; do
  [ -n "$r" ] && roots+=("$r")
done < <(printf '%s' "$ws" | jq -r '.roots[]? // empty')

out=$(mktemp)
sh "$HERE/../scripts/graph-workspace.sh" --status --depth "$depth" "${excl[@]}" -- "${roots[@]}" </dev/null >"$out" 2>/dev/null

# A hit is a repo line with an absent/cannot-evaluate graph or none/partial
# hooks, or a top-level cannot-evaluate (a missing root, bad flags).
# `hooks: cannot-evaluate <reason>` (e.g. a core.hooksPath override) is not a
# hit on purpose — /dev-loop:graph-setup cannot fix that for the user either.
hits=$(grep -E '^cannot-evaluate|	(absent|cannot-evaluate)|hooks: (none|partial)' "$out")
if [ -z "$hits" ]; then
  rm -f "$out"
  exit 0
fi
rm -f "$out"

count=$(printf '%s\n' "$hits" | grep -c .)
shown=$(printf '%s\n' "$hits" | head -10)
more=$((count - 10))

MSG="# dev-loop — code graph: ${count} repo(s) need onboarding

${shown}"
if [ "$more" -gt 0 ]; then
  MSG="${MSG}
… and ${more} more"
fi
MSG="${MSG}

Run /dev-loop:graph-setup to build absent graphs and install the merge hook (asks before every install; nothing runs automatically). Silence with DEV_LOOP_GRAPH_NUDGE=0."

json=$(printf '%s' "$MSG" | node -e '
const fs=require("fs");let s="";try{s=fs.readFileSync(0,"utf8")}catch{}
process.stdout.write(JSON.stringify({hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:s}}));
' 2>/dev/null)

# Touch the weekly marker only once the message actually emitted, so a node
# failure does not silence the nudge for a week.
if [ -n "$json" ]; then
  mkdir -p "$HOME/.dev-loop" 2>/dev/null
  touch "$MARK" 2>/dev/null
  printf '%s' "$json"
fi

exit 0
