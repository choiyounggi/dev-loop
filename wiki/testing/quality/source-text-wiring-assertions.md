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
   subject ([backend-common-change-impact-call-site-enumeration]).

2. **Bind each occurrence to the context that must contain it, and assert one
   pattern per site.** Pick the binding by how the sites are separated:

| How the sites are separated                                     | Assertion shape                                                                                                                                                           |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Each site follows a distinct preceding call or branch condition | Order anchor: `/<anchor>[\s\S]{0,N}?<call>/` — a bounded lazy quantifier, so the call must appear within N characters after that anchor and not anywhere else in the file |
| Each site lives in a separate named function                    | Slice the source to that function's body first (from its declaration to the next top-level declaration), then assert the call inside the slice                            |
| Sites differ only by an argument value                          | Assert the full call text including the argument (`setPendingEntry(null)` inside handler `X`), not the callee name                                                        |

3. **Choose N from the enclosing block, not from the file.** Set the bound to
   the largest legitimate distance between anchor and call in the current source
   plus room for one added statement. A bound wide enough to span two sites lets
   either one satisfy the other's assertion.

4. **Prove each assertion by deleting exactly its own site and requiring exactly
   that assertion to redden**, leaving the other sites intact. Deleting one call
   is the standard mutation operator, not an ad-hoc edit: Stryker's Block
   Statement mutator "removes the content of every block statement".

5. **Run a semantics-preserving control and require green** — change a comment or
   reformat the file. A source-text pattern is one whitespace assumption away
   from asserting formatting, and the control is what separates "the guard reads
   the wiring" from "the guard reads the layout"
   ([testing-quality-harness-reverse-controls]).

6. **Name each test after its site**, so a reviewer reading a failure knows which
   call went missing rather than that "the count changed".

## Edge cases

| Case                                                             | Then                                                                                                                                                                                 |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| The behavior is reachable through the public interface after all | Assert the behavior and delete the source-text guard — a text assertion passes on a call that is present and broken                                                                  |
| The sites are generated from a template or macro                 | Assert on the generator's input at its one site, and add one behavior test on the generated output; per-site text assertions on generated files re-assert the generator              |
| The anchor call itself is renamed in a refactor                  | The guard reddens on correct code — that is the coupling this guard buys; update anchor and call together, and re-run step 4 for each site                                           |
| Two sites legitimately share one anchor (a branch and its else)  | Anchor on the branch condition text instead of the shared call, so each arm has its own anchor                                                                                       |
| A site is added during review                                    | The existing assertions staying green is the review finding — a per-site guard has no signal for a site that was never enumerated; re-run step 1 whenever the handler grows a branch |
| The pattern must survive a formatter that reflows lines          | Match on the token sequence with `[\s\S]{0,N}?` between tokens rather than on a literal multi-line string, and keep the step-5 reformat control                                      |
| A site's mutant survives despite the assertion                   | Classify it before strengthening the pattern ([testing-quality-surviving-mutant-equivalence-triage]) — the call may be redundant at that site                                        |

## Instead of

| If you are about to                                                                        | Do this instead                                                                | Why                                                                                                                                                                         |
| ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Assert `matches.length >= n` or `toHaveLength(n)` for a call that appears at several sites | Assert one anchored pattern per enumerated site                                | A lower bound is satisfied by the surviving sites, so deleting the one site the guard was written for keeps it green — the exact defect the guard exists to catch passes it |
| Raise a count assertion's threshold to `toHaveLength(exact)` after finding this gap        | Anchor each occurrence to its own context                                      | An exact count reddens when any site is added or removed, including legitimately, and still cannot say which site is missing                                                |
| Match the call anywhere in the file (`/setPendingEntry\(null\)/`)                          | Bind it to the preceding call or the enclosing function slice                  | An unbound match is satisfied by any one of the sites, making N sites indistinguishable from one                                                                            |
| Ship the anchored guard because the suite is green                                         | Delete each site once and require its own assertion red                        | Narrowing a pattern is the easiest way to narrow it to nothing; a pattern that matches nothing and one that matches everything both read as green                           |
| Use a source-text guard as the primary coverage for the handler's logic                    | Keep it as a wiring check and test the behavior at the level that can reach it | Text guards are change-detector tests: they fail on refactors that preserve behavior and pass on a call whose implementation broke                                          |

## Sources

- https://stryker-mutator.io/docs/mutation-testing-elements/supported-mutators/ — the Block Statement mutator "removes the content of every block statement", so deleting the statement at one site is a standard mutation operator rather than an ad-hoc edit (step 4)
- https://pitest.org/quickstart/basic_concepts/ — "'Survived' means the mutation was not detected by the covering test"; a per-site deletion that leaves the suite green is exactly this verdict for the site the guard names
- https://jestjs.io/docs/expect — `toHaveLength` asserts a `.length` value; applied to a match array it compares a total and carries no information about which element is missing
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Regular_expressions/Quantifier — `{min,max}` "repeats an atom a minimum of `min` times and a maximum of `max` times"; adding `?` makes it non-greedy so "the quantifier will try to match as few times as possible" — the bounded lazy form is what limits an anchor's reach to one site
- https://testing.googleblog.com/2015/01/testing-on-toilet-change-detector-tests.html — "you cannot safely refactor code if you know you need to adapt the tests afterwards to get them passing again" — the cost a source-text guard accepts, and why it stays scoped to wiring
- Field measurement 2026-08-07 (rtb-unified, `apps/web` building-detail panel): `setPendingEntry(null)` appears at four sites (close, list-select, post-resolve, error branch). A `>= 3` count assertion stayed green after a mutant deleted the post-resolve site. Replacing it with the order anchor `resolveBuildingDetailEntry\([\s\S]{0,200}?setPendingEntry\(null\)` produced red on that same mutant, and a comment-only edit kept it green
