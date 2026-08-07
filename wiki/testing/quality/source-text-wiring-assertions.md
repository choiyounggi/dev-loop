---
id: testing-quality-source-text-wiring-assertions
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://stryker-mutator.io/docs/mutation-testing-elements/supported-mutators/
  - https://pitest.org/quickstart/basic_concepts/
  - https://jestjs.io/docs/expect
  - https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Regular_expressions/Quantifier
  - https://testing.googleblog.com/2015/01/testing-on-toilet-change-detector-tests.html
last_verified: 2026-08-07
related:
  [
    testing-quality-tests-that-cannot-fail,
    testing-quality-behavior-not-implementation,
    testing-quality-guard-shape-vs-consequence,
    testing-quality-harness-reverse-controls,
    testing-quality-surviving-mutant-equivalence-triage,
    backend-common-change-impact-call-site-enumeration,
  ]
---

# Asserting on Source Text That a Wiring Call Still Exists

## When this applies

A test reads a source file as a string and asserts by regex that some call is
present — a cleanup call in every handler, a logging call after each branch, a
teardown in each exit path — because the behavior has no reachable seam at this
test level. You are choosing the assertion shape, or such a guard is green while
one of the call sites is gone.

Deciding whether a source-text assertion is warranted at all →
[testing-quality-behavior-not-implementation]. Guards that scan every shipped
artifact for a structural shape → [testing-quality-guard-shape-vs-consequence].

## Do this

1. **Enumerate the call sites the guard is meant to protect, from the source,
   before writing the pattern.** The defect this class of guard exists to catch
   is "one of N sites was dropped", so the site list is the assertion's real
   subject ([backend-common-change-impact-call-site-enumeration]). Write the list
   down: the assertion count comes from it, and step 6 re-runs against it.

2. **Give each site an anchor that occurs exactly once in the file, and assert
   one pattern per site.** A regex is satisfied by _any_ anchor–call pair that
   fits its bound, so an anchor appearing at two sites lets either one satisfy
   the other's assertion. Count the anchor's occurrences before using it:

| How the sites are separated                                                      | Assertion shape                                                                                                                                                                                      |
| -------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Each site follows a call or branch condition whose text appears once in the file | Bounded order anchor: `/<anchor>[\s\S]{0,N}<call>/`, after confirming the anchor's occurrence count is 1                                                                                             |
| Each site lives in a separate named function                                     | Slice the source to that function's body (from its declaration to the next top-level declaration) and assert the call inside the slice — the slice bounds the search without needing a unique anchor |
| Sites share the callee and differ only by argument                               | Assert the full call text including the argument, inside the slice or after the unique anchor — the callee name alone is satisfied by any site                                                       |
| No anchor is unique and the sites are not separable into slices                  | The file gives the guard nothing to bind to: extract the sites into named functions first, or test the behavior at a level that reaches it                                                           |

3. **Set the bound N from the distance the anchor and call actually have in the
   current source, plus the length of one statement**, so a legitimately inserted
   line does not redden the guard. The bound is what limits the anchor's reach:
   measured 2026-08-07 in Node, `{0,20}` and `{0,20}?` return the same verdict on
   every input — greedy versus lazy changes which match is reported, not whether
   one exists, so a lazy quantifier adds no constraint.

4. **Prove each assertion by deleting exactly its own site and requiring exactly
   that assertion to redden**, leaving the other sites intact. This is a
   hand-seeded mutation: Stryker's nearest operator, Block Statement, "removes
   the content of every block statement" — it empties a whole block rather than
   one call, so tools do not generate this edit for you.

5. **Run a semantics-preserving control and require green** — change a comment or
   reformat the file. A source-text pattern is one whitespace assumption away
   from asserting formatting, and the control is what separates "the guard reads
   the wiring" from "the guard reads the layout"
   ([testing-quality-harness-reverse-controls]).

6. **Re-run step 1 whenever the enclosing function grows a branch.** A per-site
   guard has no signal for a site that was never enumerated, so the site list —
   not the assertions — is what has to be kept current.

7. **Name each test after its site**, so a reviewer reading a failure knows which
   call went missing rather than that "the count changed".

## Edge cases

