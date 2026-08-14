#!/usr/bin/env bats
# Doc gates for issue #90 (merge-on-approval + lazy dispatch worktrees):
# SKILL.md must state (1) what a `deps` edge does and does not deliver, (2)
# the approval-step merge rule + verification, (3) Phase 6's idempotence note.
# Each gate is paired with a proof it can fail (checks-that-cannot-pass): a
# hand-written fixture missing the fact, asserted to NOT match.

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

# --- doc-gate 1: Phase 3 step 0 — deps deliver signatures, not merged code ---

@test "doc-gate: Phase 3 step 0 states deps deliver signatures, merged code only via merge-on-approval" {
  flat="$(flat_skill)"
  printf '%s' "$flat" | grep -qF "injects its SIGNATURE"
  printf '%s' "$flat" | grep -qF "never its merged CODE"
  printf '%s' "$flat" | grep -qF "merge-on-approval rule"
  printf '%s' "$flat" | grep -qF "on every producer it reads"
}

@test "doc-gate can fail: a fixture without the signatures-vs-code paragraph does not match" {
  fixture="${BATS_TEST_TMPDIR}/step0-without-limitation.md"
  cat > "$fixture" <<'EOF'
0. Preceding-interface injection (Wave 2+, and completed base outputs): before
   launching this Wave, fill each task's brief <dependencies> with the exact
   signatures of the approved preceding Wave. Wave 1 with no completed
   dependencies skips this.
EOF
  count="$(grep -cF "never its merged CODE" "$fixture" || true)"
  [ "$count" -eq 0 ]
}

# --- doc-gate 2: dispatch-loop approval step — merge before re-running -----
# --- ready-set, with fast-forward-first mechanics + ancestor verification ---

@test "doc-gate: approval step states merge-on-approval mechanics and verification" {
  flat="$(flat_skill)"
  printf '%s' "$flat" | grep -qF "merge before you loop"
  printf '%s' "$flat" | grep -qF "fast-forward first"
  printf '%s' "$flat" | grep -qF "git merge-base --is-ancestor"
  printf '%s' "$flat" | grep -qF "before dispatching any dependent"
}

@test "doc-gate can fail: a fixture without the merge-on-approval rule does not match" {
  fixture="${BATS_TEST_TMPDIR}/step5-without-merge.md"
  cat > "$fixture" <<'EOF'
5. On wake, handle that task: review each worktree diff. If tests weak, audit
   with test-quality-auditor. On approval, return to step 1 -- whatever
   dependency it released shows up in the next ready-set.sh round.
EOF
  count="$(grep -cF "merge before you loop" "$fixture" || true)"
  [ "$count" -eq 0 ]
}

# --- doc-gate 3: Phase 6 — merging an already-merged branch is a no-op -----

@test "doc-gate: Phase 6 notes an already-merged branch re-merges as a no-op" {
  flat="$(flat_skill)"
  printf '%s' "$flat" | grep -qF "re-merges here as a no-op"
  printf '%s' "$flat" | grep -qF "Already up to date"
}

@test "doc-gate can fail: a fixture without the Phase 6 idempotence note does not match" {
  fixture="${BATS_TEST_TMPDIR}/phase6-without-idempotence.md"
  cat > "$fixture" <<'EOF'
1. scripts/safe-cleanup.sh merge <root> <integ> <branch>... -- refuses dirty
   worktrees, merges sequentially, stops + reports on conflict (no --force).
EOF
  count="$(grep -cF "re-merges here as a no-op" "$fixture" || true)"
  [ "$count" -eq 0 ]
}
