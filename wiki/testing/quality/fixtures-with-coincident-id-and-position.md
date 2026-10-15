---
id: testing-quality-fixtures-with-coincident-id-and-position
domain: testing
category: quality
applies_to: [general]
confidence: field-tested
sources:
  - https://en.wikipedia.org/wiki/Mutation_testing
  - https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/
last_verified: 2026-10-15
related: [testing-quality-expectation-sets-with-one-distinct-value, testing-quality-path-resolver-fixtures-with-coincident-cwd, testing-quality-tests-that-cannot-fail, testing-quality-harness-reverse-controls, frontend-rendering-long-lists]
---

# Fixtures Whose Id, Position and Order Field Coincide

## When this applies

You are writing fixtures for code that addresses rows by **id**, by **array
position**, or by a **stored order field** — a reducer with `nextId`, a list
keyed by id, a component that reads `sortOrder`, a move/reorder handler — and a
mutant that reads the wrong one of the three (position for id, `items.length`
for `nextId`, `sortOrder` for the index) survives a green suite. Also when every
assertion runs on the first render and nothing is asserted after a reorder.

## Do this

1. **Make the three axes disagree in every fixture.** Ids that are not the
   position (start at 7, or leave a gap), order values with gaps that differ from
   the index (`1, 3, 4`), and a distinct size, label or length per item. When the
   id equals the index and the order value equals the position, a read of the
   wrong field returns the right value on every case, so the suite cannot reach
   the mutant's output ([testing-quality-path-resolver-fixtures-with-coincident-cwd]
   is the same shape for a cwd fallback).
2. **Build the fixture from a history that includes a delete.** Create four
   items, delete the second: ids `1, 3, 4`, positions `0, 1, 2`, `nextId` `5`
   while `items.length + 1` is `4`. This is what stored data looks like, because
   a delete does not renumber and a reorder rewrites the order field only.
3. **Assert after a reorder or re-render, not only on the first render.** Move
   an item, re-render, then assert the order by id and that each label, length
   or end position follows the stored field it is supposed to follow.
4. **Match each wrong-field read to the fixture that exposes it:**

| Wrong read | Green while | Exposed by |
|------------|-------------|------------|
| Row lookup by position instead of id | id equals index | An id gap (the delete in step 2) |
| `nextId` derived from `items.length` | Ids contiguous from the first index | The same gap, with `nextId` stored separately and asserted after an add |
| Label, span or end position from `sortOrder` instead of the index | `sortOrder` equals position | Order values with gaps (`1, 3, 4`) |
| React `key` or dedupe on `sortOrder` instead of id | Nothing is asserted after a move | A move followed by a re-render assertion by id |

5. **Prove the fixture by mutation.** Swap each read in the table to the wrong
   field, run, and require red; run a no-op edit as the control
   ([testing-quality-harness-reverse-controls]). A mutant still green means
   another axis still coincides — change the fixture, not the assertion count
   ([testing-quality-expectation-sets-with-one-distinct-value]).

## Edge cases

| Case | Then |
|------|------|
| Ids are UUIDs | Position can never equal the id, but the order field can still equal the position; keep the gapped order values and the post-move assertion |
| The server renumbers `sortOrder` to `0..n-1` after every write | Model the state *between* a move and the renumbering (the client's optimistic state), where gaps and a non-sequential order exist |
| A single-item fixture | No field can disagree with another; use three or more items for any test of lookup or ordering |
| Fixtures are generated in a loop (`{ id: i, sortOrder: i }`) | Generate with an offset and a gap (`id: i + 7`, `sortOrder: i * 2 + 1`) so the loop variable feeds no two fields the same value |
| Snapshot tests on the rendered list | Compare the id sequence and the per-item fields; a snapshot of labels alone passes when the labels coincide with positions |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Fill fixtures with `id: 0, 1, 2` and `sortOrder: 0, 1, 2` | Start ids at an offset, leave a gap, give the order field gaps | With the coincidence in place, every wrong-field read produces the expected output |
| Assert the list on the first render only | Move an item and assert again by id | A `key` or lookup on the wrong field shows only after the order changes |
| Add assertions when a wrong-field mutant survives | Change the fixture so the fields disagree, then re-run the mutant | The defect is in the input; no assertion on an output both reads share can separate them |

## Sources

- https://en.wikipedia.org/wiki/Mutation_testing — a mutant is killed only when the infected state "must propagate to the program's output and be checked by the test"; a coincident fixture maps the wrong read back to the expected output and blocks propagation
- https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/ — "When all tests passed while this mutant was active, the mutant survived. You're missing a test for it." — here the missing thing is a fixture whose fields disagree
- Field report 2026-10-12, as recorded by the originating session (Vitest 5, a React list with a `sortOrder` field and a reducer with `nextId`): an independent test-quality audit left 6 of 6 hand-seeded mutants alive with `id === index` and `sortOrder === position` fixtures; after the fixtures were given id gaps, gapped order values and a post-move assertion, the position lookup, `nextId` from `items.length`, label / end / move from `sortOrder`, and a `sortOrder` key all went red. This flush did not re-run the mutants
