---
id: qa-process-scope-purity-checks
domain: qa
category: process
applies_to: [general]
confidence: verified
sources:
  - https://git-scm.com/docs/git-status
  - "Local reproduction, git 2.50.1 (Apple Git-155), 2026-08-05: collapsed `?? qa/` vs -uall per-file expansion"
  - https://bazel.build/reference/test-encyclopedia
  - "Field reproduction 2026-08-14 (dev-loop, reviews/i83-insight-emission-r1.md): a permanent bats test asserting `git status` scope failed on an unrelated uncommitted sibling file; rewritten to commit-diff evidence → 521/521"
last_verified: 2026-08-14
related: [testing-quality-checks-that-cannot-pass, testing-quality-harness-reverse-controls, testing-quality-history-dependent-checks-on-shallow-clones]
---

# Proving Scope Purity from `git status` Output

## When this applies

You must prove that a change, session, or agent run touched nothing outside an
allowed path set by filtering `git status --porcelain` lines; a purity gate
reports a violation on a line like `?? qa/` for a directory that is wholly in
scope; you are writing such a gate for an orchestration/CI workflow; or a
purity check that lives in a **permanent test suite** fails on files the
developer happens to have uncommitted.

## Do this

1. **Run `git status --porcelain -uall` whenever the output will be filtered by
   path.** The untracked-files mode decides whether your filter can see real
   paths at all:

| Mode | Output for an entirely-untracked directory | Effect on a path-filter gate |
|------|--------------------------------------------|------------------------------|
| `-uno` | nothing | out-of-scope untracked files are invisible — false pass |
| default (`-unormal`) | one collapsed `?? dir/` line | a per-file filter (`^\?\? qa/cases/…`) never matches the collapsed line — false violation |
| `-uall` | one line per file ("Also show individual files in untracked directories") | filter sees real paths — correct verdict |

2. **Pass the mode flag explicitly in scripts; never rely on the ambient
   default.** The default is user-configurable via `status.showUntrackedFiles`
   — a checkout where it is set to `no` makes the same gate silently pass with
   untracked out-of-scope files present. The command-line flag overrides the
   config.
3. **Validate the gate in both directions before trusting its first verdict**:
   run it against a tree whose changes are all in scope (must pass) and against
   the same tree with one planted out-of-scope file (must fail). A gate first
   observed only failing — or only passing — has not demonstrated it can tell
   the two apart ([testing-quality-checks-that-cannot-pass]).
4. **Choose the evidence source by the gate's lifetime.** The working tree is
   valid evidence only for a run that owns that tree:

| Gate lifetime | Evidence source |
|---------------|-----------------|
| One-shot gate for a run that owns its tree (orchestration step, agent session, CI job on its own checkout) | Working tree via `git status --porcelain -uall` |
| Permanent test suite anyone may run in their own checkout | The commit that introduced the change — `git diff-tree --no-commit-id --name-only -r <commit>`; when the environment cannot answer (no commit yet, shallow clone → [testing-quality-history-dependent-checks-on-shallow-clones]), skip explicitly rather than falling back to the tree |

   A permanent suite reading the ambient tree asserts someone else's
   in-progress state — tests should access only resources they have a declared
   dependency on, or they stop giving historically reproducible results (Bazel
   Test Encyclopedia); any uncommitted sibling file fails the suite spuriously.

## Edge cases

| Case | Then |
|------|------|
| Staged renames | Porcelain v1 prints `R <orig-path> -> <path>` — one line, two paths; the filter must accept the line only when **both** sides are in scope |
| Paths with whitespace/nonprintable characters | Porcelain v1 quotes them as C string literals, so a plain path prefix no longer matches — use `-z` (NUL-terminated, no quoting) and split on NUL |
| Purity must also cover ignored artifacts (build outputs, caches) | `git status` omits ignored files entirely; add `--ignored=matching` to list paths matching ignore patterns |
| Gate runs in a fresh worktree/clone | Config differences travel with `$HOME`, not the repo — the explicit `-uall` flag is still required |
| A purity check in a permanent suite went red on a teammate's unrelated WIP file | The failure indicts the runner's tree, not the change under test — move the check to commit-diff evidence (Do #4) or out of the suite into a one-shot workflow gate |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Filter default `git status --porcelain` output with per-file path patterns | Add `-uall` first | An entirely-untracked directory collapses to `?? dir/`, which file-level patterns cannot match |
| Rely on the repo's ambient untracked-files default | Pass `-uall` explicitly in the gate script | `status.showUntrackedFiles=no` in any user config hides untracked files and turns the gate into a rubber stamp |
| Adopt the gate after seeing it fail once on real output | Run known-in-scope and planted-out-of-scope controls | Every mistyped filter also produces a failing run; only the pass/fail pair shows the gate discriminates |
| Assert `git status` output in a permanent test suite | Prove scope from the introducing commit's own diff, or skip when the environment cannot answer | The ambient tree is whoever-runs-it's in-progress state — an undeclared dependency that makes results non-reproducible |

## Sources

- https://git-scm.com/docs/git-status — `-u` modes ("normal — Shows untracked files and directories", "all — Also show individual files in untracked directories"), `status.showUntrackedFiles`, porcelain v1 rename format (`<orig-path> -> <path>`), C-string quoting vs `-z`, `--ignored=matching`
- Local reproduction (git 2.50.1, 2026-08-05): scratch repo with `qa/cases/x/{a,b}.md`; default porcelain printed the single line `?? qa/`, which a `^\?\? qa/…` per-file filter treated as a violation; `-uall` expanded to three file lines and the filter passed
- https://bazel.build/reference/test-encyclopedia — "Tests should be hermetic: that is, they ought to access only those resources on which they have a declared dependency"; "If tests are not properly hermetic then they do not give historically reproducible results"
- Field reproduction 2026-08-14 (dev-loop, reviews/i83-insight-emission-r1.md): a permanent bats test asserted working-tree purity via `git status` and failed spuriously on an uncommitted sibling file; rewritten to prove scope from the introducing commit's diff → suite back to 521/521
