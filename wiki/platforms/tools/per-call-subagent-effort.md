---
id: platforms-tools-per-call-subagent-effort
domain: platforms
category: tools
applies_to: [claude-code]
confidence: verified
sources:
  - https://code.claude.com/docs/en/sub-agents#supported-frontmatter-fields
  - https://code.claude.com/docs/en/sub-agents#choose-a-model
  - https://code.claude.com/docs/en/model-config#adjust-effort-level
  - https://code.claude.com/docs/en/env-vars
  - https://code.claude.com/docs/en/settings-reference#fallbackmodel
  - "Field case 2026-10-08 (dev-loop PR #262: effort floor for analysis, design and QA agents)"
last_verified: 2026-10-09
verified_model: claude-opus-5-5
related:
  [
    infrastructure-agent-orchestration-usage-limit-paused-workers,
    qa-document-verification-generated-reference-drift-gates,
    qa-document-verification-rationale-prose-after-a-config-value-change,
  ]
---

# Varying a Claude Code Subagent's Effort Level per Call

## When this applies

A Claude Code session, skill, or orchestrator spawns the same subagent role at
different effort levels depending on the call — by risk tier, task size, or
review depth — and you are deciding how to pass the level. Also when a subagent
appears to ignore the `effort` its definition sets, and when a role must never
run below a minimum model or effort (a floor) on any tier or call path.

## Do this

1. **Select effort by agent name, not by a call parameter.** The Agent tool
   takes a per-invocation `model` but no `effort`; effort comes only from the
   `effort` frontmatter field of the agent file (or of the skill it forked
   from). One agent file per effort level is therefore the only per-call switch:

| Need | Do |
|------|----|
| Only the model varies per call | Keep one agent file; pass `model` on the call — it ranks first in the model order |
| Effort varies per call | Keep a base file plus one variant per level (`reviewer.md`, `reviewer-low.md`) that differs only in `name` and `effort`; the caller picks the name |
| Model and effort vary together | Pin both in each variant's frontmatter, and pass no per-call `model`, so one name fixes the whole profile |

2. **Generate the variants from the base file, and fail CI on drift.** Write a
   script that copies the base body and rewrites only `name`/`effort` (and
   `model` when it is part of the profile), plus a `--check` mode that
   regenerates into memory and exits non-zero when a committed variant differs
   ([qa-document-verification-generated-reference-drift-gates]). Hand-maintained
   copies diverge at the first prompt edit, and the low-effort variant then runs
   older instructions.
3. **Name the variant in the caller's routing table**, beside the condition that
   selects it, so a reviewer can see which level each tier gets.
4. **Confirm the level a run used**: `/tasks` names the model on the
   subagent's row and adds the effort level when the definition sets `effort`
   (Claude Code v2.1.242+).
5. **When the levels are a floor** ("review agents never run below high"), a
   frontmatter pin is one of four places that set the level. Check the other
   three, and add a test that reads every agent file and fails below the floor:

| Bypass path | How it drops below the floor | Close it |
|-------------|------------------------------|----------|
| The variant generator's step-down rule ("one level lower") | Regenerating writes the lower level into every copy | Clamp the rule ("one level lower, never below high") in the generator, and run the floor test on the generated copies too |
| The parent session runs with `CLAUDE_CODE_EFFORT_LEVEL` (see Edge cases) | A subagent the worker calls in-session runs at the variable's level, whatever its frontmatter says | Launch that session without the variable and pass `--effort` at or above the floor, or set the variable itself at or above the floor |
| A retry list for overload or rate-limit errors | A rule like "on 429 retry with opus, then sonnet", or a `fallbackModel` setting, names a model below the floor | Keep only models at or above the floor in the list, and escalate to a person when they are all limited |

## Edge cases

