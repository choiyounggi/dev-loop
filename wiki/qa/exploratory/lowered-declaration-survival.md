---
id: qa-exploratory-lowered-declaration-survival
domain: qa
category: exploratory
applies_to: [general]
confidence: field-tested
sources:
  - "Local reproduction (lnpl 0.2.0, 2026-08-05): two stacked `when` guards compiled rc=0 with zero diagnostics; Semantic IR and MLIR both held exactly one Guard node — the first guard's id carrying the second guard's condition"
last_verified: 2026-08-05
related: [qa-exploratory-guard-true-path-coverage, qa-exploratory-override-control-pairs]
---

# Counting Stacked Declarations in the Lowered Artifact

## When this applies

A compiler/DSL accepts multiple stacked declarations (consecutive guards,
policies, annotations) with exit 0 and no diagnostic, and you are about to
trust runtime behavior that depends on all of them; or a run honored only one
of several declared rules.

## Do this

1. **Dump the lowered artifact and count that every declared item survived**,
   before any runtime trust: semantic IR (compile stage output), MLIR/AST dump,
   or the generated config — whichever lowered form the toolchain exposes. Key
   the count to source constructs: one node per declared guard, each with its
   own condition text.
2. **Read "exit 0 + no diagnostic" as absence of rejection, not as
   acceptance.** Lowering can keep only the last of consecutive declarations
   silently: in the reproduction, two stacked `when` guards produced a single
   Guard node, and the loss was invisible in every compiler message.
3. **Count by content, not by id presence.** The surviving node can carry the
   *first* item's id with the *second* item's payload (observed:
   `…guard.1` holding the second guard's condition) — so "an id exists per
   declaration" is a weaker check than "each declared condition string appears
   once".
4. **When a declaration is missing from the artifact, probe runtime with an
   input only the dropped rule would reject** to size the impact (in the
   originating case, runtime approved amounts `0` and `-1` that the dropped
   guard existed to block), then report the silent drop as a finding
   ([qa-exploratory-guard-true-path-coverage] owns exercising the surviving
   guards).

## Edge cases

| Case | Then |
|------|------|
| The CLI has no explicit IR-dump flag | Use whatever the build leaves behind — a compile stage that prints IR JSON, `.mlir`/`.ll` files in the build workdir — any lowered form supports the count |
| The language documents merge semantics for stacked declarations | Check the documented merge rule first and verify the merged node matches it; an undocumented merge or last-wins is the finding |
| Same-kind declarations live in different scopes (per-service, per-workflow) | Count within each scope separately — cross-scope totals hide a drop in one scope |
| The artifact nests or renames declarations during lowering | Match on the invariant part (condition text, rule value), not on source-level names |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Trust exit 0 as proof all declarations took effect | Count survivors in the lowered artifact first | Last-wins lowering drops predecessors with no warning; the loss surfaces only when an input the dropped rule guarded slips through |
| Verify the declarations with one runtime input | Pick one input per declared rule, including inputs only a dropped rule would reject | A single input can satisfy the surviving rule and still say nothing about the dropped ones |
| Check that a node id exists per declaration | Check each declared condition/value appears in the artifact | The surviving node can reuse a dropped declaration's id |

## Sources

- Local reproduction (2026-08-05, lnpl 0.2.0): a workflow with `when approval.amount > 100` directly followed by `when approval.amount < 0` compiled with rc=0 and zero diagnostics; the Semantic IR JSON and the lowered MLIR each contained exactly one Guard node, `wf.approve.refund.guard.1`, with condition `approval.amount < 0` — the second declaration's condition under the first declaration's id. The originating QA session observed the runtime consequence: amounts `0` and `-1` were approved past the dropped guard
