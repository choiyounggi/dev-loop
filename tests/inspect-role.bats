#!/usr/bin/env bats
# The `inspect` capability role (reference study of an existing product during
# wiki-plan Phase A3). Covers normal (default + configured resolution, the
# analysis template block, a gate-A run with a filled Reference study block),
# error (an invalid config file still resolves inspect to default), and
# boundary (an empty override object) cases, plus the doc gates that keep the
# role listed in every place the other roles are listed.

setup() {
  ROOT="${BATS_TEST_DIRNAME}/.."
  RT="${ROOT}/scripts/resolve-tools.sh"
  PG="${ROOT}/skills/wiki-plan/scripts/plan-gate.sh"
  GC="${ROOT}/skills/loop-implement/scripts/gate-check.sh"
  FIX="${BATS_TEST_DIRNAME}/fixtures/plan-gate"
  HOME_CFG="${BATS_TEST_TMPDIR}/home-tools.json"
  PROJ_CFG="${BATS_TEST_TMPDIR}/proj-tools.json"
  export LOOP_ORCH_CONFIG_HOME="$HOME_CFG"
  export LOOP_ORCH_CONFIG_PROJECT="$PROJ_CFG"
  WORK="${BATS_TEST_TMPDIR}/work"
  mkdir -p "$WORK"
  cd "$WORK"
}

normalize_ws() { printf '%s' "$1" | tr '\n' ' ' | tr -s ' '; }

# ---------------------------------------------------------- resolve-tools --

@test "inspect resolves to default when unset and appears in the summary exactly once" {
  run bash "$RT" --summary
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c '^inspect:')" -eq 1 ]
  [[ "$output" == *"inspect: default (built-in behavior)"* ]]
  [[ "$output" == *"Phase A3 reference study"* ]]
}

@test "inspect is configurable as an MCP and shows as configured, not default" {
  printf '{"inspect":{"kind":"mcp","ref":"rea","how":"inspect_website -> analyze_javascript"}}' > "$PROJ_CFG"
  run bash "$RT" --role inspect
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.kind')" = "mcp" ]
  [ "$(printf '%s' "$output" | jq -r '.ref')" = "rea" ]
  run bash "$RT" --summary
  [[ "$output" == *"inspect: mcp rea"* ]]
  [[ "$output" != *"inspect: default"* ]]
}

@test "boundary: an empty inspect override object stays default like the other roles" {
  printf '{"inspect":{}}' > "$PROJ_CFG"
  run bash "$RT" --role inspect
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.kind')" = "default" ]
}

@test "error: an invalid per-repo config is ignored and inspect still resolves to default" {
  printf 'not json' > "$PROJ_CFG"
  run bash "$RT" --role inspect
  [ "$status" -eq 0 ]
  # stderr carries the "ignoring invalid config" warning; the JSON is the last line
  [[ "$output" == *"ignoring invalid config"* ]]
  last="${lines[$(( ${#lines[@]} - 1 ))]}"
  [ "$(printf '%s' "$last" | jq -r '.kind')" = "default" ]
}

# ------------------------------------------------------ analysis template --

@test "templates/analysis.md carries the optional Reference study block under Spikes" {
  tpl="${ROOT}/templates/analysis.md"
  spikes="$(awk '/^## Spikes/{f=1} /^## Research/{f=0} f' "$tpl")"
  [[ "$spikes" == *"### Reference study"* ]]
  [[ "$spikes" == *"| Observed behavior | Evidence (tool -> evidence id or capture name) | Unknown |"* ]]
  [[ "$spikes" == *'`inspect` role'* ]]
  [[ "$spikes" == *".claude/tmp/reference/"* ]]
  [[ "$spikes" == *"gate-A does not read this block"* ]]
}

@test "gate A still emits 6 gates and passes with a filled Reference study block" {
  plan="${WORK}/plan"
  mkdir -p "$plan"
  awk '
    { print }
    /^## Spikes$/ {
      print ""
      print "### Reference study"
      print "| Observed behavior | Evidence (tool -> evidence id or capture name) | Unknown |"
      print "|-------------------|------------------------------------------------|---------|"
      print "| typing in the search box fires one request 300 ms after the last keystroke | capture_browser_scenario -> search.har | server-side ranking |"
    }' "$FIX/passing/analysis.md" > "$plan/analysis.md"
  run sh "$PG" emit A "$plan" "$WORK/plan-A.md"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^  CHECK: ' "$WORK/plan-A.md")" -eq 6 ]
  CLAUDE_PLUGIN_ROOT="$ROOT" run bash "$GC" --run "$WORK/plan-A.md"
  [ "$status" -eq 0 ]
  run bash "$GC" --status "$WORK/plan-A.md"
  [[ "$output" == *"met=6"* ]]
}

