#!/usr/bin/env bats
# Tests for scripts/graph-freshness.sh — is the repo's graphify code graph
# fresh enough to use as a planning lead?
#
# Contract under test (wiki/infrastructure/agent-orchestration/
# code-graph-as-orientation-layer.md, directive 1 + edge case rows 3 and 6):
#   stdout one token line   exit
#   fresh                   0   no commit touched a file after graph.json's mtime
#   stale <N>               2   N distinct paths changed by later commits
#   absent                  3   no graph.json at <root>/graphify-out/ (or --graph)
#   cannot-evaluate <why>   4   usage | no-cli | bad-graph | not-git
#
# graphify itself is never executed: the CLI exits 0 on a missing node, a
# missing file, and a JSON decode error, so its status carries no signal. The
# suite therefore runs with GRAPHIFY_BIN pointing at `true` (resolves via
# command -v on both CI runners) and at `false` (would fail if ever run), and
# never needs a graphify install or a chmod +x stub.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/graph-freshness.sh"
  export GRAPHIFY_BIN=true
}

# A git repo whose only commit is dated 2020 — far older than any graph file
# the test writes afterwards, so "graph newer than every commit" needs no sleep.
make_repo() {
  git init -q "$1"
  git -C "$1" config user.email t@example.com
  git -C "$1" config user.name t
  printf 'a\n' > "$1/a.txt"
  # Like a real repo: the graph output dir is gitignored (spike S3), so
  # `git add -A` in later cases never sweeps graph.json into a commit.
  printf 'graphify-out/\n' > "$1/.gitignore"
  git -C "$1" add -A
  GIT_AUTHOR_DATE='2020-01-01T00:00:00Z' GIT_COMMITTER_DATE='2020-01-01T00:00:00Z' \
    git -C "$1" commit -q -m init
}

make_graph() {
  mkdir -p "$1/graphify-out"
  printf '{"nodes":[{"id":"a"}],"links":[]}\n' > "$1/graphify-out/graph.json"
}

# --- error: usage ------------------------------------------------------------

@test "error: no argument -> exit 4, cannot-evaluate usage on stdout, usage on stderr" {
  run bash "$SCRIPT"
  [ "$status" -eq 4 ]
  [[ "$output" == *'cannot-evaluate usage'* ]]
  [[ "$output" == *'usage: graph-freshness.sh <root> [--graph <path>]'* ]]
}

@test "error: root that is not a directory -> exit 4 cannot-evaluate usage" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/does-not-exist"
  [ "$status" -eq 4 ]
  [[ "$output" == *'cannot-evaluate usage'* ]]
}

@test "error: unknown flag -> exit 4 cannot-evaluate usage" {
  root="$BATS_TEST_TMPDIR/r"; make_repo "$root"; make_graph "$root"
  run bash "$SCRIPT" "$root" --bogus x
  [ "$status" -eq 4 ]
  [[ "$output" == *'cannot-evaluate usage'* ]]
}

# --- normal ------------------------------------------------------------------

@test "normal: no graph.json -> exit 3, stdout absent" {
  root="$BATS_TEST_TMPDIR/r"; make_repo "$root"
  run bash "$SCRIPT" "$root"
  [ "$status" -eq 3 ]
  [ "$output" = "absent" ]
}

@test "normal: graph newer than every commit -> exit 0, stdout fresh, stderr empty" {
  root="$BATS_TEST_TMPDIR/r"; make_repo "$root"; make_graph "$root"
  run bash "$SCRIPT" "$root"
  [ "$status" -eq 0 ]
  [ "$output" = "fresh" ]
  err="$(bash "$SCRIPT" "$root" 2>&1 >/dev/null)"
  [ -z "$err" ]
}

