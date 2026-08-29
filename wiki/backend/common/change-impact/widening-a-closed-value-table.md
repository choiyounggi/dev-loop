---
id: backend-common-change-impact-widening-a-closed-value-table
domain: backend
category: change-impact
applies_to: [general]
confidence: verified
sources:
  - https://refactoring.com/catalog/replaceMagicLiteral.html
  - https://pragprog.com/tips/
last_verified: 2026-08-29
related: [backend-common-change-impact-call-site-enumeration, backend-common-api-design-unenforced-declarations, backend-common-errors-diagnostics-from-a-shared-code-path, backend-common-change-impact-compiler-as-call-site-inventory]
---

# Widening a Closed Value Table Whose Consumers Inlined It

## When this applies

You are adding an entry to a closed table that maps a name to a magnitude or a
code — duration units, status codes, currency exponents, retry tiers, severity
levels — and the table exists as a named constant in one module. Also when a
newly added entry is accepted at one layer and rejected, ignored, or
mis-converted at another, so the symptom is a divergence between two paths
rather than a parse error.

## Do this

1. **Enumerate by the table's values, not only by its name.** Grep a
   distinctive magnitude from the table (`60000`, `86400`, `4290`) and a
   distinctive member string (`"ms"`), across the whole repo including tests,
   fixtures, generators, and any second-language backend. The name grep lists
   the sites that import the table; the value grep lists the sites that copied
   it, and only the second set is where widening breaks.
2. **Treat the gap between the two counts as the work item**, and state both in
   the plan: "1 site imports `DURATION_UNITS`, 7 mention `60000`" is checkable
   and shows the scope; "the units table has 1 consumer" hides it.
3. **Classify every value hit before editing:**

| Value hit is | Do |
|--------------|----|
| The canonical table's own definition | Nothing — this is the site the others should read |
| An inlined copy of the pairs (`(("ms",1),("s",1000),("m",60000))`) | Replace the literal with a read of the canonical table |
| Bare arithmetic on one member (`value % 60000`, `ms // 86400000`) | Replace the literal with a lookup into the table; it is a copy of one row |
| A second named table over the same vocabulary in the same module | Derive one from the other so a single edit widens both |
| A copy in another language, a generated artifact, or a backend that re-implements the conversion | Generate it from the table, or add a conformance test asserting both accept every member |

4. **Fix every copy to read the single table before adding the new entry**, so
   the entry lands in one place. Widening first and reconciling after means the
   new member exists in the table while each copy silently defines the old,
   narrower vocabulary.
5. **Add a test that drives every consumer with every member of the table**,
   parameterized over the table itself. It fails on the next widening if a new
   copy has appeared, which is the only check that survives the next author.
6. **When the plan is to unify two duplicate tables into one, compute both set
   differences first and rule on each element before writing the merge.** "Both
   consumers want the same set" is a claim, and unification defaults to the
   union — which widens each side by whatever the other carried. For an
   allowlist that widening *is* the change: a member the other list happened to
   include becomes newly permitted or newly exposed, and neither type-checking
   nor the existing tests read set membership as a fact worth failing on.

| A − B / B − A contains | Do |
|------------------------|----|
| Nothing (the sets are equal) | Unify; record that the difference was measured and empty |
| Elements that are an oversight in one list | Unify to the union, and name each added element in the change description |
| Elements that must legitimately differ per consumer | Keep two names derived from one base (`BASE`, `BASE + EXTRA`), so the difference stays visible instead of being erased |
| Elements you cannot classify | Leave the duplication in place until each is ruled on — an unexplained difference is the case the union silently resolves |

7. **Record the direction after merging**: diff the resulting set against each
   original and state whether it widened, narrowed, or held. A widening of an
   allowlist is a review item on its own, separate from the deduplication.

## Edge cases