@test "negative control: a template copy without the Reference study heading fails the block check" {
  old="${BATS_TEST_TMPDIR}/analysis-old.md"
  sed '/^### Reference study$/d' "${ROOT}/templates/analysis.md" > "$old"
  spikes="$(awk '/^## Spikes/{f=1} /^## Research/{f=0} f' "$old")"
  [[ "$spikes" != *"### Reference study"* ]]
}

# ------------------------------------------------------------- doc gates --

@test "wiki-plan A3 names the inspect role and both governing wiki pages, which exist" {
  text="$(normalize_ws "$(cat "${ROOT}/skills/wiki-plan/SKILL.md")")"
  [[ "$text" == *'*Reference study* (`inspect` role, optional)'* ]]
  [[ "$text" == *"wiki/qa/exploratory/behavioral-spec-from-a-reference-product.md"* ]]
  [[ "$text" == *"wiki/infrastructure/agent-orchestration/reference-study-in-a-plan.md"* ]]
  [[ "$text" == *"gate-A does not read this"* ]]
  [ -f "${ROOT}/wiki/qa/exploratory/behavioral-spec-from-a-reference-product.md" ]
  [ -f "${ROOT}/wiki/infrastructure/agent-orchestration/reference-study-in-a-plan.md" ]
}

@test "orchestrate lists inspect among the roles, runs the Phase 2 study, and carries the reference-study risk row at R2" {
  text="$(normalize_ws "$(cat "${ROOT}/skills/orchestrate/SKILL.md")")"
  [[ "$text" == *'`inspect` (how an existing product behaves'* ]]
  [[ "$text" == *"| Phase 2 reference study report | reference-study | R2 |"* ]]
  [[ "$text" == *'**Reference study (the `inspect` role).**'* ]]
  [[ "$text" == *"rows file of a"* ]]
  [[ "$text" == *'a `reference-study` basis cell also names the product and version'* ]]
  [[ "$text" == *'grep the diff for every `## Fingerprints` entry under lens 5'* ]]
}

@test "loop-implement, the brief template, README, configure and tool-profile all list inspect" {
  li="$(normalize_ws "$(cat "${ROOT}/skills/loop-implement/SKILL.md")")"
  [[ "$li" == *'and `inspect` (studying how an existing app, site, or binary behaves'* ]]
  brief="$(normalize_ws "$(cat "${ROOT}/templates/brief.md")")"
  [[ "$brief" == *'write `inspect: default` always'* ]]
  readme="$(cat "${ROOT}/README.md")"
  [[ "$readme" == *'| `inspect` | an app/site/binary inspection tool'* ]]
  conf="$(cat "${ROOT}/skills/configure/SKILL.md")"
  [[ "$conf" == *'| `inspect` | an app/site/binary inspection MCP'* ]]
  prof="$(cat "${ROOT}/references/tool-profile.md")"
  [[ "$prof" == *'| `inspect`   | studying how an existing app, site, or binary behaves'* ]]
  [[ "$prof" == *'### `inspect`'* ]]
}

@test "the example profile maps inspect to the REA MCP with a non-loop how/when, and only for a self-registered MCP" {
  run jq -r '.inspect.kind + " " + .inspect.ref' "${ROOT}/examples/tools.example.json"
  [ "$status" -eq 0 ]
  [ "$output" = "mcp rea" ]
  run jq -r '.inspect.when' "${ROOT}/examples/tools.example.json"
  [[ "$output" == *"Phase A3"* ]]
  [[ "$output" == *"ONLY when you registered the MCP yourself"* ]]
  [[ "$output" == *"scripts/reference-study.sh"* ]]
}

