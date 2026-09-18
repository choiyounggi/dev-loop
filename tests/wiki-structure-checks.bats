#!/usr/bin/env bats
# Tests for scripts/wiki-structure-checks.js — the mechanical duplicate +
# format gate for the bundled wiki (countable half of wiki-lint, CI-enforced).
#
# A checker observed only ever returning 0 findings proves nothing
# (wiki/testing/quality/checks-that-cannot-pass.md): tests/fixtures/
# wiki-structure/bad/ is the negative control — a mini-wiki carrying every
# defect class exactly where the assertions below expect it. good/ is the
# paired control: a fully-compliant mini-wiki that must stay at 0 findings.

setup() {
  CHECKER="${BATS_TEST_DIRNAME}/../scripts/wiki-structure-checks.js"
  REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  FIXTURES="${BATS_TEST_DIRNAME}/fixtures/wiki-structure"
}

# --- normal: the real corpus is compliant -----------------------------------

@test "real wiki: exits 0 with findings: 0" {
  cd "$REPO_ROOT" || return 1
  run node "$CHECKER" wiki
  [ "$status" -eq 0 ]
  [[ "$output" == *"findings: 0"* ]]
}

@test "good fixture: exits 0, summary counts pages and indexes" {
  run node "$CHECKER" "$FIXTURES/good"
  [ "$status" -eq 0 ]
  [ "$output" = "pages: 2, indexes: 1, findings: 0" ]
}

# --- error: every defect class is caught (negative control) -----------------

@test "bad fixture: exit 3 and every check class fires" {
  run node "$CHECKER" "$FIXTURES/bad"
  [ "$status" -eq 3 ]
  [[ "$output" == *"no-frontmatter:"* ]]
  [[ "$output" == *"missing-key:"* ]]
  [[ "$output" == *"frontmatter lacks 'related'"* ]]
  [[ "$output" == *"duplicate-id:"* ]]
  [[ "$output" == *"id-path-mismatch:"* ]]
  [[ "$output" == *"id 'alpha-cat-wrong' != path-derived 'alpha-cat-one'"* ]]
  [[ "$output" == *"domain-mismatch:"* ]]
  [[ "$output" == *"category-mismatch:"* ]]
  [[ "$output" == *"bad-confidence:"* ]]
  [[ "$output" == *"verified-no-sources:"* ]]
  [[ "$output" == *"broken-index-link:"* ]]
  [[ "$output" == *"cat/ghost.md"* ]]
  [[ "$output" == *"duplicate-index-row:"* ]]
  [[ "$output" == *"cross-domain-listing:"* ]]
  [[ "$output" == *"orphan-page:"* ]]
  [[ "$output" == *"bad-related:"* ]]
  [[ "$output" == *"related id 'no-such-id'"* ]]
  [[ "$output" == *"duplicate-frontmatter-key:"* ]]
  [[ "$output" == *"key 'last_verified' appears 2 times"* ]]
  [[ "$output" == *"stray-frontmatter-value:"* ]]
  [[ "$output" == *"has 2 bracket-literal value lines"* ]]
  [[ "$output" == *"has an inline value followed by a stray '- ' bullet"* ]]
}

@test "bad fixture: summary goes to stdout, findings go to stderr only" {
  run bash -c "node '$CHECKER' '$FIXTURES/bad' 2>/dev/null"
  [ "$status" -eq 3 ]
  [ "$output" = "pages: 7, indexes: 2, findings: 18" ]
  run bash -c "node '$CHECKER' '$FIXTURES/bad' 2>&1 >/dev/null"
  [ "$status" -eq 3 ]
  [[ "$output" != *"pages:"* ]]
  [[ "$output" == *"orphan-page:"* ]]
}

# --- boundary ---------------------------------------------------------------

@test "empty wiki root (no pages, no indexes): exits 0 vacuously" {
  mkdir -p "$BATS_TEST_TMPDIR/empty"
  run node "$CHECKER" "$BATS_TEST_TMPDIR/empty"
  [ "$status" -eq 0 ]
  [ "$output" = "pages: 0, indexes: 0, findings: 0" ]
}

# --- error: refusal paths ---------------------------------------------------

@test "no argument: exit 4, usage on stderr, nothing on stdout" {
  run bash -c "node '$CHECKER' 2>/dev/null"
  [ "$status" -eq 4 ]
  [ -z "$output" ]
}

@test "nonexistent root: exit 4" {
  run node "$CHECKER" "$BATS_TEST_TMPDIR/does-not-exist"
  [ "$status" -eq 4 ]
  [[ "$output" == *"not a readable directory"* ]]
}

# --- lifecycle (issue #195) ---

@test "lifecycle ok fixture: superseded/retired pages delisted, exits 0" {
  run node "$CHECKER" "$FIXTURES/lifecycle/ok"
  [ "$status" -eq 0 ]
  [ "$output" = "pages: 5, indexes: 1, findings: 0" ]
}

@test "lifecycle bad fixture: bad-status, bad-superseded-by, listed-inactive fire and orphan-page does not" {
  run node "$CHECKER" "$FIXTURES/lifecycle/bad"
  [ "$status" -eq 3 ]
  [[ "$output" == *"bad-status:"* ]]
  [[ "$output" == *"status 'archived'"* ]]
  [ "$(printf '%s\n' "$output" | grep -c '^bad-superseded-by:')" -eq 2 ]
  [[ "$output" == *"listed-inactive:"* ]]
  [[ "$output" != *"orphan-page:"* ]]
  [[ "$output" == *"pages: 4, indexes: 1, findings: 4"* ]]
}

