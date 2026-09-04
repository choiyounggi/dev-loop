---
id: infrastructure-agent-orchestration-client-bound-pty-coordinator-loss
domain: infrastructure
category: agent-orchestration
applies_to: [tmux, general]
confidence: field-tested
sources:
  - https://man7.org/linux/man-pages/man1/tmux.1.html
  - https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap11.html
  - https://www.onorca.dev/docs/ssh
last_verified: 2026-09-04
related: [infrastructure-agent-orchestration-pane-delivery-confirmation, infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, infrastructure-agent-orchestration-session-completion-gates, infrastructure-agent-orchestration-usage-limit-paused-workers]
---

# A Long-Running Coordinator Session Hosted Directly in a Client-Bound Remote Terminal

## When this applies

You are starting a long-running orchestration coordinator inside a remote
terminal card or PTY whose lifetime is owned by a client connection — an
SSH-relay terminal, a remote-terminal-relay app's card (for example an Orca
SSH target), an IDE's remote terminal — rather than inside a multiplexer
session with its own independent server process. Also when a coordinator
session has disappeared with no crash, OOM, or error in its transcript, and
the disappearance window lines up with a client reconnect or relay event.

## Do this

1. **Start the coordinator inside a `tmux` (or `screen`) session on the
   host**, and use the remote card or relay connection only to `attach` to
   that session — never as the coordinator's own controlling terminal.
2. **Before treating a vanished coordinator as a crash, walk its parent
   process chain** (`ps -o pid,ppid,command -p <pid>`, repeated upward). A
   coordinator whose chain ends in `claude ← zsh ← tmux server` survives a
   client disconnect; one ending in `claude ← zsh ← <relay/PTY-host process>`
   is reclaimed when that relay tears the PTY down.
3. **Read a documented reconnect grace period as a bound on survivable
   client disconnects, not as persistence.** Orca's SSH targets, for example,
   default to 5 minutes, configurable per target; a coordinator meant to run
   for hours goes under tmux regardless of the configured grace period.

## Edge cases

| Case | Then |
|------|------|
| The product's grace period is generous (several minutes) | It still expires on any disconnect longer than the window, or on a relay/daemon restart; tmux's server has no such window, so prefer it for any run that can outlive the grace period |
| Reattaching would race an orchestrator wait-loop that already marked the coordinator dead | Pause that wait-loop before reattaching, then resume it — otherwise the orchestrator's own liveness logic double-drives the same coordinator |
| tmux is not available on the remote host | Use the relay/terminal product's own persistent-session primitive if it has one, distinct from a live PTY lease, and verify its survival semantics with the same parent-chain check — "remote" does not imply "persistent" |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Run the coordinator directly in the remote/SSH terminal card | Start `tmux new -s coordinator` first, run the coordinator inside it, and use the card only to `tmux attach` | The card's PTY is leased to the client connection; tmux's server is a separate process a client disconnect never touches |
| Assume a vanished coordinator crashed and re-dispatch its work from scratch | Check the PTY's parent chain and the relay's own connection/reconnect log first | A relay-reclaimed PTY leaves no crash signal in the transcript — re-dispatching from scratch discards a coordinator that was mid-run, not failed |

## Sources

- https://man7.org/linux/man-pages/man1/tmux.1.html — "Each session is persistent and will survive accidental disconnection (such as ssh connection timeout) or intentional detaching"; "a session is displayed on screen by a client and all sessions are managed by a single server. The server and each client are separate processes"
- https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap11.html §11.1.10 — "If a modem disconnect is detected by the terminal interface for a controlling terminal ... the SIGHUP signal shall be sent to the controlling process for which the terminal is the controlling terminal" — the general mechanism behind a client-bound PTY's process dying on disconnect
- https://www.onorca.dev/docs/ssh — "A short grace period (5 minutes by default, configurable per target) gives the relay time to ride out a quick reconnect before tearing down detached sessions"; reconnected "leased PTYs are restored to their tabs in the attached state, with their scrollback intact" — a bounded grace window, not indefinite persistence
- Field evidence 2026-09-02 (measured in a linkly-crew orchestration run): a coordinator transcript ended after an `away_summary` with no crash; OOM, relay restart, and daemon kill were each ruled out; the death window coincided with relay socket churn, a relay-watcher restart, and a new remote shell being created. The grace-time value reported for that run (0s) could not be confirmed against the product's public default (5 min) and is a local configuration detail, not a documented default
