#!/usr/bin/env bats
# Tests for hooks/orchestrate-ask-gate.sh (PreToolUse gate on worker launches).
#
# The gate must block launch-session.sh / orca-worker-start.sh / orca-spawn.sh
# until the session transcript proves the coordinator asked Gate 1 with the
# AskUserQuestion tool — and, when Orca is available, asked the substrate choice
# in it too. Every unrelated command passes untouched.
# Stdin is the Claude Code PreToolUse payload:
#   {"transcript_path":"...","tool_input":{"command":"..."}}
# Exit 0 = allow, exit 2 = deny (message on stderr).

setup() {
  GATE="${BATS_TEST_DIRNAME}/../hooks/orchestrate-ask-gate.sh"
  TRANSCRIPT="${BATS_TEST_TMPDIR}/transcript.jsonl"

  # Neutralize Orca detection by default: no skills dir → orca-detect.sh exits 1,
  # so the substrate question is not required unless a test opts in.
  export ORCA_SKILLS_DIR="${BATS_TEST_TMPDIR}/no-such-orca-skills"
  export CLAUDE_PLUGIN_ROOT="${BATS_TEST_DIRNAME}/.."
}

# Drive the gate with a command + the current transcript.
_run_gate() {
  local cmd="$1"
  local payload
  payload="$(TP="$TRANSCRIPT" CMD="$cmd" node -e '
process.stdout.write(JSON.stringify({
  transcript_path: process.env.TP,
  tool_input: { command: process.env.CMD },
}));')"
  run bash -c "printf '%s' '$payload' | bash '$GATE'"
}

_transcript_without_ask() {
  cat > "$TRANSCRIPT" <<'EOF'
{"type":"assistant","message":{"content":[{"type":"text","text":"Task split: 3 tasks. Approve? (1) yes (2) revise"}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"git status"}}]}}
EOF
}

_transcript_with_ask() {
  cat > "$TRANSCRIPT" <<'EOF'
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"AskUserQuestion","input":{"questions":[{"header":"Task split","question":"Approve the 3-task split?","options":[{"label":"Approve as proposed (Recommended)"},{"label":"Revise"}]}]}}]}}
EOF
}

_transcript_with_ask_substrate() {
  cat > "$TRANSCRIPT" <<'EOF'
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"AskUserQuestion","input":{"questions":[{"header":"Task split","question":"Approve the 3-task split?","options":[{"label":"Approve as proposed (Recommended)"},{"label":"Revise"}]},{"header":"Substrate","question":"Orca or tmux?","options":[{"label":"Orca (Recommended)"},{"label":"tmux"}]}]}}]}}
EOF
}

# --- allow: nothing to do with a worker launch ---------------------------------

@test "unrelated command passes even with no AskUserQuestion" {
  _transcript_without_ask
  _run_gate 'git status --porcelain'
  [ "$status" -eq 0 ]
}

@test "reading the launch script is not a launch" {
  _transcript_without_ask
  _run_gate 'cat skills/orchestrate/scripts/launch-session.sh'
  [ "$status" -eq 0 ]
}

@test "launch-session.sh --help is not a launch" {
  _transcript_without_ask
  _run_gate 'scripts/launch-session.sh --help'
  [ "$status" -eq 0 ]
}

@test "empty command is a no-op" {
  _transcript_without_ask
  _run_gate ''
  [ "$status" -eq 0 ]
}

@test "missing transcript path leaves the launch alone (no fail-closed brick)" {
  _transcript_with_ask
  run bash -c "printf '%s' '{\"tool_input\":{\"command\":\"scripts/launch-session.sh lo-1 /wt\"}}' | bash '$GATE'"
  [ "$status" -eq 0 ]
}

@test "transcript path that does not exist leaves the launch alone" {
  TRANSCRIPT="${BATS_TEST_TMPDIR}/gone.jsonl"
  _run_gate 'scripts/launch-session.sh lo-1 /wt'
  [ "$status" -eq 0 ]
}

