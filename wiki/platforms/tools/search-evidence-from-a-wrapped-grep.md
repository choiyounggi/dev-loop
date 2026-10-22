---
id: platforms-tools-search-evidence-from-a-wrapped-grep
domain: platforms
category: tools
applies_to: [claude-code, agent-harness]
confidence: verified
sources:
  - https://code.claude.com/docs/en/tools-reference
  - https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md
  - https://pubs.opengroup.org/onlinepubs/9799919799/utilities/grep.html
  - https://pubs.opengroup.org/onlinepubs/9799919799/utilities/command.html
  - https://github.com/Genivia/ugrep/pull/556
  - "ugrep 7.8.4 built-in help (`--help ignore-files`, `--help exclude-from`), read from the binary Claude Code bundles"
  - "Local reproduction 2026-10-08 (Claude Code 2.1.293, bundled ugrep 7.8.4, zsh 5.9, macOS): ignore-file skips by path form, complexity-limit error with `-e` split, BSD grep memory limit"
last_verified: 2026-10-08
verified_model: claude-opus-5-5
related: [platforms-environment-path-resolution, platforms-tools-harness-mediated-tool-results, debugging-methodology-reproduce-first]
---

# A Search Run Through the Agent Shell's `grep` Wrapper Used as Evidence

## When this applies

A `grep -r`, `grep -l` or `grep -c` result run in Claude Code's Bash tool is the
evidence for a claim — a duplicate check, "no other call sites", a count, a file
list — or such a search came back blank or printed an error naming `ugrep`.
`type grep` there prints `grep is a shell function from …/shell-snapshots/…`.

## Do this

1. **Run `type grep` in the session at hand before a search becomes
   evidence.** On macOS, Linux and WSL, Claude Code leaves its Glob and Grep
   tools out of the default tool set unless the session names them (`--tools`,
   `--allowedTools`, and the other cases its tools reference lists), and in
   its shell `find` and `grep` run embedded `bfs` and `ugrep`. The shell
   snapshot defines `grep` as a function: `ARGV0=ugrep "$_cc_bin" -G
   --ignore-files --hidden -I --exclude-dir=.git … "$@"`. When any argument
   matches its defer list — `-z`/`-Z` (alone or in a short-option cluster),
   `--null`, `--null-data`, `-@`, `---…`, or ugrep's `--config`, `--pager`,
   `--view`, `--filter`, `--format-open` and `--save-config` — or the bundled
   binary is missing, it runs `command grep` instead. Adding one of those
   options therefore switches binaries silently: `grep -@` fails as an invalid
   option of `/usr/bin/grep`, although ugrep accepts `-@`. No setting turns
   the function off (2.1.293); a maintainer comment on anthropics/claude-code#69736
   (2026-08-17) says launching with the tools named (`--allowedTools Grep,Glob`
   or `--tools`) brings them back and stops the shadowing — re-run `type grep`
   to confirm in that session. Child shells do not inherit it: `bash -c`/`sh -c`
   and the scripts you run resolve `grep` to `/usr/bin/grep`.

2. **Choose the file set on purpose, with a command whose rules you can state:**

| The claim covers | Run |
|---|---|
| Every file under the path, ignored or not | `/usr/bin/grep -r --exclude-dir=.git -I …` (or `command grep …`); without those two options it also searches `.git/` and binary files, which the wrapper skips |
| Git's view: tracked plus untracked-but-not-ignored files | `git grep --untracked …` |
| Tracked files only | `git grep …` |

   The wrapper's `--ignore-files` skips paths its `.gitignore` files match, and
   the skipped set changes with how you spell the search path: ugrep matches a
   glob containing `/` against the full pathname and any other glob against
   the basename. From the directory holding the `.gitignore` (path `.` or none)
   it skipped a basename pattern and an anchored `sub/file.txt` pattern, as git
   does. Given an absolute or parent-relative path, it still skipped the
   basename match but searched `sub/file.txt`. A count built on that rule
   supports neither "none" nor "all".

3. **Read the exit status before the output.** grep exits 0 when lines were
   selected, 1 when none were, and above 1 on an error. The wrapper reports a
   regex it cannot compile on stderr — `ugrep: error: error at position N …
   exceeds complexity limits` — with exit 2 and nothing on stdout, so a `-c`
   count or a `$(…)` capture reads as blank or 0. When the status is 2, record
   "search did not run" and re-run it ([testing-quality-checks-that-cannot-pass]).

4. **Pick the fix by the error you got:**

| Error | Do |
|---|---|
| `ugrep: … exceeds complexity limits` | Run the same pattern with `/usr/bin/grep`; splitting it into separate `-e` patterns or a `-f` file fails at the same position, because ugrep joins them into one regex |
| `/usr/bin/grep`: `grep: out of memory` on one long `-E` alternation | Pass the alternatives as separate `-e` patterns or one per line in `-f <file>` |
| `claude native binary not installed` | The wrapper could not start ugrep, so nothing was searched; run `/usr/bin/grep` |