| Case                                                              | Then                                                                                                                                                                    |
| ----------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| The behavior is reachable through the public interface after all  | Assert the behavior and delete the source-text guard — a text assertion passes on a call that is present and broken                                                     |
| The sites are generated from a template or macro                  | Assert on the generator's input at its one site, and add one behavior test on the generated output; per-site text assertions on generated files re-assert the generator |
| The anchor call itself is renamed in a refactor                   | The guard reddens on correct code — that is the coupling this guard buys; update anchor and call together, and re-run step 4 for each site                              |
| Two sites legitimately share one anchor (a branch and its else)   | Anchor on each arm's own branch-condition text, or slice per arm; a shared anchor makes the two assertions interchangeable                                              |
| The anchor's occurrence count rises from 1 to 2 in a later change | Both assertions became satisfiable by either site — re-run step 2 and pick a new anchor, then re-prove with step 4                                                      |
| The pattern must survive a formatter that reflows lines           | Match on the token sequence with `[\s\S]{0,N}` between tokens rather than on a literal multi-line string, and keep the step-5 reformat control                          |
| A site's mutant survives despite the assertion                    | Classify it before strengthening the pattern ([testing-quality-surviving-mutant-equivalence-triage]) — the call may be redundant at that site                           |

## Instead of

| If you are about to                                                                        | Do this instead                                                                                   | Why                                                                                                                                                                         |
| ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Assert `matches.length >= n` or `toHaveLength(n)` for a call that appears at several sites | Assert one anchored or sliced pattern per enumerated site                                         | A lower bound is satisfied by the surviving sites, so deleting the one site the guard was written for keeps it green — the exact defect the guard exists to catch passes it |
| Raise the count assertion to an exact `toHaveLength(n)` after finding this gap             | Keep the per-site assertions and re-run the enumeration (step 6) when the function grows a branch | An exact count reddens on legitimate additions and names no site; the per-site guard names the site, and step 6 is what covers additions                                    |
| Match the call anywhere in the file (`/setPendingEntry\(null\)/`)                          | Bind it to a once-occurring anchor or to the enclosing function slice                             | An unbound match is satisfied by any one of the sites, making N sites indistinguishable from one                                                                            |
| Add `?` to the quantifier to keep the anchor from reaching a later site                    | Set the bound N, and confirm the anchor occurs once                                               | Laziness changes which match is reported, not whether the pattern matches; the reach is decided by N and by the anchor's uniqueness                                         |
| Ship the anchored guard because the suite is green                                         | Delete each site once and require its own assertion red                                           | Narrowing a pattern is the easiest way to narrow it to nothing; a pattern that matches nothing and one that matches everything both read as green                           |
| Use a source-text guard as the primary coverage for the handler's logic                    | Keep it as a wiring check and test the behavior at the level that can reach it                    | Text guards fail on refactors that preserve behavior and pass on a call whose implementation broke                                                                          |

## Sources

- https://stryker-mutator.io/docs/mutation-testing-elements/supported-mutators/ — the Block Statement mutator "removes the content of every block statement"; it empties a block rather than removing one call, which is why the per-site deletion in step 4 is hand-seeded rather than tool-generated
- https://pitest.org/quickstart/basic_concepts/ — "'Survived' means the mutation was not detected by the covering test"; a per-site deletion that leaves the suite green is exactly this verdict for the site the guard names
- https://jestjs.io/docs/expect — `toHaveLength` asserts a `.length` value; applied to a match array it compares a total and carries no information about which element is missing
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Regular_expressions/Quantifier — documents `{min,max}` as a bounded repetition and `?` as the non-greedy form that "will try to match as few times as possible"; non-greediness governs how much the quantifier consumes, not whether the overall pattern matches (measured, step 3)
- https://testing.googleblog.com/2015/01/testing-on-toilet-change-detector-tests.html — Alex Eagle, "Testing on the Toilet: Change-Detector Tests Considered Harmful" (2015-01-27), cited for the change-detector category itself: a test coupled to source shape fails on behavior-preserving edits. The article body was not retrievable in full on 2026-08-07, so nothing here is quoted from it
- Measurement 2026-08-07 (Node): `/ANCHOR\([\s\S]{0,20}CALL\(/` and its lazy form `{0,20}?` returned identical verdicts on four inputs (anchor-then-call in range, call-before-anchor only, call beyond the bound, call both before and after the anchor) — the bound decides reach, and a call elsewhere in the file neither blocks nor is excluded by the pattern
- Field measurement 2026-08-07 (rtb-unified, `apps/web` building-detail panel): `setPendingEntry(null)` appears at four sites (close, list-select, post-resolve, error branch). A `>= 3` count assertion stayed green after a mutant deleted the post-resolve site. Binding it to the once-occurring anchor `resolveBuildingDetailEntry\(` within a 200-character bound produced red on that same mutant, and a comment-only edit kept it green
