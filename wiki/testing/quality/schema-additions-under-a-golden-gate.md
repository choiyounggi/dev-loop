---
id: testing-quality-schema-additions-under-a-golden-gate
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://json-schema.org/understanding-json-schema/reference/conditionals
  - https://json-schema.org/understanding-json-schema/reference/object
  - https://json-schema.org/draft/2020-12/json-schema-core
  - https://pitest.org/quickstart/basic_concepts/
last_verified: 2026-08-04
related: [testing-quality-spec-artifact-checks, testing-quality-tests-that-cannot-fail, testing-quality-harness-reverse-controls, qa-document-verification-spec-document-gates]
---

# Adding a Case to a Format Whose Only Gate Mutates a Golden Example

## When this applies

You are adding a node kind, variant, discriminator value, or field to a document
format (an IR, a JSON Schema, a spec artifact), and the format's only automated
gate builds its negative cases by mutating one committed golden example. Also
when a schema change lands and the gate — or the whole suite — comes back green.

## Do this

1. **Check whether the golden example contains an instance of the new kind
   before reading the gate's verdict.** When it does not, every mutant derived
   from that golden leaves the new branch untouched, so the green run reports on
   the old shapes only. JSON Schema states the mechanism for conditional
   branches: "If `if` is invalid, `else` must also be valid (and `then` is
   ignored)" — a branch keyed on the new kind is never applied to an instance
   that lacks it. The same gap has a name in mutation tooling: PIT's **No
   coverage** is "the same as **Survived** except there were no tests that
   exercised the line of code where the mutation was created".

2. **Commit a minimal conforming fixture that contains the new kind, next to the
   gate, and register it as a must-pass input.** Build it to exercise the new
   branch only — the smallest document the schema accepts that reaches it.

3. **Add one negative per keyword the new branch introduces**, mutating only
   what that keyword owns:

| Keyword the new branch adds | Negative that must redden the gate |
|-----------------------------|------------------------------------|
| `required` (a new mandatory field) | Delete that field from the new fixture |
| `type` | Replace the field's value with another JSON type |
| `enum` / `const` (the discriminator) | Replace the value with one absent from the set |
| `additionalProperties: false` | Add one property the branch does not declare |
| A cross-document id that must resolve | Repoint the id at a target that does not exist |

4. **Restore each negative one at a time and observe the gate go red.** A
   negative that has never been seen failing is an assertion about the gate, not
   a control ([testing-quality-tests-that-cannot-fail]).

5. **Constrain the new branch before writing its negatives.** With
   `additionalProperties` omitted, "By default any additional properties are
   allowed", and `properties` alone mandates nothing — "the properties defined
   by the `properties` keyword are not required". A branch carrying neither
   `required` nor `additionalProperties: false` has no negative to write,
   because no instance of the new kind can fail it.

6. **Judge the rest of the suite by whether it reads the schema at all.**
   Enumerate the tests that load the schema file by name; when that count is
   zero, a full green suite is unrelated to the change and is not evidence for
   it. Report the two verdicts separately.

## Edge cases

| Case | Then |
|------|------|
| The gate is a real mutation tool (PIT, Stryker) rather than a hand-rolled script | Same gap under its own label: read **No coverage** / **Survived** on the new branch as the missing fixture, not as a missing rule |
| The golden example is generated rather than hand-written | Regenerate it from a generator input that includes the new kind and commit the regenerated output as the fixture, so a generator change reddens the gate |
| The new kind is valid only in a nested position (inside a specific parent node) | Place the fixture's instance at a position the schema actually admits; a top-level instance of a nested-only kind tests the parent's rejection path instead |
| You add the new kind to the existing golden instead of a separate fixture | Re-run every pre-existing negative afterwards and require each one's prior verdict; enlarging the golden changes the input all of them mutate |
| The gate only checks that the document parses, never validating it against the schema | The addition has no gate — say so, and add schema validation before adding negatives |
| The new branch is `unevaluatedProperties`- or `$ref`-based rather than inline | Mutate through the reference: change the target subschema's own keyword, and require the referring branch to redden |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add the schema branch, run the gate, and read green as "the new kind is validated" | Commit a fixture containing the new kind, then one negative per keyword the branch adds | Mutants of a golden that lacks the new kind never reach the new branch, so the verdict predates the change |
| Cite "the full test suite passes" as coverage for a schema change | Enumerate the tests that read the schema file and report that count first | A suite in which nothing loads the schema is unaffected by any edit to it |
| Write one negative for the whole new branch | Write one per keyword and require the branch to redden for each | One red proves some keyword fires, not that each keyword the branch added is enforced |
| Trust `properties` on the new branch to reject a malformed instance | Add `required` for the mandatory fields and `additionalProperties: false` | Both omitted defaults are permissive: extra properties are allowed and declared properties are optional |

## Sources

- https://json-schema.org/understanding-json-schema/reference/conditionals — "If `if` is invalid, `else` must also be valid (and `then` is ignored)"; a conditional branch is not applied to an instance that fails its `if`
- https://json-schema.org/understanding-json-schema/reference/object — "By default any additional properties are allowed"; "By default, the properties defined by the `properties` keyword are not required"
- https://json-schema.org/draft/2020-12/json-schema-core — subschema applicators "MUST NOT impact the results of sibling subschemas"; "A JSON Schema MAY contain properties which are not schema keywords. Unknown keywords SHOULD be treated as annotations" — a misspelled keyword in a new branch is ignored rather than rejected
- https://pitest.org/quickstart/basic_concepts/ — "**Survived**: the mutation was not detected by the covering test"; "**No coverage**: the same as **Survived** except there were no tests that exercised the line of code where the mutation was created"
- Field observation 2026-08-04 (`linkly-t1-spec-notation`, Python): the only schema gate over `*.lir.json` was `scripts/validate_ir.py --self-test`, whose three negatives were all `copy.deepcopy` mutations of `examples/login.lir.json`; `grep -rln "lir.schema\|jsonschema" impl/tests/` returned zero of 447 tests, so neither the gate's green run nor the suite's constrained any node kind absent from that one example
