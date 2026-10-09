---
id: platforms-tools-gitignore-directory-reinclusion
domain: platforms
category: tools
applies_to: [git]
confidence: verified
sources:
  - https://git-scm.com/docs/gitignore
  - https://git-scm.com/docs/git-check-ignore
last_verified: 2026-09-27
related: [infrastructure-agent-orchestration-worktree-isolated-workers, infrastructure-agent-orchestration-checkable-claims-in-an-adopted-plan]
---

# Re-including a Path Under an Ignored Directory

## When this applies

Writing a `.gitignore` / `info/exclude` rule, an error message, or a doc that
tells a reader to keep one path inside a directory that is otherwise ignored
(`dir/` plus `!dir/keep`); a `!` negation for a nested path has no visible
effect; a tool refused a deliverable as ignored and you are choosing the
pattern pair to recommend in its message.

## Do this

1. **Ignore the directory's contents, not the directory.** Write `dir/*` and
   then `!dir/keep`. Git does not descend into a directory excluded by `dir/`,
   so a negation for anything under it is never evaluated — the gitignore
   reference states it directly: "It is not possible to re-include a file if a
   parent directory of that file is excluded."
2. **Prove the pair before publishing it** in a scratch repository with
   `git check-ignore -v <path>`: exit 1 with no output means re-included; exit
   0 printing `file:line:pattern` means still ignored and names the rule that
   wins.
3. **Re-include every ancestor level for a deeper path.** For `dir/sub/keep`
   write `dir/*`, `!dir/sub`, `dir/sub/*`, `!dir/sub/keep` — each level must be
   listed again before its own contents can be negated.

| Pattern pair | `git check-ignore -v dir/keep/f` | Read as |
|--------------|----------------------------------|---------|
| `dir/` + `!dir/keep` | exit 0, prints `.gitignore:1:dir/` | Negation unreachable; the directory itself is excluded |
| `dir/*` + `!dir/keep` | exit 1, no output | Re-included; only siblings of `keep` stay ignored |

## Edge cases

| Case | Then |
|------|------|
| The `dir/` rule lives in a parent `.gitignore`, `info/exclude`, or a global excludes file you do not own | The semantics are the same; `check-ignore -v` names the file and line that wins, so edit that rule to `dir/*` or add a narrower `!` in a file git reads later (`info/exclude` is read after every `.gitignore`) |
| The file to keep is already tracked | Ignore rules apply to untracked files only; `git ls-files dir` shows what is tracked. Once `git add -f dir/keep` has tracked it, later modifications are tracked regardless of the rule — use this when the ignore file cannot be edited |
| The message is about a whole subtree (`dir/artifacts/`) rather than one file | Recommend `dir/*` + `!dir/artifacts` and verify with a file inside the subtree, not the directory path — `check-ignore` on a directory path reports the directory rule, not what a file under it would get |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Tell the user to add `!dir/keep` below an existing `dir/` line | Tell them to change `dir/` to `dir/*` and then add `!dir/keep` | The negation has no effect while the parent directory is excluded |
| Publish the recommended pattern from memory | Run `git check-ignore -v` on the pair in a scratch repo and paste the exit code | The two pairs differ by one character and only the exit code separates them |

## Sources

- https://git-scm.com/docs/gitignore — "It is not possible to re-include a file if a parent directory of that file is excluded. Git doesn't list excluded directories for performance reasons, so any patterns on contained files have no effect, no matter where they are defined."
- https://git-scm.com/docs/git-check-ignore — exit status 0 when one or more paths are ignored, 1 when none are; `-v` prints the matching pattern with its source file and line
- Local reproduction 2026-09-27 (git 2.50.1, macOS): `.crew/` + `!.crew/artifacts` → `git check-ignore -v .crew/artifacts/f.txt` printed `.gitignore:1:.crew/` and exited 0; `.crew/*` + `!.crew/artifacts` → no output, exit 1
- Field evidence 2026-09 (an orchestration run's plan review, error-message wording for an artifacts directory under an ignored `.crew/`): the reviewer reproduced the same two exit codes in a scratch repo before the message text was fixed to recommend `.crew/*`
