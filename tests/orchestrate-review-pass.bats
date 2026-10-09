#!/usr/bin/env bats
# Tests for skills/orchestrate/SKILL.md Phase 4's six-lens review pass and
# skills/orchestrate/templates/review-report.md (i82-phase4-lenses, issue
# #82 / #84).
#
# A checker's own report is not evidence it works until it has been shown to
# fail on something (wiki/testing/quality/checks-that-cannot-pass.md) — each
# structural assertion below has a paired negative control that strips the
# asserted span from a copy and shows the same check fail
# (wiki/testing/quality/spec-artifact-checks.md).
#
# These tests do NOT assert the existence of i81 (AGENTS.md routing step 7)
# or i85 (the lens-3/lens-4 wiki pages) artifacts — those land on sibling
# branches, not this one; SKILL.md only needs to *cite* their paths.

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  SKILL="${REPO_ROOT}/skills/orchestrate/SKILL.md"
  TEMPLATE="${REPO_ROOT}/skills/orchestrate/templates/review-report.md"
}

# Extracts the "## Phase 4" section: from its heading up to (not including)
# the next "## " heading.
phase4_section() {
  awk '/^## Phase 4/{p=1} p && /^## / && !/^## Phase 4/{exit} p' "$1"
}

# Concatenates the digit prefix of every numbered-bold lens line found in
# the Phase 4 section of the given file, e.g. "1234" when all four are
# present in order, "" when none are, "134" when one is missing.
lens_order() {
  phase4_section "$1" | grep -oE '^[0-9]\. \*\*[^*]+\*\*' | sed -E 's/^([0-9])\..*/\1/' | tr -d '\n'
}

# --- normal: the six lenses are present, numbered 1-6, in order ------------

@test "Phase 4 contains the six lenses, numbered 1-6, in order" {
  [ "$(lens_order "$SKILL")" = "123456" ]
  section="$(phase4_section "$SKILL")"
  [[ "$section" == *"Plan conformance"* ]]
  [[ "$section" == *"Wiki re-route from the diff"* ]]
  [[ "$section" == *"Execution-environment reality"* ]]
  [[ "$section" == *"Multi-object write ordering"* ]]
  [[ "$section" == *"AC traceability"* ]]
  [[ "$section" == *"Excess"* ]]
}

@test "lens 2 cites AGENTS.md routing protocol step 7 by document and step number only" {
  section="$(phase4_section "$SKILL")"
  [[ "$section" == *"AGENTS.md routing protocol step 7"* ]]
}

@test "lens 3 and lens 4 cite their grounding wiki pages" {
  section="$(phase4_section "$SKILL")"
  [[ "$section" == *"wiki/platforms/toolchains/flag-availability-at-the-execution-site.md"* ]]
  [[ "$section" == *"wiki/backend/common/storage/multi-object-write-ordering.md"* ]]
}

@test "lens 4 states the coordinator-only leverage" {
  section="$(phase4_section "$SKILL")"
  [[ "$section" == *"only reviewer who sees every worktree at once"* ]]
}

@test "Phase 4 instructs writing reviews/<task>-rN.md from templates/review-report.md" {
  section="$(phase4_section "$SKILL")"
  [[ "$section" == *'reviews/<task>-rN.md'* ]]
  [[ "$section" == *'templates/review-report.md'* ]]
}

@test "Phase 4 retains the test-quality-auditor obligation as prose alongside the pass, not as a numbered lens" {
  section="$(phase4_section "$SKILL")"
  [[ "$section" == *'test-quality-auditor'* ]]
  # it must not be a seventh numbered lens — the lens list is fixed at six
  [[ "$section" != *'7. **'* ]]
  [[ "$section" == *'5. **AC traceability'* ]]
  [[ "$section" == *'6. **Excess'* ]]
}

@test "Phase 4 retains the surrounding mechanics: the agent's diff range, rework budget, escalation, dispatch-loop return" {
  section="$(phase4_section "$SKILL")"
  [[ "$section" == *'git -C <wt> diff'* ]]
  [[ "$section" == *'<integ>...HEAD'* ]]
  # the 3-round cap is code-enforced since #106: the budget lives in
  # ready-set.sh (LO_MAX_REWORK) and exhaustion escalates via the exit-3
  # DEADLOCK route to a human decision
  [[ "$section" == *'LO_MAX_REWORK'* ]]
  [[ "$section" == *'human decision'* ]]
  [[ "$section" == *'return to step 1 of the dispatch'* ]]
  [[ "$section" == *'go to Phase 5'* ]]
}

