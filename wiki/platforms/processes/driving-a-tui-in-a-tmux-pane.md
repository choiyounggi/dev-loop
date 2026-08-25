---
id: platforms-processes-driving-a-tui-in-a-tmux-pane
domain: platforms
category: processes
applies_to: [macos, linux, tmux]
confidence: verified
sources:
  - https://man.openbsd.org/tmux.1
  - https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap12.html
  - https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap11.html
last_verified: 2026-08-25
related: [platforms-processes-non-interactive-cli-invocation, platforms-processes-background-services, platforms-shells-portable-shell-scripts, infrastructure-agent-orchestration-pane-delivery-confirmation]
---

# Sending Input to a TUI Running in a tmux Pane

## When this applies

A script, orchestrator, or agent sends text or keystrokes into a long-lived
interactive program running in a tmux pane (`tmux send-keys`) and must know
whether the program actually consumed them. Also when the payload is arbitrary
text from a variable rather than a fixed literal.

## Do this

1. **Pass the payload after a `--` separator**: `tmux send-keys -t "$pane" -l -- "$text"`.
   tmux parses its own arguments getopt-style, so a payload beginning with `-` is
   read as a flag and the whole command is rejected — quoting does not help,
   because the problem is tmux's argument parsing, not shell word splitting.
   POSIX reserves `--` as "the first argument that … delimit[s] the end of the
   options"; `send-keys` honours it even though its man page does not list it.

2. **Send the payload and the newline as separate calls**: `-l` "disables key name
   lookup and processes the keys as literal UTF-8 characters", so a trailing
   newline in the payload is not a key press. Follow with
   `tmux send-keys -t "$pane" Enter`.

3. **Confirm delivery by the target's own state, never by pane content changing.**
   Run the checks in this order and stop at the first that matches:

| Check | What it proves |
|-------|----------------|
| The program's own busy/queued **indicator**, in the last N non-empty lines of `capture-pane` — this fixed window is scoped to an indicator the TUI paints at a fixed position near the bottom, not to a marker whose position moves with the payload (see edge cases) | The program has the text but has not consumed it — treat as **not yet delivered** and wait |
| An effect only the program can produce (its output line, a status file it writes, a marker it prints) | Consumed |
| `capture-pane` output differs from before the send | **Nothing.** The tty line discipline echoes typed characters back to the pane while the foreground process is busy, so the pane changes for input that was never read |

4. **Make anything the caller must act on out-of-band.** Have the target write a
   status file and poll that file, rather than parsing the pane. Pane text is a
   rendering — it repaints, scrolls, and wraps.

5. **Treat `send-keys` exit 0 as "tmux accepted the keys"**, not as "the program
   read them". The two are separated by the pty buffer.

## Edge cases

| Case | Then |
|------|------|
| The pane repainted between send and capture | The echoed characters are gone, so absence of the echo is not evidence of consumption either — fall back to the program's own effect (step 3, row 2) |
| The payload contains a literal newline and must arrive as one paste | Use `tmux load-buffer -` + `paste-buffer -t "$pane"`; `send-keys -l` delivers the newline as a character, which many TUIs treat as submit |
| Delivery must be confirmed but the program has no busy indicator and no artifact | Add one: have the wrapper echo a unique marker after processing, and search for that marker rather than for the prompt text |
| The pane's process has exited (shell prompt only) | The keys land on the shell and run as commands — check `#{pane_dead}` / the pane's current command before sending |
| A collapsed paste placeholder (`[Pasted text #N]`) has the paste's own remainder rendered below it | Not findable in a fixed last-N window — the marker's distance from the bottom grows with the payload; anchor on the **input box** (the region between the last two horizontal rules of the full capture) instead. See [infrastructure-agent-orchestration-pane-delivery-confirmation] for the full detection rule |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Diff `capture-pane` before/after and call a difference "delivered" | Check the program's busy indicator first, then an effect only it can produce | The tty echoes keystrokes while the process is busy, so the diff reports success for exactly the queued case the check was written to catch |
| Interpolate a variable straight into `send-keys -l "$text"` | Add the `--` separator before the payload | A payload starting with `-` is parsed as a tmux flag and the send fails with exit 1 |
| Treat `send-keys` exit 0 as proof the prompt was answered | Poll a status artifact the target writes | Exit 0 means the keys reached the pty, which is upstream of the program reading them |

## Sources

- https://man.openbsd.org/tmux.1 — `send-keys [-FHKlMRX] … [key ...]`; "The `-l` flag disables key name lookup and processes the keys as literal UTF-8 characters"
- https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap12.html — Utility Syntax Guideline 10: `--` delimits the end of options, after which arguments are operands
- https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap11.html — terminal `ECHO` in canonical mode echoes input characters back to the terminal, independently of whether the reading process has consumed them
- Field context (tmux 3.7b, macOS, 2026-08-05): `tmux send-keys -t S -l "-n hello"` → `command send-keys: unknown flag -n`, exit 1; the same call with `-- "-n hello"` → exit 0. Sending `echo SECOND_PROMPT` to a pane running `sleep 6` changed the pane content (a naive diff reads "delivered") while the command's own output count stayed 0, becoming 1 only after the sleep drained