@test "lifecycle chain fixture: superseded-chain warns on stderr without changing exit code" {
  run bash -c "node '$CHECKER' '$FIXTURES/lifecycle/chain' 2>/dev/null"
  [ "$status" -eq 0 ]
  [ "$output" = $'pages: 3, indexes: 1, findings: 0\nwarnings: 1' ]
  run bash -c "node '$CHECKER' '$FIXTURES/lifecycle/chain' 2>&1 >/dev/null"
  [[ "$output" == *"superseded-chain:"* ]]
  [[ "$output" == *"alpha-cat-b"* ]]
}

@test "no status key: absent reads as active, orphan-page still fires, bad-status does not" {
  mkdir -p "$BATS_TEST_TMPDIR/nostatus/alpha/cat"
  cat > "$BATS_TEST_TMPDIR/nostatus/alpha/index.md" <<'EOF'
# alpha — Domain Index
EOF
  cat > "$BATS_TEST_TMPDIR/nostatus/alpha/cat/solo.md" <<'EOF'
---
id: alpha-cat-solo
domain: alpha
category: cat
applies_to: [general]
confidence: field-tested
sources:
  - https://example.com/solo
last_verified: 2026-01-01
related: []
---

# Solo
EOF
  run node "$CHECKER" "$BATS_TEST_TMPDIR/nostatus"
  [ "$status" -eq 3 ]
  [[ "$output" == *"orphan-page:"* ]]
  [[ "$output" != *"bad-status:"* ]]
}

@test "lifecycle ok fixture: negative control, no lifecycle class fires" {
  run bash -c "node '$CHECKER' '$FIXTURES/lifecycle/ok' 2>&1"
  [[ "$output" != *"bad-status:"* ]]
  [[ "$output" != *"bad-superseded-by:"* ]]
  [[ "$output" != *"listed-inactive:"* ]]
  [[ "$output" != *"superseded-chain:"* ]]
}

# --- reference_impl (issue #194 B) ---

@test "reference_impl local-ok: --layer local resolves paths against the parent of the root, exits 0" {
  cd "$BATS_TEST_TMPDIR"
  run node "$CHECKER" "$FIXTURES/reference-impl/local-ok/wiki-local" --layer local
  [ "$status" -eq 0 ]
  [ "$output" = "pages: 3, indexes: 1, findings: 0" ]
}

@test "reference_impl bundled-bad: reference-impl-bundled fires as an error with no layer flag" {
  run node "$CHECKER" "$FIXTURES/reference-impl/bundled-bad"
  [ "$status" -eq 3 ]
  [[ "$output" == *"reference-impl-bundled:"* ]]
  [[ "$output" == *"pointer.md"* ]]
  [[ "$output" == *"pages: 1, indexes: 1, findings: 1"* ]]
}

@test "reference_impl local-dead: reference-impl-missing warns twice on stderr without changing the exit code" {
  run bash -c "node '$CHECKER' '$FIXTURES/reference-impl/local-dead/wiki-local' --layer local 2>/dev/null"
  [ "$status" -eq 0 ]
  [ "$output" = $'pages: 1, indexes: 1, findings: 0\nwarnings: 2' ]
  run bash -c "node '$CHECKER' '$FIXTURES/reference-impl/local-dead/wiki-local' --layer local 2>&1 >/dev/null"
  [ "$(printf '%s\n' "$output" | grep -c '^reference-impl-missing:')" -eq 2 ]
  [[ "$output" == *"src/gone.js"* ]]
  [[ "$output" == *"../escape.js"* ]]
}

@test "reference_impl boundary: a page without the key or with an empty list is silent in the local layer" {
  run bash -c "node '$CHECKER' '$FIXTURES/reference-impl/local-ok/wiki-local' --layer local 2>&1"
  [[ "$output" != *"warnings:"* ]]
  [[ "$output" != *"reference-impl-"* ]]
}

@test "negative control: local-ok run without --layer flips to exactly one reference-impl-bundled" {
  run bash -c "node '$CHECKER' '$FIXTURES/reference-impl/local-ok/wiki-local' 2>&1"
  [ "$status" -eq 3 ]
  [ "$(printf '%s\n' "$output" | grep -c '^reference-impl-bundled:')" -eq 1 ]
  [[ "$output" == *"id-path-mismatch:"* ]]
}

@test "--layer with an unknown value: exit 4, reason on stderr, nothing on stdout" {
  run bash -c "node '$CHECKER' '$FIXTURES/good' --layer bogus 2>/dev/null"
  [ "$status" -eq 4 ]
  [ -z "$output" ]
  run bash -c "node '$CHECKER' '$FIXTURES/good' --layer bogus 2>&1 >/dev/null"
  [[ "$output" == *"--layer"* ]]
}

# --- schema wiring (issue #194 B) ---

@test "AGENTS.md and templates/page.md declare reference_impl as wiki-local only" {
  run grep -F 'reference_impl: [<repo-relative path>, ...] # wiki-local/** only' "$REPO_ROOT/AGENTS.md"
  [ "$status" -eq 0 ]
  run grep -F 'reference_impl: [<repo-relative path>, ...]' "$REPO_ROOT/templates/page.md"
  [ "$status" -eq 0 ]
}

@test "negative control: an AGENTS.md copy without the reference_impl line fails the wiring pin" {
  grep -v 'reference_impl: \[<repo-relative path>' "$REPO_ROOT/AGENTS.md" > "$BATS_TEST_TMPDIR/agents.md"
  run grep -F 'reference_impl: [<repo-relative path>, ...] # wiki-local/** only' "$BATS_TEST_TMPDIR/agents.md"
  [ "$status" -ne 0 ]
}
