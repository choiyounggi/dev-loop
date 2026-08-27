---
id: infrastructure-ci-cd-changed-files-only-gates
domain: infrastructure
category: ci-cd
applies_to: [general]
confidence: verified
sources:
  - https://prettier.io/docs/en/cli
  - https://prettier.io/docs/en/ignore
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
   count, and on zero emit an explicit skip line and exit success *without*
   invoking the tool. Invoking it with no operands is the vacuous case that
   exits **0** while checking nothing, and its message names a parser rather
   than the empty list, so nothing in the log says "no subject".

2. **Read the exit code, not the success sentence.** "All matched files use
   Prettier code style!" is printed in cases that examined nothing, including
   ones that exit non-zero — so the sentence alone never establishes a pass.
   Measured (Prettier 3.7.4), the shapes split like this:

| What the gate passed | Output | Exit | Examined |
|----------------------|--------|------|----------|
| No operands at all | `[error] No parser and no file path given, couldn't infer a parser.` | **0** | nothing — silent vacuous pass |
| Operands all ignore-filtered (`.prettierignore`/`.gitignore`) | `Checking formatting...` + success sentence | **0** | nothing — silent vacuous pass |
| Only unsupported extensions, with `--ignore-unknown` | `Checking formatting...` + success sentence | **0** | nothing — silent vacuous pass |
| A pattern/operand matching no file | `[error] No files matching the pattern were found: "…"` **and** the success sentence | **2** | nothing — loud, unless the error is suppressed |
| Only unsupported extensions, without `--ignore-unknown` | `[error] No parser could be inferred…` | **2** | nothing — loud |
| Real files, all clean | `Checking formatting...` + success sentence | **0** | yes |

3. **Log the file list you passed, not just its length.** The three exit-0 rows
   above are indistinguishable from a real pass in the log, and two of them
   occur with a non-empty operand list — so a count alone does not separate
   them. The list is what lets a reviewer tell which row happened.

4. **Keep `--no-error-on-unmatched-pattern` off unless the empty case is
   handled by step 1.** That flag turns the loud row into a silent one: the
   unmatched-pattern error is the only signal distinguishing "operands named
   nothing" from "operands were clean".

5. **Pass the list as separate words, in a form the shell splits.** Use an array
   (`"${FILES[@]}"` in bash, an array or `${(f)…}` in zsh), or pipe into `xargs`.
   zsh does not word-split unquoted parameter expansions by default — the FAQ
   states "In most Bourne-shell derivatives, multiple-word variables such as
   `var="foo bar"` are split into words … By default, zsh does not have that
   behaviour: the variable remains intact" — so `cmd $FILES` arrives as **one**
   operand naming a file that does not exist:

