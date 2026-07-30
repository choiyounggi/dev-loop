---
id: testing-docs-as-spec-document-conformance-checks
domain: testing
category: docs-as-spec
applies_to: [general]
confidence: verified
sources:
  - https://eslint.org/docs/latest/integrate/nodejs-api#ruletester
  - https://docs.semgrep.dev/writing-rules/testing-rules
  - https://testing.googleblog.com/2021/04/mutation-testing.html
  - https://json-schema.org/understanding-json-schema/reference/object
  - https://github.github.com/gfm/#tables-extension-
last_verified: 2026-07-30
related: [testing-quality-tests-that-cannot-fail, testing-quality-minimum-case-set, qa-process-acceptance-criteria]
---

# Checking a Document Against Its Spec

## When this applies

You are writing or reviewing an automated check whose subject is a **document** —
an RFC, API spec, schema doc, mapping table, ADR — and the check decides whether
that document satisfies stated requirements (grep gate, parse script, CI step).
Includes checks authored before the document they will judge exists.

## Do this

1. **Give every check two controls, and run both before adopting it.** This is the
   rule linters apply to their own rules: ESLint `RuleTester` requires a `valid`
   and an `invalid` array; Semgrep rule tests require `ok:` (true negative) and
   `ruleid:` (true positive) lines. A check that has run against only one of the
   two is unproven.

| Control | Input | Required result | What it proves |
|---------|-------|-----------------|----------------|
| Positive | A document that already conforms — the sibling spec written to the same template | PASS, with the exact expected count (`7` sections, `2` matches), not merely exit 0 | The pattern, anchors, and escaping are correct |
| Negative | A copy of that conforming document with exactly one requirement broken | FAIL, naming that requirement | The check detects the defect it owns |

2. **When the target document does not exist yet, take the positive control from a
   conforming sibling.** A missing file makes every pattern red, so red is
   evidence about the file's absence, not about the pattern. A typo'd or
   mis-anchored pattern produces the same red and becomes a gate that fails
   forever once the document is written.

3. **Split the requirement into axes and give each axis its own check and its own
   negative control** — one mutation that breaks only what that check owns:

| Axis | The check | Its negative control |
|------|-----------|----------------------|
| Structure | Parse the table: row count, column count per row, no empty cells | Delete the whole table, leaving the surrounding prose intact |
| Normative modality | The required/optional column values and the obligation sentence in prose | Flip one `required` cell to `optional` |
| Enumeration completeness | The enum table has exactly N rows, one per canonical case | Delete one row |
| Cross-reference | Every identifier cited here resolves in the document it points at | Replace one identifier with a nonexistent one |

4. **Pair every coverage check with a value-validity check.** Coverage answers
   "is there a row for each required item"; validity answers "is each cell's value
   a member of the canonical enum / schema / id set". JSON Schema draws the same
   line: `required` asserts key presence and constrains no value. Run each as a
   separate check so the failure message says which one broke.

## Edge cases

| Case | Then |
|------|------|
| The check parses Markdown table rows | Split on unescaped pipes — `re.split(r"(?<!\\)\|", row)` — then unescape `\|` in each cell before counting. GFM permits a literal pipe in a cell when escaped, including inside code spans (`create\|update\|delete`) |
| No conforming sibling exists (first document of its kind) | Hand-write a 10-line fixture that satisfies the requirement, use it as the positive control, and keep it next to the check |
| A negative control passes | The check is decoration: fix it against that mutation, then re-run both controls before adopting |
| Prose and table state the same requirement | Check the table (machine-readable, load-bearing) and cross-check that the prose sentence exists; a prose-only match is not evidence the table survived |
| The subject is code, not a document | The general mutate-and-require-red rule → [testing-quality-tests-that-cannot-fail] |
| Requirements are still being drafted | Fix the requirement wording first → [qa-process-acceptance-criteria]; a check cannot be more precise than the requirement it encodes |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Accept a pattern because it exits non-zero against the not-yet-written document | Run it against a conforming sibling and require the exact expected count | Absence makes every pattern red, a typo'd one included; the gate then fails forever once the document lands |
| Verify a requirement with one token-presence grep | Add the structural and value checks for that requirement, each with its own negative control | The token survives in prose after the table it came from is deleted, so the gate passes on a document that lost the requirement |
| Read a green coverage check ("every rule has a row") as "the mapping is verified" | Add a value-validity check: each cell's value must exist in the canonical enum/id set | Set equality on row names is blind to cell contents — a typo'd, empty, or swapped value keeps coverage at 100% |
| Prove an `Examples` section demonstrates a rule and stop there | Check the normative statement itself (the required/optional cell, the obligation sentence) | Examples keep matching after the rule that mandates them is relaxed, so the example check reports green on a weakened spec |
| Split Markdown rows with `split("\|")` | Split on unescaped pipes, then unescape each cell | `\|` is legal cell content, so a naive split reports a correctly rendering row as over-wide and buries real breakage in false alarms |

## Sources

- https://eslint.org/docs/latest/integrate/nodejs-api#ruletester — `RuleTester` takes `valid` and `invalid` case arrays; invalid cases must assert the errors the rule is expected to produce
- https://docs.semgrep.dev/writing-rules/testing-rules — rule tests annotate true positives (`ruleid:`) and true negatives (`ok:`) in the same test file
- https://testing.googleblog.com/2021/04/mutation-testing.html — inserting a fault and requiring the check to fail measures detection; coverage alone does not
- https://json-schema.org/understanding-json-schema/reference/object — `required` lists properties that must be present and places no constraint on their values
- https://github.github.com/gfm/#tables-extension- — cells are separated by pipes; "include a pipe in a cell's content by escaping it, including inside other inline spans"
