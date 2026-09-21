---
id: backend-common-llm-binding-instructions-for-agents
domain: backend
category: llm
applies_to: [general]
confidence: field-tested
sources:
  - https://github.com/obra/superpowers
  - https://github.com/ayghri/i-have-adhd/blob/main/skills/i-have-adhd/SKILL.md
last_verified: 2026-08-24
related: [backend-common-api-design-agent-tool-granularity, backend-common-llm-progressive-disclosure-artifacts, platforms-tools-deny-rules-under-bypassed-permissions, qa-document-verification-rationale-prose-after-a-config-value-change, qa-deliverables-obligation-row-without-a-named-actor, backend-common-llm-project-local-layer-over-shared-guidance]
---

# Instruction Text That Must Bind an LLM Agent's Behavior

## When this applies

Authoring or editing a skill, system prompt, hook message, or CLAUDE.md/
AGENTS.md rule that must change an agent's behavior under pressure; an
existing instruction keeps getting rationalized around; writing the
description or trigger line that decides when an instruction loads.

## Do this

1. Test wording like code. Run the pressure scenario without the instruction
   and require the baseline to fail — a compliant baseline means there is
   nothing to fix. Then run with the instruction and require compliance. Use
   5+ fresh-context repetitions per variant; a verdict that varies across
   repetitions means the wording does not bind.
2. Match the instruction's form to the observed failure:

| Observed failure | Form that fixes it |
|------------------|--------------------|
| Rule skipped under pressure ("just this once", "too simple to count") | Prohibition plus the specific rationalizations countered by name, plus a red-flag phrase list |
| Output compliant in letter but wrong in shape | A positive recipe or template of the wanted shape — in head-to-head wording tests, adding prohibitions to a wrong-shape failure produced MORE of the unwanted content than no guidance |
| A required element omitted | A structural template with the element as a REQUIRED slot |
| Behavior that depends on the situation | Predicate-keyed rules ("when X, do A; when Y, do B") — a blanket rule with exemption clauses leaves the boundary to per-run improvisation |
| The instruction said "ask the user" and the agent asked in prose (a numbered list typed into the reply instead of the question tool's chooser) | Name the channel, not only the shape — "ask with the `AskUserQuestion` tool" — and gate the action that depends on the answer with a PreToolUse hook that reads `transcript_path` and denies (exit 2) until a call to that tool exists in the transcript. Shape words ("numbered list", "one at a time") leave the tool choice open, and prose is the cheapest rendering; wording alone does not hold the choice across sessions, a hook checks it mechanically |

3. Close loopholes from actual transcripts: quote the rationalization the
   agent produced and counter it by name; add counters only for observed
   workarounds, because speculative counters bloat the rule without binding
   anything.
4. Keep nuance out of the rule sentence: a single appended "unless it
   matters" clause degraded a previously consistent wording to noisy in
   repeated tests — encode each exception as its own predicate row instead.
5. Write description/trigger fields as loading conditions only ("use when
   ..."). A description that summarizes the workflow gets followed as the
   workflow — the agent acts on the summary and skips the body's steps.
6. For an output-shape rule, append a pre-send self-check the agent runs
   against its own draft before emitting — phrased as observable predicates
   ("does the first line state the action? does the last line commit to a
   next step?"), each with the fix ("if not, delete it"). A rule stated only
   at the top of a skill is applied at generation time and forgotten by the
   final token; the self-check re-applies it to the finished output.
   i-have-adhd's "Pre-send check" pairs each of its ten output rules with such
   a predicate.

## Edge cases

| Case | Then |
|------|------|
| The instruction must hold across models or versions | Re-run the baseline+instruction pair per model — binding wording is model-specific, and an upgrade can un-bind it |
| Two instruction sources conflict (a skill vs a project rule) | State the precedence inside the artifact itself; unstated precedence gets resolved differently per run |
| The instruction is a one-off for a single session | Skip the test harness and state the rule directly — the testing cost is justified by reuse, and a session instruction is consumed once |
| The gated question runs headless (no TTY) | The question tool resolves at once with empty answers, so the transcript carries a call with no human answer; have the hook also require a non-empty answer in the tool result, or route the decision out of band per [infrastructure-agent-orchestration-unattended-worker-questions] |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Stack a third prohibition after two were ignored | Rewrite as a recipe or predicate rules, then retest | Prohibition stacking measured worse than no guidance for wrong-shape failures |
| Ship a wording after one clean test run | Run 5+ repetitions plus a no-guidance control | A single run samples the good tail of the distribution; the control proves the instruction is doing the work |
| Write "never do X" on its own | Pair it with the replacement action that makes it unnecessary | A bare prohibition invites improvisation at the boundary — the same rule this wiki's AGENTS.md enforces on its own pages |
| Fix a "asked in prose" regression by adding "use a numbered list" to the wording | Name the question tool in the wording and add the transcript-reading PreToolUse gate | The list instruction was already present when the regression happened; only the tool name plus a mechanical check binds the channel |

## Sources

- https://github.com/obra/superpowers — writing-skills skill and its testing references: baseline-fails-first discipline, form-matched-to-failure table with head-to-head wording measurements, nuance-clause degradation, description-as-trigger-only rule; field-tested across the framework's own skill suite
- https://github.com/ayghri/i-have-adhd/blob/main/skills/i-have-adhd/SKILL.md — "Pre-send check": each output rule paired with a pre-emit self-check predicate and its fix
- https://code.claude.com/docs/en/hooks — PreToolUse hook input carries `transcript_path` (the session's JSONL transcript) and `tool_input`; exit code 2 blocks the tool call and shows stderr to the model
- https://github.com/choiyounggi/dev-loop/pull/144 with `hooks/orchestrate-ask-gate.sh` (https://github.com/choiyounggi/dev-loop/blob/main/hooks/orchestrate-ask-gate.sh) — field reproduction 2026-08-25: PR #136 introduced the gate wording ("ask in one numbered round") without naming the tool and Gate 1 degraded to prose questions; #144 named `AskUserQuestion` in the skill text and added a PreToolUse(Bash) gate that scans the transcript for that tool call before the first worker launch (27 bats cases; 744 tests green)
