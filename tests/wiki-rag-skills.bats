#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Prose-wiring pins for issue #202 A4-A6: the wiki_search fail-open second path
# in wiki-query step 3, wiki-ingest step 4/8, and wiki-lint check 19, plus the
# docs that describe the feature (references/tool-profile.md, the code-graph
# wiki page, README.md, log.md). Every @test's deciding assertion is its final
# command — a mid-test `[[ ]]` is silently masked on macOS's bundled bash 3.2
# (issue #114).

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  WQ="${REPO_ROOT}/skills/wiki-query/SKILL.md"
  WI="${REPO_ROOT}/skills/wiki-ingest/SKILL.md"
  WL="${REPO_ROOT}/skills/wiki-lint/SKILL.md"
  WP="${REPO_ROOT}/skills/wiki-plan/SKILL.md"
  TP="${REPO_ROOT}/references/tool-profile.md"
  CG="${REPO_ROOT}/wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md"
  RM="${REPO_ROOT}/README.md"
  LOG="${REPO_ROOT}/log.md"
  FAIL_OPEN='When the `wiki_search` tool is absent from the session or returns an empty list, continue exactly as this step read before the tool existed.'
}

# Word-wrapped prose (unlike a markdown table row) breaks a literal sentence
# across physical lines, so a literal grep -F cannot see it. Fold the file to
# single-spaced text the way a markdown renderer joins soft-wrapped lines,
# then count occurrences of the exact sentence in that folded text.
fail_open_count() {
  tr '\n' ' ' < "$1" | tr -s ' ' | grep -o -F "$FAIL_OPEN" | wc -l | tr -d ' '
}

# --- (a)/(b): wiki-query step 3 ---------------------------------------------

@test "(a) wiki-query step 3 carries the wiki_search retry, the trigger check, and the fail-open sentence" {
  run grep -F 'wiki_search(query, k=5)' "$WQ"
  [ "$status" -eq 0 ]
  run grep -F '"When this applies"' "$WQ"
  [ "$status" -eq 0 ]
  [ "$(fail_open_count "$WQ")" -eq 1 ]
}

@test "(b) negative control: stripping the wiki_search call removes the wiring match" {
  grep -v 'wiki_search(query, k=5)' "$WQ" > "$BATS_TEST_TMPDIR/wq.md"
  run grep -F 'wiki_search(query, k=5)' "$BATS_TEST_TMPDIR/wq.md"
  [ "$status" -ne 0 ]
}

# --- (c)/(d): wiki-ingest step 4 / step 8 -----------------------------------

@test "(c) wiki-ingest step 4 dedupes semantically, step 8 reports the hits, step 3 is untouched" {
  run grep -F 'Semantic dedupe first:' "$WI"
  [ "$status" -eq 0 ]
  [ "$(fail_open_count "$WI")" -eq 1 ]
  run grep -F 'top-5 wiki_search hits' "$WI"
  [ "$status" -eq 0 ]
  run grep -F 'project-specific when' "$WI"
  [ "$status" -eq 0 ]
}

@test "(d) negative control: stripping the semantic-dedupe bullet removes the wiring match" {
  grep -v 'Semantic dedupe first:' "$WI" > "$BATS_TEST_TMPDIR/wi.md"
  run grep -F 'Semantic dedupe first:' "$BATS_TEST_TMPDIR/wi.md"
  [ "$status" -ne 0 ]
}

# --- (e)/(f): wiki-lint check 19 --------------------------------------------

@test "(e) wiki-lint carries row 19, the moved weight pins, the Fix protocol bullet, and Phase 0 line" {
  run grep -F '| 19 | Two pages whose trigger chunks' "$WL"
  [ "$status" -eq 0 ]
  run grep -F '| info | 1 | 10–12, 18, 19 |' "$WL"
  [ "$status" -eq 0 ]
  run grep -F 'total_weight = 40' "$WL"
  [ "$status" -eq 0 ]
  run grep -F '(7×3 + 7×2 + 5×1)' "$WL"
  [ "$status" -eq 0 ]
  run grep -F -- '- For 19: report-only' "$WL"
  [ "$status" -eq 0 ]
  run grep -F -- '- Near-duplicate pairs (optional):' "$WL"
  [ "$status" -eq 0 ]
  [ "$(fail_open_count "$WL")" -eq 1 ]
}