# --- negative control: stripping the lens list breaks the order check ------

@test "negative control: a SKILL.md copy with the lens lines removed fails the order check" {
  stripped="${BATS_TEST_TMPDIR}/skill-no-lenses.md"
  grep -v -E '^[0-9]\. \*\*(Plan conformance|Wiki re-route|Execution-environment|Multi-object|AC traceability|Excess)' "$SKILL" > "$stripped"
  [ "$(lens_order "$stripped")" != "123456" ]
}

# --- negative control: reordering two lenses breaks the order check --------

@test "negative control: a SKILL.md copy with lenses 2 and 3 swapped fails the order check" {
  swapped="${BATS_TEST_TMPDIR}/skill-swapped-lenses.md"
  awk '
    /^2\. \*\*Wiki re-route/ { line2 = $0; getline; rest2 = $0; got2 = 1; next }
    /^3\. \*\*Execution-environment/ && got2 {
      print $0; getline; print $0
      print line2; print rest2
      next
    }
    { print }
  ' "$SKILL" > "$swapped"
  [ "$(lens_order "$swapped")" != "123456" ]
}

# --- template structure: three-part finding format + non-blocking section --

@test "review-report.md has the three-part finding format" {
  content="$(cat "$TEMPLATE")"
  [[ "$content" == *"Observation"* ]]
  [[ "$content" == *"Failure scenario"* ]]
  [[ "$content" == *"Question"* ]]
  [[ "$content" == *"## Non-blocking"* ]]
}

@test "review-report.md has a header naming task, round, and an approve/rework verdict" {
  content="$(cat "$TEMPLATE")"
  [[ "$content" == *"{TASK}"* ]]
  [[ "$content" == *"{N}"* ]]
  [[ "$content" == *"approve"* ]]
  [[ "$content" == *"rework"* ]]
}

# --- error/boundary: per-lens table distinguishes clean, findings, not-run -

@test "review-report.md's per-lens table has 6 rows, each distinguishing clean/findings/not-run" {
  content="$(cat "$TEMPLATE")"
  clean_count="$(grep -c 'clean —' "$TEMPLATE")"
  notrun_count="$(grep -c 'not run —' "$TEMPLATE")"
  [ "$clean_count" -eq 6 ]
  [ "$notrun_count" -eq 6 ]
  [[ "$content" == *"| 6. Excess |"* ]]
  [[ "$content" == *"findings: F1, F2"* ]]
}

# --- negative control: a template copy missing the not-run option fails ----

@test "negative control: a review-report.md copy with 'not run' stripped fails the distinguishing check" {
  stripped="${BATS_TEST_TMPDIR}/review-report-no-notrun.md"
  sed 's/ or `not run — <why>`//' "$TEMPLATE" > "$stripped"
  notrun_count="$(grep -c 'not run —' "$stripped" || true)"
  [ "$notrun_count" -eq 0 ]
}

# --- negative control: a template copy without the non-blocking section ----

@test "negative control: a review-report.md copy without the Non-blocking section fails the structure check" {
  stripped="${BATS_TEST_TMPDIR}/review-report-no-nonblocking.md"
  awk '/^## Non-blocking/{exit} {print}' "$TEMPLATE" > "$stripped"
  content="$(cat "$stripped")"
  [[ "$content" != *"## Non-blocking"* ]]
}

# --- lens 5 AC traceability (issue #192 stage 3) ----------------------------

@test "review-report.md has the AC traceability section with the DoD, gate id, test case columns" {
  content="$(cat "$TEMPLATE")"
  [[ "$content" == *"## AC traceability"* ]]
  [[ "$content" == *"| DoD item | gate id | test case |"* ]]
}

@test "negative control: a review-report.md copy without the AC traceability heading fails the section check" {
  stripped="${BATS_TEST_TMPDIR}/review-report-no-ac-traceability.md"
  awk '/^## AC traceability/{exit} {print}' "$TEMPLATE" > "$stripped"
  content="$(cat "$stripped")"
  [[ "$content" != *"## AC traceability"* ]]
}

@test "lens 5 names the three columns and routes empty cells to Findings" {
  section="$(phase4_section "$SKILL")"
  [[ "$section" == *"| DoD item | gate id | test case |"* ]]
  [[ "$section" == *"empty gate or test cell is a Findings item"* ]]
}

