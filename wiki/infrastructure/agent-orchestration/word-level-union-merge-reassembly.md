---
id: infrastructure-agent-orchestration-word-level-union-merge-reassembly
domain: infrastructure
category: agent-orchestration
applies_to: [general]
confidence: verified
sources:
  - https://git-scm.com/docs/git-merge-file
last_verified: 2026-09-27
related: [infrastructure-agent-orchestration-ours-resolution-on-a-mixed-content-conflict, infrastructure-agent-orchestration-semantic-conflicts-after-parallel-merge]
---

# Reassembling a Line After a Word-Level Union Merge

## When this applies

Integrating several parallel branches where two sides appended different text
to the same line — a `related:` list, a `sources` bullet, a `last_verified`
date, one sentence — and you resolve the conflict automatically by splitting
the line into words, running `git merge-file --union`, and joining the result
back; or you are reviewing such a resolution and the merged line reads as one
glued token (`planning)the`, `2026-09-172026-09-06`).

## Do this

1. **Locate the failure in the rejoin step, not in `--union`.** `merge-file
   --union` works on lines and keeps a newline between every span it retains,
   even when no input file ends in a newline. The separator disappears when the
   word-per-line output is joined with `tr -d '\n'` or plain string
   concatenation: the newline that stood in for the space is deleted instead of
   translated. Join with the separator the split removed (`paste -sd' '`, or
   `tr '\n' ' '` followed by trimming) and the boundaries return.
2. **Compare the merged line against both inputs before writing it.** Every
   token boundary present in either input must be present in the output; grep
   the result for glued signatures — a closing bracket followed by a letter
   (`\)[A-Za-z]`), two dates adjacent (`[0-9]{2}[0-9]{4}-`), a list id
   followed by another id with no comma.
3. **Resolve structured fields by their semantics, not by word merge.**

| Field shape | Resolve by |
|-------------|------------|
| Id list (`related:`, tags) | Union of the two id sets, deduplicated, original order then additions |
| Date (`last_verified`) | The later of the two dates |
| A count both sides re-measured | Re-measure on the merged tree ([infrastructure-agent-orchestration-ours-resolution-on-a-mixed-content-conflict]) |
| Source bullets | Keep both bullets as separate list items |
| One prose sentence extended on both sides | Keep both versions side by side and rewrite by hand; a word union of two sentence tails is a third sentence nobody wrote |

## Edge cases

| Case | Then |
|------|------|
| The two sides appended at the same point and neither input carries a separator there (`foo(bar` vs `foo(baz`) | `--union` emits both tails on separate lines; the rejoin has no separator to restore, so choose one and record the choice in the merge commit |
| A format lint passes over the merged file | Glued text is well-formed markdown and a lint keyed on structure does not see it; add the glued-signature grep from step 2 to the integration gate |
| Only one side changed the line | There is no conflict and `--union` returns that side unchanged; the reassembly hazard exists only for lines both sides edited |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Rejoin word-merged output with `tr -d '\n'` | Rejoin with `paste -sd' '` and diff against both inputs | Deleting the newline deletes the space it replaced |
| Word-merge a `related:` list or a date | Apply the field rule from the table (set union, max date) | These fields have a defined merge that does not depend on token order |

## Sources

- https://git-scm.com/docs/git-merge-file — `--union`: "resolve conflicts favouring our (or their or both) side of the lines"; the tool merges line ranges and writes the kept lines in order
- Local reproduction 2026-09-27 (git 2.50.1): `merge-file -p --union` on a one-line conflict wrote both versions joined by `\n` (also with no trailing newline on any input); word-per-line union then `tr -d '\n'` produced `theplanisreadyforreviewandapproved`, while `paste -sd' '` on the same union output produced `the plan is ready for review and approved`
- Field evidence 2026-09-21 (dev-loop integration branch consolidating 19 knowledge PRs, `word-merges.log`): 4 of 6 automated word-level merges glued tokens (`planning)the`, `2026-09-172026-09-06`); the lines were repaired by hand and confirmed by an independent review
