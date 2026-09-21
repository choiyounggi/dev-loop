---
id: infrastructure-agent-orchestration-forward-references-in-a-numbered-protocol
domain: infrastructure
category: agent-orchestration
applies_to: [general]
confidence: field-tested
sources:
  - Field reproduction 2026-08-27 (dispatch-contracts protocol graft, review t3-dispatch-contracts-r1 F1) — see Sources
last_verified: 2026-09-03
related: [infrastructure-agent-orchestration-session-completion-gates, infrastructure-agent-orchestration-dispatching-after-a-completion-report, qa-process-adversarial-change-review, testing-quality-checks-that-cannot-pass, testing-quality-spec-artifact-checks]
---

# Grafting a New Step Into a Numbered Protocol Sequence

## When this applies

Editing a numbered protocol, pipeline, or session-prompt sequence (worker brief
steps, skill workflow steps, CI job order) to add a step whose text quotes, reads,
or depends on an artifact that a later-numbered step produces. Also when reviewing
such an edit: a review scoped to the new step's own section passes while the
sequence as a whole is broken.

## Do this

1. After drafting the new step, read the whole numbered sequence in execution order
   (not diff order) and list every artifact each step consumes. For each artifact,
   find the step that produces it. When the producing step's number is not lower,
   the graft references something that does not exist yet at that point.
2. When the new mechanism must consume a later step's artifact, state the
   reordering as a named exception in the protocol text itself ("step 4 runs before
   step 3 in this case because …") instead of renumbering silently, so the next
   editor sees a deliberate deviation rather than inferring a different sequence from
   the numbers.
3. Give the exception its own spec test — a check that runs or models the sequence
   and asserts the artifact exists at the point the new step reads it. A test scoped
   to the new step's section passes on this exact defect, because from inside that
   section the artifact's existence is assumed, not verified
   ([testing-quality-spec-artifact-checks]).
4. When reviewing a graft into a numbered sequence, read the merged document in
   step order once, independent of the task's own scoped section. The defect this
   page exists for is invisible from inside any one step and visible only when the
   whole sequence is read start to finish — this is the gain a fresh-context
   whole-diff reviewer buys ([qa-process-adversarial-change-review]).

## Edge cases

| Case | Then |
|------|------|
| The dependency is optional and the step degrades without it | Say so in the step text ("when step 5 has not yet produced X, do Y") rather than relying on ordering alone |
| The sequence is prose or a DAG of named phases rather than numbered | Trace the reader's actual execution path, not the paragraph order — the same forward-reference check applies to whatever order is executed |
| Two grafts land in the same protocol from parallel branches | Re-run the full-sequence trace after both merge; each graft alone can be clean while the pair is not |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Review a new protocol step by checking that its own section reads correctly | Trace the full numbered sequence in execution order and locate the producer of everything the new step consumes | A section-scoped review cannot see that the artifact it assumes is produced by a step numbered after it |
| Renumber steps around a necessary reordering without saying so | State the reordering as an explicit exception with its own spec test | An unstated reordering reads as a numbering mistake to the next editor, who "fixes" it back into the broken order |
| Trust a scoped test that asserts the new section contains the right keywords | Add a spec test that models the sequence and asserts the artifact is present at the point of use | Keyword presence inside one section says nothing about which step produces the referent, or when |

## Sources

- Field reproduction 2026-08-27 (a protocol graft into a numbered dispatch-contracts sequence): the per-task scoped review of the new step's own section found the required keywords present and reported nothing; the fresh-context review of the full merged protocol, read in execution order, found the new step quoting an artifact produced by a later-numbered step (`reviews/t3-dispatch-contracts-r1.md`, finding F1). The fixing commit `c06d299` made the reordering an explicit stated exception with its own check; the round-2 review of the same document reported 0 findings. No external primary source governs this authoring practice; the page rests on this reproduction
