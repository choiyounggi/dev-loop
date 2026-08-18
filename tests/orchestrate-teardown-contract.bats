#!/usr/bin/env bats
# Doc gates for tdn0818 (end-of-run contract): SKILL.md must state (1) the
# `## End-of-run contract` section and its three terminal outcomes, (2)
# teardown as the final step of all three, naming the archive destination.
# Each gate is paired with a proof it can fail (checks-that-cannot-pass): a
# hand-written fixture missing the fact, asserted to NOT match. A final case
# guards this task against breaking the sibling doc-gate pin
# (orchestrate-merge-on-approval.bats's Phase 6 idempotence note).

setup() {
  SKILL="${BATS_TEST_DIRNAME}/../skills/orchestrate/SKILL.md"
}

# Collapses embedded newlines (and the whitespace runs they leave behind) to
# a single space so a substring assertion survives prose hard-wrapped across
# physical lines (wiki/testing/quality/checks-that-cannot-pass.md).
normalize_ws() {
  printf '%s' "$1" | tr '\n' ' ' | tr -s ' '
}

flat_skill() {
  normalize_ws "$(cat "$SKILL")"
}

# --- doc-gate 1: End-of-run contract section names all three outcomes -----

@test "doc-gate: End-of-run contract section names merged, aborted, escalated-and-abandoned" {
  flat="$(flat_skill)"
  printf '%s' "$flat" | grep -qF "## End-of-run contract"
  printf '%s' "$flat" | grep -qF "**merged**"
  printf '%s' "$flat" | grep -qF "**aborted**"
  printf '%s' "$flat" | grep -qF "escalated-and-abandoned"
}

@test "doc-gate can fail: a fixture without the three outcomes does not match" {
  fixture="${BATS_TEST_TMPDIR}/eorc-without-outcomes.md"
  cat > "$fixture" <<'EOF'
## End-of-run contract
Every orchestration run eventually finishes, one way or another, and cleanup
should happen when it does.
EOF
  count="$(grep -cF "escalated-and-abandoned" "$fixture" || true)"
  [ "$count" -eq 0 ]
}

# --- doc-gate 2: teardown is the final step of all three, with archive dest -

@test "doc-gate: End-of-run contract names teardown as the final step and the archive destination" {
  flat="$(flat_skill)"
  printf '%s' "$flat" | grep -qF "the final step is the same"
  printf '%s' "$flat" | grep -qF "safe-cleanup.sh teardown"
  printf '%s' "$flat" | grep -qF "archive-<date>-<runid>/"
}

@test "doc-gate can fail: a fixture without the teardown-as-final-step line does not match" {
  fixture="${BATS_TEST_TMPDIR}/eorc-without-teardown.md"
  cat > "$fixture" <<'EOF'
## End-of-run contract
Every orchestration run terminates in exactly one of three outcomes: merged,
aborted, or escalated-and-abandoned.
EOF
  count="$(grep -cF "safe-cleanup.sh teardown" "$fixture" || true)"
  [ "$count" -eq 0 ]
}

# --- doc-gate 3: Phase 6 ties steps 2-3 (+ archive) to teardown -----------

@test "doc-gate: Phase 6 ties steps 2-3 (worktree removal, session sweep) to teardown" {
  flat="$(flat_skill)"
  printf '%s' "$flat" | grep -qF "worktree removal, session sweep"
  printf '%s' "$flat" | grep -qF "composes into one call"
}

@test "doc-gate can fail: a fixture without the Phase 6 tie-in sentence does not match" {
  fixture="${BATS_TEST_TMPDIR}/phase6-without-tiein.md"
  cat > "$fixture" <<'EOF'
**Local merge into the feature branch only.** Remote push / PR is the user's job.

## End-of-run contract
EOF
  count="$(grep -cF "composes into one call" "$fixture" || true)"
  [ "$count" -eq 0 ]
}

# --- doc-gate 4: Re-entry names list-orphans --stale -> LO_RUN_ID=<id> teardown

@test "doc-gate: Re-entry names list-orphans --stale and LO_RUN_ID=<id> teardown for dead runs" {
  flat="$(flat_skill)"
  printf '%s' "$flat" | grep -qF "list-orphans --stale <root>"
  printf '%s' "$flat" | grep -qF "LO_RUN_ID=<id> scripts/safe-cleanup.sh teardown <root>"
}

@test "doc-gate can fail: a fixture without the re-entry stale/teardown line does not match" {
  fixture="${BATS_TEST_TMPDIR}/reentry-without-stale.md"
  cat > "$fixture" <<'EOF'
For leftovers of a run that already died, `scripts/safe-cleanup.sh list-orphans
<root>` enumerates them read-only, including each session's run id.
EOF
  count="$(grep -cF "LO_RUN_ID=<id> scripts/safe-cleanup.sh teardown <root>" "$fixture" || true)"
  [ "$count" -eq 0 ]
}

# --- sibling-pin boundary check: this task must not break the merge-on- ---
# --- approval doc-gate's Phase 6 idempotence note ---

@test "sibling-pin boundary: Phase 6 idempotence note pinned by orchestrate-merge-on-approval.bats survives" {
  flat="$(flat_skill)"
  printf '%s' "$flat" | grep -qF "re-merges here as a no-op"
  printf '%s' "$flat" | grep -qF "Already up to date"
  printf '%s' "$flat" | grep -qF "scripts/safe-cleanup.sh merge <root> <integ> <branch>..."
}
