#!/usr/bin/env bash
# loop-orchestrator preflight — detect required CLIs, resolve their paths, and
# advise on missing ones. ADVISORY ONLY: never auto-installs, never blocks
# (exit 0 always). Auto-install (brew, with consent) happens at orchestrate
# skill entry, not here — this runs on every SessionStart of any plugin-active
# session, so it must stay side-effect free. See design.md §8.1, §8.3.
set -u

resolve() { command -v "$1" 2>/dev/null || true; }

GIT_BIN=$(resolve git)
TMUX_BIN=$(resolve tmux)
JQ_BIN=$(resolve jq)

# Emit resolved absolute paths so callers can source them instead of
# hardcoding /usr/bin/git or /opt/homebrew/bin/tmux (portability, design §8.1).
echo "LOOP_GIT=${GIT_BIN}"
echo "LOOP_TMUX=${TMUX_BIN}"
echo "LOOP_JQ=${JQ_BIN}"

missing=()
[ -z "$GIT_BIN" ]  && missing+=("git")
[ -z "$TMUX_BIN" ] && missing+=("tmux")
[ -z "$JQ_BIN" ]   && missing+=("jq")

if [ "${#missing[@]}" -gt 0 ]; then
  {
    echo "loop-orchestrator: missing required CLIs: ${missing[*]}"
    case "${OSTYPE:-}" in
      darwin*) echo "  macOS:           brew install ${missing[*]}" ;;
      linux*)  echo "  Debian/Ubuntu:   sudo apt-get install -y ${missing[*]}"
               echo "  RHEL/CentOS:     sudo yum install -y ${missing[*]}" ;;
      *)       echo "  install ${missing[*]} via your package manager" ;;
    esac
    echo "  (preflight never auto-installs; install manually, then re-run.)"
  } >&2
fi

exit 0
