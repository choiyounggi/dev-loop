---
id: backend-common-change-impact-sibling-validators-on-a-shared-node
domain: backend
category: change-impact
applies_to: [general]
confidence: field-tested
sources:
  - Field incident 2026-08-31, linkly `impl/lnpl/lower.py` (task t8-agg-avg-min-max) — described under Sources
last_verified: 2026-09-03
related: [backend-common-change-impact-widening-a-closed-value-table, backend-common-change-impact-call-site-enumeration, backend-common-errors-diagnostics-from-a-shared-code-path, backend-common-change-impact-corpus-sweep-before-a-rejection-rule]
---

# Widening One Check on a Node That a Second, Older Check Also Gates

## When this applies

You are widening the set of declared types or values a construct accepts in a
compiler, linter, or schema validator's checking pass (a new legal source type
for an aggregate), and the construct's result lands in another declared slot on
the same node — an assignment target, a parameter, a return. Also when the
widened construct now passes its named check and the same statement is still
rejected by a function you did not edit, with a message that names the target
rather than the construct.

## Do this

1. **Enumerate every static check that runs on the node type or verb**, by
   searching for the node name (`Assignment`, `visit_assignment`, the verb
   keyword) rather than for the validation function you already know: an older
   check on the same node does not mention the function you are widening.
2. **Classify each check by which attribute of the node it validates:**

| The check validates | Relationship to the widening |
|---------------------|------------------------------|
| The attribute you widened, through the function you changed | Covered by the edit |
| Another attribute of the same node (the target's type when you widened the source's) | An independent gate that keeps rejecting on its own message; it needs its own decision |
| A helper shared with other nodes | Enumerate that helper's callers ([backend-common-change-impact-call-site-enumeration]) before touching it |

3. **Admit the new case at the one call site that needs it** — a flag threaded
   from the specific caller (`check_reference(..., allow_money=True)` from the
   aggregate-assignment path) — and leave the check's default for every other
   caller unchanged.
4. **Keep the existing regression test for the check's original rejection
   passing unmodified**; it is the proof that the admission stayed scoped.
5. **Write the test for the composed statement** (`set target to <construct>`),
   not only for the construct alone; the construct in isolation passes the
   widened check and never reaches the second gate.

## Edge cases

| Case | Then |
|------|------|
| The rejection message names an attribute unrelated to what you widened | Search for a second validator on the node before re-editing the first; the first is complete |
| The second check is reached from several constructs | Thread the exception per call site; a widened default admits the type for every caller at once |
| The plan or brief names only the construct-specific check | Add the enumeration result to the task report — the plan's scope was the search that found one check |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Re-open the function you just widened when the statement is still rejected | Grep for other checks on the same node or verb | Two gates on one node are the common shape (source-type check, target-type check); the second predates the change and never mentions the first |
| Relax the shared check's default so the new type passes everywhere | Pass a scoped flag from the one caller that needs it | A relaxed default removes the check for every other caller with no test reporting it |

## Sources

- Field incident 2026-08-31 (linkly, task t8-agg-avg-min-max, `impl/lnpl/lower.py`): after `_check_aggregate` was widened to accept Money, `sum payment.amount` compiled while `set report.totalAmount to sum payment.amount` still raised `LowerError` from `_Scope._dimension_of` ("declared type Money is neither Integer nor DateTime"), an RFC-0016-era assignment-target check the task brief never named. Fixed by threading `allow_money` through `check_reference`/`_dimension_of` from the aggregate-assignment call site only; the existing Money-rejection regression test for guard/`Value` contexts passed unchanged. No external source states this enumeration step; compiler texts describe semantic checks as several passes over one tree without naming the practice, so the page stays `field-tested`