# --- deny: a launch with no chooser in the session ------------------------------

@test "tmux launch is denied when no AskUserQuestion was asked" {
  _transcript_without_ask
  _run_gate 'scripts/launch-session.sh lo-1 /wt "prompt"'
  [ "$status" -eq 2 ]
  [[ "$output" == *"AskUserQuestion"* ]]
  [[ "$output" == *"Gate 1 is a CHOOSER"* ]]
}

@test "orca worker start is denied when no AskUserQuestion was asked" {
  _transcript_without_ask
  _run_gate 'scripts/orca-worker-start.sh --task t1 --worktree id:r::/wt'
  [ "$status" -eq 2 ]
}

@test "orca-spawn is denied when no AskUserQuestion was asked" {
  _transcript_without_ask
  _run_gate 'bash scripts/orca-spawn.sh --task t1'
  [ "$status" -eq 2 ]
}

@test "a launch chained after another command is still gated" {
  _transcript_without_ask
  _run_gate 'cd /repo && scripts/launch-session.sh lo-1 /wt "prompt"'
  [ "$status" -eq 2 ]
}

@test "prose mentioning AskUserQuestion does not satisfy the gate" {
  cat > "$TRANSCRIPT" <<'EOF'
{"type":"assistant","message":{"content":[{"type":"text","text":"I could use AskUserQuestion here but I will just ask in text."}]}}
EOF
  _run_gate 'scripts/launch-session.sh lo-1 /wt "prompt"'
  [ "$status" -eq 2 ]
}

# --- allow: the chooser happened -----------------------------------------------

@test "tmux launch passes once an AskUserQuestion is in the transcript" {
  _transcript_with_ask
  _run_gate 'scripts/launch-session.sh lo-1 /wt "prompt"'
  [ "$status" -eq 0 ]
}

@test "multi-line launch command passes with the chooser present" {
  _transcript_with_ask
  _run_gate 'scripts/launch-session.sh lo-1 /wt \
  "prompt line 1
prompt line 2"'
  [ "$status" -eq 0 ]
}

# --- substrate: a detected Orca must have been offered --------------------------

@test "orca launch is denied when the chooser never named the substrate" {
  _transcript_with_ask
  _run_gate 'scripts/orca-worker-start.sh --task t1 --worktree id:r::/wt'
  [ "$status" -eq 2 ]
  [[ "$output" == *"substrate"* ]]
}

@test "orca launch passes when the chooser carried the substrate question" {
  _transcript_with_ask_substrate
  _run_gate 'scripts/orca-worker-start.sh --task t1 --worktree id:r::/wt'
  [ "$status" -eq 0 ]
}

@test "tmux launch is denied when Orca was detected but never offered" {
  # Make orca-detect.sh succeed: a skills dir plus canned reachable status.
  mkdir -p "${BATS_TEST_TMPDIR}/orca-skills"
  export ORCA_SKILLS_DIR="${BATS_TEST_TMPDIR}/orca-skills"
  export ORCA_STATUS_JSON='{"result":{"runtime":{"reachable":true}}}'
  _transcript_with_ask
  _run_gate 'scripts/launch-session.sh lo-1 /wt "prompt"'
  [ "$status" -eq 2 ]
  [[ "$output" == *"substrate"* ]]
}

@test "tmux launch passes when Orca was detected and the substrate was offered" {
  mkdir -p "${BATS_TEST_TMPDIR}/orca-skills"
  export ORCA_SKILLS_DIR="${BATS_TEST_TMPDIR}/orca-skills"
  export ORCA_STATUS_JSON='{"result":{"runtime":{"reachable":true}}}'
  _transcript_with_ask_substrate
  _run_gate 'scripts/launch-session.sh lo-1 /wt "prompt"'
  [ "$status" -eq 0 ]
}

# --- doc-gates: the skill must mandate the chooser at every human gate ---------
#
# The hook only blocks the launch; the SKILL text is what makes the coordinator
# ask correctly in the first place. Each gate is paired with a negative control
# (wiki/testing/quality/checks-that-cannot-pass.md).

