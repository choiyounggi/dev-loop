---
id: testing-quality-alias-table-contract-tests
domain: testing
category: quality
applies_to: [general]
confidence: field-tested
sources:
  - https://pitest.org/quickstart/basic_concepts/
  - https://testing.googleblog.com/2021/04/mutation-testing.html
  - https://junit.org/junit5/docs/current/user-guide/
last_verified: 2026-09-28
related: [testing-quality-spec-artifact-checks, testing-quality-tests-that-cannot-fail, testing-quality-minimum-case-set, infrastructure-agent-orchestration-checkable-claims-in-an-adopted-plan, testing-mocking-fake-intersection-observer-for-viewport-animations]
---

# Testing a Compatibility Alias Table Row for Row

## When this applies

A task ships a compatibility layer of deprecated names forwarding to new
canonical ones — design-token roles, typography styles, colour names, enum
members, function or type aliases — that a later task will migrate call sites
against, and you are writing or reviewing the test that pins the mapping. Also
when a review finds such a test asserting a hand-picked subset of the rows.

## Do this

1. **Assert every row from a table whose expected column is transcribed from
   the design document's mapping**, not read back from the alias declarations.
   A test that derives its expectations from the implementation passes on any
   mapping, right or wrong.
2. **Assert the table's size equals the legacy-name count** the same document
   states, and — where the language enumerates the legacy set (an `enum`'s
   `values()`, a sealed hierarchy, an exported list) — assert that every member
   has a row. An alias missing from the test is then a failure, not a gap.
3. **Prove detection once:** retarget one alias (or flip one expected cell) and
   require exactly that row to fail; record the red output in the task report
   ([testing-quality-tests-that-cannot-fail]).
4. **Keep the table in the consumer-facing shape** (legacy name → canonical
   name) so the migration task can diff it against its own call-site rewrite.

| Situation | Do |
|-----------|----|
| The mapping is in a design doc's decision table | Copy each row into the test as data; iterate with a parameterized test (`@ParameterizedTest`, `test.each`, a `forEach` over a list of pairs) |
| The legacy names are an enum | Iterate `values()` and look each up in the table; assert `values().size == table.size` |
| A legacy name is intentionally removed rather than aliased | Give it an explicit row with a removal sentinel instead of omitting it, so absence stays a failure |
| The document and the code disagree on a target | Escalate per [infrastructure-agent-orchestration-checkable-claims-in-an-adopted-plan]; do not copy the code's value into the test |

## Edge cases

| Case | Then |
|------|------|
| The alias forwards through a property or function, not a constant | Assert on the resolved value (the object the alias returns), not on the alias's declaration text |
| Two legacy names map to one canonical name | Two rows, same target — the size assertion counts legacy names, not targets |
| The document's table has more rows than the code declares | The size assertion fails first; that is the finding — report it before adding rows to the code |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Spot-check four of eighteen aliases | Assert all rows plus the count | Any un-asserted alias can forward to the wrong target and only a screen migration notices, visually |
| Build the expected column by reading the alias definitions | Transcribe it from the design document | Expectations derived from the implementation cannot disagree with it |
| Stop at "the test passes" | Retarget one alias and watch that row fail | A table test that cannot fail proves nothing about the mapping |

## Sources

- https://pitest.org/quickstart/basic_concepts/ — a mutant is killed when a test fails on the mutated code; a surviving mutant marks a test that does not detect the change
- https://testing.googleblog.com/2021/04/mutation-testing.html — mutation testing as the check that tests actually detect behavioural changes, beyond coverage
- https://junit.org/junit5/docs/current/user-guide/ — `@ParameterizedTest` with `@MethodSource` / `@CsvSource` runs one invocation per row of a data table
- Field evidence 2026-09-27 (linkly-calendar Android, t1-design-tokens): review round 1 found the typography alias test asserting 4 of 18 legacy names; the replacement test iterated all 20 `Typography.kt` enum entries against the plan's D4 mapping table with a size assertion, and the round-2 reviewer retargeted `ButtonMd` and saw exactly that test fail
