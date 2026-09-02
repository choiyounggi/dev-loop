#!/bin/sh
# resolve-tools.sh — resolve the dev-loop tool profile by layering
# config files over built-in defaults (git-config style precedence):
#
#   built-in defaults  <  ~/.claude/dev-loop/tools.json  <  <repo>/.dev-loop/tools.json
#
# (The old loop-orchestrator paths — ~/.claude/loop-orchestrator/tools.json and
#  <repo>/.loop-orchestrator/tools.json — are still read as a fallback so existing
#  configs keep working after the rename.)
#
# Each capability role (intake / knowledge / tacit / verify / explore /
# design / research, plus any custom role) is merged independently and field-wise, so a project file can
# override one role — or just one field of a role — and inherit everything else.
# To drop an inherited value, set that field to null.
#
# A role is a tool or information source injected into ONE loop step — never a
# loop itself. Do not map a role to a tool that runs its own implement/verify/
# retry loop or another orchestrator (that nests loops); see references/tool-profile.md.
#
# usage:
#   resolve-tools.sh             # print the resolved profile as JSON (default)
#   resolve-tools.sh --summary   # one human-readable line per role
#   resolve-tools.sh --role verify # print just the resolved object for one role
#
# env overrides (mainly for tests / non-standard layouts):
#   DEV_LOOP_CONFIG_HOME      per-user config path
#                             (default: ~/.claude/dev-loop/tools.json)
#   DEV_LOOP_CONFIG_PROJECT   per-repo config path
#                             (default: <git-root-or-PWD>/.dev-loop/tools.json)
#   LOOP_ORCH_CONFIG_HOME / LOOP_ORCH_CONFIG_PROJECT — legacy fallbacks (still honored)
set -eu

JQ=$(command -v jq) || { echo "resolve-tools: jq not found" >&2; exit 127; }

# Built-in defaults: every role unset → kind "default" (use loop-implement's own
# generic behavior). Keeps the plugin fully functional with zero config.
DEFAULTS='{
  "intake":    {"kind":"default","when":"work-list source — issue tracker (orchestrate); unset = decompose the natural-language goal directly"},
  "knowledge": {"kind":"default","when":"domain facts, policy, code/status values (step 1)"},
  "tacit":     {"kind":"default","when":"past incidents, edge cases, danger zones (step 1/6)"},
  "verify":    {"kind":"default","when":"running tests / build / QA checks (step 5)"},
  "explore":   {"kind":"default","when":"locating code, symbols, call sites (step 1)"},
  "design":    {"kind":"default","when":"visual/UI spec for FE/UI tasks, e.g. a Figma link in the issue — read the referenced design before implementing (orchestrate Phase 0/2; loop-implement step 1)"},
  "research":  {"kind":"default","when":"external best-practice/insight search during plan phases A/B; resolution order owned by loop-implement SKILL (configured tool -> brave-search MCP -> built-in WebSearch -> ABANDON)"}
}'

# Per-user config: explicit env wins; else the dev-loop path; else the legacy
# loop-orchestrator path if it exists; else the canonical dev-loop path.
if [ -n "${DEV_LOOP_CONFIG_HOME:-}" ]; then
  home_cfg="$DEV_LOOP_CONFIG_HOME"
elif [ -n "${LOOP_ORCH_CONFIG_HOME:-}" ]; then
  home_cfg="$LOOP_ORCH_CONFIG_HOME"
elif [ -f "$HOME/.claude/dev-loop/tools.json" ]; then
  home_cfg="$HOME/.claude/dev-loop/tools.json"
elif [ -f "$HOME/.claude/loop-orchestrator/tools.json" ]; then
  home_cfg="$HOME/.claude/loop-orchestrator/tools.json"
else
  home_cfg="$HOME/.claude/dev-loop/tools.json"
fi

# Per-repo config: same precedence, resolved against the repo root.
if [ -n "${DEV_LOOP_CONFIG_PROJECT:-}" ]; then
  proj_cfg="$DEV_LOOP_CONFIG_PROJECT"
elif [ -n "${LOOP_ORCH_CONFIG_PROJECT:-}" ]; then
  proj_cfg="$LOOP_ORCH_CONFIG_PROJECT"
else
  root=$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)
  if [ -f "$root/.dev-loop/tools.json" ]; then
    proj_cfg="$root/.dev-loop/tools.json"
  elif [ -f "$root/.loop-orchestrator/tools.json" ]; then
    proj_cfg="$root/.loop-orchestrator/tools.json"
  else
    proj_cfg="$root/.dev-loop/tools.json"
  fi
fi

# Load a layer as compact JSON; warn + skip if missing/invalid (fail-open to {}).
load() {
  f="$1"
  [ -f "$f" ] || { echo '{}'; return; }
  if "$JQ" -e 'type=="object"' "$f" >/dev/null 2>&1; then
    "$JQ" -c '.' "$f"
  else
    echo "resolve-tools: ignoring invalid config '$f' (not a JSON object)" >&2
    echo '{}'
  fi
}

home_json=$(load "$home_cfg")
proj_json=$(load "$proj_cfg")

# Deep-merge, right wins: defaults < home < project.
resolved=$(printf '%s\n%s\n%s\n' "$DEFAULTS" "$home_json" "$proj_json" | "$JQ" -s '.[0] * .[1] * .[2]')

case "${1:-}" in
  ''|--json)
    printf '%s\n' "$resolved"
    ;;
  --summary)
    printf '%s' "$resolved" | "$JQ" -r '
      to_entries[] |
      .key + ": " +
      (if (.value.kind // "default") == "default"
        then "default (built-in behavior)"
        else (.value.kind | tostring) + " " + (.value.ref // "?")
             + (if .value.how then " — " + .value.how else "" end)
      end)
      + (if .value.when then "  [when: " + .value.when + "]" else "" end)'
    ;;
  --role)
    role="${2:?resolve-tools: --role needs a role name}"
    printf '%s' "$resolved" | "$JQ" -c --arg r "$role" '.[$r] // {"kind":"default"}'
    ;;
  *)
    echo "resolve-tools: unknown arg '$1' (use --summary | --role <name> | --json)" >&2
    exit 2
    ;;
esac
