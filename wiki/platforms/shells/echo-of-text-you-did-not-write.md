---
id: platforms-shells-echo-of-text-you-did-not-write
domain: platforms
category: shells
applies_to: [zsh, posix-sh, dash, bash, macos]
confidence: verified
sources:
  - https://zsh.sourceforge.io/Doc/Release/Shell-Builtin-Commands.html
  - https://zsh.sourceforge.io/Doc/Release/Options.html
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/echo.html
last_verified: 2026-10-11
related: [platforms-shells-portable-shell-scripts, platforms-shells-escapes-in-shell-string-literals, platforms-shells-option-like-argument-values, platforms-tools-bsd-vs-gnu-cli, platforms-shells-line-by-line-read-loops]
---

# Printing Text You Did Not Write Through `echo`

## When this applies

A script stores text it did not author — a fetched HTML page, a file's
contents, a tool's output, user or model input — in a variable and then
hands it to the next command with `echo "$VAR" | grep …`, `echo "$VAR" |
sed …`, or `echo "$VAR" > file`. Symptom: the consumer reports no match,
`grep -c` prints `0` or nothing, or the written file is shorter than the
variable, while a direct pipeline from the producer (`curl … | grep …`)
matches on the first try.

## Do this

1. **Treat `echo` as a formatter for literals you typed, not as a pass-through
   for data.** In zsh, in POSIX/XSI `sh` (macOS `/bin/sh`, dash) and in any
   shell with `xpg_echo` on, the builtin `echo` interprets backslash escapes
   inside its operands. `\c` means "suppress subsequent characters and final
   newline", so one `\c` anywhere in the text ends the output there; `\n`,
   `\t`, `\0nn` and the rest rewrite bytes in place. Nothing fails — the
   consumer just sees less than the variable holds.

2. **Choose the carrier by what the text is:**

| Text | Write |
|------|-------|
| A literal you wrote, no backslashes | `echo 'done'` is fine |
| Data from anywhere else, held in a variable | `printf '%s\n' "$VAR"` — `%s` performs no escape processing on the argument |
| Data that is about to be piped from the producer anyway | Pipe producer into consumer directly (`curl -s "$u" \| sed … \| grep …`); no variable, no `echo` |
| Data that must reach a program as an argument, not stdin | Pass `"$VAR"` as the argument and add `--` before it when it may start with `-` ([platforms-shells-option-like-argument-values]) |
| A multi-line body that must land in a file | `printf '%s\n' "$VAR" > file`, or a quoted heredoc (`<<'EOF'`) for text you typed |

3. **When a grep over stored text returns nothing, check the carrier before
   the pattern.** Print the length the consumer receives against the length
   of the variable: `printf '%s' "$VAR" | wc -c` versus `echo "$VAR" | wc -c`.
   A shorter `echo` side is this page; an equal count means the pattern is at
   fault ([platforms-shells-escapes-in-shell-string-literals]).

## Edge cases

| Case | Then |
|------|------|
| The script runs under bash | bash's builtin `echo` leaves backslashes alone unless `xpg_echo` is set or `-e` is given, so the same line works there and breaks when pasted into a zsh terminal or run by `sh`. Use `printf` so the line means one thing in every shell |
| You need zsh's `echo` to behave like bash's for one script | `setopt BSD_ECHO` ("disables backslashed escape sequences in echo strings unless the -e option is specified") or `echo -E`; both are zsh-only, so `printf` remains the portable form |
| The text starts with `-n`, `-e` or `-E` | Even with escapes off, `echo` may consume the leading word as an option; `printf '%s\n'` prints it |
| `echo` is also used to write a sentinel or count into a status file | `printf '%s\n' "$value" > file`; a count or path never contains a backslash today, but the line is copied into a data path tomorrow |
| The consumer is `read` in a loop | The `\c`/`\n` damage happens before `read` sees anything; combine `printf '%s\n'` with the `IFS= read -r` form ([platforms-shells-line-by-line-read-loops]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `echo "$RAW" \| grep -c pattern` on fetched or read text | `printf '%s\n' "$RAW" \| grep -c pattern`, or `curl … \| grep -c pattern` | zsh and XSI `sh` process escapes in `echo` operands; a `\c` in the data truncates the stream and the zero count reads as "no match" |
| `echo -E "$RAW"` or `echo -e "$RAW"` to control escapes | `printf '%s\n' "$RAW"` | Flag handling differs per shell and userland; POSIX says new applications "are encouraged to use printf instead of echo" |
| Conclude "the page has changed" or "the pattern is wrong" from an empty grep over stored text | Compare the byte count `echo` delivers with the variable's byte count | A truncated carrier produces the same empty result as an absent match |

## Sources

- https://zsh.sourceforge.io/Doc/Release/Shell-Builtin-Commands.html — `echo [ -neE ] [ arg ... ]`: "echo recognizes the following escape sequences", including `\c` "suppress subsequent characters and final newline"; `-E` disables them
- https://zsh.sourceforge.io/Doc/Release/Options.html — `BSD_ECHO`: "Make the echo builtin compatible with the BSD echo(1) command. This disables backslashed escape sequences in echo strings unless the -e option is specified"
- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/echo.html — XSI `echo` recognizes `\c` ("Suppress the <newline> that otherwise follows the final argument in the output. All characters following the '\c' in the arguments shall be ignored"); Application Usage: "New applications are encouraged to use printf instead of echo"
- Reproduction 2026-10-11 (macOS 26.1, zsh 5.9): a 27-byte variable built with `printf '%s' 'before-marker\cafter-marker'`; `echo "$v" | grep -c after-marker` printed `0` (rc 1) under zsh, macOS `/bin/sh` and dash, and `1` under bash; `printf '%s\n' "$v" | grep -c after-marker`, `echo -E`, and `setopt BSD_ECHO` each printed `1`. Field case the same day: every `echo "$RAW" | grep` over a stored 125 KB `libpq-connect.html` (HTTP 200) printed nothing, while the identical `curl … | sed | grep` pipeline matched on the first try
