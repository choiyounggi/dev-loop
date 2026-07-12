#!/bin/sh
# launch-session.sh — start a claude session inside a tmux window, pass the
# trust / permission screen, then inject a one-line prompt.
#
# usage: launch-session.sh <session> <worktree> <perm-mode> <prompt-oneliner>
#   <session>   tmux session name (e.g. lo-1)
#   <worktree>  absolute path to the task worktree
#   <perm-mode> claude --permission-mode value (e.g. bypassPermissions)
#   <prompt>    one-line prompt to inject (no newlines)
#
# Trust pitfall: on a fresh worktree, claude's first launch shows a trust /
# permission screen that swallows a start-arg prompt. So we pass the screen,
# confirm the REPL is ready, then send-keys the prompt separately. The screen
# wording is version-dependent (design §8.11) — patterns are kept in one place.
set -eu
TMUX=$(command -v tmux) || { echo "launch-session: tmux not found" >&2; exit 127; }

[ $# -eq 4 ] || { echo "usage: launch-session.sh <session> <worktree> <perm> <prompt>" >&2; exit 1; }
session="$1"; wt="$2"; perm="$3"; prompt="$4"

# whitelist the permission mode — it is interpolated into a shell command sent to
# the pane, so reject anything unexpected (injection guard).
case "$perm" in
  bypassPermissions|acceptEdits|plan|default) : ;;
  *) echo "launch-session: invalid permission mode '$perm'" >&2; exit 2 ;;
esac

# locate the claude binary (avoid nvm lazy wrappers / shell functions)
CLAUDE=""
for c in "$HOME"/.nvm/versions/node/*/bin/claude /opt/homebrew/bin/claude /usr/local/bin/claude "$HOME"/.local/bin/claude; do
  [ -x "$c" ] && { CLAUDE="$c"; break; }
done
[ -n "$CLAUDE" ] || CLAUDE=$(command -v claude 2>/dev/null || true)
[ -x "$CLAUDE" ] || { echo "launch-session: claude CLI not found" >&2; exit 127; }
claudedir=$(dirname "$CLAUDE")   # also where node lives for nvm installs

if "$TMUX" has-session -t "$session" 2>/dev/null; then
  echo "-> session $session exists — skip"; exit 0
fi

"$TMUX" new-session -d -s "$session" -x 220 -y 50 -c "$wt"
"$TMUX" send-keys -t "$session" "export PATH=\"$claudedir:\$PATH\" && \"$CLAUDE\" --permission-mode $perm" Enter

# Pass trust screen + permission warning, wait for REPL ready (~60s).
# NOTE: the bypassPermissions warning defaults to "1. No, exit" — pressing Enter
# would quit claude. We must Down->Enter to pick "Yes, I accept". The ready/accept
# patterns are matched before the generic trust patterns.
ready=0; i=0; pane=""
while [ $i -lt 30 ]; do
  sleep 2
  pane=$("$TMUX" capture-pane -t "$session" -p 2>/dev/null || echo "")
  case "$pane" in
    *"bypass permissions on"*|*"shift+tab to cycle"*|*"for shortcuts"*|*"? for"*)
      ready=1; break ;;
    *"Yes, I accept"*|*"accept all responsibility"*)
      "$TMUX" send-keys -t "$session" Down; sleep 1; "$TMUX" send-keys -t "$session" Enter ;;
    *"Do you trust"*|*"trust the files"*|*"Enter to confirm"*)
      "$TMUX" send-keys -t "$session" Enter ;;
  esac
  i=$((i+1))
done

if [ "$ready" -ne 1 ]; then
  echo "launch-session: $session REPL not ready — manual check (last screen below)" >&2
  echo "$pane" | tail -8 >&2
  exit 4
fi

# inject the one-line prompt (literal) then submit
"$TMUX" send-keys -t "$session" -l "$prompt"
"$TMUX" send-keys -t "$session" Enter
echo "ok: $session launched + prompt injected"
