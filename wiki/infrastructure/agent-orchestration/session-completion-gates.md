---
id: infrastructure-agent-orchestration-session-completion-gates
domain: infrastructure
category: agent-orchestration
applies_to: [claude-code, general]
confidence: verified
sources:
  - https://code.claude.com/docs/en/hooks
  - https://csf.tools/reference/nist-sp-800-53/r5/ac/ac-5/
  - https://github.com/Leonxlnx/unlazy/blob/main/scripts/stop-hook.mjs
  - https://man7.org/linux/man-pages/man1/tmux.1.html
  - https://man7.org/linux/man-pages/man7/environ.7.html
  - https://code.claude.com/docs/en/cli-reference
last_verified: 2026-10-06
related: [infrastructure-agent-orchestration-pane-delivery-confirmation, infrastructure-agent-orchestration-worktree-isolated-workers, platforms-processes-tool-diagnostics-without-a-failing-exit-code, infrastructure-agent-orchestration-dispatching-after-a-completion-report, infrastructure-agent-orchestration-escape-hatch-uses-as-a-knowledge-gap-signal, infrastructure-agent-orchestration-client-bound-pty-coordinator-loss, infrastructure-agent-orchestration-gate-evidence-exit-code-class, infrastructure-ci-cd-write-time-limit-guards]
---

# A Gate That Blocks a Worker Session from Ending Mid-Workflow

## When this applies

You are writing a completion gate (a `Stop`/`SubagentStop` hook) that keeps an
orchestrated worker from ending while its recorded phase is unfinished; or such a
gate fires on a worker that followed its prompt (including you, parked at an
instructed pause), names the worker by `cwd` + tmux session, or blocks you for a task you were never given.

## Do this

1. **Enumerate every phase at which the protocol itself tells a worker to
   stop**, and put all of them in the gate's terminal set — not only the phases
   that mean "finished". Read the session prompt and the phase vocabulary side
   by side and classify each phase:

| Phase kind | Example | Gate treats it as |
|------------|---------|-------------------|
| Completed | `done`, `merged`, `failed` | terminal — allow stop |
| Instructed pause awaiting an external actor | `plan_ready` awaiting approval, `impl_done` awaiting review | terminal — allow stop |
| Unknown or unset | `""`, a phase name the gate does not recognize | terminal — allow stop, and log the unrecognized value |
| Work in progress the worker abandoned | `implementing`, `planning` | blocking — emit the instruction and block |

2. **Derive the set from the prompt that the workers actually receive**, and
   re-derive it whenever that prompt or the phase vocabulary changes. The two
   are one contract; a phase added to the status script without a matching gate
   entry becomes a stall.
3. **Make the gate self-limiting via the harness's re-entry flag.** In Claude
   Code, exit 0 immediately when `stop_hook_active` is true, before any other
   logic — the flag marks a session already continuing because of this hook, and
   without the early return the gate can block indefinitely. Claude Code
   overrides a Stop hook after it blocks eight consecutive times.
4. **No-op outside the managed workspace.** Locate the orchestration state by
   walking up from the session's `cwd`; when it is absent, exit 0. A gate that
   assumes it is managed fires in every unrelated session on the machine.
5. **Say what to do, not that something is wrong.** The block message names the
   phase, the next action, and the exact command that records completion — a
   blocked session's only input is that text.
6. **On the receiving side, hold the phase and report the mismatch.** When the
   gate fires on you at a pause your own prompt instructed, keep the recorded
   phase and tell the coordinator the gate's terminal set disagrees with the
   prompt. Write only phases your role is authorized to write:

| Phase | Written by | Because |
|-------|-----------|---------|
| `plan_ready`, `impl_done` | the worker | they record *its* progress and claim nothing about review |
| `approved`, `merged` | the coordinator only | they are the review verdict — the worker is the reviewed party |
| `done` | the worker, but only after the coordinator's approval message | it means "committed", which the approval authorizes |

   Silencing the gate by advancing the phase is the reviewed party issuing its
   own approval; a downstream scheduler that treats those phases as dependency-
   satisfying then dispatches work against an interface nobody reviewed.

7. **Pair the self-reported phase with a second gate that parses a
   machine-verifiable evidence ledger** — a value the worker wrote about itself
   is never the gate's only input. A phase field is free for the worker to set:
   it is the actor being graded writing its own grade. Have the worker's checker
   script run the actual verification commands and write their exit code and
   output into a ledger file; have the Stop hook parse that ledger (never re-run
   the commands itself — keep the parse/execute split, as `hooks/loop-gate.sh`
   does via `gate-check.sh --status`) and block while any entry is unmet or
   claimed without evidence:

| Signal | Who can make it say "done" | Gate treats it as |
|--------|----------------------------|-------------------|
| Self-reported phase (`status.json` `.phase`) | The worker, by calling its own status-update script | Workflow position (items 1–6), not proof of correctness |
| Ledger evidence (`CHECK:`/`EXPECT:` result: exit code + matched output) | Only a run of the actual command — the worker cannot hand-write a passing entry | The completion gate the phase check cannot fake |

8. **Give the ledger gate its own no-progress release valve, separate from the
   harness's re-entry flag.** `stop_hook_active` (item 3) only prevents this
   *same* stop event from re-blocking; it does nothing about a session that gets
   blocked, tries again next turn, and stays blocked because the ledger never
   changes. Hash the ledger's content each time the gate runs; block while the
   hash changes between blocks (progress), and release after N consecutive
   blocks with an unchanged hash (genuinely stuck) — track the count per session
   so one stalled session cannot exhaust another's budget.

## Edge cases

| Case | Then |
|------|------|
| A worker legitimately stops at an approval point but its status was never updated | The gate is right to block; make the status update the last step of the instructed pause so "stopped where told" and "recorded as paused" cannot diverge |
| The gate's state file is unreadable or its parser is missing | Exit 0 and log — a gate that blocks on its own malfunction traps every session |
| Several workers share one status directory | Match the entry by the session's resolved physical `cwd`; on macOS resolve `/var`→`/private/var` and symlinks on both sides before comparing |
| The gate decides "this session is the managed worker" from `cwd` plus the tmux session name (`tmux display-message -p '#S'`) | The name identifies a pane, not a process. Every process started from the pane inherits its `TMUX`/`TMUX_PANE` environment, so a headless agent that a hook launches in the worker's folder reports the worker's name. With `TMUX` unset, the command does not fail; it falls back to the most recently used session. Bind identity to a value only the worker has: launch it with a fixed session id (`claude --session-id <uuid>`), record that id in the status entry, and compare it with the hook input's `session_id` |
| The identity check compares `session_id` alone | A subagent's hook input carries its parent's `session_id`; `agent_id` is "Present only when the hook fires inside a subagent call". Handle a `SubagentStop` (or any input with `agent_id`) as the subagent, not the worker. When the worker is relaunched, resume it with `--resume <uuid>` so the id stays the same, or record the new id: `--fork-session` mints a new one |
| You are blocked with "finish your loop" for a task your own prompt never mentioned | Check that you are that worker before acting: compare the task the block names with the task in your own instructions. For a headless `claude -p`, `ps -o command= -p $PPID` run from your tool shell prints your own agent process and its prompt argument; an interactive worker received its prompt by paste, so argv holds none. If the tasks differ, report the misidentification and end the turn, leaving that task's status and files untouched |
| A phase means "waiting on another worker" | Terminal — the worker cannot progress it; the orchestrator's wait loop owns that transition |
| The worker cannot reach a terminal phase because the task is genuinely blocked | Provide a `failed` transition it may record itself; without one, the only escapes are fabricated completion or an eight-block override |
| You are the worker and the nudge repeats every turn at an instructed pause | Read it as a gate-vs-prompt mismatch, not as work you skipped; inventing extra work to satisfy it writes code the brief did not ask for |
| The gate's terminal set and the phase vocabulary live in different files | Cite both line numbers in the report — the fix belongs in the gate, and the coordinator is the one who can change it |
| The ledger gate (items 7–8) and the phase gate (items 1–6) are both present | Run both; a worker can be at a legitimate terminal phase (`impl_done`, awaiting review) while its ledger is still unmet — the ledger gate blocks independently of phase, because "instructed to pause" and "proved the work" are different claims |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| List only "success" phases as terminal | Add every phase at which the protocol instructs a stop, including mid-workflow handoffs | The gate otherwise fights the prompts the system issues, pushing the worker to fabricate completion or to do work it was told to hold |
| Treat an unrecognized phase value as unfinished | Treat it as terminal and log the value | A typo or a newly added phase would otherwise trap sessions until someone reads the hook |
| Rely on the block message alone to stop a loop | Return early on the harness's re-entry flag first | The message does not bound repetition; the flag is what makes the gate fire once |
| Advance your phase to a terminal value to stop a gate firing on you | Hold the instructed phase and report the gate-vs-prompt mismatch to the coordinator | The terminal values that would silence it are the review verdict; writing one makes the reviewed party its own approver, and the scheduler reads it as reviewed |
| Treat a matching tmux session name as proof the stopping session is the worker | Compare a per-process id recorded at launch with the hook input's `session_id` | Any process started from the worker's pane inherits the pane's tmux environment, and outside a pane the name lookup falls back to the most recently used session |
| Trust a self-reported phase/status field as proof the work is done | Add a gate that parses a ledger of actual command exit codes and output, written only by running the check | The worker can set a phase field to any value for free; it cannot fabricate a ledger entry without the command actually passing |