@test "negative control: a Phase 4 copy without the AC traceability lens fails the three-column check" {
  stripped="${BATS_TEST_TMPDIR}/skill-no-ac-traceability-lens.md"
  grep -v 'AC traceability' "$SKILL" > "$stripped"
  section="$(phase4_section "$stripped")"
  [[ "$section" != *"| DoD item | gate id | test case |"* ]]
}

# --- task-reviewer invocation (issue #192 stage 4) --------------------------

@test "Phase 4 delegates the per-task review to task-reviewer and reads only the verdict line" {
  section="$(phase4_section "$SKILL" | tr '\n' ' ' | tr -s ' ')"
  [[ "$section" == *"task-reviewer"* ]]
  [[ "$section" == *"head -1"* ]]
  [[ "$section" == *"MUST NOT read the worktree diff"* ]]
  [[ "$section" == *"VERDICT: approve"* ]]
  [[ "$section" == *"floor=pass"* ]]
}

@test "Phase 4 exit 3 writes the rework review coordinator-side without invoking task-reviewer" {
  section="$(phase4_section "$SKILL" | tr '\n' ' ' | tr -s ' ')"
  [[ "$section" == *"do not invoke \`task-reviewer\`"* ]]
  [[ "$section" == *"VERDICT: rework"* ]]
}

@test "negative control: a Phase 4 copy without task-reviewer fails the delegation check" {
  stripped="${BATS_TEST_TMPDIR}/skill-no-task-reviewer.md"
  sed 's/task-reviewer/coordinator/g' "$SKILL" > "$stripped"
  section="$(phase4_section "$stripped" | tr '\n' ' ' | tr -s ' ')"
  [[ "$section" != *"task-reviewer"* ]]
}

@test "review-report.md line 1 is the VERDICT placeholder" {
  first="$(head -1 "$TEMPLATE")"
  [[ "$first" == VERDICT:* ]]
  [[ "$first" == *"approve"* ]]
  [[ "$first" == *"rework"* ]]
}

@test "negative control: a template copy with line 1 removed fails the first-line check" {
  stripped="${BATS_TEST_TMPDIR}/review-report-no-line1.md"
  tail -n +2 "$TEMPLATE" > "$stripped"
  [[ "$(head -1 "$stripped")" != VERDICT:* ]]
}

@test "boundary: an empty template copy fails the first-line check" {
  empty="${BATS_TEST_TMPDIR}/review-report-empty.md"
  : > "$empty"
  [[ "$(head -1 "$empty")" != VERDICT:* ]]
}

# --- r1 rework: two-dot working-tree diff + exact verdict match (F1/F2) -----

@test "Phase 4 has task-reviewer read untracked files via ls-files, not just the diff" {
  section="$(phase4_section "$SKILL" | tr '\n' ' ' | tr -s ' ')"
  [[ "$section" == *"ls-files --others --exclude-standard"* ]]
  [[ "$section" == *"has not committed yet"* ]]
}

@test "negative control: a Phase 4 copy without the ls-files untracked-file step fails the check" {
  stripped="${BATS_TEST_TMPDIR}/skill-no-ls-files.md"
  sed 's/ls-files --others --exclude-standard//' "$SKILL" > "$stripped"
  section="$(phase4_section "$stripped" | tr '\n' ' ' | tr -s ' ')"
  [[ "$section" != *"ls-files --others --exclude-standard"* ]]
}

@test "Phase 4 requires an EXACT verdict match, never a prefix, and rejects the template placeholder" {
  section="$(phase4_section "$SKILL" | tr '\n' ' ' | tr -s ' ')"
  [[ "$section" == *"EXACTLY"* ]]
  [[ "$section" == *"prefix or substring match is not valid"* ]]
  [[ "$section" == *"not-a-verdict"* ]]
}

@test "negative control: a Phase 4 copy without the exact-match requirement fails the strict-verdict check" {
  stripped="${BATS_TEST_TMPDIR}/skill-no-exact-verdict.md"
  sed 's/a prefix or substring//' "$SKILL" > "$stripped"
  section="$(phase4_section "$stripped" | tr '\n' ' ' | tr -s ' ')"
  [[ "$section" != *"prefix or substring match is not valid"* ]]
}

# --- lens 6 Excess (plans/excess-lens-and-lint-gate D4) ----------------------

