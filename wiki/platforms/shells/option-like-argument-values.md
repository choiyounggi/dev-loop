---
id: platforms-shells-option-like-argument-values
domain: platforms
category: shells
applies_to: [bash, zsh, posix-sh]
confidence: verified
sources:
  - https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap12.html
  - https://man7.org/linux/man-pages/man1/tmux.1.html
last_verified: 2026-08-05
related: [platforms-shells-portable-shell-scripts, platforms-shells-command-text-inspected-before-execution, infrastructure-agent-orchestration-pane-delivery-confirmation]
---

# Passing Text You Did Not Author as a Command Operand

## When this applies

A script interpolates text it does not control — user input, a model's output, a
file's contents, a message body — into a command as an operand: `tmux send-keys
-l "$text"`, `grep "$pat" f`, `rm "$name"`, `git commit -m "$msg"`. Also when
such a call fails with "unknown flag" or "invalid option" on text that is
correct as data.

## Do this

1. **Put `--` between the last option and the first operand**, always, not only
   when the value looks suspicious:

   ```sh
   tmux send-keys -t "$session" -l -- "$text"
   grep -e "$pattern" -- "$file"
   ```

   POSIX Guideline 10 makes `--` the delimiter: arguments after it "should be
   treated as operands, even if they begin with the '-' character."

2. **Treat this as parsing, not quoting.** Quoting decides how the *shell*
   splits the word; `--` decides how the *called program* classifies it. A
   value that survives quoting intact still reaches the program as a single
   word starting with `-`, which its option parser claims.

3. **Check the call's exit status against a specific meaning**, not against
   "something happened". A rejected `send-keys` exits 1 with the payload never
   delivered; a caller that reads any nonzero status as "nothing to send"
   reports success for a lost message.

4. **For a program whose option parser does not honour `--`**, pass the value
   through a channel that is not the argument vector: stdin (`cmd <<EOF`), a
   temporary file inside the project, or an environment variable the program
   reads by name.

## Edge cases

| Case | Then |
|------|------|
| The operand is a path that may begin with `-` | `--` covers it; when the program also lacks `--`, prefix the path instead: `./-weird` or `"$PWD/-weird"` |
| The command takes options *after* operands (GNU permuting utilities) | `--` still ends option parsing for everything that follows, which is the behavior you want — pass every option before it |
| `--` itself must be delivered as literal data | It is: only the **first** `--` is consumed as the delimiter, later ones are operands |
| The value is empty | `--` keeps the empty string a positional operand instead of the parser seeing a missing argument; verify the program accepts an empty operand at all |
| The text is assembled into one string and re-parsed (`eval`, `sh -c "$cmd"`) | Build an array and expand it quoted instead ([platforms-shells-portable-shell-scripts]) — `--` cannot protect a value that is re-parsed as source text |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Rely on quoting alone: `tmux send-keys -l "$text"` | `tmux send-keys -l -- "$text"` | Quoting stops shell word-splitting; the program's own option parser still reads a leading `-` as a flag |
| Sanitize the value by stripping or escaping leading dashes | Pass it after `--` unchanged | Stripping silently corrupts the payload; `--` delivers the exact bytes |
| Add `--` only for values that "look like flags" | Add it at every interpolation of untrusted text | The failing input is the one you did not anticipate, and the cost of `--` is two characters |

## Sources

- https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap12.html — Utility Argument Syntax, Guideline 10: "The first `--` argument that is not an option-argument should be accepted as a delimiter indicating the end of options. Any following arguments should be treated as operands, even if they begin with the '-' character"
- https://man7.org/linux/man-pages/man1/tmux.1.html — tmux command syntax; each tmux command parses its own flags from the argument vector, so a payload word is classified by tmux, not by the shell
- Field reproduction 2026-08-05 (tmux 3.7b, macOS): `tmux send-keys -t S -l "-n hello"` → `command send-keys: unknown flag -n`, exit 1; `tmux send-keys -t S -l -- "-n hello"` → exit 0
