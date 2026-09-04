# Task 01: graph-freshness.sh with its bats suite
## Objective
`scripts/graph-freshness.sh <root> [--graph <path>]` exists, prints exactly one stdout token line, exits 0/2/3/4 per D2, never executes graphify, and `tests/graph-freshness.bats` proves every outcome on a runner that has no graphify installed.
## Wiki pages (read these first, only these)
- wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md — use for: directive 1 (freshness from git log), edge cases "CLI exits 0", "uncommitted edits"
- wiki/testing/quality/checks-that-cannot-pass.md — use for: directives 3–4 (target-missing vs content-missing get distinct exit codes and messages)
- wiki/platforms/shells/portable-shell-scripts.md — use for: shebang, `set -euo pipefail`, quoting, verifying state with an independent command
- wiki/platforms/tools/bsd-vs-gnu-cli.md — use for: the `date`/`stat` fallback chain (macOS BSD vs Linux GNU)
## Inputs
- Decisions that bind you: D1 (mtime vs git log), D2 (exit contract, `GRAPHIFY_BIN` override, never execute graphify), D3 (dialect, fallback chain, jq validity)
- Style reference: tests/resolve-tools.bats (setup() with `BATS_TEST_TMPDIR`, `run bash "$SCRIPT"`, `[ "$status" -eq N ]`)
## Steps
1. Create `scripts/graph-freshness.sh` (mode 0755 like the sibling scripts, `#!/usr/bin/env bash`, `set -euo pipefail`) with this header comment, verbatim in intent:
   ```
   # graph-freshness.sh — is the repo's graphify code graph fresh enough to use as a lead?
   # usage: graph-freshness.sh <root> [--graph <path>]
   # stdout: exactly one line the caller branches on
   #   fresh                          exit 0  no commit touched a file after graph.json's mtime
   #   stale <N>                      exit 2  N distinct paths changed by commits after the mtime
   #   absent                         exit 3  no graph.json (default <root>/graphify-out/graph.json)
   #   cannot-evaluate <reason>       exit 4  reason: usage | no-cli | bad-graph | not-git
   # stderr: on exit 2 one hint line naming `graphify update <root>`; on exit 4 the reason
   # Never runs graphify. Only checks that `${GRAPHIFY_BIN:-graphify}` resolves via command -v,
   # because the CLI exits 0 on a missing node, a missing file, and a JSON decode error, so its
   # exit status carries no signal (wiki: code-graph-as-orientation-layer, edge case row 3).
   # Uncommitted edits are not counted — freshness is relative to commits only.
   # A commit in the same second as the mtime counts as stale (git --since is inclusive).
   ```
2. Implement in this order, each branch printing its token to stdout and exiting:
   1. Parse args: first positional is `root`; `--graph <path>` optional. Missing root, unknown flag, or `root` not a directory → stderr `usage: graph-freshness.sh <root> [--graph <path>]`, stdout `cannot-evaluate usage`, exit 4.
   2. `graph="${graph_override:-$root/graphify-out/graph.json}"`; `[ -f "$graph" ]` else stdout `absent`, exit 3.
   3. `command -v "${GRAPHIFY_BIN:-graphify}" >/dev/null 2>&1` else stderr `graphify CLI not found (GRAPHIFY_BIN=${GRAPHIFY_BIN:-graphify})`, stdout `cannot-evaluate no-cli`, exit 4.
   4. `jq -e '.nodes | type == "array"' "$graph" >/dev/null 2>&1` else stderr `unreadable graph: $graph`, stdout `cannot-evaluate bad-graph`, exit 4.
   5. `git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1` else stderr `not a git repository: $root`, stdout `cannot-evaluate not-git`, exit 4.
   6. `epoch=$(date -r "$graph" +%s 2>/dev/null || stat -c %Y "$graph" 2>/dev/null || stat -f %m "$graph")`.
   7. `n=$(git -C "$root" log --since="@$epoch" --name-only --format='' | sed '/^$/d' | sort -u | wc -l | tr -d ' ')`.
   8. `[ "$n" -eq 0 ]` → stdout `fresh`, exit 0. Else stderr `hint: graphify update "$root"   # AST-only, no LLM, rebuilds graphify-out/graph.json from the current checkout`, stdout `stale $n`, exit 2.
