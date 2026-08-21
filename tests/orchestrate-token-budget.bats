#!/usr/bin/env bats
# Doc gates for t2-skill-token-directives: SKILL.md and the brief template
# must direct token-efficient coordinator/worker behavior, each citing the
# governing wiki page
# (wiki/infrastructure/agent-orchestration/session-context-token-budget.md).
# session-prompt.md's item [4] is already pinned by the byte-level cksum
# guard in tests/send-prompt.bats, so it is not duplicated here.
#
# Each gate is paired with a negative control (checks-that-cannot-pass,
# wiki/testing/quality/checks-that-cannot-pass.md): a fixture with the
# asserted span stripped, shown to fail the same check.

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  SKILL="${REPO_ROOT}/skills/orchestrate/SKILL.md"
  BRIEF="${REPO_ROOT}/skills/orchestrate/templates/brief.md"
}

# Collapses embedded newlines to a single space so a substring assertion
# survives prose hard-wrapped across physical lines (same technique as
# tests/orchestrate-teardown-contract.bats).
normalize_ws() {
  printf '%s' "$1" | tr '\n' ' ' | tr -s ' '
}

flat_skill() {
  normalize_ws "$(cat "$SKILL")"
}

WIKI_SLUG='wiki/infrastructure/agent-orchestration/session-context-token-budget.md'

# --- doc-gate 1: Coordinator token budget section (D1) ---------------------

@test "doc-gate: Coordinator token budget section exists and cites the wiki page" {
  flat="$(flat_skill)"
  printf '%s' "$flat" | grep -qF "## Coordinator token budget"
  printf '%s' "$flat" | grep -qF "$WIKI_SLUG"
  printf '%s' "$flat" | grep -qF "delegate the visual check to a subagent"
  printf '%s' "$flat" | grep -qF "/compact"
}

@test "doc-gate can fail: a fixture without the Coordinator token budget section does not match" {
  fixture="${BATS_TEST_TMPDIR}/no-token-budget.md"
  grep -v 'Coordinator token budget' "$SKILL" > "$fixture"
  flat="$(normalize_ws "$(cat "$fixture")")"
  count="$(printf '%s' "$flat" | grep -cF "## Coordinator token budget" || true)"
  [ "$count" -eq 0 ]
}

# --- doc-gate 2: teardown token audit step (D2) -----------------------------

@test "doc-gate: End-of-run contract runs token-report.sh after teardown, citing the wiki page" {
  flat="$(flat_skill)"
  printf '%s' "$flat" | grep -qF "token-report.sh"
  printf '%s' "$flat" | grep -qF -- "--cwd <root> ."
  printf '%s' "$flat" | grep -qF -- "--cwd"
  printf '%s' "$flat" | grep -qF "$WIKI_SLUG"
  printf '%s' "$flat" | grep -qF "Exit 0 is the report, exit 2 a usage error, exit 4 a malformed"
}

@test "doc-gate can fail: a fixture without the token-report teardown step does not match" {
  fixture="${BATS_TEST_TMPDIR}/no-token-report.md"
  grep -v 'token-report.sh' "$SKILL" > "$fixture"
  flat="$(normalize_ws "$(cat "$fixture")")"
  count="$(printf '%s' "$flat" | grep -cF "token-report.sh" || true)"
  [ "$count" -eq 0 ]
}

# --- doc-gate 3: brief.md token-hygiene constraint (D4) --------------------

@test "doc-gate: brief.md constraints carry the token-hygiene line citing the wiki page" {
  grep -qF 'token hygiene' "$BRIEF"
  grep -qF "$WIKI_SLUG" "$BRIEF"
}

@test "doc-gate can fail: a fixture without the token-hygiene line does not match" {
  fixture="${BATS_TEST_TMPDIR}/brief-no-hygiene.md"
  grep -v 'token hygiene' "$BRIEF" > "$fixture"
  count="$(grep -cF 'token hygiene' "$fixture" || true)"
  [ "$count" -eq 0 ]
}
