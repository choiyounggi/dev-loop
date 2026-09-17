#!/usr/bin/env bats
# Tests for the review-time routing protocol: AGENTS.md step 7 (diff-signal
# decision table + page-set comparison directive) and the two-input preamble
# it and INDEX.md share.
#
# A check that has never been shown to fail is not evidence (see
# wiki/testing/quality/tests-that-cannot-fail.md). The negative-control case
# below strips step 7 from a copy of AGENTS.md and asserts the same check
# that passes on the real file fails against the stripped copy.

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  AGENTS="${REPO_ROOT}/AGENTS.md"
  INDEX="${REPO_ROOT}/INDEX.md"
  CHECKER="${REPO_ROOT}/scripts/wiki-lint-prohibitions.js"
}

step7_line_count() {
  # count '7. ' lines inside the routing protocol section of a given AGENTS.md
  grep -c '^7\. \*\*Review entry' "$1"
}

step7_table_rows() {
  # data rows of the step-7 table: lines starting with '|' (after leading
  # whitespace) that are not the header or the separator row
  awk '
    /^7\. \*\*Review entry/ { f=1 }
    f && /^[[:space:]]*\| Signal in the diff/ { h=1; next }
    f && h && /^[[:space:]]*\|-/ { next }
    f && h && /^[[:space:]]*\|/ { print }
    f && h && /^[[:space:]]*$/ { exit }
  ' "$1" | wc -l | tr -d ' '
}

# --- normal: AGENTS.md carries step 7 with a 6-row decision table -----------

@test "AGENTS.md: step 7 exists in the routing protocol with a 6-row table" {
  [ "$(step7_line_count "$AGENTS")" -eq 1 ]
  [ "$(step7_table_rows "$AGENTS")" -eq 6 ]
}

# --- normal: INDEX.md preamble names both inputs and cites AGENTS.md --------

@test "INDEX.md: preamble mentions both task and diff, and cites AGENTS.md" {
  preamble="$(sed -n '1,6p' "$INDEX")"
  [[ "$preamble" == *"task"* ]]
  [[ "$preamble" == *"diff"* ]]
  [[ "$preamble" == *"AGENTS.md"* ]]
}

# --- error: the prohibition checker still passes on the edited file ---------

@test "AGENTS.md: wiki-lint-prohibitions exits 0 with 0 violations" {
  run node "$CHECKER" "$AGENTS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"violations: 0"* ]]
}

# --- boundary: the empty page-set difference is stated, not omitted (D5) ----

@test "AGENTS.md: step 7 states the empty-diff-result case explicitly" {
  run grep -F "no unplanned pages reached" "$AGENTS"
  [ "$status" -eq 0 ]
}

# --- negative control: proves the step-7 check above can fail ---------------

@test "negative control: a copy of AGENTS.md missing step 7 fails the step-7 check" {
  stripped="${BATS_TEST_TMPDIR}/AGENTS-no-step7.md"
  # drop the step-7 block: from its '7. **Review entry' line up to (but not
  # including) the 'Hard rule:' paragraph that follows it.
  awk '/^7\. \*\*Review entry/{skip=1} /^Hard rule:/{skip=0} !skip{print}' "$AGENTS" > "$stripped"

  [ "$(step7_line_count "$stripped")" -eq 0 ]
  run grep -F "no unplanned pages reached" "$stripped"
  [ "$status" -ne 0 ]
}

# --- wiring: every local-layer sentence the plan placed is present ----------
# The twelve sites this guard protects (issue #194 A), enumerated from the
# source before the pattern was written: AGENTS.md x6 — the layers-table row,
# the directory-layout page line, the step-2 conditional local index read, the
# step-6 local-wins precedence, the Frontmatter confidence default, and the
# local- id prefix — plus skills/wiki-plan/SKILL.md (Wiki basis grammar),
# skills/loop-implement/SKILL.md (step 1 root split), skills/wiki-ingest/SKILL.md
# (layer test), skills/knowledge-flush/SKILL.md (report section),
# skills/configure/SKILL.md (not the knowledge role), README.md (the paragraph).

@test "AGENTS.md and the wiki skills carry the project-local layer wiring" {
  run grep -F "wiki-local/index.md" "$AGENTS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Project-local layer"* ]]

  run grep -F '| Project layer | `wiki-local/**`' "$AGENTS"
  [ "$status" -eq 0 ]

  run grep -F "wiki-local/<domain>/<category>/<page>.md" "$AGENTS"
  [ "$status" -eq 0 ]

  run grep -F "apply the local page" "$AGENTS"
  [ "$status" -eq 0 ]

  run grep -F 'defaults to `confidence: field-tested`' "$AGENTS"
  [ "$status" -eq 0 ]

  run grep -F "local-<domain>-<category>-<slug>" "$AGENTS"
  [ "$status" -eq 0 ]

  run grep -F "wiki-local/<domain>/<category>/<page>.md" "$REPO_ROOT/skills/wiki-plan/SKILL.md"
  [ "$status" -eq 0 ]

  run grep -F 'a `wiki-local/...` path' "$REPO_ROOT/skills/loop-implement/SKILL.md"
  [ "$status" -eq 0 ]
  run grep -F "from the project root — plus the task's Inputs" "$REPO_ROOT/skills/loop-implement/SKILL.md"
  [ "$status" -eq 0 ]

  run grep -F "project-specific when" "$REPO_ROOT/skills/wiki-ingest/SKILL.md"
  [ "$status" -eq 0 ]

  run grep -F "## Local-layer candidates" "$REPO_ROOT/skills/knowledge-flush/SKILL.md"
  [ "$status" -eq 0 ]

  run grep -F 'when it exists) also needs no config; it is not the `knowledge` role.' "$REPO_ROOT/skills/configure/SKILL.md"
  [ "$status" -eq 0 ]

  run grep -F 'A project can add its own layer at `<repo>/wiki-local/`' "$REPO_ROOT/README.md"
  [ "$status" -eq 0 ]
  run grep -F '`wiki-local/` layer needs no config either.)' "$REPO_ROOT/README.md"
  [ "$status" -eq 0 ]
}

# --- negative control: proves the wiring check above can fail ---------------

@test "negative control: an AGENTS.md copy without the local-layer lines fails the wiring check" {
  stripped="${BATS_TEST_TMPDIR}/AGENTS-no-local.md"
  grep -v 'wiki-local' "$AGENTS" | grep -v 'apply the local page' > "$stripped"

  run grep -F "wiki-local/index.md" "$stripped"
  [ "$status" -ne 0 ]
  run grep -F "apply the local page" "$stripped"
  [ "$status" -ne 0 ]
  run grep -F '| Project layer | `wiki-local/**`' "$stripped"
  [ "$status" -ne 0 ]
  run grep -F 'defaults to `confidence: field-tested`' "$stripped"
  [ "$status" -ne 0 ]
  # the strip removed only local-layer lines: the pinned step-7 line survives
  [ "$(step7_line_count "$stripped")" -eq 1 ]
  run grep -F "no unplanned pages reached" "$stripped"
  [ "$status" -eq 0 ]
}
