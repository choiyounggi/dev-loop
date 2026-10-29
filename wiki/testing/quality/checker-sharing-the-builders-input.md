---
id: testing-quality-checker-sharing-the-builders-input
domain: testing
category: quality
applies_to: [general]
confidence: field-tested
sources:
  - https://discovery.ucl.ac.uk/1471263/
  - https://github.com/kenjudy/pdca-agentic-coding-framework/issues/181
  - https://pitest.org/quickstart/basic_concepts/
last_verified: 2026-10-29
related: [testing-quality-cross-component-invariant-via-shared-helper, testing-quality-spec-artifact-checks, testing-quality-harness-reverse-controls, qa-document-verification-spec-document-gates]
---

# A Fidelity Checker That Reads the Builder's Own Manifest or Ranges

## When this applies

A document or artifact is assembled from pieces of sources (line ranges,
fragments listed in a manifest, a ledger of what to copy and what to drop),
and the checker that proves it faithful reads that same manifest or ledger;
you are about to record the checker's green run as proof of fidelity.

## Do this

1. **Name what the shared-input check proves.** A checker that replays the
   builder's manifest proves the manifest was applied. A wrong range or a wrong
   cut sits in both copies, so builder and checker agree and the check stays
   green. Report it as "manifest applied", not "faithful to the sources".
2. **Add at least one check whose expected value does not come from the
   manifest.** Pick from this table by what the artifact has:

| The artifact has | Independent check |
|------------------|-------------------|
| Source ranges cut from prose | Require every range to start and end on a unit boundary (blank line, heading, table row, end of a fenced or quoted block), and require every non-boundary line next to a range to be listed as a deliberate drop |
| A separate ledger of which source lines are kept or excluded | Check every source line against that ledger alone (each line is used once or excluded with a reason), without reading the manifest |
| Sibling artifacts built independently from the same sources | Compare the shared spans byte for byte with the sibling |
| Structural markers around each span (heading before, end of block after) | Rebuild the expected text from those markers once, then compare |

3. **Mutate the shared input, not only the output.** Shorten one range in the
   manifest, delete one drop declaration from the ledger, and require red. A
   mutant of the output alone is caught by the manifest replay and so cannot
   show whether the independent checks work.
4. **Give each mutant an expected set of failing checks** and require exactly
   that set, per [testing-quality-spec-artifact-checks]. A mutant that reddens
   only the manifest replay shows the independent checks are blind to it.

## Edge cases

| Case | Then |
|------|------|
| A range legitimately ends mid-paragraph (a declared cut after a sentence) | Record the cut in the ledger with its anchor text, and have the boundary check accept that line only when the ledger names it |
| Builder and checker both hard-code the same ranges (no shared file) | Treat the two copies as one shared input; the same mutant (shortening both) must still go red through an independent check |
| The checker runs many times over a pinned input file | Pin the file by hash, and keep at least one independent check that does not read it, so a wrong pinned value cannot pass every run |
| An auditor re-derives the manifest decisions from the sources | Count that as the independent check for the decisions it re-derived, and record which ones it covered |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Cite "fidelity check: N/N pass" from a checker that reads the build manifest | Add a boundary, ledger or sibling check and cite its result beside the replay | Two copies of one wrong range agree with each other |
| Prove the checker with mutants of the built document only | Also mutate the manifest or ledger and require an independent check to go red | A wrong input is the defect the replay cannot see |

## Sources

- https://discovery.ucl.ac.uk/1471263/ — Barr, Harman, McMinn, Shahbaz, Yoo, "The Oracle Problem in Software Testing: A Survey" (IEEE TSE 2015): an oracle must tell correct behaviour apart from incorrect behaviour; a check whose expected value comes from the build input cannot tell a wrong input apart
- https://github.com/kenjudy/pdca-agentic-coding-framework/issues/181 — recorded rule: "Oracle: where does the expected value come from, and is that source independent of the code under test?"
- https://pitest.org/quickstart/basic_concepts/ — a mutant that survives is not detected by the covering tests; the shared-input mutant is the one to seed
- Field evidence 2026-10-27 (RFC consolidation run, task t72): an auditor shortened a source range from 207-301 to 207-300 in both the spec and the built document; the completeness checker returned rc=0 while the section's last sentence was missing
- Field evidence 2026-10-29 (same project, task t2): a ledger mutant that removed the drop declaration for one source line failed only once a unit-boundary check was added ("ends inside a unit (line 173 is text)"); before it, the plan's range passed silently
- Field evidence 2026-10-29 (same project, task t7): a manifest-driven check plus a ledger-only check plus a byte comparison with merged sibling documents; 12 mutants each failed exactly their expected set of checks