_flat_skill() {
  tr '\n' ' ' < "${BATS_TEST_DIRNAME}/../skills/orchestrate/SKILL.md" | tr -s ' '
}

@test "doc-gate: the skill has an 'Asking the user' section requiring AskUserQuestion" {
  flat="$(_flat_skill)"
  printf '%s' "$flat" | grep -qF "## Asking the user — every question is a chooser (REQUIRED)"
  printf '%s' "$flat" | grep -qF "AskUserQuestion"
  printf '%s' "$flat" | grep -qF "recommended answer is option 1"
  printf '%s' "$flat" | grep -qF "orchestrate-ask-gate.sh"
}

@test "doc-gate can fail: a fixture without the section does not match" {
  fixture="${BATS_TEST_TMPDIR}/no-chooser.md"
  grep -v 'Asking the user' "${BATS_TEST_DIRNAME}/../skills/orchestrate/SKILL.md" > "$fixture"
  count="$(tr '\n' ' ' < "$fixture" | tr -s ' ' | grep -cF "## Asking the user — every question is a chooser (REQUIRED)" || true)"
  [ "$count" -eq 0 ]
}

@test "doc-gate: Gate 1 asks the split and the substrate in one AskUserQuestion call" {
  flat="$(_flat_skill)"
  printf '%s' "$flat" | grep -qF "the approval itself is **one AskUserQuestion call**"
  printf '%s' "$flat" | grep -qF "carry the choice as a **question in the same AskUserQuestion call** as the split approval"
}

@test "doc-gate can fail: a fixture without Gate 1's chooser sentence does not match" {
  fixture="${BATS_TEST_TMPDIR}/no-gate1-chooser.md"
  grep -v 'AskUserQuestion' "${BATS_TEST_DIRNAME}/../skills/orchestrate/SKILL.md" > "$fixture"
  count="$(tr '\n' ' ' < "$fixture" | tr -s ' ' | grep -cF "the approval itself is **one AskUserQuestion call**" || true)"
  [ "$count" -eq 0 ]
}

@test "doc-gate: Gate 2 asks the merge verdict with AskUserQuestion" {
  flat="$(_flat_skill)"
  printf '%s' "$flat" | grep -qF "ask for the verdict with **AskUserQuestion**"
  printf '%s' "$flat" | grep -qF "merge / send back for rework / abort"
}

@test "doc-gate: workers are still barred from AskUserQuestion" {
  grep -qF "NEVER use the AskUserQuestion" "${BATS_TEST_DIRNAME}/../skills/orchestrate/templates/session-prompt.md"
  _flat_skill | grep -qF "never AskUserQuestion — escalate via \`ask-coordinator.sh\`"
}

# --- invocation forms the coordinator actually uses -----------------------------

@test "env-prefixed launch is gated" {
  _transcript_without_ask
  _run_gate 'LO_RUN_ID=r1 GROUNDWORK_ESCALATION_DIR=/e sh scripts/launch-session.sh lo-1 /wt "p"'
  [ "$status" -eq 2 ]
}

@test "absolute-path sh launch is gated" {
  _transcript_without_ask
  _run_gate 'sh /Users/me/.claude/plugins/cache/gw/dev-loop/1.11.0/skills/orchestrate/scripts/launch-session.sh lo-1 /wt "p"'
  [ "$status" -eq 2 ]
}

@test "absolute-path sh launch passes with the chooser present" {
  _transcript_with_ask
  _run_gate 'sh /Users/me/.claude/plugins/cache/gw/dev-loop/1.11.0/skills/orchestrate/scripts/launch-session.sh lo-1 /wt "p"'
  [ "$status" -eq 0 ]
}

@test "grepping the launch script is not a launch" {
  _transcript_without_ask
  _run_gate 'grep -n launch scripts/launch-session.sh'
  [ "$status" -eq 0 ]
}
