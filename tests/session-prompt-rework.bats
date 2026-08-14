#!/usr/bin/env bats
# Tests for skills/orchestrate/templates/session-prompt.md §3/§O3 — the
# per-finding fix-or-answer obligation (issue #84). i82's review-report.md
# finding format (Observation/Failure scenario/Question, blocking vs
# `## Non-blocking`) is cited by these sections in prose only; that template
# lives on a sibling branch not present here, so no test below may assert its
# existence (wiki/testing/quality/checks-that-cannot-pass.md — never gate on
# a target absent from this branch). A stripped-copy negative control is
# included per the same page: a check never shown to fail on anything proves
# nothing.

setup() {
  TEMPLATE="${BATS_TEST_DIRNAME}/../skills/orchestrate/templates/session-prompt.md"
}

extract_section() {
  local heading="$1" file="$2"
  awk -v h="$heading" '
    index($0, h) == 1 { flag=1; next }
    /^## / { flag=0 }
    flag { print }
  ' "$file"
}

# --- normal: §3 obliges fix-or-answer + the Answer-line convention ----------

@test "§3: obliges fix-or-answer per finding and the Answer-line convention" {
  section="$(extract_section '## (3)' "$TEMPLATE")"
  [[ "$section" == *"fix it, or answer its Question"* ]]
  [[ "$section" == *"Answer (r{N})"* ]]
  [[ "$section" == *"silence"* ]]
}

# --- normal: §3 states the blocking-only scope -------------------------------

@test "§3: blocking-only scope is stated, Non-blocking answering not obliged" {
  section="$(extract_section '## (3)' "$TEMPLATE")"
  [[ "$section" == *"blocking"* ]]
  [[ "$section" == *"Non-blocking"* ]]
  [[ "$section" == *"encouraged"* ]]
}

# --- normal: §O3 carries the same obligation ---------------------------------

@test "§O3: obliges fix-or-answer per finding and the Answer-line convention" {
  section="$(extract_section '## (O3)' "$TEMPLATE")"
  [[ "$section" == *"fix it, or answer its Question"* ]]
  [[ "$section" == *"Answer (r{N})"* ]]
  [[ "$section" == *"silence"* ]]
  [[ "$section" == *"blocking"* ]]
  [[ "$section" == *"Non-blocking"* ]]
}

# --- normal: §O3 obliges the per-finding worker_done --body summary ---------

@test "§O3: worker_done --body must summarize per-finding outcomes" {
  section="$(extract_section '## (O3)' "$TEMPLATE")"
  [[ "$section" == *"--body"* ]]
  [[ "$section" == *"fixed"* ]]
  [[ "$section" == *"stands"* ]]
}

# --- boundary: §3 stays exactly one physical line (send-keys -l safe) -------

@test "§3: is a single physical line (no embedded newlines, flatten-safe)" {
  section="$(extract_section '## (3)' "$TEMPLATE")"
  non_blank_lines="$(printf '%s\n' "$section" | grep -c '.')"
  [ "$non_blank_lines" -eq 1 ]
}

# --- negative control: a stripped §3 fails the obligation check -------------

@test "negative control: a stripped §3 (pre-i84 text) fails the obligation check" {
  stripped="${BATS_TEST_TMPDIR}/stripped-session-prompt.md"
  cat > "$stripped" <<'EOF'
## (3) Rework — injected when review requests changes

Address the issues in .orchestration/reviews/{TASK}-r{N}.md via the loop-implement skill (re-run step 6.5 audit; never weaken or skip tests). Then run `STATUS_DIR={STATUS_DIR} sh {SKILL}/scripts/status-update.sh {TASK} impl_done worktree=$PWD` and wait.

## (4) Merge-prep
EOF
  section="$(extract_section '## (3)' "$stripped")"
  [[ "$section" != *"fix it, or answer its Question"* ]]
  [[ "$section" != *"Answer (r{N})"* ]]
  [[ "$section" != *"silence"* ]]
}
