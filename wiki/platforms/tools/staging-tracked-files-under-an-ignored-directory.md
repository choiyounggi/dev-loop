---
id: platforms-tools-staging-tracked-files-under-an-ignored-directory
domain: platforms
category: tools
applies_to: [git]
confidence: verified
sources:
  - https://git-scm.com/docs/git-add
  - https://git-scm.com/docs/gitignore
  - https://git-scm.com/docs/git-check-ignore
  - https://github.com/microsoft/vscode/issues/160653
  - https://github.com/gitextensions/gitextensions/issues/10806
last_verified: 2026-10-07
related: [platforms-processes-tool-diagnostics-without-a-failing-exit-code, infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, infrastructure-agent-orchestration-worktree-isolated-workers, infrastructure-agent-orchestration-checkable-claims-in-an-adopted-plan]
---

# Staging a Tracked File That Sits Under an Ignored Directory

## When this applies

A `git add` names a file that is tracked but lives under a directory an ignore
rule matches (`reports/` in `.gitignore` or `.git/info/exclude` while
`reports/summary.md` is committed), alone or among other paths — chained into a
commit (`git add -- a.md reports/summary.md && git commit …`), run under
`set -e`, or judged by its exit status. Also when `git add` prints `The following
paths are ignored by one of your .gitignore files:` naming a directory while
`git status` shows the file staged.

## Do this

1. **Stage tracked files under an ignored directory with `git add -u`, the rest
   with a plain `git add`, and chain the two into the commit:**

   ```sh
   git add -- src/ README.md && git add -u -- reports/summary.md && git commit -m "…"
   ```

   `-u` updates only entries the index already has and "adds no new files", so
   it cannot pick up an ignored untracked file, and it exits 0 for this path. On
   a path the index lacks — a new report, a rename's new name — `-u` exits 128
   (`did not match any file(s) known to git`) and stages none of that command's
   paths; add such a file with `git add -f -- <file>`.