@test "normal: a commit after the graph touching two files -> exit 2, stdout \"stale 2\", stderr hint names graphify update" {
  root="$BATS_TEST_TMPDIR/r"; make_repo "$root"; make_graph "$root"
  printf 'b\n' > "$root/b.txt"; printf 'c\n' > "$root/c.txt"
  git -C "$root" add -A; git -C "$root" commit -q -m later
  run bash "$SCRIPT" "$root"
  [ "$status" -eq 2 ]
  [[ "$output" == *'stale 2'* ]]
  [[ "$output" == *'graphify update'* ]]
  out="$(bash "$SCRIPT" "$root" 2>/dev/null || true)"
  [ "$out" = "stale 2" ]
}

# --- error: cannot-evaluate --------------------------------------------------

@test "error: graph.json is not JSON -> exit 4 cannot-evaluate bad-graph, stderr names the file" {
  root="$BATS_TEST_TMPDIR/r"; make_repo "$root"
  mkdir -p "$root/graphify-out"; printf '{bad\n' > "$root/graphify-out/graph.json"
  run bash "$SCRIPT" "$root"
  [ "$status" -eq 4 ]
  [[ "$output" == *'cannot-evaluate bad-graph'* ]]
  [[ "$output" == *'graphify-out/graph.json'* ]]
}

@test "error: graph.json without a nodes array -> exit 4 cannot-evaluate bad-graph" {
  root="$BATS_TEST_TMPDIR/r"; make_repo "$root"
  mkdir -p "$root/graphify-out"; printf '{"foo":1}\n' > "$root/graphify-out/graph.json"
  run bash "$SCRIPT" "$root"
  [ "$status" -eq 4 ]
  [[ "$output" == *'cannot-evaluate bad-graph'* ]]
}

@test "error: GRAPHIFY_BIN does not resolve -> exit 4 cannot-evaluate no-cli" {
  root="$BATS_TEST_TMPDIR/r"; make_repo "$root"; make_graph "$root"
  GRAPHIFY_BIN="graphify-missing-xyz-$$" run bash "$SCRIPT" "$root"
  [ "$status" -eq 4 ]
  [[ "$output" == *'cannot-evaluate no-cli'* ]]
  [[ "$output" == *"graphify-missing-xyz-$$"* ]]
}

@test "error: root is not a git repository -> exit 4 cannot-evaluate not-git" {
  root="$BATS_TEST_TMPDIR/plain"; mkdir -p "$root"; make_graph "$root"
  # BATS_TEST_TMPDIR sits outside any repository, so `git -C "$root"` cannot
  # walk up into one; if that ever changes this case fails loudly (not-git
  # would read as fresh), never falsely passes.
  run bash "$SCRIPT" "$root"
  [ "$status" -eq 4 ]
  [[ "$output" == *'cannot-evaluate not-git'* ]]
}

# --- boundary ----------------------------------------------------------------

@test "boundary: uncommitted edits to a tracked file do not make the graph stale" {
  root="$BATS_TEST_TMPDIR/r"; make_repo "$root"; make_graph "$root"
  printf 'edited\n' >> "$root/a.txt"
  run bash "$SCRIPT" "$root"
  [ "$status" -eq 0 ]
  [ "$output" = "fresh" ]
}

@test "boundary: an empty nodes array is a readable graph -> fresh" {
  root="$BATS_TEST_TMPDIR/r"; make_repo "$root"
  mkdir -p "$root/graphify-out"; printf '{"nodes":[]}\n' > "$root/graphify-out/graph.json"
  run bash "$SCRIPT" "$root"
  [ "$status" -eq 0 ]
  [ "$output" = "fresh" ]
}

@test "boundary: --graph override is used when the default path is absent" {
  root="$BATS_TEST_TMPDIR/r"; make_repo "$root"
  printf '{"nodes":[{"id":"x"}]}\n' > "$BATS_TEST_TMPDIR/elsewhere.json"
  run bash "$SCRIPT" "$root" --graph "$BATS_TEST_TMPDIR/elsewhere.json"
  [ "$status" -eq 0 ]
  [ "$output" = "fresh" ]
}