| Case | Then |
|------|------|
| The parent session runs with `CLAUDE_CODE_EFFORT_LEVEL` set (a worker launched with it) | Frontmatter effort overrides the session level but not this variable, so every variant runs at the variable's level. Launch the parent without it — use `--effort` for the parent's own level, which frontmatter does override — or accept one level for all its subagents |
| A `maxEffortLevel` setting or organization effort cap is set | Variants above the cap run at the cap; read the cap before adding a higher variant |
| The variant names an effort the model does not offer | Claude Code falls back to the highest supported level at or below it (`xhigh` runs as `high` on Opus 4.6); pin a `model` that offers the level |
| `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` is on | Frontmatter `model` and the per-call `model` are both ignored; only `effort` still distinguishes the variants |
| A rationale paragraph in the base body explains the old level | The generator copies it into every variant; rewrite it when the levels change ([qa-document-verification-rationale-prose-after-a-config-value-change]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write "run at low effort" in the subagent's prompt | Call the variant whose frontmatter sets `effort: low` | The prompt text does not set the API effort parameter |
| Copy the agent file by hand for each level | Generate the variants and gate them with `--check` (step 2) | A hand copy keeps its old body after the base file changes |
| Pass the level through `CLAUDE_CODE_EFFORT_LEVEL` to a session whose subagents carry their own `effort` | Pass `--effort` to that session | The variable outranks every subagent's frontmatter |
| Enforce a floor by editing the agents' frontmatter table only | Also clamp the generator, the session's env var and the retry list (step 5) | The generator rewrites the frontmatter, and the env var and the retry list override it at run time |

## Sources

- https://code.claude.com/docs/en/sub-agents#supported-frontmatter-fields — `effort`: "Effort level when this subagent is active. Overrides the session effort level, but not the `CLAUDE_CODE_EFFORT_LEVEL` environment variable. Options: `low`, `medium`, `high`, `xhigh`, `max`; available levels depend on the model" (wording re-read from the raw page 2026-10-09)
- https://code.claude.com/docs/en/sub-agents#choose-a-model — "When Claude invokes a subagent, it can also pass a `model` parameter for that specific invocation"; the order is per-invocation `model`, then frontmatter, then `CLAUDE_CODE_SUBAGENT_MODEL`; `/tasks` shows the effort level when the definition sets `effort` (v2.1.242+); `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` ignores both model sources
- https://code.claude.com/docs/en/model-config#adjust-effort-level — "Frontmatter effort applies when that skill or subagent is active, overriding the session level but not the environment variable"; `maxEffortLevel` and organization caps still limit it; an unsupported level falls back to the highest supported one at or below it
- `--effort` row and edge case: model-config lists `--effort` under the explicit-choice step that sets the session's level, and states frontmatter overrides "the session level but not the environment variable" — that `--effort` is overridden while `CLAUDE_CODE_EFFORT_LEVEL` is not is read from that sentence, not separately measured
- https://code.claude.com/docs/en/env-vars — `CLAUDE_CODE_EFFORT_LEVEL`: "Takes precedence over `--effort`, `/effort`, and the `modelSettings` and `effortLevel` settings. A `maxEffortLevel` cap still applies" (step 5, row 2; raw page re-checked 2026-10-09)
- https://code.claude.com/docs/en/settings-reference#fallbackmodel — `fallbackModel`: "Name backup models for Claude Code to try, in order, when your primary model is overloaded or unavailable" (step 5, row 3)
- Field case 2026-10-08 (dev-loop PR #262, merged as `5c9bddb`): one change closed all three paths — the tier generator went from one level lower to "one effort step lower, never below high", worker effort went from medium to high because the worker's in-session self-audit inherits `CLAUDE_CODE_EFFORT_LEVEL`, and the 429 rule went from "opus, then sonnet" to "whichever of `opus` and `fable` the 429 does not name … never below Opus". Re-checked 2026-10-09 in a scratch clone: with the generator set back to `task-reviewer:medium`, `tests/agent-model-pin.bats` test 5 ("meets the opus-5.5-high floor") failed; on `main` the two floor test files passed 21 of 21
- Observed 2026-10-06 (Claude Code, Opus 5.5 session): the Agent tool's input schema lists `description`, `prompt`, `subagent_type`, `model`, `isolation`, `run_in_background` and no effort field
