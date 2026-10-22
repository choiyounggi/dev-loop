---
id: qa-process-scope-purity-checks
domain: qa
category: process
applies_to: [general]
confidence: verified
sources:
  - https://git-scm.com/docs/git-status
  - https://www.gnu.org/software/bash/manual/html_node/Lists.html
  - "Local reproduction 2026-10-08 (zsh 5.9, BSD grep 2.6.0): chained one-liner printed a violator and `SCOPE_OK` with exit 0; a single-verdict script exited 1 with no token"
  - "Local reproduction, git 2.50.1 (Apple Git-155), 2026-08-05: collapsed `?? qa/` vs -uall per-file expansion"
  - https://bazel.build/reference/test-encyclopedia
  - "Field reproduction 2026-08-14 (dev-loop, reviews/i83-insight-emission-r1.md): a permanent bats test asserting `git status` scope failed on an unrelated uncommitted sibling file; rewritten to commit-diff evidence → 521/521"
  - https://git-scm.com/docs/gitignore
  - https://git-scm.com/docs/git-rev-parse
  - https://git-scm.com/docs/git-check-ignore
  - "dev-loop skills/loop-implement/SKILL.md, Gates ledger: step 0 writes `.dev-loop/gates/<task-id>.md`, step 7 and the Stop hook read it"
  - "Local reproduction 2026-10-08 (git 2.50.1, repo + linked worktree): `.dev-loop/` ledger shown as untracked, then hidden via `info/exclude` with no tracked change"
last_verified: 2026-10-08
related: [testing-quality-checks-that-cannot-pass, testing-quality-harness-reverse-controls, testing-quality-history-dependent-checks-on-shallow-clones, infrastructure-agent-orchestration-worktree-isolated-workers, platforms-toolchains-agent-files-written-by-next-dev]
---

# Proving Scope Purity from `git status` Output

## When this applies

You must prove that a change, session, or agent run touched nothing outside an
allowed path set by filtering `git status --porcelain` lines; a purity gate
reports a violation on a line like `?? qa/` for a directory that is wholly in
scope, or on state the run's own tooling wrote (`?? .dev-loop/`); you are writing such a gate for an orchestration/CI workflow; or a
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
   the two apart ([testing-quality-checks-that-cannot-pass]). "Fail" means the
   gate's own verdict — a non-zero exit and no pass token — not the planted
   path showing up in its output. Compute that verdict in one script from every
   condition (scope filter, forbidden files, any other check), print the token
   only after all of them held, and plant the bad input into that script's
   input rather than into a copy of one filter:

| Gate shape | Planted out-of-scope path produces |
|------------|------------------------------------|
| Chained one-liner: `<filter that prints violators>; <other check> \|\| echo SCOPE_OK` | The path **and** `SCOPE_OK`, exit 0 — the token follows the last check's status only (Bash manual, Lists, in Sources) |
| One script that appends each violation to `bad`, prints `bad=[…]` and exits 1 when `bad` is non-empty, and otherwise prints the token | `bad=[<path>]`, exit 1, no token |

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
| The run's own tooling writes untracked state into the tree it gates — dev-loop's `.dev-loop/gates/<task-id>.md` ledger (loop-implement step 0), which step 7 and the Stop hook still read | Before the first gate run, test a file inside it: `git check-ignore -q .dev-loop/gates/<file>` (without `--no-index`, which also reports a tracked file as ignored although `--porcelain` still lists it). Exit 0: it is ignored and stays out of `--porcelain`. Exit 1: add the directory to the gate's allowed set, or append it to the file `git rev-parse --git-path info/exclude` prints — that file is untracked and shared by every worktree of the repository, so the fix adds nothing to the change set. Keep the ledger in place |
| The gate also lists ignored files (`--ignored=matching`) | Tool state hidden through `info/exclude` comes back as `!! .dev-loop/`; keep that directory in the allowed set as well |
| A dev server or generator that ran during the session wrote files nobody asked for (`next dev` under an AI agent writes `AGENTS.md`/`CLAUDE.md`) | Attribute each unexpected path to the command that wrote it before you call it a violation or delete it ([platforms-toolchains-agent-files-written-by-next-dev]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Filter default `git status --porcelain` output with per-file path patterns | Add `-uall` first | An entirely-untracked directory collapses to `?? dir/`, which file-level patterns cannot match |
| Rely on the repo's ambient untracked-files default | Pass `-uall` explicitly in the gate script | `status.showUntrackedFiles=no` in any user config hides untracked files and turns the gate into a rubber stamp |
| Adopt the gate after seeing it fail once on real output | Run known-in-scope and planted-out-of-scope controls | Every mistyped filter also produces a failing run; only the pass/fail pair shows the gate discriminates |
| Prove the gate by running its path filter alone on the planted path | Plant the path in the whole gate's input and check its exit status and pass token | A filter run proves the filter; a token chained to only one of the checks still prints OK beside the violation |
| Assert `git status` output in a permanent test suite | Prove scope from the introducing commit's own diff, or skip when the environment cannot answer | The ambient tree is whoever-runs-it's in-progress state — an undeclared dependency that makes results non-reproducible |
| Delete the tool's ledger directory, or add it to the tracked `.gitignore` inside a scoped task, to turn the gate green | Hide it through `git rev-parse --git-path info/exclude` or allow it for this run; commit the `.gitignore` line as its own change | The ledger is still read for the final verdict, and a `.gitignore` edit is itself a tracked change outside the allowed set |

## Sources

- https://git-scm.com/docs/git-status — `-u` modes ("normal — Show untracked files and directories", "all — Also show individual files in untracked directories"), `status.showUntrackedFiles`, porcelain v1 rename format (`<orig-path> -> <path>`), C-string quoting vs `-z`, `--ignored=matching`
- https://www.gnu.org/software/bash/manual/html_node/Lists.html — "Commands separated by a ';' are executed sequentially"; in an OR list "command2 is executed if, and only if, command1 returns a non-zero exit status"; "The return status of AND and OR lists is the exit status of the last command executed in the list" — so `<filter>; <check> || echo SCOPE_OK` prints the token whenever the last check finds nothing, whatever the filter printed
- Local reproduction 2026-10-08 (zsh 5.9, BSD grep 2.6.0-FreeBSD): input `src/lib/pixel/a.ts` and `src/styles/x.css` through `<grep -vE scope filter>; <grep -qE forbidden-file check> || echo SCOPE_OK` printed `src/styles/x.css` and `SCOPE_OK`, exit 0, and the filter run alone printed the path. A single script collecting violations into `bad` printed `bad=[src/styles/x.css]`, exit 1, no token; it passed a known-good input and caught an in-scope `.env`. Field case the same day (a linkly task worktree, audit round 2): the task's gate printed `src/styles/x.css` with `SCOPE_OK` and exit 0, and its single-script rewrite reported `bad=[src/styles/x.css]` with no token
- Local reproduction (git 2.50.1, 2026-08-05): scratch repo with `qa/cases/x/{a,b}.md`; default porcelain printed the single line `?? qa/`, which a `^\?\? qa/…` per-file filter treated as a violation; `-uall` expanded to three file lines and the filter passed
- https://bazel.build/reference/test-encyclopedia — "Tests should be hermetic: that is, they ought to access only those resources on which they have a declared dependency"; "If tests are not properly hermetic then they do not give historically reproducible results"
- Field reproduction 2026-08-14 (dev-loop, reviews/i83-insight-emission-r1.md): a permanent bats test asserted working-tree purity via `git status` and failed spuriously on an uncommitted sibling file; rewritten to prove scope from the introducing commit's diff → suite back to 521/521
- https://git-scm.com/docs/gitignore — patterns "specific to a particular repository but which do not need to be shared with other related repositories (e.g., auxiliary files that live inside the repository but are specific to one user's workflow) should go into the `$GIT_COMMON_DIR/info/exclude` file"
- https://git-scm.com/docs/git-rev-parse — `--git-path <path>`: "Resolve "$GIT_DIR/<path>" and takes other path relocation variables … into account"
- dev-loop `skills/loop-implement/SKILL.md`, "Gates ledger": step 0 writes `.dev-loop/gates/<task-id>.md`; step 7 runs `gate-check.sh --run` on it; the Stop hook parses the ledgers and blocks the session from ending while gates are unmet
- Local reproduction 2026-10-08 (git 2.50.1, a repository plus one linked worktree): a ledger at `.dev-loop/gates/15-x.md` printed `?? .dev-loop/` (default) and `?? .dev-loop/gates/15-x.md` (`-uall`), `check-ignore` exit 1. From the worktree, `git rev-parse --git-path info/exclude` printed the main repository's `.git/info/exclude`; after appending `.dev-loop/` there, `--porcelain -uall` printed 0 lines in the worktree and in the main checkout, `check-ignore -v` named `info/exclude:7` (exit 0), and `--ignored=matching` printed `!! .dev-loop/`
- https://git-scm.com/docs/git-check-ignore — "By default, tracked files are not shown at all since they are not subject to exclude rules; but see '--no-index'." Reproduced 2026-10-08 (git 2.50.1): a committed `.dev-loop/gates/1.md` under an `info/exclude` rule exited 0 with `--no-index` and 1 without it, and `git status --porcelain` listed it as ` M`; an untracked file in the same directory exited 0 without `--no-index`
- Field case 2026-10-07 (a dev-loop task worktree in a Next.js project): `git check-ignore -q --no-index .dev-loop/gates/15-zod.md` exited 1, and feeding the line `?? .dev-loop/` through the plan's porcelain filter printed `.dev-loop/` as out of scope
