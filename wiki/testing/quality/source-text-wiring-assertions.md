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
  - https://eslint.org/docs/latest/extend/custom-rules
last_verified: 2026-08-10
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
one of the call sites is gone. Also when such a guard — a negative
`not.toMatch`, or a "this token appears N times" count — reddens on code that is
correct, and a comment is the only thing that changed.

Deciding whether a source-text assertion is warranted at all →
[testing-quality-behavior-not-implementation]. Guards that scan every shipped
artifact for a structural shape → [testing-quality-guard-shape-vs-consequence].

## Do this

1. **Enumerate the call sites the guard is meant to protect, from the source,
   before writing the pattern.** The defect this class of guard exists to catch
   is "one of N sites was dropped", so the site list is the assertion's real
   subject ([backend-common-change-impact-call-site-enumeration]). Write the list
   down: the assertion count comes from it, and step 7 re-runs against it.

2. **Make the assertion's subject the file with comments removed, using the
   language's own tokenizer or parser.** Comments carry the same tokens the guard
   searches for — a JSDoc naming the component, a `// guard: never use X here`
   note — and text search cannot tell prose from code. ESLint states the split
   directly: "While comments are not technically part of the AST", so a rule must
   reach them through `sourceCode.getAllComments()` rather than by traversing
   nodes. Strip with the parser (`sourceCode.getAllComments()` ranges, Babel/TS
   `ts.createSourceFile`, Python `tokenize.COMMENT`) and keep the stripper honest
   with its own fixture: comment-only text removed, every string and regex literal
   byte-identical afterwards.

3. **Give each site an anchor that occurs exactly once in the file, and assert
   one pattern per site.** A regex is satisfied by _any_ anchor–call pair that
   fits its bound, so an anchor appearing at two sites lets either one satisfy
   the other's assertion. Count the anchor's occurrences before using it:

| How the sites are separated                                                      | Assertion shape                                                                                                                                                                                      |
| -------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Each site follows a call or branch condition whose text appears once in the file | Bounded order anchor: `/<anchor>[\s\S]{0,N}<call>/`, after confirming the anchor's occurrence count is 1                                                                                             |
| Each site lives in a separate named function                                     | Slice the source to that function's body (from its declaration to the next top-level declaration) and assert the call inside the slice — the slice bounds the search without needing a unique anchor |
| Sites share the callee and differ only by argument                               | Assert the full call text including the argument, inside the slice or after the unique anchor — the callee name alone is satisfied by any site                                                       |
| No anchor is unique and the sites are not separable into slices                  | The file gives the guard nothing to bind to: extract the sites into named functions first, or test the behavior at a level that reaches it                                                           |

4. **Set the bound N from the distance the anchor and call actually have in the
   current source, plus the length of one statement**, so a legitimately inserted
   line does not redden the guard. The bound is what limits the anchor's reach:
   measured 2026-08-07 in Node, `{0,20}` and `{0,20}?` return the same verdict on
   every input — greedy versus lazy changes which match is reported, not whether
   one exists, so a lazy quantifier adds no constraint.

5. **Prove each assertion by deleting exactly its own site and requiring exactly
   that assertion to redden**, leaving the other sites intact. This is a
   hand-seeded mutation: Stryker's nearest operator, Block Statement, "removes
   the content of every block statement" — it empties a whole block rather than
   one call, so tools do not generate this edit for you.

6. **Run a semantics-preserving control and require green** — change a comment or
   reformat the file. A source-text pattern is one whitespace assumption away
   from asserting formatting, and the control is what separates "the guard reads
   the wiring" from "the guard reads the layout"
   ([testing-quality-harness-reverse-controls]). With step 2 in place this
   control is green by construction, so a red comment-only edit means the
   stripper leaked, not that the wiring moved — fix the stripper before touching
   the pattern.

7. **Re-run step 1 whenever the enclosing function grows a branch.** A per-site
   guard has no signal for a site that was never enumerated, so the site list —
   not the assertions — is what has to be kept current.

8. **Name each test after its site**, so a reviewer reading a failure knows which
   call went missing rather than that "the count changed".