## Edge cases

| Case | Then |
|------|------|
| You name a gitignored file explicitly as an operand | It is searched; the skipping applies while recursing into directories |
| You want the wrapper's speed and every file | Add `--no-ignore-files`, which cancels the wrapper's `--ignore-files`; keep it to the Bash tool, because `/usr/bin/grep` rejects it with exit 2 |
| A gate script greps and you double-check its result by hand in the Bash tool | The script ran `/usr/bin/grep` and your check ran ugrep — compare with the same binary ([debugging-methodology-reproduce-first]) |
| The search must also skip build output or dependencies | Scope it with `git grep` or explicit paths and `--exclude-dir=<dir>`, and say so in the claim, so the skipped set is one you chose |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Cite a recursive `grep` from the Bash tool as "no other occurrences" | Run `/usr/bin/grep -r` or `git grep`, and name which one in the claim | The wrapper skips ignored files by a rule that changes with the path form |
| Read a blank `grep -c` result as zero | Check `$?` first; 2 means the search failed | ugrep prints its compile error to stderr and nothing to stdout |
| Split a failing alternation into `-e` patterns for the wrapper | Run the same pattern with `/usr/bin/grep` | ugrep joins the `-e` patterns and hits the same limit |

## Sources

- https://code.claude.com/docs/en/tools-reference — "On macOS, Linux, and WSL, Claude Code leaves Glob and Grep out of the default tool set, and Claude searches with `find` and `grep` through the Bash tool instead. In Claude's shell those two commands run embedded versions of `bfs` and `ugrep`" (raw `.md` page grepped 2026-10-08)
- https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md — 2.1.117: "Native builds on macOS and Linux: the `Glob` and `Grep` tools are replaced by embedded `bfs` and `ugrep` available through the Bash tool"; the opt-out request https://github.com/anthropics/claude-code/issues/69736 ("Add an opt-out for the built-in find→bfs / grep→ugrep shadow functions injected into the Bash tool shell") was open on 2026-10-08
- ugrep 7.8.4 `--help ignore-files`: "Ignore files and directories matching the globs in each FILE that is encountered in recursive searches. The default FILE is `.gitignore'"; `--no-ignore-files`: "cancel --ignore-files when specified"; `--help exclude-from`: "When a glob contains a `/', full pathnames are matched. Otherwise basenames are matched"
- https://github.com/Genivia/ugrep/pull/556 — "Fail fast when DFA position sets exceed complexity limits": `Pattern::compile()` raises `regex_error::exceeds_limits` when the DFA position count passes `DFA::MAX_POSITIONS` (4M), so the limit belongs to the compiled pattern as a whole
- https://pubs.opengroup.org/onlinepubs/9799919799/utilities/grep.html — EXIT STATUS: "0 One or more lines were selected …", "1 No lines were selected", ">1 An error occurred"
- https://pubs.opengroup.org/onlinepubs/9799919799/utilities/command.html — `command` treats its arguments as a simple command, "suppressing the shell function lookup"
- Local reproduction 2026-10-08 (Claude Code 2.1.293, bundled ugrep 7.8.4, zsh 5.9, macOS, BSD grep 2.6.0-FreeBSD): `functions grep` printed the ugrep invocation and its defer list (`-*-filter* | -*-pager* | -*-view* | -*-format-open* | -*-config* | ---* | -@* | -*-save-config* | -[Zz]* | -[!-]*[Zz]* | --null | --null-data`); `bash -c 'type grep'` printed `/usr/bin/grep`; `grep -@ -rl` through the wrapper exited 2 with `grep: invalid option -- @`, while the bundled ugrep run directly with `-@` listed every file. In a probe whose `.gitignore` listed `hidden.txt` and `sub/ignored-dir-file.txt`, `git check-ignore` matched both; the wrapper run with an absolute path skipped only `hidden.txt`, run from inside the probe it skipped both, and `/usr/bin/grep -rl` listed all four files. 200 alternatives of `(gh|git|curl)[^|]{0,80}prN` with `-ciE` made the wrapper exit 2 with `exceeds complexity limits` and empty stdout, joined or as 201 `-e` patterns; `/usr/bin/grep` returned 1 for both forms. One `-E` alternation of 3,000 words made `/usr/bin/grep` exit 2 with `out of memory`; 3,001 `-e` patterns or `-f` returned 1
- Field case 2026-10-08 (linkly worktree session): a long `-iE` alternation counted across 26 PR heads printed blank counts for every head through the wrapper; a dedup search through the wrapper missed gitignored files
