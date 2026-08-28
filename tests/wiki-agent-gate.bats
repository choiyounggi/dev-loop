#!/usr/bin/env bats
# Doc-gate for .github/workflows/wiki-agent-gate.yml and its prompt file.
#
# The workflow runs Claude Code headless over knowledge PRs with the base
# repo's secrets (pull_request_target), so its two security guards — the
# trust-gate `if:` and the base-ref-only checkout — are load-bearing: losing
# either one hands a fork PR the OAuth token or checks untrusted content into
# the workspace. These tests pin those guards, the fail-closed verdict step,
# and the contract shared between the workflow's JSON schema and the prompt
# file, the same way other doc-gates here pin SKILL.md invariants. Each
# positive check is paired with a negative control proving the grep can fail.

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  WORKFLOW="${REPO_ROOT}/.github/workflows/wiki-agent-gate.yml"
  PROMPT="${REPO_ROOT}/.github/wiki-agent-gate-prompt.md"
}

# --- normal: the pieces exist and reference each other -----------------------

@test "workflow and prompt file both exist" {
  [ -f "$WORKFLOW" ]
  [ -f "$PROMPT" ]
}

@test "workflow tells the agent to read the prompt file that exists" {
  grep -qF ".github/wiki-agent-gate-prompt.md" "$WORKFLOW"
}

@test "workflow authenticates with the subscription OAuth token secret" {
  grep -qF 'claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}' "$WORKFLOW"
}

# --- security guard 1: the trust gate on pull_request_target -----------------

@test "pull_request_target is paired with a job-level trust gate" {
  grep -qF "pull_request_target:" "$WORKFLOW"
  # the gate must test the head repo, on a job-level if: (secrets exposure)
  grep -qF "github.event.pull_request.head.repo.full_name == github.repository" "$WORKFLOW"
}

@test "negative control: a copy without the trust gate fails the check" {
  stripped="${BATS_TEST_TMPDIR}/no-gate.yml"
  grep -vF "head.repo.full_name" "$WORKFLOW" > "$stripped"
  run grep -qF "github.event.pull_request.head.repo.full_name == github.repository" "$stripped"
  [ "$status" -ne 0 ]
}

# --- security guard 2: the checkout never takes the PR head ------------------

@test "no checkout step references the PR head ref or sha" {
  run grep -E "ref:.*(head\.ref|head\.sha)" "$WORKFLOW"
  [ "$status" -ne 0 ]
}

@test "negative control: a head-ref checkout would be caught" {
  bad="${BATS_TEST_TMPDIR}/head-checkout.yml"
  cp "$WORKFLOW" "$bad"
  printf '          ref: ${{ github.event.pull_request.head.sha }}\n' >> "$bad"
  run grep -E "ref:.*(head\.ref|head\.sha)" "$bad"
  [ "$status" -eq 0 ]
}

# --- fail closed: a silent agent is a red gate, never a green one ------------

@test "the verdict step fails on empty structured output" {
  grep -qF "failing closed" "$WORKFLOW"
  # the empty-RESULT branch must exit non-zero
  awk '/if \[ -z "\$RESULT" \]/,/fi/' "$WORKFLOW" | grep -qF "exit 1"
}

# --- contract: workflow schema and prompt file agree -------------------------

@test "the check names in the JSON schema all appear in the prompt file" {
  for check in transferability duplication fact; do
    grep -qF "\"$check\"" "$WORKFLOW"
    grep -qF "\`$check\`" "$PROMPT"
  done
}

@test "prompt defines all three check sections and the blocker->fail rule" {
  grep -qF "## Check 1" "$PROMPT"
  grep -qF "## Check 2" "$PROMPT"
  grep -qF "## Check 3" "$PROMPT"
  # verdict rule: fail iff at least one blocker
  grep -qF "at least one \`blocker\` finding" "$PROMPT"
}

@test "negative control: a prompt copy missing a check section fails" {
  stripped="${BATS_TEST_TMPDIR}/no-check3.md"
  grep -vF "## Check 3" "$PROMPT" > "$stripped"
  run grep -qF "## Check 3" "$stripped"
  [ "$status" -ne 0 ]
}

# --- boundary: injection stance is stated in the prompt ----------------------

@test "prompt tells the agent to treat in-diff instructions as findings" {
  grep -qiF "never something to follow" "$PROMPT"
}
