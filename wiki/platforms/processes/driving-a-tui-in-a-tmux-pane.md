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
  - https://code.claude.com/docs/en/terminal-config
last_verified: 2026-10-02
related: [platforms-processes-non-interactive-cli-invocation, platforms-processes-background-services, platforms-shells-portable-shell-scripts, infrastructure-agent-orchestration-pane-delivery-confirmation, platforms-processes-sentinel-driven-repl-payloads]
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
| The payload is a multi-kilobyte instruction text (a task brief, a rework prompt), passed as a launch argument or through `send-keys` | Write the full text to a file and send one short line naming that file's absolute path ("Read `<absolute path>` and carry it out"). After the send, require the **first words of the pointer line** (`Read` plus the start of the path) in the pane — that shows the head was not cut — and then confirm consumption by step 3's indicator or effect checks. A large payload goes through the target's paste handling, and the observed failure is a prompt that arrives without its head: the tail alone is well-formed text, so the target submits it and then waits or guesses, while the send wrapper reports success. A one-line pointer stays under the paste threshold, and the file is also what the target re-reads in later turns. For a payload over the paste threshold this row takes precedence over the `load-buffer` row above |
| The same loop sends keys and then reads the pane for a state witness ("still blocked", "still waiting") | Skip the capture on the iteration that sent keys and read on the next poll — the pane repaints only after the target consumes the input, so a same-iteration capture can confirm the state the send just changed. See [infrastructure-agent-orchestration-pane-delivery-confirmation] |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Diff `capture-pane` before/after and call a difference "delivered" | Check the program's busy indicator first, then an effect only it can produce | The tty echoes keystrokes while the process is busy, so the diff reports success for exactly the queued case the check was written to catch |
| Interpolate a variable straight into `send-keys -l "$text"` | Add the `--` separator before the payload | A payload starting with `-` is parsed as a tmux flag and the send fails with exit 1 |
| Send a several-kilobyte prompt inline and confirm it by its last line or by the wrapper's "submitted" word | Send a file pointer; require the first words of the pointer line in the pane, then confirm consumption by step 3's checks | A prompt that lost its head still ends correctly and still submits; only the beginning shows the loss |
| Treat `send-keys` exit 0 as proof the prompt was answered | Poll a status artifact the target writes | Exit 0 means the keys reached the pty, which is upstream of the program reading them |

## Sources

- https://man.openbsd.org/tmux.1 — `send-keys [-FHKlMRX] … [key ...]`; "The `-l` flag disables key name lookup and processes the keys as literal UTF-8 characters"
- https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap12.html — Utility Syntax Guideline 10: `--` delimits the end of options, after which arguments are operands
- https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap11.html — terminal `ECHO` in canonical mode echoes input characters back to the terminal, independently of whether the reading process has consumed them
- Field context (tmux 3.7b, macOS, 2026-08-05): `tmux send-keys -t S -l "-n hello"` → `command send-keys: unknown flag -n`, exit 1; the same call with `-- "-n hello"` → exit 0. Sending `echo SECOND_PROMPT` to a pane running `sleep 6` changed the pane content (a naive diff reads "delivered") while the command's own output count stayed 0, becoming 1 only after the sleep drained
- https://code.claude.com/docs/en/terminal-config — "Paste large content": input over 800 characters or more than three lines collapses to a `[Pasted text #N]` placeholder; "For very large inputs such as entire files or long logs, write the content to a file and ask Claude to read it instead of pasting"; one terminal "can also drop characters from very large pastes before they reach Claude Code, so use a file there"
- Field observation 2026-10-01 (an agent CLI worker in a tmux session, launched by an orchestrator script): a 3,411-byte single-line prompt returned exit 0 with "prompt submitted (confirmed)", while the pane showed the prompt beginning mid-word, well into its text; the worker stopped at an idle prompt and the run's watcher reported it blocked. Re-sending a one-line pointer to a file holding the same text was delivered and the worker started