## Sources

- https://code.claude.com/docs/en/hooks — `Stop`/`SubagentStop` input includes `stop_hook_active`; hooks check it and exit early to allow the stop. Claude Code overrides a Stop hook after it blocks eight times in a row without progress (cap adjustable via `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`)
- https://csf.tools/reference/nist-sp-800-53/r5/ac/ac-5/ — NIST SP 800-53 r5 AC-5: "Separation of duties addresses the potential for abuse of authorized privileges and helps to reduce the risk of malevolent activity without collusion. Separation of duties includes dividing mission or business functions and support functions among different individuals or roles" — the phase that records a review verdict belongs to the reviewing role, not the reviewed one
- https://github.com/Leonxlnx/unlazy/blob/main/scripts/stop-hook.mjs — `MAX_BLOCKS = 6`; a per-session, ledger-content-hash-keyed no-progress counter releases the Stop-hook block after 6 consecutive blocks with no ledger change (read 2026-09-08); the project's CHANGELOG records a 1.0.0 "instruction-only" method replaced in 2.0.0 by "gate files, runnable checks, evidence, and an optional Claude Code Stop hook"
- Field reproduction 2026-09-08, dev-loop repo `hooks/loop-gate.sh` (Gate 2, lines 112–174): parses `.dev-loop/gates/*.md` via `gate-check.sh --status` (never executes CHECK commands from the Stop hook), blocks on UNMET/CLAIMED/malformed, releases after `MAX_GATE_BLOCKS=6` consecutive blocks with an unchanged ledger hash — in addition to Gate 1's self-reported-phase check; `tests/loop-gate.bats` "releases after 6 blocks without ledger progress" and "ledger progress resets the no-progress counter" pin the valve
- Field reproduction 2026-08-13, dev-loop repo at `fa89dc2`: a worker parked at `impl_done` per `skills/orchestrate/templates/session-prompt.md:75` ("run `… status-update.sh {TASK} impl_done …` and wait") received "verification loop incomplete" on every turn, because `hooks/loop-gate.sh:55` accepts only `done|approved|merged|failed|""` while `skills/orchestrate/scripts/status-update.sh:6` lists `impl_done` as a first-class phase. The three values that would have silenced it are exactly the three `skills/orchestrate/scripts/ready-set.sh:74` counts as dependency-satisfying (`approved|merged|done`), and that file states the rule the fabrication would break: "A dependency counts as satisfied only at `approved` or higher, NOT at impl_done: a task that consumes an unreviewed interface has to be redone when rework changes that signature"
- Field reproduction 2026-08-05, dev-loop repo at `95cf947`: `hooks/loop-gate.sh:55` lists `done|approved|merged|failed|""` as terminal, while `skills/orchestrate/templates/session-prompt.md:20` instructs a plan-phase worker to record `plan_ready` and "wait for an approval message. Do NOT write implementation code yet." A worker that followed its prompt exactly was blocked; the `stop_hook_active` early return at line 30 is what kept the block from repeating
- https://man7.org/linux/man-pages/man1/tmux.1.html — "If a session is omitted, the current session is used if available; if no current session is available, the most recently used is chosen"; the pane ID "is passed to the child process of the pane in the TMUX_PANE environment variable"
- https://man7.org/linux/man-pages/man7/environ.7.html — "When a child process is created via fork(2), it inherits a copy of its parent's environment"
- https://code.claude.com/docs/en/hooks (first source, read 2026-10-06) — common input fields: `session_id` "Current session identifier"; `agent_id` "Unique identifier for the subagent. Present only when the hook fires inside a subagent call. Use this to distinguish subagent hook calls from main-thread calls"
- https://code.claude.com/docs/en/cli-reference — `--session-id`: "Use a specific session ID for the conversation (must be a valid UUID)"; `--fork-session`: "When resuming, create a new session ID instead of reusing the original"
- Field reproduction 2026-10-06 (dev-loop `hooks/loop-gate.sh`, tmux 3.7b): the gate blocked a headless knowledge-flush `claude -p` with "phase=implementing" for an orchestrated task, because `tmux display-message -p '#S'` inside it returned the worker's session name and the status entry's `.session` matched. On an isolated `tmux -L` server, a grandchild shell started from pane `worker-a` printed `worker-a`; the same query with `TMUX` unset printed `worker-b`, not an error (`worker-b` was created last and no client was attached, so this run cannot separate "created last" from "used last"; the fallback rule itself is the man page's). In the same flush session, launched by `hooks/auto-flush.sh`, `ps -o command= -p $PPID` from the tool shell printed `claude -p Run the dev-loop:knowledge-flush skill now…`, its own agent process
