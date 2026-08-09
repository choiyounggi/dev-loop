---
id: qa-document-verification-spec-document-gates
domain: qa
category: document-verification
applies_to: [general]
confidence: field-tested
sources:
  - https://eslint.org/docs/latest/extend/custom-rule-tutorial
  - https://eslint.org/docs/latest/integrate/nodejs-api
  - https://testing.googleblog.com/2021/04/mutation-testing.html
  - https://www.rfc-editor.org/rfc/rfc2119
  - https://docs.vale.sh/checks/conditional
  - https://docs.vale.sh/checks/occurrence
  - https://github.com/DavidAnson/markdownlint/blob/main/doc/md056.md
  - https://github.com/DavidAnson/markdownlint/issues/1206
last_verified: 2026-08-09
related:
  [
    qa-process-acceptance-criteria,
    testing-quality-tests-that-cannot-fail,
    platforms-environment-unicode-text-matching,
    qa-deliverables-generated-artifacts-as-deliverable-source,
    qa-document-verification-generated-reference-drift-gates,
  ]
---

# Automated Gates on a Specification Document

## When this applies

You are writing or reviewing automated checks (grep/script) that decide whether a
written deliverable — RFC, API spec, schema doc, design doc — satisfies its stated
requirements; a document passed its checklist but a reviewer still found the
requirement unmet; you are fixing gate patterns for a document that is not written yet.

## Do this

1. **Prove the gate on a conforming sample before adopting it.** Run each pattern
   against a sibling document that already satisfies the same spec and require the
   exact expected count (`7` sections, `2` signature mentions). A run against the
   not-yet-written target only shows the file is absent — a typo'd or mis-anchored
   pattern produces the identical result. ESLint's `RuleTester` encodes this pairing:
   it "requires that at least one valid and one invalid test scenario be present."
2. **Prove the gate on a mutated copy.** Plant the exact defect the gate claims to
   catch, require FAIL, and keep the mutant as a permanent self-test — this is
   mutation testing applied to the checker instead of the code.
3. **Check on four axes.** Token existence alone passes documents that violate the spec:

| Axis                  | What the check does                                                                                                     | Defect that a token-existence check misses                                                      |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| Structure             | Parse the table and assert rows, columns, and non-empty cells                                                           | The whole table is deleted while the token survives in a nearby paragraph                       |
| Modality and polarity | Within one sentence scope, assert the requirement is neither negated nor demoted (MUST→SHOULD, 필수→권장/원칙적으로)    | "X is not required" and "X is recommended" both contain every keyword                           |
| Set completeness      | Assert the exact member count of a closed set (`enum has exactly 5 rows`)                                               | One enum row is deleted; the token count is still ≥ 1                                           |
| Cross-reference       | Assert that a statement in one section implies its counterpart elsewhere, and recompute a derived value from its inputs | Two sections disagree, or an `Examples` block silently stands in for the deleted normative rule |

4. **Fail closed when the anchor is missing.** When the section heading, table, or
   derivation input a check needs cannot be located, report FAIL. A check that
   reports "nothing to check" disappears the moment someone rewords the sentence it
   keyed on.
5. **Write patterns against the literal text in the document**, not a remembered
   stem — for non-ASCII text apply [platforms-environment-unicode-text-matching].

## Edge cases

| Case                                                                            | Then                                                                                                                                   |
| ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| No conforming sibling exists (first document of its kind)                       | Author a minimal conforming fixture, run the gate against it, require PASS, and keep the fixture next to the gate                      |
| The gate must exist before the document (plan-first workflow)                   | Take the positive control from the sibling or fixture; treat the target's failing run as evidence of absence only                      |
| The `Examples` section satisfies the check while the normative section does not | Scope the check to the normative section (heading range), so examples cannot stand in for the rule                                     |
| The check counts delimiters (`\|`) as a stand-in for parsing                    | Use a Markdown parser — markdownlint's own MD056 misreports when a pipe appears inside backticks (issue #1206)                         |
| The document deliberately relaxes a requirement                                 | Change the gate and the acceptance criteria in the same commit, and record the relaxation in the PR ([qa-process-acceptance-criteria]) |
| The deliverable is code, not a document                                         | Apply [testing-quality-tests-that-cannot-fail] — same red-run proof, expressed as tests                                                |

## Instead of

| If you are about to                                                    | Do this instead                                                    | Why                                                                                                                          |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------- |
| Adopt a pattern because it exits non-zero against the unwritten target | Run it against a conforming sibling and require the expected count | An absent file fails every pattern; the red run cannot distinguish a correct pattern from a mistyped one                     |
| Treat "the keyword is present" as the requirement being met            | Add the sentence-scoped polarity and modality check                | RFC 2119 makes MUST and SHOULD different requirement levels, so a demotion keeps every keyword while dropping the obligation |
| Assert a token appears at least once for a closed enum                 | Parse the table and assert the exact row count                     | Deleting one member leaves the count ≥ 1, so the gate stays green on an incomplete set                                       |
| Skip a check whose anchor sentence was not found                       | Report FAIL and name the missing anchor                            | A skipped check is indistinguishable from a passed one in the summary line                                                   |
| Verify a cross-section value by matching the number as written         | Recompute it from its inputs and compare                           | Matching the written number passes when both sections were edited to the same wrong value                                    |

## Sources

- https://eslint.org/docs/latest/extend/custom-rule-tutorial — "RuleTester requires that at least one valid and one invalid test scenario be present" — a checker is proved by code that must pass plus code that must fail
- https://eslint.org/docs/latest/integrate/nodejs-api — `RuleTester#run()` takes `valid` and `invalid` case arrays; invalid cases assert the expected error count
- https://testing.googleblog.com/2021/04/mutation-testing.html — inserting faults and requiring failure measures whether checks detect defects; coverage alone does not
- https://www.rfc-editor.org/rfc/rfc2119 — MUST is "an absolute requirement"; SHOULD permits ignoring the item with justification — distinct requirement levels behind the same vocabulary
- https://docs.vale.sh/checks/conditional — "Ensures that the existence of 'first' implies the existence of 'second'" — the cross-reference axis as a first-class check
- https://docs.vale.sh/checks/occurrence — enforces the minimum/maximum number of times a token appears "in a given scope" — count and scope, not bare existence
- https://github.com/DavidAnson/markdownlint/blob/main/doc/md056.md — MD056 flags tables whose rows disagree with the header's column count (structural table checking)
- https://github.com/DavidAnson/markdownlint/issues/1206 — MD056 counts pipes inside backticks as separators: a delimiter count is not a parse

## Field context

Distilled from RFC-authoring sessions in this repo (2026-07): an independent
auditor built 8 tampered copies of an RFC that a 16-gate token-existence
checklist accepted — 5 passed all 16 gates, including a copy whose 5-row `type`
enum had a row removed. After the four axes above plus fail-closed anchors were
added, all 32 tampered copies failed their designated check while the intact
document passed 62/62.
