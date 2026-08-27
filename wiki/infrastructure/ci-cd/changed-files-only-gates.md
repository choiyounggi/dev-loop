---
id: infrastructure-ci-cd-changed-files-only-gates
domain: infrastructure
category: ci-cd
applies_to: [general]
confidence: verified
sources:
  - https://prettier.io/docs/en/cli
  - https://zsh.sourceforge.io/FAQ/zshfaq03.html
  - https://www.gnu.org/software/bash/manual/bash.html
  - https://eslint.org/docs/latest/use/command-line-interface
last_verified: 2026-08-27
related:
  [
    infrastructure-ci-cd-pipeline-structure,
    testing-quality-tests-that-cannot-fail,
    testing-quality-checks-that-cannot-pass,
    testing-quality-harness-reverse-controls,
    platforms-shells-portable-shell-scripts,
    testing-quality-history-dependent-checks-on-shallow-clones,
  ]
---

# A Lint or Format Gate Scoped to the Files a Change Touched

## When this applies

A CI step builds a list of changed files in the shell and passes it to a tool
that takes filenames as operands — `prettier --check`, `eslint`, a type checker,
a custom script. You are writing that step, or such a gate is green and you are
deciding whether "green" means "no violations" or "nothing was examined".

## Do this

1. **Count the list and branch on empty before calling the tool.** Emit the
   count, and on zero emit an explicit skip line and exit success without
   invoking the tool. Zero-file runs are the common case (a docs-only PR, a
   base ref that could not be resolved), and the tool's own success message does
   not distinguish them: Prettier prints "All matched files use Prettier code
   style!" and exits 0. A log reading `no formattable files changed — skipped`
   with no `Checking formatting...` line is what separates the two afterwards.

2. **Log the file list you actually passed, not just its length.** Flags that
   skip files silently put a second layer between "N operands" and "N files
   examined" — `--ignore-unknown` makes Prettier "ignore unknown files matched by
   patterns", and a list of only unsupported extensions produces the same success
   sentence as a clean run.

3. **Pass the list as separate words, in a form the shell splits.** Use an array
   (`"${FILES[@]}"` in bash, `${(f)FILES}` or an array in zsh), or pipe the list
   into `xargs`. zsh does not word-split unquoted parameters by default — the FAQ
   states "In most Bourne-shell derivatives, multiple-word variables such as
   `var="foo bar"` are split into words … By default, zsh does not have that
   behaviour: the variable remains intact" — so `cmd $FILES` reaches the tool as
   one operand naming a file that does not exist:

| Shell the step runs under | Pass the list as |
|---------------------------|------------------|
| `bash`/`sh` (GitHub Actions default `shell: bash`) | An array `"${FILES[@]}"`; unquoted `$FILES` splits but also globs |
| `zsh` (a developer's local run of the same script) | An array, or `xargs` — unquoted `$FILES` stays one word |
| Unknown / both | `printf '%s\n' "$LIST" \| xargs -r <tool>` — `-r` also supplies the empty-list guard from step 1 |

4. **Prove the gate can fail, in the same invocation shape CI uses.** Put a
   deliberately violating probe file in the list and require red
   ([testing-quality-tests-that-cannot-fail]).

5. **Place the probe on a path the tool does not ignore.** Prettier's default
   ignore set includes `.gitignore`, so a probe under a scratch directory is
   skipped and the control passes — which reads exactly like the gate working.
   Put it inside a checked package (`packages/<pkg>/src/…`), confirm red, then
   delete it.

6. **Resolve the base ref explicitly and fail the step when it is missing.** A
   diff against an absent ref yields an empty list, which step 1 turns into a
   *reported* skip rather than a silent pass; under a shallow clone, fetch the
   depth the diff needs ([testing-quality-history-dependent-checks-on-shallow-clones]).

## Edge cases

| Case | Then |
|------|------|
| The tool exits non-zero when patterns match nothing | Keep step 1 anyway — Prettier's `--no-error-on-unmatched-pattern` exists precisely to turn that error off, and a later flag change would silently restore the vacuous pass |
| Renamed or deleted files appear in the diff | Filter to files present in the working tree (`git diff --diff-filter=d`); a deleted path makes the tool error on a missing file and the failure is read as a lint violation |
| Paths contain spaces or non-ASCII | Use `-z`/NUL-delimited output (`git diff -z`) with `xargs -0`; newline-delimited lists split those paths into fragments |
| The list is long enough to hit the argument limit | Pipe through `xargs`, which batches; a single exec of the whole list fails with `E2BIG` and the message does not name a lint rule |
| The gate runs on a merge commit | Diff against the merge base, not the first parent, or the list includes the other branch's files and the count looks healthy while the change's own files are absent |
| The tool is `eslint` rather than `prettier` | The same empty-list shape applies, plus `--no-error-on-unmatched-pattern`; ESLint additionally skips files matched by `ignores`, so step 5's probe placement rule holds unchanged |
| Only the count is available in the log of an old run | The run cannot be re-read as evidence — re-run with step 2's list logging before citing it as a passing gate |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write `npx prettier --check $FILES` | Build an array and pass `"${FILES[@]}"`, or pipe to `xargs -r` | Under zsh the variable stays one word, so the tool matches nothing and still prints the success sentence with exit 0 |
| Read "All matched files use Prettier code style!" as the gate having checked the change | Log the count and the file list, and skip explicitly at zero | The sentence is emitted for an empty match set as well; the output alone cannot separate "no violations" from "no subject" |
| Add `--ignore-unknown` to stop errors on odd extensions | Add it and log the passed list | The flag removes the error that was the only signal that the operands were not being examined |
| Validate the gate with a probe file in a scratch or temp directory | Put the probe inside a checked package, require red, then delete it | Prettier's default ignores include `.gitignore`, so a scratch-path probe is skipped and the control passes without testing anything |
| Trust a green gate whose base ref failed to resolve | Fail the step when the base ref is missing | An unresolvable ref produces an empty diff, and an empty diff is the input that makes the gate vacuous |

## Sources

- https://prettier.io/docs/en/cli — `--check` prints "All matched files use Prettier code style!" and exits 0 when files pass; `--ignore-unknown` makes Prettier "ignore unknown files matched by patterns"; `--no-error-on-unmatched-pattern` "prevents errors when pattern is unmatched", which is what makes the unmatched case silent when enabled
- https://zsh.sourceforge.io/FAQ/zshfaq03.html — "In most Bourne-shell derivatives, multiple-word variables such as `var="foo bar"` are split into words when passed to a command … By default, zsh does not have that behaviour: the variable remains intact"; `setopt shwordsplit` restores the Bourne behaviour, and the FAQ recommends arrays instead
- https://www.gnu.org/software/bash/manual/bash.html — word splitting of unquoted expansions, and `"${arr[@]}"` expanding to one word per element, which is the portable form step 3 uses
- https://eslint.org/docs/latest/use/command-line-interface — `--no-error-on-unmatched-pattern` and the `ignores` configuration, the ESLint analogues in the edge-case table
- Field measurement 2026-08-24 (`rtb-unified`, zsh): `FILES="a.ts b.ts …"; npx prettier --check $FILES` printed `[error] No files matching the pattern were found: "a.ts b.ts …"` **together with** `All matched files use Prettier code style!`. Re-run with literal operands, an unformatted probe at `packages/orpc/src/zz-fmt-probe.ts` produced `[warn]` and a red gate; the same probe placed under `.claude/tmp/` passed, because that path is covered by the default `.gitignore`-based ignore set
- Field measurement 2026-08-24 (same repo): an empty list and a list containing only a `.png` both produced `All matched files use Prettier code style!` with rc=0; a gate carrying the step-1 zero branch instead logged `no formattable files changed — skipped` and omitted the `Checking formatting...` line entirely, which is the difference a reviewer can see
