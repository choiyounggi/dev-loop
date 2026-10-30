---
id: platforms-tools-freshness-check-of-an-uncommitted-generated-file
domain: platforms
category: tools
applies_to: [git]
confidence: verified
sources:
  - https://git-scm.com/docs/git-add
  - https://git-scm.com/docs/git-diff
  - https://code.googlesource.com/git/+/HEAD/t/t2203-add-intent.sh
last_verified: 2026-10-30
related: [qa-document-verification-generated-reference-drift-gates, platforms-toolchains-regeneration-silently-drops-hand-edited-state, platforms-tools-staging-tracked-files-under-an-ignored-directory, testing-quality-checks-that-cannot-pass]
---

# Freshness Check of a Generated File That Is Not Committed Yet

## When this applies

You must prove that a generated file (a lockfile such as `requirements*.txt` from
`pip-compile --generate-hashes`, codegen output, a rendered reference) is up to
date — regenerating it changes nothing — and the file is new in this change: not
in `HEAD`, not yet committed. The usual CI check is
`<regenerate> && git diff --exit-code -- <file>`, and you are about to run it
before the first commit, or a gate already ran it and failed with
`new file mode 100644` and every line shown as `+`.

## Do this

1. **Before the first commit, compare a saved copy with the regenerated file:**

   ```sh
   cp requirements.txt requirements.txt.before
   <regenerate>
   cmp requirements.txt.before requirements.txt; rc=$?
   rm requirements.txt.before
   ```

   `cmp` exits 0 when the files are byte-identical and 1 when they differ — the
   same answer the CI check gives once the file is committed.
2. **Keep `git diff --exit-code -- <file>` for CI and for later commits**, where the
   file is in `HEAD`: there the index holds the committed content, so the diff is
   empty exactly when regeneration changed nothing.
3. **Prove the pre-commit check can fail** before trusting it: edit one line of the
   generated file (a pinned version, one hash), run step 1, and require exit 1.

## Edge cases

| Case | Then |
|------|------|
| The file was marked with `git add -N` (intent-to-add) so `git diff` would see it | The index entry has no content, so `git diff` prints the whole file as a new file and `--exit-code` exits 1 even when regeneration is byte-identical — the check cannot pass. Use step 1 |
| The file is untracked and not marked | `git diff` compares the working tree with the index, which has no entry for the file, so it prints nothing and `--exit-code` exits 0 whatever the content — the check cannot fail ([testing-quality-checks-that-cannot-pass]) |
| The file was staged with a plain `git add` (content in the index) before regenerating | `git diff --exit-code -- <file>` now compares against the staged content and works; restage after any intended change, or the check compares against an older version |
| Several generated files (one lockfile per dependency group) | Save and compare each one; report which file differed, not only that one did |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `git add -N <file>` so the CI command works before the first commit | Save a copy, regenerate, `cmp` | An intent-to-add entry is empty, so the diff always shows the whole file and the gate is red on correct work |
| Run `git diff --exit-code` on a new, unstaged file | `cmp` against a saved copy | An untracked file is not in the index, so the diff is empty and the gate is green on any content |

## Sources

- https://git-scm.com/docs/git-add — `-N`, `--intent-to-add`: "Record only the fact
  that the path will be added later. An entry for the path is placed in the index
  with no content. This is useful for, among other things, showing the unstaged
  content of such files with `git diff` and committing them with `git commit -a`."
- https://git-scm.com/docs/git-diff — `git diff [<options>] [--] [<path>...]`: "This
  form is to view the changes you made relative to the index (staging area for the
  next commit)"; `--exit-code` makes the program exit with 1 if there were
  differences and 0 otherwise.
- https://code.googlesource.com/git/+/HEAD/t/t2203-add-intent.sh — git's own test
  suite expects an intent-to-add path to appear in the diff as a new file
  (`new file mode`) with its whole content as added lines.
- Field reproduction 2026-10-30 (a Python repository adding hash-pinned
  `requirements*.txt` lockfiles): a gate running
  `git add -N requirements*.txt && <regen> && git diff --exit-code` exited 1 with
  `new file mode 100644` and 444 added lines on a byte-identical regeneration; the
  `cmp`-based check on the same regeneration exited 0.