## Edge cases

| Case                                                              | Then                                                                                                                                                                    |
| ----------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| The behavior is reachable through the public interface after all  | Assert the behavior and delete the source-text guard — a text assertion passes on a call that is present and broken                                                     |
| The sites are generated from a template or macro                  | Assert on the generator's input at its one site, and add one behavior test on the generated output; per-site text assertions on generated files re-assert the generator |
| The anchor call itself is renamed in a refactor                   | The guard reddens on correct code — that is the coupling this guard buys; update anchor and call together, and re-run step 5 for each site                              |
| Two sites legitimately share one anchor (a branch and its else)   | Anchor on each arm's own branch-condition text, or slice per arm; a shared anchor makes the two assertions interchangeable                                              |
| The anchor's occurrence count rises from 1 to 2 in a later change | Both assertions became satisfiable by either site — re-run step 3 and pick a new anchor, then re-prove with step 5                                                      |
| The pattern must survive a formatter that reflows lines           | Match on the token sequence with `[\s\S]{0,N}` between tokens rather than on a literal multi-line string, and keep the step-6 reformat control                          |
| A site's mutant survives despite the assertion                    | Classify it before strengthening the pattern ([testing-quality-surviving-mutant-equivalence-triage]) — the call may be redundant at that site                           |
| The guard reddens on a change that only added a comment           | The comment contains the searched token; apply step 2 rather than loosening the pattern, which would also stop catching the deleted site                                |
| The assertion is negative (`not.toMatch`) or a count              | These are the shapes comments flip: a `// never use X here` note satisfies the negative, and a doc comment naming the component inflates the count — step 2 is required, not optional, for both |
| No parser is available for the file's language                    | Assert per line with comment lines filtered by the language's line-comment prefix, and record in the test that block comments and comment-shaped text inside strings are out of scope |
| The code under test is itself about comments (a doc gate, a lint rule) | Comments are the subject, so keep the raw source — and assert on the raw and stripped forms as two separate named tests so a reader knows which one each claim is about |

## Instead of

| If you are about to                                                                        | Do this instead                                                                                   | Why                                                                                                                                                                         |
| ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Assert `matches.length >= n` or `toHaveLength(n)` for a call that appears at several sites | Assert one anchored or sliced pattern per enumerated site                                         | A lower bound is satisfied by the surviving sites, so deleting the one site the guard was written for keeps it green — the exact defect the guard exists to catch passes it |
| Raise the count assertion to an exact `toHaveLength(n)` after finding this gap             | Keep the per-site assertions and re-run the enumeration (step 7) when the function grows a branch | An exact count reddens on legitimate additions and names no site; the per-site guard names the site, and step 7 is what covers additions                                    |
| Match the call anywhere in the file (`/setPendingEntry\(null\)/`)                          | Bind it to a once-occurring anchor or to the enclosing function slice                             | An unbound match is satisfied by any one of the sites, making N sites indistinguishable from one                                                                            |
| Add `?` to the quantifier to keep the anchor from reaching a later site                    | Set the bound N, and confirm the anchor occurs once                                               | Laziness changes which match is reported, not whether the pattern matches; the reach is decided by N and by the anchor's uniqueness                                         |
| Ship the anchored guard because the suite is green                                         | Delete each site once and require its own assertion red                                           | Narrowing a pattern is the easiest way to narrow it to nothing; a pattern that matches nothing and one that matches everything both read as green                           |
| Use a source-text guard as the primary coverage for the handler's logic                    | Keep it as a wiring check and test the behavior at the level that can reach it                    | Text guards fail on refactors that preserve behavior and pass on a call whose implementation broke                                                                          |
| Strip comments with `src.replace(/\/\*[\s\S]*?\*\//g,'').replace(/\/\/.*$/gm,'')`          | Take the comment ranges from the parser (step 2), and fixture-test the stripper                   | Measured 2026-08-10 in Node: that pair truncates `"https://api.example.com//v2/items"` to `"https:` — the `//` inside a string literal is read as a comment start, so the guard then searches a corrupted subject and its verdict means nothing |
| Add string-literal handling to the stripping regex and ship it                             | Take the comment ranges from the parser (step 2)                                                  | Measured the same session: a string-aware alternation keeps the URL intact and still truncates `const re = /a//b/` to `const re = /a` — each regex fix leaves the next literal form, which is the case the tokenizer already handles |
| Delete the comment that explains the guard so the guard stops firing on it                 | Apply step 2 and keep the comment                                                                 | A guard that has to be kept comment-free trades its own documentation for its verdict, and the next author restores the comment without knowing why it was gone            |

