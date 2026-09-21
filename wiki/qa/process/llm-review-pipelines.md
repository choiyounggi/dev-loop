---
id: qa-process-llm-review-pipelines
domain: qa
category: process
applies_to: [general]
confidence: field-tested
sources:
  - https://github.com/alibaba/open-code-review
  - https://github.com/alibaba/open-code-review/blob/main/skills/open-code-review/SKILL.md
last_verified: 2026-08-24
related: [qa-process-evaluating-review-feedback, backend-common-llm-vendor-benchmark-claims-for-an-llm-tool]
---

# Structuring an Automated LLM Code-Review Pipeline

## When this applies

Building or configuring an automated LLM code-review pipeline (CI review bot,
review skill, PR-reviewer agent); review token cost grows with changeset size;
deciding which pipeline stages run as deterministic code and which the model
decides; model-written comments land on the wrong lines.

## Do this

1. **Split the pipeline: deterministic selection, model judgment.** File
   selection/exclusion, related-file bundling, and rule-to-file matching run as
   deterministic code before the model sees anything; the model only reads the
   pre-bundled context and judges it. Alibaba's open-code-review measures ~1/9
   the tokens of a general-purpose agent (Claude Code, same base model) on its
   AACR-Bench (50 repos, 200 real PRs, 10 languages, 1,505 issue labels
   cross-validated by 80+ senior engineers) with this split — a self-published
   benchmark, so treat the exact ratio as vendor-measured, not independently
   reproduced.
2. **Keep review rules as matchable data, not prompt prose.** Rules live in a
   layered config (`--rule` flag > repo `.opencodereview/rule.json` > user
   config > built-ins, with an explicit merge flag) and bind to files by path
   glob. Deterministic matching decides which rules load for a file; the model
   applies only the rules that matched.
3. **Bundle related files into one isolated review unit.** Files that must be
   judged together (e.g. `message_en.properties` + `message_zh.properties`) go
   to one sub-review with its own bounded context; units are independent, so
   they run concurrently and a huge changeset degrades into many small reviews
   instead of one overflowing context.
4. **Verify model-emitted coordinates deterministically.** Line numbers and
   comment anchors coming out of the model pass through a positioning/reflection
   check that re-locates the quoted code in the diff before the comment posts;
   a comment whose anchor cannot be re-located is corrected or dropped.
5. **Gate published comments on precision, and measure it.** open-code-review
   explicitly trades recall for precision (its README reports higher
   precision/F1, lower recall). Score any threshold change against a labeled
   PR set rather than by impression.

## Edge cases

| Case | Then |
|------|------|
| No labeled benchmark exists for your codebase | Label a small PR set from recent history first — the precision-vs-recall trade in step 5 is unmeasurable without it |
| A general-purpose review agent is already in place | Add the deterministic selection/bundling stage in front of it; the ~1/9 measurement is exactly this comparison |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Prompt the model with the whole diff plus every rule | Deterministic file selection and glob-matched rules first (steps 1–2) | Token cost scales with changeset × rulebook; matched subsets keep both bounded |
| Post the model's line numbers as-is | Re-locate each anchor deterministically (step 4) | Models misplace anchors; a right finding on a wrong line reads as a wrong finding |

## Sources

- https://github.com/alibaba/open-code-review — README "Core Design: Deterministic Engineering × Agent Hybrid", AACR-Bench description, ~1/9-token and precision-over-recall claims
- https://github.com/alibaba/open-code-review/blob/main/skills/open-code-review/SKILL.md — rule.json format, layering and merge_system_rule semantics
