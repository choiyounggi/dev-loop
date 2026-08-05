---
id: platforms-shells-command-text-inspected-before-execution
domain: platforms
category: shells
applies_to: [bash, zsh, posix-sh]
confidence: verified
sources:
  - https://code.claude.com/docs/en/hooks
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
last_verified: 2026-08-05
related: [platforms-shells-portable-shell-scripts, platforms-environment-path-resolution, infrastructure-orchestration-control-signals-vs-primary-artifacts, platforms-tools-harness-mediated-tool-results]
---

# Commands Read as Text by a Gate Before the Shell Runs Them

## When this applies

A hook, policy gate, allow-list, or audit rule inspects your command line and
decides whether it may run (agent PreToolUse hook, commit gate, sudo command
pattern, CI policy check); the gate blocked or mis-parsed a command that is
correct as written; or you are composing a command that must satisfy such a gate
on the first attempt.

## Do this

1. **Write values the gate reads as literal text.** The gate is handed the command
   as an unexecuted string — a Claude Code `PreToolUse` hook receives
   `tool_input.command` (`{"tool_name":"Bash","tool_input":{"command":"npm test"}}`)
   and runs "Before a tool call executes". Nothing has expanded yet: `"$VAR"` is
   four literal characters plus a name, and the quote marks are part of the text.
   Shell expansion is defined to happen when the shell processes the line, which is
   after the gate has already decided.

2. **Know which of the two failure modes you are in — the error message tells you.**
   Both a quoted path and an unexpanded variable break a gate that extracts a file
   argument, but for different reasons and with different symptoms:

| What you wrote | What the gate extracts | How it fails |
|----------------|------------------------|--------------|
| `--body-file /abs/path/REPORT.md` | `/abs/path/REPORT.md` | Passes |
| `--body-file="/abs/path/REPORT.md"` or `--body-file "$REPO/REPORT.md"` | nothing — the extraction pattern excludes the quote character, so the match fails outright | Gate reports the argument as **missing** ("no `--body-file` found"), which reads as a malformed command |
| `--body-file $REPO/REPORT.md` (unquoted variable) | the literal string `$REPO/REPORT.md` | Gate reports the file as **nonexistent**, which reads as a missing deliverable |

3. **Create the file a gate will read in an earlier, separate command.** The gate
   runs before this command executes, so a file produced by a heredoc inside the
   same command does not exist yet at inspection time and the gate fails closed.
   Write the file in one call, reference it by literal path in the next.

4. **When content must contain patterns the gate treats as dangerous, put the
   content in a file with a non-shell tool and pass the path.** Release notes,
   docs, or fixtures containing `curl … | sh` or `rm -rf` are data, but a
   text-scanning gate cannot tell data from an invocation. A file written by an
   editor/Write tool is never scanned as a command; `--notes-file` / `--body-file`
   then carries it.

5. **Read the gate's own extraction pattern when a correct command is refused.**
   The pattern is the specification of what the gate can see. Reproduce it against
   your exact command string before rewriting anything else — one run tells you
   whether you are in the missing-argument or nonexistent-file mode above.

## Edge cases

| Case | Then |
|------|------|
| Blocking feedback appears without the gate's message | Exit code 2 sends the reason to **stderr**, not stdout; read stderr for the actual cause |
| The gate matches an intended-as-prose mention of a dangerous command (in a commit message, doc, or test fixture) | Move the text into a file and pass it by path (step 4) rather than reshaping the sentence |
| Path contains a space, so quoting is unavoidable | Relocate or symlink the target to a space-free path for gated commands; a gate that excludes quote characters cannot receive a quoted path at all |
| The gate needs `~` expanded | Write the absolute path; a gate that resolves `~` itself is doing so on the literal tilde, which only works if it implements the expansion |
| The same command must also be portable/robust as a script | Keep the gate-read argument literal and leave the rest of the script quoted normally ([platforms-shells-portable-shell-scripts]) — this page narrows one argument, it does not license unquoted expansions elsewhere |
| The blocked command was the one that emits your progress/status signal | A blocked command produces no side effect, so a consumer polling for that signal waits forever. `stat` the artifact the command was to write, and report the signal as un-emitted ([infrastructure-orchestration-control-signals-vs-primary-artifacts]) |
| A gate scoped to a path refuses the harness's own script | Path-scoped rules match the command text, not the command's purpose, so a tool's own helper is refused like any other write. Report the refused path and the rule id rather than rewriting the path to evade it |
| An editor/Write tool succeeds on the exact path Bash was refused for | The gate is registered for the Bash tool and does not see other tools' writes. Treat the disagreement as gate scope, not as permission to route around the rule |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Interpolate `"$VAR/file"` into an argument a gate inspects | Write the resolved absolute path literally | The gate sees pre-expansion text; the quote character can defeat its extractor entirely and the variable name never resolves for it |
| Assume a blocked command means the deliverable is wrong | Reproduce the gate's extraction pattern against your literal command string first | A quoting-level extraction failure and a genuinely incomplete deliverable produce the same refusal, so fixing content wastes the round |
| Build the file the gate checks with a heredoc in the same command | Write it in a prior command and reference the path | The gate is evaluated before execution, so the file is absent at decision time |
| Reword prose to get a dangerous-looking string past a scanner | Put the prose in a file and pass `--notes-file`/`--body-file` | Editing meaning to satisfy a text scanner degrades the artifact; a file is not scanned as a command |

## Sources

- https://code.claude.com/docs/en/hooks — `PreToolUse` runs "Before a tool call executes. Can block it"; the hook's stdin JSON carries `tool_input.command` — the unexecuted Bash command string. Exit 2 blocks and "stderr text is fed back to Claude as an error message"
- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html — the shell's order of word expansion (tilde, parameter, command substitution, field splitting, quote removal) is performed by the shell as it processes the command, so an external reader of the command text sees none of it applied

## Field context

Reproduced against the extraction pattern of this repo's own flush gate
(``--body-file[= ]+[^ '"`]+``, `hooks/pre-flush-pr-gate.sh`) on 2026-07-30: five
variants run through that pattern gave `--body-file "$REPO/…"` → empty (blocked as
missing), `--body-file $REPO/…` → literal `$REPO/…` (blocked as nonexistent),
`--body-file "/abs/…"` → empty even with a literal path, while
`--body-file /abs/…` and `--body-file=/abs/…` extracted correctly. A same-command
heredoc body-file was separately blocked as not-yet-existing until moved to a
preceding call.