@test "lens 6 asks for the serving brief/plan line and blocks only on search evidence" {
  section="$(phase4_section "$SKILL" | tr '\n' ' ' | tr -s ' ')"
  [[ "$section" == *"name the brief or plan line it serves"* ]]
  [[ "$section" == *"or a later task's Inputs"* ]]
  [[ "$section" == *"two or more call sites that all pass the same value"* ]]
  [[ "$section" == *"zero call sites outside its own tests"* ]]
  [[ "$section" == *"standard-library/language function"* ]]
  [[ "$section" == *"exactly one implementation"* ]]
  [[ "$section" == *"belongs to lens 1"* ]]
  [[ "$section" == *"goes under Non-blocking"* ]]
}

@test "negative control: a Phase 4 copy without the lens 6 block fails the Excess check" {
  stripped="${BATS_TEST_TMPDIR}/skill-no-excess.md"
  awk '/^6\. \*\*Excess/{skip=1} !skip{print} skip && /Non-blocking\.$/{skip=0}' "$SKILL" > "$stripped"
  section="$(phase4_section "$stripped" | tr '\n' ' ' | tr -s ' ')"
  [[ "$section" != *"zero call sites outside its own tests"* ]]
}

@test "review-report.md states what an Excess finding's failure scenario is" {
  content="$(tr '\n' ' ' < "$TEMPLATE" | tr -s ' ')"
  [[ "$content" == *'For a lens 6 (Excess) finding, the failure scenario is the search command, its hit count, and "no brief or plan line needs it".'* ]]
}

@test "negative control: a review-report.md copy without the Excess row counts 5 clean rows" {
  stripped="${BATS_TEST_TMPDIR}/review-report-no-excess.md"
  grep -v '^| 6\. Excess |' "$TEMPLATE" > "$stripped"
  [ "$(grep -c 'clean —' "$stripped")" -eq 5 ]
}

# --- task-reviewer agent lens 6 (plans/excess-lens-and-lint-gate task 07) ---

agent_flat() { # <file>
  tr '\n' ' ' < "$1" | tr -s ' '
}

@test "task-reviewer carries lens 6 and names it for every tier" {
  agent="${BATS_TEST_DIRNAME}/../agents/task-reviewer.md"
  text="$(agent_flat "$agent")"
  [[ "$text" == *'6. **Excess**'* ]]
  [[ "$text" == *'zero call sites outside its own tests'* ]]
  [[ "$text" == *"or a later task's Inputs"* ]]
  [[ "$text" == *'two or more call sites that all pass the same value'* ]]
  [[ "$text" == *'| R0 | lenses 1, 3 and 6; write not run — R0 profile in rows 2, 4, 5 |'* ]]
  [[ "$text" == *'| R1 | lenses 1-4 and 6; write not run — R1 profile in row 5 |'* ]]
  [[ "$text" == *'| R2 or R3 | lenses 1-6; R3 also applies the adversarial-change-review techniques under lens 5 |'* ]]
}

@test "the generated task-reviewer-r1 copy carries lens 6 too" {
  text="$(agent_flat "${BATS_TEST_DIRNAME}/../agents/task-reviewer-r1.md")"
  [[ "$text" == *'6. **Excess**'* ]]
  [[ "$text" == *'| R1 | lenses 1-4 and 6; write not run — R1 profile in row 5 |'* ]]
}

@test "boundary: the agent body has exactly one lens 6 line" {
  [ "$(grep -c '^6\. \*\*Excess\*\*' "${BATS_TEST_DIRNAME}/../agents/task-reviewer.md")" -eq 1 ]
}

@test "negative control: an agent copy with the old R1 row fails the R1 check" {
  old="${BATS_TEST_TMPDIR}/task-reviewer-old-r1.md"
  sed 's/| R1 | lenses 1-4 and 6;/| R1 | lenses 1-4;/' "${BATS_TEST_DIRNAME}/../agents/task-reviewer.md" > "$old"
  text="$(agent_flat "$old")"
  [[ "$text" != *'| R1 | lenses 1-4 and 6; write not run — R1 profile in row 5 |'* ]]
}

@test "negative control: a Phase 4 copy without the later-task seam exemption fails the lens-6 check" {
  stripped="${BATS_TEST_TMPDIR}/skill-no-seam.md"
  sed "s/, or a later task's Inputs//" "$SKILL" > "$stripped"
  section="$(phase4_section "$stripped" | tr '\n' ' ' | tr -s ' ')"
  [[ "$section" != *"or a later task's Inputs"* ]]
}
