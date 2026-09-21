---
id: infrastructure-agent-orchestration-session-context-token-budget
domain: infrastructure
category: agent-orchestration
applies_to: [general]
confidence: verified
sources:
  - https://platform.claude.com/docs/en/build-with-claude/prompt-caching
  - https://code.claude.com/docs/en/costs
  - https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
  - https://code.claude.com/docs/en/best-practices
  - https://code.claude.com/docs/en/sub-agents
  - https://platform.claude.com/docs/en/build-with-claude/vision
  - https://www.anthropic.com/engineering/multi-agent-research-system
last_verified: 2026-08-21
related: [infrastructure-agent-orchestration-worktree-isolated-workers, infrastructure-agent-orchestration-usage-limit-paused-workers, backend-common-llm-context-window-budget, qa-process-fresh-context-code-review]
---

# Token Budget for Long-Lived Coordinator and Worker Agent Sessions

## When this applies

Planning or running a long-lived coordinator or worker agent session and deciding
when to compact or clear context; a run's cost is dominated by cache-read tokens
rather than any single call; a screenshot or a large file read is about to enter a
long-lived session's history; choosing slot counts or per-phase token budgets for
an orchestrated run.

## Do this

1. **Track accumulated context as the cost driver, not turn count.** Cache reads
   cost ~0.1x the base input token price; 5-minute cache writes cost ~1.25x, 1-hour
   writes cost 2x. Every call resends the full conversation history (billed at the
   cached rate for the cached portion), so cost per turn grows with how much
   context has accumulated — a session's total cost grows faster than linearly with
   turn count because each of its turns re-bills a history that keeps growing.

2. **Reset context at phase boundaries, not only when the window is full.** Run
   `/compact` between milestones inside one task (optionally with instructions on
   what to preserve — architectural decisions, unresolved bugs, implementation
   details survive; redundant tool output does not) and `/clear` when switching to
   an unrelated task. Waiting until the window is nearly full to compact means the
   session already paid a quality cost first: accuracy at recalling earlier context
   degrades as the window fills, an effect distinct from the token-cost mechanism
   in directive 1.

3. **Delegate visual verification to a throwaway subagent.** A subagent runs in its
   own isolated context window and returns only its summary to the caller, so
   verbose search results, logs, or file contents it produced never enter the
   long-lived session. This matters most for images: once a screenshot enters a
   session's history, its bytes are resent in full on every subsequent turn, so
   check it with a subagent that returns a text verdict instead of Reading it
   directly into a coordinator or worker's own context. When an image does need to
   stay in context across many turns, upload it through the Files API and
   reference it by `file_id` — the payload then stays flat regardless of how many
   images accumulate. Size the check itself against the current image-token
   formula, `⌈width / 28⌉ × ⌈height / 28⌉` visual tokens (28x28-pixel patches) — an
   older `(width × height) / 750` figure circulates in outdated summaries and no
   longer matches the documented pricing.

4. **Bound tool output before it reaches context.** Prefer a search mode that
   returns matching filenames over one that returns full matched content; read a
   large file by range (offset/limit) instead of in full when only part of it is
   needed; pipe verbose command output through a filter (e.g. `grep` + `head`) so a
   10,000-line log becomes the handful of matching lines instead of the whole file.

5. **Size an orchestrated run's slot count against its architecture, not habit.**
   Anthropic's own multi-agent research system measured multi-agent work (an
   orchestrator plus parallel subagents, each with an independent context window)
   at roughly 15x the tokens of a single chat interaction, with each individual
   agent in that fleet running roughly 4x a single chat interaction on its own;
   Claude Code's parallel-instance "agent teams" feature separately measured
   roughly 7x when teammates run in plan mode, since token usage there scales with
   team size and how long each teammate stays active. Both sources tie this
   multiplier to justification, not prohibition: reserve the parallel/orchestrated
   shape for tasks whose value justifies it or whose scope exceeds one context
   window, keep spawn prompts focused since everything in one adds to that
   teammate's context from the start, and end a worker's session once its phase
   completes rather than leaving it idle and still billing.

## Edge cases

| Case | Then |
|------|------|
| A subagent's result must reach the main session | Have it return only a text summary — the verbose intermediate output stays in the subagent's own context and is never itself pasted into the caller |
| Several images must stay referenceable across a long session | Upload each through the Files API and pass its `file_id` instead of inlining base64 bytes on every turn |
| The session is a single chat interaction rather than an orchestrated run | The 4x/15x/7x multipliers above do not apply; the accumulated-context mechanism in directive 1 still does |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Let a long session run until the context window is nearly full before compacting | Compact at each phase or milestone boundary | Recall accuracy degrades as the window fills, so waiting until it is full means the session already paid that cost before the reset |
| Read a large log or test-output file directly into the main session to find one error | Filter it first (grep/head) or delegate the search to a subagent | The main session then holds the few matching lines instead of the whole file |
| Treat an image already in conversation history as a one-time cost | Treat it as a recurring per-turn cost for the rest of that session | Base64 image bytes are part of the full conversation payload resent on every subsequent turn |
| Pick a fleet size for an orchestrated run by habit or convenience | Size it against the measured 4x (single agent) / 15x (multi-agent) / 7x (agent teams in plan mode) multipliers and the task's value | An orchestrated run's cost is structurally higher than a single session's, independent of how efficiently any one agent in it runs |

## Sources

- https://platform.claude.com/docs/en/build-with-claude/prompt-caching — cache read (~0.1x) and cache write (~1.25x for 5-minute, 2x for 1-hour) token price multipliers
- https://code.claude.com/docs/en/costs — full conversation history resent (at the cached rate) on every request; `/clear` between unrelated tasks and `/compact <instructions>` mid-task; delegating verbose operations (tests, doc fetches, log processing) to subagents or filtering hooks (e.g. `grep`+`head`) so only matching lines reach context; agent-team cost scaling with team size and teammate duration (~7x in plan mode)
- https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents — context rot (recall accuracy decreasing as the context window fills); compaction should preserve architectural decisions, unresolved bugs, and implementation details while discarding redundant tool output
- https://code.claude.com/docs/en/best-practices — `/clear` and `/compact` usage guidance; performance degrading as the context window fills
- https://code.claude.com/docs/en/sub-agents — subagents run in an isolated context window and return only a summary to the caller
- https://platform.claude.com/docs/en/build-with-claude/vision — current image-token formula `⌈width / 28⌉ × ⌈height / 28⌉` (28x28-pixel patches); base64 images resent in full on every turn; Files API `file_id` keeps payload size flat
- https://www.anthropic.com/engineering/multi-agent-research-system — multi-agent systems measured at ~15x the tokens of a single chat interaction (~4x per individual agent); reserved for high-value, parallelizable, or context-exceeding tasks
- Field evidence 2026-08-21 (dev-loop orchestration run): the coordinator session ended a run at approximately 501k tokens of accumulated context over 593 API calls, with approximately 164M cumulative cache-read tokens billed across the run; a post-run review found approximately 2.2MB of screenshot PNGs had been Read directly into the coordinator's own context over the run instead of delegated to a subagent per directive 3 — a measured instance of that directive's cost when skipped