| Shell the step runs under | Pass the list as |
|---------------------------|------------------|
| `bash`/`sh` (GitHub Actions default `shell: bash`) | An array `"${FILES[@]}"`; unquoted `$FILES` splits but also globs |
| `zsh` (a developer's local run of the same script) | An array, or `xargs` — unquoted `$FILES` stays one word |
| Unknown / both | `printf '%s\n' "$LIST" \| xargs -r <tool>` — `-r` also supplies the empty-list guard from step 1 |

6. **Prove the gate can fail, in the same invocation shape CI uses**, by putting
   a deliberately violating probe file in the list and requiring red
   ([testing-quality-tests-that-cannot-fail]).

7. **Place the probe on a path the tool does not ignore.** Prettier ignores
   paths in `.gitignore` and `.prettierignore`, and an ignored operand produces
   the success sentence with exit 0 — so a probe in a scratch directory makes
   the control pass while testing nothing. Put it inside a checked package,
   confirm red, then delete it.

8. **Resolve the base ref explicitly and fail the step when it is missing.** An
   absent ref yields an empty list, which step 1 turns into a reported skip
   rather than a silent pass; under a shallow clone, fetch the depth the diff
   needs ([testing-quality-history-dependent-checks-on-shallow-clones]).

## Edge cases

| Case | Then |
|------|------|
| Renamed or deleted files appear in the diff | Filter to files present in the working tree (`git diff --diff-filter=d`); a deleted path makes the operand match nothing, which exits 2 with a message about patterns rather than about lint |
| Paths contain spaces or non-ASCII | Use NUL-delimited output (`git diff -z`) with `xargs -0`; newline-delimited lists split those paths into fragments, and each fragment then matches nothing |
| The list is long enough to hit the argument limit | Pipe through `xargs`, which batches; a single exec of the whole list fails with `E2BIG`, and that message names no lint rule |
| The gate runs on a merge commit | Diff against the merge base, not the first parent, or the list carries the other branch's files while the change's own are absent |
| The tool is `eslint` rather than `prettier` | Same empty-list shape, plus its own `--no-error-on-unmatched-pattern`; ESLint also skips files matched by `ignores`, so step 7's probe placement rule holds unchanged |
| Only the count is available in the log of an old run | The run cannot be re-read as evidence — the ignore-filtered and `--ignore-unknown` rows have non-zero counts and examined nothing; re-run with step 3's list logging before citing it |
| The step pipes the tool's output (`| tee`, `| tail`) | The pipeline's exit code is the last command's — set `set -o pipefail`, or the exit-2 rows are reported as passes |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Read "All matched files use Prettier code style!" as the gate having checked the change | Branch on an empty list, log the passed list, and judge by exit code | Measured: that sentence is printed for an ignore-filtered list (exit 0) and alongside an unmatched-pattern error (exit 2) — it tracks neither "examined" nor "passed" |
| Invoke the tool with whatever the diff produced, including nothing | Skip explicitly at zero operands | Measured: `prettier --check` with no operands exits **0**, and its message mentions a missing parser rather than an empty list |
| Write `npx prettier --check $FILES` | Build an array and pass `"${FILES[@]}"`, or pipe to `xargs -r` | Under zsh the variable stays one word, so the tool matches nothing; it exits 2, but the log also carries the success sentence, which is what gets quoted as evidence |
| Add `--ignore-unknown` to stop errors on odd extensions | Add it and log the passed list | Measured: with the flag, a list of only unsupported files exits 0 with the success sentence — the error it removed was the signal that nothing was examined |
| Add `--no-error-on-unmatched-pattern` to quiet a noisy step | Fix the list construction, and keep step 1's empty branch | The flag converts the one loudly-failing empty case into a silent pass |
| Validate the gate with a probe file in a scratch or temp directory | Put the probe inside a checked package, require red, then delete it | Prettier ignores `.gitignore`d paths, and an ignored operand returns the success sentence with exit 0 |

## Sources

- https://prettier.io/docs/en/cli — `--check` reports whether files are formatted; `--ignore-unknown` makes Prettier "ignore unknown files matched by patterns"; `--no-error-on-unmatched-pattern` "prevents errors when pattern is unmatched", i.e. erroring is the default for an unmatched pattern
- https://prettier.io/docs/en/ignore — `.prettierignore` and `.gitignore` paths are excluded from formatting, the mechanism behind the ignore-filtered rows and step 7
- https://zsh.sourceforge.io/FAQ/zshfaq03.html — "In most Bourne-shell derivatives, multiple-word variables such as `var="foo bar"` are split into words … By default, zsh does not have that behaviour: the variable remains intact"; `setopt shwordsplit` restores Bourne behaviour, and the FAQ recommends arrays
- https://www.gnu.org/software/bash/manual/bash.html — word splitting of unquoted expansions, and `"${arr[@]}"` expanding to one word per element (step 5's portable form)
- https://eslint.org/docs/latest/use/command-line-interface — `--no-error-on-unmatched-pattern` and `ignores`, the ESLint analogues in the edge-case table
- Local measurement 2026-08-27 (Prettier **3.7.4**, macOS, fixture: `good.ts` clean, `bad.ts` unformatted, `pic.png`): no operands → `[error] No parser and no file path given, couldn't infer a parser.`, **rc=0**; `'nope/**/*.ts'` → `[error] No files matching the pattern were found` *plus* `All matched files use Prettier code style!`, **rc=2**; single word-split operand `"good.ts bad.ts"` → same pair, **rc=2**; `pic.png` alone → `[error] No parser could be inferred`, **rc=2**; `--ignore-unknown pic.png` → success sentence, **rc=0**; `good.ts` while listed in `.prettierignore` → success sentence, **rc=0**; `good.ts` normally → success sentence, rc=0. This measurement corrected an earlier draft of this page, which had generalised "empty match set ⇒ exit 0" from a field log in which the success sentence and the unmatched-pattern error appeared together
- Field observation 2026-08-24 (`rtb-unified`, zsh): `npx prettier --check $FILES` emitted `[error] No files matching the pattern were found: "a.ts b.ts …"` together with the success sentence — the pairing that makes such a log read as a pass when only the sentence is quoted. A probe at `packages/orpc/src/zz-fmt-probe.ts` produced `[warn]` and a red gate; the same probe under `.claude/tmp/` passed, that path being `.gitignore`d
