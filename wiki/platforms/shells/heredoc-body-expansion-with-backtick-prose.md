---
id: platforms-shells-heredoc-body-expansion-with-backtick-prose
domain: platforms
category: shells
applies_to: [bash, zsh, posix-sh]
confidence: verified
sources:
  - https://www.gnu.org/software/bash/manual/html_node/Redirections.html
  - https://zsh.sourceforge.io/Doc/Release/Redirection.html
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
last_verified: 2026-09-28
related: [platforms-shells-escapes-in-shell-string-literals, platforms-shells-portable-shell-scripts, platforms-shells-command-text-inspected-before-execution]
---

# Heredoc Body That Must Expand a Variable While Holding Backtick Prose

## When this applies

You are writing a multi-line text body through a heredoc (`cat <<EOF > notes.md`,
a commit or PR message, a worker outbox note, a README fragment) that both needs
at least one shell variable expanded and quotes commands in markdown backtick
spans. Also when such a write printed `command not found: <word>` or a tool error
(`fatal: a branch named … already exists`) for a command you never ran, or the
written file has empty gaps where the backtick spans were.

## Do this

1. **Know the one rule.** The delimiter word decides the whole body. A quoted
   delimiter (`<<'EOF'`, `<<"EOF"`, `<<\EOF`) makes the body verbatim. An unquoted
   delimiter (`<<EOF`) treats the body like a double-quoted string: every line
   undergoes parameter expansion, command substitution and arithmetic expansion,
   so each `` `…` `` span **runs as a command in the current directory and
   environment** and its stdout replaces the span; only `\`, `$` and `` ` `` can
   be backslash-quoted. bash, zsh and POSIX `sh` document the same rule (Sources).

2. **Pick the body strategy from the table.** Rows are ordered general → specific;
   take the most specific row that fits.

| Case | Do |
|------|----|
| The body needs no variable | Quote the delimiter (`<<'EOF'`); the text lands byte-for-byte, backticks and `$` included |
| The body needs a variable and holds no backtick and no literal `$` | The unquoted delimiter is correct as written; the variable expands and nothing else is touched |
| The body needs a variable and holds backtick spans (or a literal `$`) | Quote the delimiter and put a placeholder (`@@TASK@@`) where the value goes; substitute it after the write with a tool that treats the replacement as data (`V="$TASK" python3 -c '…replace("@@TASK@@", os.environ["V"])…'`), or write the body with a non-shell tool (an editor/Write tool) with the value already inlined |
| Same, and GNU `envsubst` is installed | Keep the delimiter quoted and pipe the body through `envsubst '$TASK'` with an explicit variable list; it rewrites only the listed `$NAME` references and leaves backticks and every other `$` untouched (macOS: `brew install gettext`) |
| The body must stay one unquoted heredoc (a one-shot inline command) | Backslash every backtick (`` \` ``) and every literal `$` (`\$`) in the body, then re-read the body once for a missed one: one unescaped span still executes |

3. **Judge the write by stderr and by the artifact, not by the exit status.** The
   heredoc's exit status is the consumer's (`cat`); a substituted command that
   failed changes nothing in `$?`. Read stderr for `command not found: <first word
   of a span>` and for tool errors from spans that resolved to real commands, then
   open the file and look for the spans.

4. **When a span did execute, audit its side effect before moving on.** The
   command ran with your cwd, environment and credentials. For each span that
   named a real tool, establish what it does when run bare (`git branch x` creates
   a branch; `rm …`, `git push`, `npm publish` are worse) and inspect the state it
   touched (`git branch --list`, `git status`, the target service) — the stderr
   line proves the span ran, not what it changed.

## Edge cases

| Case | Then |
|------|------|
| The heredoc builds the file of a command a gate inspects before execution (`gh pr create --body-file` with the file made in the same call) | Write the file in a prior command and pass its path; the gate reads command text before any expansion happens ([platforms-shells-command-text-inspected-before-execution]) |
| Placeholder substitution with `sed` | `sed`'s replacement string interprets `&`, `\N` and its own delimiter, so a value holding `&` or `/` corrupts the text; use the environment-variable `replace` form from the table, or `envsubst` |
| `envsubst` and a `\$` in the body | `envsubst` gives backslash no quoting meaning: `\$TASK` becomes `\<value>`. A literal `$TASK` that must survive stays out of the variable list |
| `<<-EOF` (tab-stripping form) | Leading tabs are removed from body lines; the quoting rule above is unchanged by the dash |
| A here-string (`<<< "$body"`) instead of a heredoc | The word is expanded like a double-quoted string, so a backtick span inside the double quotes executes; single-quote the here-string or read the text from a file |
| The consumer is a remote shell (`ssh host bash <<EOF`) | An unquoted delimiter expands spans locally before the text leaves the machine; a quoted delimiter ships the text verbatim and the remote shell runs it — pick by where each `$` and backtick must resolve |
| The text is a single-line argument, not a heredoc (`git commit -m "…"`) | The double-quote rule of [platforms-shells-escapes-in-shell-string-literals] applies: single-quote it, or `\`` the spans |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Drop the quotes on the delimiter because one variable has to expand | Quote the delimiter and substitute a placeholder afterwards (step 2) | Unquoting turns every backtick span in the prose into a command that runs in the current repo |
| Treat `rc=0` from the write as proof the body landed intact | Read stderr for `command not found` and open the written file | The exit status belongs to `cat`; substituted commands fail and mutate state without changing it |
| Fix the file and continue after a `fatal:`/`command not found` line | Audit what the span's command changed first (step 4) | The span already ran with your cwd and credentials; the file is the smaller damage |

## Sources

- https://www.gnu.org/software/bash/manual/html_node/Redirections.html — 3.6.6 Here Documents: "If any part of word is quoted … the lines in the here-document are not expanded. If word is unquoted … all lines of the here-document are subjected to parameter expansion, command substitution, and arithmetic expansion … and '\' must be used to quote the characters '\', '$', and '`'"
- https://zsh.sourceforge.io/Doc/Release/Redirection.html — `<<[-] word`: "If any character of word is quoted with single or double quotes or a '\', no interpretation is placed upon the characters of the document. Otherwise, parameter and command substitution occurs … and '\' must be used to quote the characters '\', '$', '`'"
- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html — 2.7.4 Here-Document: "If no part of word is quoted, all lines of the here-document shall be expanded for parameter expansion, command substitution, and arithmetic expansion. In this case, the <backslash> in the input behaves as the <backslash> inside double-quotes" — the same rule in POSIX, so the behaviour holds under `sh` and dash
- Reproduced 2026-09-28 (bash 5.3.15, zsh 5.9, macOS) in a scratch git repo: `cat <<EOF` with the prose `` `git branch crew/qa` then `frobnicate --all` `` exited 0, printed only `frobnicate: command not found` on stderr, wrote `Next run  then .`, and `git branch --list` showed the new `crew/qa` branch; the same body under `<<'EOF'` + python placeholder replace, under `<<EOF` with `` \` ``, and under `<<'EOF' | envsubst '$TASK'` each wrote the prose intact with the variable expanded and created no branch. Field case the same day: an agent's unquoted notes heredoc printed `fatal: a branch named 'crew/qa' already exists` — the prose `git branch crew/qa` had run against the worktree's repo