@test "the default inspect path is the bundled study script, named wherever the role is explained" {
  [ -x "${ROOT}/scripts/reference-study.sh" ]
  for f in skills/orchestrate/SKILL.md skills/wiki-plan/SKILL.md skills/configure/SKILL.md references/tool-profile.md README.md wiki/infrastructure/agent-orchestration/reference-study-in-a-plan.md; do
    text="$(normalize_ws "$(cat "${ROOT}/$f")")"
    [[ "$text" == *"scripts/reference-study.sh"* ]] || { echo "missing script reference in $f"; return 1; }
  done
  # unset = the script with the pinned REA, not black-box observation
  run bash "$RT" --role inspect
  [[ "$(printf '%s' "$output" | jq -r '.when')" == *"scripts/reference-study.sh runs the pinned REA MCP"* ]]
  # the coordinator runs the script in Phase 2 and keeps the Agent spawn for a self-registered MCP only
  orch="$(normalize_ws "$(cat "${ROOT}/skills/orchestrate/SKILL.md")")"
  [[ "$orch" == *'sh ${CLAUDE_PLUGIN_ROOT}/scripts/reference-study.sh --brief <that abs path> --slug <product-slug>'* ]]
  [[ "$orch" == *"When the role is configured to an MCP you registered yourself, spawn one fresh-context"* ]]
  [[ "$orch" == *"a script exit of 3, 4 or 5"* ]]
  # no shipped text still describes the old default (a study agent spawned to inherit a registered MCP)
  for f in references/tool-profile.md skills/orchestrate/SKILL.md skills/wiki-plan/SKILL.md templates/analysis.md wiki/infrastructure/agent-orchestration/reference-study-in-a-plan.md; do
    run grep -n -E "spawned by the (orchestrate )?coordinator|spawns the study agent|reference/<feature>/" "${ROOT}/$f"
    [ "$status" -eq 1 ] || { echo "old-design phrase in $f: $output"; return 1; }
  done
}

@test "the reference-product wiki page is indexed and its related ids resolve" {
  [[ "$(cat "${ROOT}/wiki/qa/index.md")" == *"[behavioral-spec-from-a-reference-product](exploratory/behavioral-spec-from-a-reference-product.md)"* ]]
  [[ "$(cat "${ROOT}/wiki/infrastructure/index.md")" == *"[reference-study-in-a-plan](agent-orchestration/reference-study-in-a-plan.md)"* ]]
  run node "${ROOT}/scripts/wiki-structure-checks.js" "${ROOT}/wiki"
  [ "$status" -eq 0 ]
  [[ "$output" == *"findings: 0"* ]]
}

# ------------------------------------------------- redesign invariants --

@test "no shipped text hands the inspection tool to the analyst, names R1 for reference-study, or commits a trail under plans/" {
  files="${ROOT}/skills/orchestrate/SKILL.md ${ROOT}/skills/wiki-plan/SKILL.md ${ROOT}/skills/loop-implement/SKILL.md ${ROOT}/references/tool-profile.md ${ROOT}/templates/analysis.md ${ROOT}/templates/brief.md ${ROOT}/examples/tools.example.json ${ROOT}/wiki/qa/exploratory/behavioral-spec-from-a-reference-product.md ${ROOT}/wiki/infrastructure/agent-orchestration/reference-study-in-a-plan.md"
  run grep -l -- "reference-trail.md" $files
  [ "$status" -eq 1 ]
  run grep -l -- "| reference-study | R1 |" $files
  [ "$status" -eq 1 ]
  run grep -lE -- "analyst (runs|calls) the (study|tool)" $files
  [ "$status" -eq 1 ]
  # the bundled analyst keeps an explicit allowlist with no MCP tool, which is why it consumes rows
  tools_line="$(grep -m1 '^tools:' "${ROOT}/agents/task-analyst.md")"
  [[ "$tools_line" != *"mcp__"* ]]
  [[ "$tools_line" != *"Agent"* ]]
}

@test "the study report carries trail dir, the licence row is settled before capture, and the wiki path is absolute" {
  text="$(normalize_ws "$(cat "${ROOT}/skills/orchestrate/SKILL.md")")"
  [[ "$text" == *'`trail dir: <abs path>`'* ]]
  [[ "$text" == *"settled BEFORE the first capture"* ]]
  [[ "$text" == *'return `licence: unresolved` with `rows: 0`'* ]]
  [[ "$text" == *'${CLAUDE_PLUGIN_ROOT}/wiki/qa/exploratory/behavioral-spec-from-a-reference-product.md'* ]]
  [[ "$text" == *"a trail dir that does not exist is itself a Findings item"* ]]
  prof="$(normalize_ws "$(cat "${ROOT}/references/tool-profile.md")")"
  [[ "$prof" == *"**Study brief (the fixed contract).**"* ]]
  [[ "$prof" == *'`trail dir: <abs path>`'* ]]
}
