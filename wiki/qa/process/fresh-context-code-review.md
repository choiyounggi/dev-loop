---
id: qa-process-fresh-context-code-review
domain: qa
category: process
applies_to: [general]
confidence: verified
sources:
  - https://arxiv.org/abs/2603.12123
last_verified: 2026-09-04
related: [qa-process-llm-review-pipelines, qa-process-evaluating-review-feedback, qa-process-adversarial-change-review, infrastructure-agent-orchestration-session-context-token-budget]
---

# Reviewing LLM-Produced Work From a Session That Did Not Produce It

## When this applies

Reviewing code, a plan, or a document an LLM session just produced, and
deciding whether the producing session (or a subagent spawned from it) may
also serve as the reviewer; about to ask a session to "double check your
work"; designing which session or subagent an automated review stage
dispatches to.

## Do this

1. **Run the review in a session that never received the production
   conversation** — a fresh session, or a subagent invoked with only the
   artifact (diff, plan, document) and the review instructions, not the
   reasoning trail that produced it. arXiv:2603.12123 ("Cross-Context
   Review", CCR) measured this at 28.6% F1 across 360 reviews over 150 seeded
   errors in 30 artifacts, against 24.6% F1 for same-session self-review
   (p=0.008).
2. **Buy the gain with isolation, not repetition.** Asking the same session
   to review twice (SR2) scored 21.7% F1, not significantly different from a
   single same-session pass (p=0.11). One fresh-context pass replaces any
   number of same-session re-reads.
3. **Give a subagent reviewer the artifact only.** A subagent that inherited
   the producing session's context (SA) scored 23.8% F1, statistically on par
   with same-session review — the subagent boundary by itself buys nothing;
   the missing production context is what does.
4. **Return only the verdict to the original session**, not the reviewer's
   reasoning trail, so a correction loop does not re-mix the production
   context back into the next round's review.
5. **Budget one extra session, not a pipeline.** The paper's method "requires
   no special infrastructure and costs only one additional session." This
   repo's own `test-quality-auditor`, `integration-reviewer`, and
   `plan-reviewer` subagents already implement it — each exists "so the
   session that wrote the code does not grade its own tests" / to review
   "from a fresh context the coordinator's own session never reaches."

## Edge cases

| Case | Then |
|------|------|
| The reviewer needs shared background (repo layout, conventions) but not the production reasoning | Give it the artifact and repo access, not the transcript — [infrastructure-agent-orchestration-session-context-token-budget] already isolates subagent context for cost; the same isolation carries this page's accuracy gain |
| The review stage is a deterministic CI bot, not a chat session | Isolation still applies — [qa-process-llm-review-pipelines] bundles files into isolated review units; keep the producing agent's own narrated reasoning (commit-message chain-of-thought, plan rationale) out of the unit's input |
| The change is high-risk (auth, payments, migration) | Weight fresh-context review highest here: CCR's gain concentrated on critical errors (+11 percentage points) and code artifacts (+4.7 F1 points), consistent with [qa-process-adversarial-change-review]'s depth-by-risk table |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Ask the session that wrote the code or plan to "double-check your work" | Dispatch a fresh session or artifact-only subagent | Same-session review scored 24.6% F1 vs 28.6% for a fresh session on the same 150-seeded-error benchmark (p=0.008) |
| Ask the producing session to review twice for extra confidence | Run one fresh-context review | Repeated same-session review (21.7% F1) is not significantly better than one pass (p=0.11) |
| Hand review to a subagent spawned with the same conversation | Spawn the subagent with only the artifact, not the production transcript | Context-sharing subagents scored 23.8% F1 — statistically on par with same-session review |

## Sources

- https://arxiv.org/abs/2603.12123 — Song, "Cross-Context Review: Improving LLM Output Quality by Separating Production and Review Sessions" (Mar 2026): 30 artifacts, 150 seeded errors, 360 reviews; abstract reads "CCR reached an F1 of 28.6%, outperforming SR (24.6%, p=0.008, d=0.52), SR2 (21.7%, p<0.001, d=0.72), and SA (23.8%, p=0.004, d=0.57)"; SR2 vs SR not significant (p=0.11); gains concentrated on critical errors (+11pp) and code artifacts (+4.7 F1)
- Local reproduction 2026-09-04 (this repo, `agents/test-quality-auditor.md`, `agents/integration-reviewer.md`, `agents/plan-reviewer.md`): each is a fresh-context reviewer invoked "so the session that wrote the code does not grade its own tests" / "from a fresh context the coordinator's own session never reaches" — a production instance of the paper's mechanism
