---
id: infrastructure-agent-orchestration-login-expiry-during-unattended-turns
domain: infrastructure
category: agent-orchestration
applies_to: [claude-code, tmux, general]
confidence: verified
sources:
  - https://code.claude.com/docs/en/authentication
  - https://code.claude.com/docs/en/errors
last_verified: 2026-09-03
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