3. Create `tests/graph-freshness.bats` with `setup()` that sets `SCRIPT="${BATS_TEST_DIRNAME}/../scripts/graph-freshness.sh"`, `export GRAPHIFY_BIN=true` (the `true` binary resolves via `command -v` on both OSes, and the script must never execute it), and a helper `make_repo()` that: `git init -q "$1"`, sets `user.email`/`user.name` locally, writes `a.txt`, and commits with `GIT_AUTHOR_DATE='2020-01-01T00:00:00Z' GIT_COMMITTER_DATE='2020-01-01T00:00:00Z'` so the commit is far older than any graph file written afterwards. A helper `make_graph()` writes `{"nodes":[{"id":"a"}],"links":[]}` to `$1/graphify-out/graph.json` (mkdir -p first).
4. Write these cases (names are the `@test` strings; keep the `normal:`/`error:`/`boundary:`/`state:` prefixes the suite uses):
   - `error: no argument -> exit 4, cannot-evaluate usage on stdout, usage on stderr`
   - `error: root that is not a directory -> exit 4 cannot-evaluate usage`
   - `normal: no graph.json -> exit 3, stdout absent`
   - `normal: graph newer than every commit -> exit 0, stdout fresh, stderr empty`
   - `normal: a commit after the graph touching two files -> exit 2, stdout "stale 2", stderr hint names graphify update` (make_repo, make_graph, then write `b.txt` and `c.txt`, `git add -A`, commit with the default (now) date)
   - `error: graph.json is not JSON -> exit 4 cannot-evaluate bad-graph, stderr names the file`
   - `error: graph.json without a nodes array -> exit 4 cannot-evaluate bad-graph` (`{"foo":1}`)
   - `error: GRAPHIFY_BIN does not resolve -> exit 4 cannot-evaluate no-cli` (`GRAPHIFY_BIN=graphify-missing-xyz-$$`)
   - `error: root is not a git repository -> exit 4 cannot-evaluate not-git` (plain dir + make_graph)
   - `boundary: uncommitted edits to a tracked file do not make the graph stale` (make_repo, make_graph, `echo x >> a.txt`, expect fresh)
   - `boundary: an empty nodes array is a readable graph -> fresh` (`{"nodes":[]}`)
   - `boundary: --graph override is used when the default path is absent` (graph at `$BATS_TEST_TMPDIR/elsewhere.json`, root has no graphify-out; expect fresh)
   - `state: stdout carries exactly one line on every outcome` (loop the fresh, stale, absent, bad-graph cases; `[ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" -eq 1 ]` on stdout only — capture stdout separately with `run bash -c '... 2>/dev/null'`)
   - `state: the graphify binary is never executed` (`GRAPHIFY_BIN=false` — resolves, would exit 1 if run — expect `fresh` exit 0)
5. Run `PATH=/opt/homebrew/bin:$PATH bats tests/graph-freshness.bats` and `shellcheck scripts/graph-freshness.sh` if shellcheck is installed (skip silently if not).
## Deliverables
- scripts/graph-freshness.sh (new, executable)
- tests/graph-freshness.bats (new)
## Verify
- `PATH=/opt/homebrew/bin:$PATH bats tests/graph-freshness.bats` → all `ok`, 14 cases
- `bash scripts/graph-freshness.sh` (no args) → prints `cannot-evaluate usage`, rc 4 (run bare, read `$?` on the next line — never in a pipe)
- covers: R1, R2, R3, R11
## Out of scope
- Any SKILL.md or brief text (tasks 03/04); tool-profile docs (02/05); running or offering `graphify update` (the script only prints the hint).
