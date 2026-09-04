---
id: infrastructure-agent-orchestration-login-expiry-during-unattended-turns
domain: infrastructure
category: agent-orchestration
applies_to: [claude-code, tmux, general]
confidence: verified
sources:
  - https://code.claude.com/docs/en/authentication
  - https://code.claude.com/docs/en/errors
  - https://www.rfc-editor.org/rfc/rfc9700.txt
last_verified: 2026-09-04
related: [infrastructure-agent-orchestration-unattended-worker-questions, infrastructure-agent-orchestration-usage-limit-paused-workers, infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, infrastructure-agent-orchestration-shared-run-state]
---

# A Worker Pane Ends Its Turn With "Login Expired · Please Run /login"

## When this applies

An unattended tmux or orchestrated worker turn ends with no output and the pane's
last line is `Login expired · Please run /login`; deciding whether to send `/login`
to the pane, relaunch the worker, or finish the remaining step yourself. Also when
choosing the credential for workers that will run unattended for longer than a
login session lasts.

## Do this

1. Read the message as a terminal state for that pane, not a stall to re-prompt.
   `/login` opens a browser sign-in that no unattended pane can complete, and every
   model request fails until a human signs in again — sending the command re-prints
   the same prompt and spends a turn.
2. Classify the remaining work before choosing a response:

| Remaining work | Do |
|----------------|----|
| Mechanical bookkeeping on already-produced, already-reviewed changes (commit the reviewed diff, write the status file, run one agreed command) | The coordinator performs it directly in the worker's worktree — it needs no further model judgment, so it does not need the credential the pane lacks |
| Work that still needs generation or judgment (more code, another review pass) | This pane cannot finish it; hand the pane to a human to run `/login`, or relaunch a fresh worker under a valid credential with the same brief |

3. Distinguish the terminal message from the advance warning. `Login expired ·
   Please run /login` blocks requests; the earlier `Your login expires in N days`
   notice blocks nothing and is the cue to renew before starting a long run.
4. For runs expected to outlive a login session, start workers on a credential that
   renews without a browser — an API key via `ANTHROPIC_API_KEY` or an
   `apiKeyHelper` script — so the pane never reaches the sign-in prompt.

## Edge cases

| Case | Then |
|------|------|
| The remaining work spans several files or open decisions | That is not bookkeeping; escalate for a human `/login` or relaunch after re-authentication rather than finishing it by hand as coordinator |
| Several workers share one login and expire together | All are down until a human signs in somewhere — unlike a usage-limit pause there is no reset time that clears it unattended ([infrastructure-agent-orchestration-usage-limit-paused-workers]) |
| `claude auth status` reports `loggedIn: true` while the pane still shows `Login expired`, and other idle Claude Code sessions are running on the same machine (same `CLAUDE_CONFIG_DIR`) | Treat it as a possible false expiry before escalating: kill the idle sibling sessions, then relaunch this worker with the same credential. All Claude Code sessions sharing a `CLAUDE_CONFIG_DIR` read and write one `~/.claude/.credentials.json` file, so a losing session in a concurrent token refresh is a plausible cause — unconfirmed against Anthropic's implementation, but clearing idle siblings and relaunching is cheap to try first and required no human `/login` in the case observed |
| The worker's remaining step itself needs a browser flow (an app install, a re-auth) | Bookkeeping-by-coordinator does not apply; that step waits for the human |
| The coordinator commits on the worker's behalf | Record the substitution in the run ledger with the worker id and the reason, so the branch history explains a commit the brief did not assign to the coordinator |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Send `/login` (or any text) to the wedged pane and wait | Classify the remaining work first; do mechanical bookkeeping yourself in the worktree | `/login` opens a browser flow no headless pane can complete; the pane stays where it was |
| Relaunch a fresh worker session just to commit an already-reviewed diff | Have the coordinator commit it directly | The relaunch re-spends a session on a step that needs zero new decisions — the diff already exists and was reviewed |
| Treat the pane as stalled and re-deliver the prompt | Read the pane's last line first | A login-expiry pane looks idle; the re-delivered prompt fails the same way and the watcher loops |

## Sources

- https://code.claude.com/docs/en/authentication — "Once the stored login expires and can't be refreshed, each model request fails with Login expired · Please run /login until you sign in again"; "Renewing early matters most for sessions that run unattended … stops making progress once the credential expires and can't recover until you sign in again"; `apiKeyHelper` runs a shell script that returns an API key and supplies the credential without an OAuth login
- https://code.claude.com/docs/en/errors — "Login expired · Please run /login": run `/login` to re-authenticate; the client sends no request for a login it already failed to renew
- Field evidence 2026-08-18 (dev-loop orchestrate run i11475): both workers' commit turns died on login expiry after implementation and audit had finished; the coordinator committed `c2999de` and `36dc9b5` directly in each worktree instead of re-driving the panes, the suite finished 601/601, and PR #116 merged green
- https://code.claude.com/docs/en/authentication — "credentials are stored in `~/.claude/.credentials.json`" and a session with a different `CLAUDE_CONFIG_DIR` "reads a different entry" — multiple sessions on one machine share a single credential store, the structural precondition for the cross-session interference hypothesis above
- https://www.rfc-editor.org/rfc/rfc9700.txt §2.2.2 — "Refresh tokens for public clients MUST be sender-constrained or use refresh token rotation" — rotation-invalidates-the-loser is a standard OAuth pattern in general; this does not confirm Claude Code's claude.ai login uses it, so the "sessions race on a shared refresh token" causal claim above stays a hypothesis
- Field evidence 2026-08-19 (measured in a linkly-crew orchestration run, sessions lo-1–lo-7): killing five idle sibling Claude Code sessions immediately unblocked a `Login expired` worker under an identical launch command, with no recurrence afterward and no human `/login` performed
