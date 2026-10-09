---
id: testing-quality-schema-rejection-key-coverage
domain: testing
category: quality
applies_to: [zod, general]
confidence: verified
sources:
  - https://zod.dev/api
  - https://zod.dev/basics
  - https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/
  - https://pitest.org/quickstart/basic_concepts/
  - "Local reproduction 2026-10-08 (Node 26.7.0, zod 4.6.5, node --test): a one-key schema-level rejection test passed under 5 mutants that an every-key loop through the wrappers failed under; a per-kind probe mapped 12 mutants to the bad inputs that expose them"
  - "Field case 2026-10-07 (an independent mutation audit of a 13-field zod schema): `.default` replaced by `.catch` survived on the 9 fields the tests did not sample"
last_verified: 2026-10-08
related: [testing-quality-minimum-case-set, testing-quality-unasserted-return-fields, testing-quality-surviving-mutant-equivalence-triage, backend-node-boundaries-runtime-validation]
---

# Rejection Tests for Every Key of a Multi-Field Schema

## When this applies

You are writing or reviewing tests for code that validates an object with several
keys through a schema library (zod `z.object` / `z.strictObject`), and the tests
check rejection on some of the keys, or call only the schema object while callers
go through a wrapper (`parseX(input)`, `isX(input)`).

## Do this

1. **Loop over every key the schema declares.** A schema mutation lands on one key;
   a rejection test on a different key cannot observe it. Drive the loop from a
   key table in the test and assert that the table's keys equal
   `Object.keys(Schema.shape)`, so a key added to the schema without a table row
   fails instead of going untested.
2. **Feed each key all six bad-input kinds.** Measured on zod 4.6.5, five of the
   six are the only input that exposes some mutation:

| Bad-input kind | Build it as | Exposes |
|---|---|---|
| Unknown value | A value outside the key's enum or pattern | An enum widened to `z.string()`, a dropped `.regex` (the case and sibling kinds expose these too) |
| Case or whitespace variant | Two inputs, one change each: the valid value padded (`' gold '`) and case-flipped (`'GOLD'`) | A trim preprocess (only the padded input exposes it) and a lowercase preprocess (only the case-flipped one does); a single combined `' GOLD '` exposes only a normalizer that does both |
| `null` | `null` | `.nullable()` — no other kind does |
| The valid value in another type | `[valid]` for a string key, `'5'` for a number key | `z.coerce.*` (`String(['id-1'])` is `'id-1'`) — on a key with an enum or pattern no other kind does; on a free-text key `null` exposes it too (`z.coerce.string()` turns it into `'null'`) |
| A value valid only in a sibling key | A member of a sibling key's enum | The key's enum merged with the sibling's values — no other kind does |
| Key deletion | `delete input[key]` | `.optional()` or `.default(v)` on a required key — no other kind does |

   `.catch(v)` on a key is exposed by all six kinds on that key and by none on any
   other key — which is why a sampled test misses it.
3. **Assert through the entry points callers use, down to the error.** For every
   key × kind, expect `parseX(bad)` to throw and `isX(bad)` to return `false`.
   A test that calls only `Schema.safeParse` stays green when `isX` inverts the
   result or `parseX` returns its input unvalidated.
4. **Prove the loop by mutation before trusting it.** Apply one mutant at a time
   (`.catch`, `.optional`, a widened type, a trim-only and a lowercase-only
   preprocess, an inverted guard, a passthrough wrapper), require red, revert, and confirm the unmutated suite is green again.
   Triage any survivor with [testing-quality-surviving-mutant-equivalence-triage].

## Edge cases

