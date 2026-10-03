---
id: platforms-shells-unmatched-glob-in-a-command-argument
domain: platforms
category: shells
applies_to: [bash, zsh]
confidence: verified
sources:
  - https://zsh.sourceforge.io/Doc/Release/Options.html
  - https://www.gnu.org/software/bash/manual/html_node/Filename-Expansion.html
  - https://www.gnu.org/software/grep/manual/grep.html
last_verified: 2026-10-03
related: [platforms-shells-portable-shell-scripts, platforms-shells-escapes-in-shell-string-literals, testing-quality-checks-that-cannot-pass, backend-common-change-impact-call-site-enumeration, infrastructure-ci-cd-changed-files-only-gates]
---

# A Glob Meant for the Tool Written Unquoted in a Command Argument

## When this applies

A command passes a wildcard pattern to a program that does its own matching —
`grep -r --include=*.py`, `find . -name *.md`, `rsync --exclude=*.log`,
`git ls-files *.ts` — and the line runs in zsh (an interactive terminal, a
zsh-backed agent shell tool, a `#!/bin/zsh` script). Also when such a command
feeds an enumeration ("every file that registers X") and the list came back empty.

## Do this

1. **Quote every pattern the program is supposed to match**: `--include='*.py'`,
   `-name '*.md'`. The shell then hands the literal pattern to the program in
   every shell, and the program applies it the way its manual describes (GNU
   grep matches `--include` against each file's base name while recursing).
2. **Know what each shell does with an unquoted pattern that matches no file in
   the current directory.** A word such as `--include=*.py` almost never matches,
   because the shell compares the whole word, `--include=` prefix included,
   against file names:

| Shell (default options) | Unmatched unquoted pattern | What you see |
|-------------------------|----------------------------|--------------|
| bash, sh | Word passed through unchanged | Works — by accident; breaks when a file named like the word exists |
| bash with `failglob` | Command not run, error printed | `no match: --include=*.py`; under `bash -c` the rest of the line is skipped too |
| bash with `nullglob` | Word deleted from the arguments | The program runs with the flag missing — searches every file |
| zsh (`NOMATCH` on by default) | Command not run, error printed | `zsh: no matches found: --include=*.py`, status 1 |
| zsh with `NULL_GLOB` | Word deleted | Same as bash `nullglob` |

3. **Treat an empty enumeration as unverified until a positive control appears
   in it.** Before acting on "no file is missing X", confirm the same command
   lists one file you know contains the target. In zsh the failed command
   produces no output, and when it sits in a pipeline or a function the overall
   status can still be 0 — the empty result reads exactly like "nothing found".
4. **Read stderr of an enumeration that returned nothing.** `no matches found`
   (zsh) or `no match` (bash `failglob`) names the unquoted word to fix.

## Edge cases

| Case | Then |
|------|------|
| `cmd --include=*.py … \| sort > list.txt` in zsh | The first stage never runs, `sort` succeeds on empty input, the pipeline status is 0 and `list.txt` is empty. Quote the pattern; add `setopt pipefail` only if you also want the status to show it |
| The unquoted command is inside a zsh function or `$(…)` | The command is skipped, the function continues with the next line, and a substitution yields an empty string. Quote at the call site; the surrounding status does not reveal the skip |
| A file whose name matches the whole word exists in the cwd (bash, or zsh) | The shell substitutes that file name (`--include=x.py`), the program receives a different pattern than you wrote, and both shells print an empty list with status 0. Quoting removes the dependence on the cwd |
| Script must run under both bash and zsh | Quote the pattern; `setopt nonomatch` / `shopt` settings change only one shell and leave the other's behavior in place |
| The pattern is built in a variable (`pat='*.py'`) | Expand it quoted: `--include="$pat"`. bash splits and globs an unquoted `$pat`; zsh does not glob it unless `GLOB_SUBST` is set — quoting gives one behavior in both |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write `grep -r --include=*.py PAT .` | Write `grep -r --include='*.py' PAT .` | zsh refuses to run the unquoted form; bash runs it only while no file in the cwd matches the word |
| Report "no registry is missing the new code" from an empty search | Re-run until a known-present file appears in the output, then read the list | An aborted or mistyped search and a true absence both print nothing |
| Fix the zsh error with `unsetopt nomatch` in your shell | Quote the pattern in the command itself | The option fixes your terminal only; the next shell (CI bash, a teammate's zsh) gets the original behavior |

## Sources

- https://zsh.sourceforge.io/Doc/Release/Options.html — `NOMATCH` (default in zsh emulation): "If a pattern for filename generation has no matches, print an error, instead of leaving it unchanged in the argument list"; `NULL_GLOB` deletes the pattern instead and overrides `NOMATCH`
- https://www.gnu.org/software/bash/manual/html_node/Filename-Expansion.html — bash: with `nullglob` disabled an unmatched word "is left unchanged"; `nullglob` removes it; `failglob` "prints an error message and does not execute the command"
- https://www.gnu.org/software/grep/manual/grep.html — `--include=glob` / `--exclude=glob`: grep does its own wildcard matching against the base name of each file when searching recursively
- Local reproduction 2026-10-03 (macOS, zsh 5.9, bash 5.3.15): in a directory holding `sub/a.py`, zsh `grep -rl --include=*.py PAT .` printed `zsh:1: no matches found: --include=*.py` with status 1, and still did so with a `b.py` in the cwd; the quoted form and bash's unquoted form both listed `./sub/a.py`; `… | sort > out.txt` in zsh exited 0 with an empty `out.txt`; inside a zsh function the next line still ran and the function returned 0; bash `failglob` printed `no match: --include=*.py` and skipped the rest of the `bash -c` line; bash `nullglob` listed `sub/b.txt` as well (flag deleted); with a file named `--include=x.py` in the cwd both shells listed nothing and exited 0
- Field case 2026-10-02 (agent session, zsh-backed shell tool): an unquoted `--include=*.py` enumeration of "every place X is registered" printed two empty sections that read as "no registries missing"; the quoted form listed 10 files, 4 of them without the new code
