#!/usr/bin/env bash
# dev-loop — generate the R1/R0 copy of each tier-graded orchestrate agent.
#
# The Agent tool overrides a subagent's `model` per call but never its
# `effort`; effort lives only in the agent file's frontmatter. So each role in
# orchestrate's Tier to pipeline profile table has two files: the base
# `agents/<name>.md` (the R3/R2 profile) and a generated `agents/<name>-r1.md`
# with the same body, `name: <name>-r1`, and the effort one step lower (R1/R0),
# never below high — analysis, design, and QA agents run at claude-opus-5-5
# high or above at every tier. Edit only the base file, then re-run this script.
#
# Usage: gen-agent-tier-variants.sh [--check] [agents-dir]
#   (default)  write every <name>-r1.md
#   --check    write nothing; exit 1 when any <name>-r1.md is missing or differs
#              from what this script would generate (CI drift guard)
# Exit: 0 ok, 1 drift (--check), 2 a base file is missing or malformed.

set -u

# base agent name -> its R1/R0 effort (one step below the base's own effort,
# floored at high)
VARIANTS="task-analyst:high task-planner:high test-quality-auditor:high task-reviewer:high integration-reviewer:xhigh"

check=0
if [ "${1:-}" = "--check" ]; then check=1; shift; fi
dir="${1:-$(cd "$(dirname "$0")/../agents" && pwd)}"

render() { # <base file> <base name> <r1 effort>
  awk -v base="$2" -v eff="$3" '
    BEGIN { fm = 0; names = 0; effs = 0 }
    /^---$/ {
      fm++; print
      if (fm == 2) printf "\n<!-- GENERATED from agents/%s.md by scripts/gen-agent-tier-variants.sh; edit the base file and re-run -->\n", base
      next
    }
    fm == 1 && $0 == "name: " base { print "name: " base "-r1"; names++; next }
    fm == 1 && /^effort: / { print "effort: " eff; effs++; next }
    fm == 1 && /^description: / { sub(/^description: /, "description: R1/R0 tier copy (one effort step lower, never below high) of the " base " agent. "); print; next }
    { print }
    END { if (fm < 2 || names != 1 || effs != 1) exit 3 }
  ' "$1"
}

rc=0
for pair in $VARIANTS; do
  name="${pair%%:*}"; eff="${pair#*:}"
  src="$dir/$name.md"; dst="$dir/$name-r1.md"
  if [ ! -f "$src" ]; then
    echo "gen-agent-tier-variants: missing base $src" >&2; exit 2
  fi
  if ! out="$(render "$src" "$name" "$eff")"; then
    echo "gen-agent-tier-variants: $src needs one 'name: $name' and one 'effort:' line inside its frontmatter" >&2
    exit 2
  fi
  if [ "$check" = 1 ]; then
    if [ ! -f "$dst" ] || [ "$(cat "$dst")" != "$out" ]; then
      echo "gen-agent-tier-variants: $dst is stale — run scripts/gen-agent-tier-variants.sh" >&2
      rc=1
    fi
  else
    printf '%s\n' "$out" > "$dst"
  fi
done
exit "$rc"
