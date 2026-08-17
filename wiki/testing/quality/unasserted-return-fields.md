---
id: testing-quality-unasserted-return-fields
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://pitest.org/quickstart/basic_concepts/
  - https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/
  - https://arxiv.org/abs/2211.12003
  - https://hypothesis.works/articles/what-is-property-based-testing/
  - https://abseil.io/resources/swe-book/html/ch12.html
last_verified: 2026-08-06
related: [testing-quality-tests-that-cannot-fail, testing-quality-minimum-case-set, testing-quality-harness-reverse-controls, testing-quality-write-path-assertions, testing-quality-value-preserving-refactor-assertions]
---

# Return Fields No Assertion Reads

## When this applies

The function under test returns a composite — dict, record, tuple, struct — with
several computed fields, and the suite's assertions read one or a few of them
(the headline number, the label). Also when a suite reports a large assertion
count for such a function and you are judging whether that count is coverage.

## Do this

1. **Enumerate the returned fields and diff that list against the fields any
   assertion mentions.** Grep the test files for each field name; a field that
   appears in zero assertions has its whole computation path unverified,
   whatever the suite's assertion count is. Record the list — it is the page's
   working output, not a side note.

2. **Confirm each absence with one mutation per unread field before writing
   anything.** Change that field's computation (swap the percentile it reads,
   widen the multiplier, invert the scope factor) and run the suite. A survived
   mutation is the proof the field is unguarded; a killed one means some
   assertion does read it indirectly, so re-read that assertion instead of
   adding a duplicate. A suite that stays green under the mutation is the
   *survived* verdict; keep it distinct from **No coverage**, where the field's
   computation never executed at all — the first says no assertion checks the
   field, the second says the test never reached it.

3. **Run the harness's no-op control in the same session.** A semantics-
   preserving edit must survive; when it is reported as caught, the mutations
   proved nothing about the fields and the environment is what failed
   ([testing-quality-harness-reverse-controls]).

4. **When two or more returned fields are bound by a relation, assert that
   relation as its own assertion.** An ordering (`lo ≤ point ≤ hi`), a sum
   (`parts == total`), or a derivation (`rate * base == amount`) is a claim no
   single field's value expresses, so no per-field assertion can fail on a
   formula that breaks it. This is a metamorphic relation: MT reasons about
   "relations between outputs" instead of a full input-output specification, and
   such relations "provide formal specification of the system under test" where
   per-field expected values are impractical to enumerate. Choose the assertion
   by what binds the fields:

| Relation between fields | Assert |
|---|---|
| Interval around an estimate (`lo`, `point`, `hi`) | `lo ≤ point ≤ hi` on every case, as its own assertion separate from any value check |
| Parts and a total | The parts sum to the total, and each part is within the total's domain |
| A field derived from others (rate × base) | The derivation recomputed from the returned inputs equals the returned result |
| A label or category paired with a numeric field | The pairing is consistent both ways — the label implies the numeric band and the band implies the label |
| Optional field plus a flag that says whether it is present | The flag and the field's presence agree, in both truth values |

5. **Exercise the relation over the input grid, not one sampled case.** Take the
   cartesian product of the discrete inputs that feed the fields (size buckets ×
   scope factors × type flags) and assert the invariant on every combination.
   The invariant is a property that must hold for all inputs, so a grid — or a
   generator when the space is too large to enumerate — is what can falsify it;
   one hand-picked case can only confirm it.

6. **Report a violated invariant with the combinations that violate it.** The
   count and the specific inputs localize the fault to the field whose formula
   crosses the bound, which a single failing case does not.

## Edge cases

| Case | Then |
|------|------|
| A field is deliberately informational (a debug string, a trace id) | Exclude it explicitly in the test file with the reason; keep it out of the unread-field list so the list stays actionable |
| The grid is too large to enumerate | Generate the inputs with a property-based runner and keep the invariant as the assertion; record the seed with any failure so it replays |
| The invariant holds for all grid points and you cannot construct a violation | Mutate the field's formula and require the invariant assertion to redden — an invariant no input can violate on correct code still has to be provably violable on broken code |
| Two fields are computed by the same expression | Assert each field's value independently, and either drop the relation between them or record it as non-discriminating with that reason — a relation between two copies of one expression cannot fail on a defect that moves both, so keeping it unlabelled adds an assertion that cannot fail |
| The invariant is violated on inputs the caller cannot produce | Fix the field's domain guard or narrow the grid to reachable inputs, and state which it was — a violation on unreachable input is not a bug in the formula |
| The composite is returned across a boundary you own (HTTP/JSON) | Assert the fields on the deserialized response, not the internal object, so the serialization is covered too ([testing-quality-write-path-assertions]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Read a high assertion count on a multi-field return as coverage of that return | Diff the field list against the fields assertions mention, then mutate each unread field | Assertion count measures how often the read fields were checked, not how much of the return is guarded |
| Add one more value assertion for each unread field and stop | Add the value assertions *and* the cross-field invariant | Per-field values cannot express an ordering or sum between fields, so a formula that keeps each field plausible while breaking their relation stays green |
| Assert the invariant on one representative case | Assert it across the grid of discrete inputs, or generate them | An invariant claims something for all inputs; a single case is consistent with it failing everywhere else |
| Trust a survived mutation as proof of a coverage gap without a control | Run the no-op control in the same session and require it to survive too | A harness whose cases die before the rule runs reports survival and catch for reasons unrelated to the tests |

## Sources

- https://pitest.org/quickstart/basic_concepts/ — "**No coverage** is the same as **Survived** except there were no tests that exercised the line of code where the mutation was created": the distinction step 2 depends on when reading a survived per-field mutation as an unguarded field
- https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/ — the mutant state set (`Killed`, `Survived`, `No coverage`, `Timeout`, `Runtime error`, `Compile error`, `Ignored`) and the `detected / valid` score, cited for those states only
- https://arxiv.org/abs/2211.12003 — Alzahrani, Spichkova, Harland, "Application of property-based testing tools for metamorphic testing": "The core concept in MT is metamorphic relations (MRs) which provide formal specification of the system under test", the approach used when determining each expected output directly is impractical
- https://hypothesis.works/articles/what-is-property-based-testing/ — property-based testing as "the construction of tests such that, when these tests are fuzzed, failures in the test reveal problems with the system under test that could not have been revealed by direct fuzzing of that system" — why an invariant plus generated inputs finds what per-case assertions miss
- https://abseil.io/resources/swe-book/html/ch12.html — test the behaviors (guarantees) a unit makes; a cross-field invariant is one such guarantee and needs its own assertion
- Field reproduction 2026-08-05 (manday estimation engine): the suite held 58 passing assertions over a function returning `lo`/`sp`/`hi`; `lo` and `hi` appeared in none of them. Four mutations of their formulas (percentile `p25`→`p75`, `p75`→`p25`, scope factor large→small) each left all 58 assertions passing, while the no-op control survived — confirming the harness discriminated. Adding `lo ≤ sp ≤ hi` over the full discrete input grid surfaced 13 combinations with `sp > hi`