@test "(f) negative control: stripping the row-19 line removes the wiring match" {
  grep -v -- '| 19 |' "$WL" > "$BATS_TEST_TMPDIR/wl.md"
  run grep -F -- '| 19 |' "$BATS_TEST_TMPDIR/wl.md"
  [ "$status" -ne 0 ]
}

# --- (g): the fail-open sentence is byte-identical and appears once per file ---

@test "(g) the fail-open sentence appears exactly once in each of the four SKILL.md files" {
  cq=$(fail_open_count "$WQ")
  ci=$(fail_open_count "$WI")
  cl=$(fail_open_count "$WL")
  cp=$(fail_open_count "$WP")
  [ "$cq" -eq 1 ] && [ "$ci" -eq 1 ] && [ "$cl" -eq 1 ] && [ "$cp" -eq 1 ]
}

# --- (h)/(i): references/tool-profile.md ------------------------------------

@test "(h) tool-profile carries the wiki RAG heading and the not-a-role sentence" {
  run grep -F -- '### wiki RAG — the bundled index and MCP (optional, not a role)' "$TP"
  [ "$status" -eq 0 ]
  run grep -F 'It is not the `knowledge` role' "$TP"
  [ "$status" -eq 0 ]
}

@test "(i) negative control: stripping the wiki RAG heading removes the wiring match" {
  grep -v -- '### wiki RAG' "$TP" > "$BATS_TEST_TMPDIR/tp.md"
  run grep -F -- '### wiki RAG — the bundled index and MCP (optional, not a role)' "$BATS_TEST_TMPDIR/tp.md"
  [ "$status" -ne 0 ]
}

# --- (j): the code-graph wiki page -------------------------------------------

@test "(j) the code-graph page carries the two-tool edge case row and the MCP-cost Sources bullet" {
  run grep -F 'tool count bounded to two' "$CG"
  [ "$status" -eq 0 ]
  run grep -F 'code-execution-with-mcp' "$CG"
  [ "$status" -eq 0 ]
}

@test "(j2) negative control: stripping the edge-case row removes the wiring match" {
  grep -v 'tool count bounded to two' "$CG" > "$BATS_TEST_TMPDIR/cg.md"
  run grep -F 'tool count bounded to two' "$BATS_TEST_TMPDIR/cg.md"
  [ "$status" -ne 0 ]
}

# --- (k): README ---------------------------------------------------------------

@test "(k) README carries the wiki search index heading and the off switch" {
  run grep -F -- '### Wiki search index (optional, fail-open)' "$RM"
  [ "$status" -eq 0 ]
  run grep -F 'DEV_LOOP_WIKI_INDEX=0' "$RM"
  [ "$status" -eq 0 ]
}

@test "(k2) negative control: stripping the README heading removes the wiring match" {
  grep -v -- '### Wiki search index' "$RM" > "$BATS_TEST_TMPDIR/rm.md"
  run grep -F -- '### Wiki search index (optional, fail-open)' "$BATS_TEST_TMPDIR/rm.md"
  [ "$status" -ne 0 ]
}

# --- (l): log.md ------------------------------------------------------------

@test "(l) log.md carries exactly one revise entry citing issue #202 A4-A6" {
  count=$(grep -F -c 'issue #202 A4-A6' "$LOG")
  [ "$count" -eq 1 ]
}

# --- (m)/(n): wiki-plan Phase B semantic candidate check --------------------

@test "(m) wiki-plan Phase B carries the semantic candidate check, the CLI form, and the candidates-only sentence" {
  run grep -F 'Semantic candidate check' "$WP"
  [ "$status" -eq 0 ]
  run grep -F 'index search --query' "$WP"
  [ "$status" -eq 0 ]
  run grep -F 'never on score alone' "$WP"
  [ "$status" -eq 0 ]
  [ "$(fail_open_count "$WP")" -eq 1 ]
}

@test "(n) negative control: stripping the semantic candidate check heading removes the wiring match" {
  grep -v 'Semantic candidate check' "$WP" > "$BATS_TEST_TMPDIR/wp.md"
  run grep -F 'Semantic candidate check' "$BATS_TEST_TMPDIR/wp.md"
  [ "$status" -ne 0 ]
}