## Sources

- https://stryker-mutator.io/docs/mutation-testing-elements/supported-mutators/ — the Block Statement mutator "removes the content of every block statement"; it empties a block rather than removing one call, which is why the per-site deletion in step 5 is hand-seeded rather than tool-generated
- https://pitest.org/quickstart/basic_concepts/ — "'Survived' means the mutation was not detected by the covering test"; a per-site deletion that leaves the suite green is exactly this verdict for the site the guard names
- https://jestjs.io/docs/expect — `toHaveLength` asserts a `.length` value; applied to a match array it compares a total and carries no information about which element is missing
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Regular_expressions/Quantifier — documents `{min,max}` as a bounded repetition and `?` as the non-greedy form that "will try to match as few times as possible"; non-greediness governs how much the quantifier consumes, not whether the overall pattern matches (measured, step 4)
- https://testing.googleblog.com/2015/01/testing-on-toilet-change-detector-tests.html — Alex Eagle, "Testing on the Toilet: Change-Detector Tests Considered Harmful" (2015-01-27), cited for the change-detector category itself: a test coupled to source shape fails on behavior-preserving edits. The article body was not retrievable in full on 2026-08-07, so nothing here is quoted from it
- Measurement 2026-08-07 (Node): `/ANCHOR\([\s\S]{0,20}CALL\(/` and its lazy form `{0,20}?` returned identical verdicts on four inputs (anchor-then-call in range, call-before-anchor only, call beyond the bound, call both before and after the anchor) — the bound decides reach, and a call elsewhere in the file neither blocks nor is excluded by the pattern
- https://eslint.org/docs/latest/extend/custom-rules — "While comments are not technically part of the AST, ESLint provides the `sourceCode.getAllComments()`, `sourceCode.getCommentsBefore()`, `sourceCode.getCommentsAfter()`, and `sourceCode.getCommentsInside()` to access them"; rules visit "nodes while traversing the abstract syntax tree (AST as defined by ESTree)". This is the split step 2 relies on: a structural check runs over a tree comments do not appear in, a text check runs over the file where they do
- Measurement 2026-08-10 (Node, fixture with a JSDoc block, a line comment, a URL string literal and a regex literal): on the raw source, `<BlockDetailPanel` matched 2 times where the code has 1 site, and `/Number\.isFinite/` tested true from a `// guard: never use Number.isFinite here` comment. After parser-equivalent comment removal both returned the code's own values (1, false). The regex stripper in the same run corrupted a string literal (`"https://…//v2/items"` → `"https:`), and a string-aware variant still corrupted a regex literal (`/a//b/` → `/a`) — the basis for the two `Instead of` rows
- Field measurement 2026-08-10 (rtb-unified, `feat-NEWRTB-2451-detail-entry-rule`): three source-text guards in one PR reddened on correct code, each from a comment — a JSDoc mentioning `<BlockDetailPanel` (mount-count assertion), a comment naming `Number.isFinite` (negative assertion), and a comment containing `SOURCE.slice(...)` (a self-check forbidding a raw slice). All three were resolved by asserting on comment-stripped code, and a comment-only control edit stayed green afterwards
- Field measurement 2026-08-07 (rtb-unified, `apps/web` building-detail panel): `setPendingEntry(null)` appears at four sites (close, list-select, post-resolve, error branch). A `>= 3` count assertion stayed green after a mutant deleted the post-resolve site. Binding it to the once-occurring anchor `resolveBuildingDetailEntry\(` within a 200-character bound produced red on that same mutant, and a comment-only edit kept it green