| Case | Then |
|------|------|
| A key is optional or defaulted by design | The deletion check expects the default (or absence); keep the five value kinds expecting rejection — they are the only checks that expose `.default(v)` turned into `.catch(v)` |
| A key coerces by design (`z.coerce.number()`, as [backend-node-boundaries-runtime-validation] advises for string → number) | Expect the valid value in another type to be accepted and converted (`'5'` → `5`), and use a value that cannot convert (`'abc'`) as that key's rejection input |
| A key accepts `null` by design (`.nullable()`) | Expect `null` to be accepted for that key, and keep the other kinds expecting rejection |
| The schema is strict (`z.strictObject`) | Add a seventh input: a valid object plus one extra key, expecting rejection. It is the only input that exposes the schema relaxed to `z.object`, which strips the key and accepts |
| Two keys legitimately share a value (a `'none'` sentinel) | Leave that value out of the sibling kind for the pair and write the reason beside the key table row |
| A key is free text with no enum or pattern | Keep `null`, the valid value in another type, and deletion; record in the table that the enum kinds have nothing to test |
| A nested object | Loop the leaf keys at every level and assert the issue `path` names the full path (`['a', 'b']`) |
| The exported schema is the public API (no wrapper) | Its `parse` / `safeParse` are the entry points; asserting on them meets step 3 |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Check rejection on one or two keys and call the schema covered | Loop every key through all six kinds | Reproduced: `.catch`, `.optional` and a widened enum on an unsampled key all passed the sampled test |
| Assert only `Schema.safeParse(...)` | Also assert that `parseX` throws and `isX` returns `false` | An inverted guard and a passthrough wrapper passed every schema-level check |
| Use `42` as the "wrong type" for every key | Send the valid value in another type (`[valid]`, `'5'`) | A coercion mutant turns `[valid]` back into a valid value; `42` sent to a regex-checked string is rejected with or without coercion |

## Sources

- https://zod.dev/api — `.catch()`: "Use .catch() to define a fallback value to be returned in the event of a validation error"; `.optional()`: "To make a schema optional (that is, to allow undefined inputs)"; `.nullable()`: "To make a schema nullable (that is, to allow null inputs)"; `.default()`: "If the input is undefined, the default value is eagerly returned"; `z.enum`: "Use z.enum to validate inputs against a fixed set of allowable string values"; strict objects: "To define a strict schema that throws an error when unknown keys are found", while "By default, unrecognized keys are stripped from the parsed result"; coercion: `z.coerce.string(); // String(input)`, `z.coerce.number(); // Number(input)`; object keys: `Dog.shape.name; // => string schema`
- https://zod.dev/basics — "When validation fails, the .parse() method will throw a ZodError instance with granular information about the validation issues"; `.safeParse()` returns "a plain result object"; each issue carries a `path` (`path: [ 'username' ]`)
- https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/ — "When all tests passed while this mutant was active, the mutant survived. You're missing a test for it."
- https://pitest.org/quickstart/basic_concepts/ — "Survived means the mutation was not detected by the covering test."
- Local reproduction 2026-10-08 (Node 26.7.0, zod 4.6.5, `node --test`): a 3-key `z.strictObject` (two disjoint enums, one regex-checked id) behind `parseRecord` / `isRecord`. A test of one key through the schema object passed under 5 mutants (`.catch`, `.optional` and `z.string()` on another key, an inverted `isRecord`, a passthrough `parseRecord`); the every-key loop through the wrappers failed under all 5. A per-kind probe of 12 mutants gave the "Exposes" column and the strict-object row: with `42` as the other-type value, `z.coerce.string()` and `z.strictObject` → `z.object` were exposed by none of the six kinds; `['owner-1']` exposed the coercion and an extra key exposed the relaxed object. The unmutated schema was exposed by no input. With the case and padding split into single-change inputs, a trim-only preprocess accepted only `' gold '` and a lowercase-only one only `'GOLD'`, while the combined `' GOLD '` was rejected by both; `z.coerce.string()` accepted `null` as `"null"`.
- Field case 2026-10-07 (an independent mutation audit of a 13-field zod schema whose tests sampled a few fields): `.default` replaced by `.catch` survived on the 9 unsampled fields — real defects, since `.catch` turns an invalid value into the fallback. After the switch to an every-key loop through the entry points, each of the 7 re-applied surviving mutants failed.