@test "boundary: a commit touching only the graph output dir does not make the graph stale" {
  root="$BATS_TEST_TMPDIR/r"; make_repo "$root"; make_graph "$root"
  # A repo that tracks its graph: the rebuild commit itself must not read as stale.
  git -C "$root" add -f graphify-out/graph.json; git -C "$root" commit -q -m "track graph"
  run bash "$SCRIPT" "$root"
  [ "$status" -eq 0 ]
  [ "$output" = "fresh" ]
}

@test "boundary: a repo with no commits yet (unborn HEAD) -> fresh, not a git error" {
  root="$BATS_TEST_TMPDIR/unborn"; git init -q "$root"; make_graph "$root"
  run bash "$SCRIPT" "$root"
  [ "$status" -eq 0 ]
  [ "$output" = "fresh" ]
}

@test "boundary: an old branch merged after the graph was built is counted as stale" {
  root="$BATS_TEST_TMPDIR/r"; make_repo "$root"; make_graph "$root"
  # The topic commit itself predates the graph (2020) — only the merge commit is
  # newer. Plain `git log --name-only` prints nothing for a merge commit, so
  # without `-m --first-parent` this would read as fresh.
  git -C "$root" checkout -q -b topic
  printf 'b\n' > "$root/b.txt"; git -C "$root" add -A
  GIT_AUTHOR_DATE='2020-01-02T00:00:00Z' GIT_COMMITTER_DATE='2020-01-02T00:00:00Z' \
    git -C "$root" commit -q -m topic
  git -C "$root" checkout -q -
  git -C "$root" merge -q --no-ff -m merge topic
  out="$(bash "$SCRIPT" "$root" 2>/dev/null || true)"
  [ "$out" = "stale 1" ]
}

@test "boundary: stale count is distinct paths, not commits or lines" {
  root="$BATS_TEST_TMPDIR/r"; make_repo "$root"; make_graph "$root"
  printf 'b\n' > "$root/b.txt"; git -C "$root" add -A; git -C "$root" commit -q -m one
  printf 'b2\n' > "$root/b.txt"; git -C "$root" add -A; git -C "$root" commit -q -m two
  out="$(bash "$SCRIPT" "$root" 2>/dev/null || true)"
  [ "$out" = "stale 1" ]
}

# --- state -------------------------------------------------------------------

@test "state: stdout carries exactly one line on every outcome" {
  fresh="$BATS_TEST_TMPDIR/fresh"; make_repo "$fresh"; make_graph "$fresh"
  stale="$BATS_TEST_TMPDIR/stale"; make_repo "$stale"; make_graph "$stale"
  printf 'b\n' > "$stale/b.txt"; git -C "$stale" add -A; git -C "$stale" commit -q -m later
  absent="$BATS_TEST_TMPDIR/absent"; make_repo "$absent"
  bad="$BATS_TEST_TMPDIR/bad"; make_repo "$bad"
  mkdir -p "$bad/graphify-out"; printf 'nope\n' > "$bad/graphify-out/graph.json"
  for r in "$fresh" "$stale" "$absent" "$bad"; do
    out="$(bash "$SCRIPT" "$r" 2>/dev/null || true)"
    [ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" -eq 1 ]
    # Non-vacuous: the one line is a contract token, never empty text.
    [[ "$out" =~ ^(fresh|stale\ [0-9]+|absent|cannot-evaluate\ [a-z-]+)$ ]]
  done
}

@test "state: the graphify binary is never executed" {
  root="$BATS_TEST_TMPDIR/r"; make_repo "$root"; make_graph "$root"
  # `false` resolves via command -v but exits 1 if run — a fresh verdict
  # proves the script only resolved the name.
  GRAPHIFY_BIN=false run bash "$SCRIPT" "$root"
  [ "$status" -eq 0 ]
  [ "$output" = "fresh" ]
}
