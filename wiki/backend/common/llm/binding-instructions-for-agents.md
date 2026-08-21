---
id: backend-common-llm-binding-instructions-for-agents
domain: backend
category: llm
applies_to: [general]
confidence: field-tested
sources:
  - https://github.com/obra/superpowers
last_verified: 2026-08-22
related: [backend-common-api-design-agent-tool-granularity]
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

## Edge cases

| Case | Then |
|------|------|
| The instruction must hold across models or versions | Re-run the baseline+instruction pair per model — binding wording is model-specific, and an upgrade can un-bind it |
| Two instruction sources conflict (a skill vs a project rule) | State the precedence inside the artifact itself; unstated precedence gets resolved differently per run |
| The instruction is a one-off for a single session | Skip the test harness and state the rule directly — the testing cost is justified by reuse, and a session instruction is consumed once |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Stack a third prohibition after two were ignored | Rewrite as a recipe or predicate rules, then retest | Prohibition stacking measured worse than no guidance for wrong-shape failures |
| Ship a wording after one clean test run | Run 5+ repetitions plus a no-guidance control | A single run samples the good tail of the distribution; the control proves the instruction is doing the work |
| Write "never do X" on its own | Pair it with the replacement action that makes it unnecessary | A bare prohibition invites improvisation at the boundary — the same rule this wiki's AGENTS.md enforces on its own pages |

## Sources

- https://github.com/obra/superpowers — writing-skills skill and its testing references: baseline-fails-first discipline, form-matched-to-failure table with head-to-head wording measurements, nuance-clause degradation, description-as-trigger-only rule; field-tested across the framework's own skill suite