| Case | Then |
|------|------|
| The inlined copies are already narrower than the canonical table | The divergence predates your change — the table's later members are already unreachable through those paths. Fix them as part of this change and note the pre-existing gap, or your widening gets blamed for it |
| The magnitude is not distinctive (`1`, `60`, `1000`) | Grep the member name string (`"ms"`, `"USD"`) and the suffix form instead; a bare `1000` returns every unrelated site and the enumeration stops being readable |
| The same vocabulary is expressed in two units across a boundary (seconds inside, milliseconds at the edge) | Grep both magnitudes (`60` and `60000`) — a copy converted at the boundary matches neither the table's values nor its name |
| Members of the table are persisted (stored in rows, serialized into messages, written into config already deployed) | Widening is a migration, not an edit: old readers must keep accepting stored values, and the new member cannot be written until every reader ships |
| The table is consumed by a caller you do not own (published package, other repo, plugin API) | Widening is a versioned release for them; enumerate only what you own, and treat the new member as unsupported until their version pins forward |
| A copy exists only in a test fixture | It still diverges — a fixture pinned to the narrow vocabulary keeps passing while the widened path is never exercised, so the suite reports green on an unmigrated consumer |
| The lookup is a `switch`/`if` chain over member names rather than a value copy | The value grep misses it — grep the member names as well, since the chain encodes the same table as control flow |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Grep the constant's name, report N consumers, and scope the change from that | Grep the table's values and member strings too, and scope from the union | Consumers routinely inline the pairs instead of importing the constant, so the name grep counts imports and misses copies — the copies are the sites that break |
| Add the entry to the canonical table and run the suite | Reconcile the copies first, then widen | A green suite means the consumers the tests reach accepted the entry; the copied ones were never asked |
| Leave one inlined copy because it is a hot path or avoids an import cycle | Have that path read the table once at import and keep the local binding | The copy is not cheaper than a module-level lookup, and it is the site that silently defines a different vocabulary |
| Extend a second same-vocabulary table alongside the first to keep both callers happy | Derive the second from the first in the same module | Two canonical-looking tables make the next author's name grep authoritative and wrong |
| Replace two duplicate allowlists with one union because they "look the same" | Compute both set differences, rule on each element, then unify or derive | The union grants every consumer the other's extra members; for an allowlist that is a new exposure, and no type or test reports it |

## Sources

- https://refactoring.com/catalog/replaceMagicLiteral.html — *Replace Magic Literal*, alias "Replace Magic Number with Symbolic Constant": a literal with a particular meaning becomes a named constant. The refactoring exists because the inlined literal is the default state of such values, which is what makes the value the reliable search handle
- https://pragprog.com/tips/ — Tip 15, DRY: "Every piece of knowledge must have a single, unambiguous, authoritative representation within a system." A copied value table is a second representation, and widening one representation is what produces the divergence
- Field measurement 2026-08-25 (`rtb-unified`, PR #965): a cleanup proposed folding `DISPLAYABLE_ERROR_CODES` into `USER_FACING_ERROR_CODES` as one SSOT. Computing the set difference before merging showed the union added `UNAUTHORIZED` and `VALIDATION_ERROR` to the displayable set — the path by which raw server messages would have been surfaced as inline UI errors. The sets were kept derived-with-an-explicit-difference instead; nothing in the type system or the suite had flagged the widening
- Local reproduction 2026-08-06 (`linkly`, Python, macOS): `grep -rn "DURATION_UNITS" impl/lnpl/*.py` returns **1** hit (the definition); `grep -rn "60000" impl/lnpl/*.py` returns **7** across four files, among them a second named table (`DURATION_UNIT_MS`, `lexer.py:23`), three independently inlined `(("ms",1),("s",1000),("m",60000))` tuples (`condition.py:353`, `interp.py:1020`, `backend.py:446`), and two bare-literal arithmetic sites (`condition.py:269-270`). The predicted divergence was already present: the canonical map carries `h` and `d`, while all three inlined copies stop at `m`, so those paths cannot convert a unit the lexer accepts