2. **Before committing a mixed list, compare `git diff --cached --name-status`
   with the list you meant to stage.** A `D` beside a file you meant to update
   means it is gone from the working tree: `git add -u` stages that deletion
   with exit 0, and `--name-only` prints it the same as an update. The staged
   set is the result; the exit status is not. A plain `git add` that names such
   a file exits 1 after staging that file and every other named path that is not
   itself untracked and ignored (step 3's `*.txt` row), so `&&` skips the commit
   while the index is complete.
3. **Know which ignore rules trigger it.** Measured with git 2.50.1, tracked
   `ign/t.txt` modified, untracked `other.txt`, running
   `git add -- other.txt ign/t.txt`:

| Rule that matches `ign/t.txt` | Result |
|-------------------------------|--------|
| `ign/` or `ign` (the directory), in `.gitignore` or `.git/info/exclude` | Lists `ign` as ignored, exit 1; both paths staged |
| `ign/*` or `ign/t.txt` (the file itself) | exit 0, both staged |
| `*.txt` (also matches the untracked `other.txt`) | Lists `other.txt`, exit 1; `ign/t.txt` staged, `other.txt` not staged |

4. **Find the rule with `git check-ignore -v --no-index <path>`.** Without
   `--no-index`, check-ignore skips tracked files ("they are not subject to
   exclude rules") and exits 1 for this path, which reads as "not ignored".

## Edge cases

| Case | Then |
|------|------|
| A named path is untracked and ignored | That path is not staged, so the exit 1 is real for it; stage it with `git add -f -- <file>` when you mean to track it |
| `git add -f` or `git add -u` with a directory operand | `-f` also adds every ignored untracked file inside; `-u` also stages the deletion of every tracked file missing from it. Pass file paths to both |
| `advice.addIgnoredFile=false` is set | Only the `hint:` lines disappear; the path list and exit 1 remain |
| `git add .` or a bare `git add -A` from the root (directory recursion) | exit 0: recursion skips ignored untracked files silently and updates tracked ones |
| Committing tracked paths directly (`git commit -m … -- ign/t.txt`) | Commits their working-tree content with exit 0 and no prior add; new files still need `git add` first |
| A GUI or wrapper stages one file at a time (VS Code, Git Extensions) | It reports the exit 1 as an error or exception although the file is staged; read `git status` before retrying |
| A plain `git add` already exited 1 on such a list | Read `git diff --cached --name-status`; when it matches the intended list, run `git commit` as its own command |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Chain `git add -- a.md ign/t.txt && git commit` | `git add -- a.md && git add -u -- ign/t.txt && git commit` | The plain add exits 1 after staging, so the chain stops with a complete index and no commit |
| Retry with `git add -f ign/` to clear the message | `git add -u -- ign/t.txt`, or `-f` on that file path | `-f` on the directory stages every ignored untracked file in it |
| Read the exit 1 as "nothing staged" and stage again | Read `git diff --cached --name-status` | The index already holds the change; a retry repeats the same exit 1 |
| Delete the directory rule from `.gitignore` to silence it | Keep the rule and stage the tracked file with `-u` | The rule keeps untracked byproducts out of every commit ([infrastructure-agent-orchestration-worktree-isolated-workers]) |

## Sources

- https://git-scm.com/docs/git-add — "If you specify the exact filename of an ignored file, git add will fail with a list of ignored files. Otherwise it will silently ignore the file."; `-u`: "Update the index just where it already has an entry matching <pathspec>. This removes as well as modifies index entries to match the working tree, but adds no new files."; `-f`: "Allow adding otherwise ignored files"
- https://git-scm.com/docs/gitignore — "Files already tracked by Git are not affected" — the docs do not describe the exit 1 for a tracked file under an ignored directory
- https://git-scm.com/docs/git-check-ignore — "By default, tracked files are not shown at all since they are not subject to exclude rules; but see '--no-index'"
- https://github.com/microsoft/vscode/issues/160653 — a tracked file under an ignored `Desktop` directory: `git add -A -- <file>` lists `Desktop` as ignored; with `advice.addIgnoredFile false` the list still prints (open since 2022-09-11)
- https://github.com/gitextensions/gitextensions/issues/10806 — Git 2.38.1.windows.1: `git add -- "<file under Assets/StreamingAssets/Audio>"` during conflict resolution → "Exit code: 1", listing `Assets/StreamingAssets/Audio`; the GUI raised an exception
- Local reproduction 2026-10-07 (git 2.50.1, Apple Git-155, one scratch repo per case): the step-3 table; `git add -- ign/t.txt` alone also exited 1 with the file staged; `git add -u -- ign/t.txt`, `git add -f -- …`, `git add .` and a bare `git add -A` exited 0 with the paths staged (the bare `-A` left an ignored untracked `ign/untracked.txt` unstaged); `git add -f -- ign/` staged that untracked file; `advice.addIgnoredFile=false` kept the list and exit 1; `git commit -m x -- ign/t.txt` exited 0 and committed the working-tree content; `git add … && git commit` left HEAD unchanged; `git add -- other.txt && git add -u -- ign/t.txt && git commit` exited 0 with both paths in the commit. After deleting `ign/t.txt`, `git add -u -- ign/t.txt` exited 0, `--name-only` printed `ign/t.txt` and `--name-status` printed `D ign/t.txt`; `git add -u -- ign/t.txt ign/new.txt` exited 128 with nothing staged; `git add -u -- ign/` staged `M ign/t.txt` and `D ign/u.txt`
- Field case 2026-10-07 (a knowledge-flush checkout, `.dev-loop/` in `.gitignore`, `.dev-loop/INGEST_REPORT.md` tracked): `git add -- … .dev-loop/INGEST_REPORT.md` exited 1 with the hint while the index held every path; a separate `git commit` produced the commit (71350ab)
