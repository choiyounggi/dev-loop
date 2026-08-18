---
id: qa-deliverables-quantitative-claims-in-a-published-document
domain: qa
category: deliverables
applies_to: [general]
confidence: verified
sources:
  - https://google.github.io/styleguide/docguide/best_practices.html
  - https://www.writethedocs.org/guide/writing/docs-principles/
last_verified: 2026-08-06
related:
  [qa-deliverables-generated-artifacts-as-deliverable-source, qa-document-verification-spec-document-gates, testing-quality-spec-artifact-checks]
---

# Numbers in a Document About to Be Published Outside the Team

## When this applies

You are about to publish or hand out a hand-maintained document that describes
the repository — README, landing page, launch post, architecture overview — and
it states counts: tests, rules, supported types, grammar productions, endpoints,
documents in a given state. Also when someone reports that one number in such a
document is wrong.

## Do this

1. **Enumerate every quantitative claim in the document first, then verify.**
   Extract them as a list before checking any of them
   (`grep -on '[0-9][0-9,]*' README.md` as the starting sweep), so the work is
   bounded by the document and not by which number was noticed.
2. **Recompute each one from the source by a command, and record the command
   next to the number.** A claim is verified when a reader can re-run the check:

| Claim shape | Recompute with |
|-------------|----------------|
| Test count | The suite's own summary line from a full run, not a per-file sum |
| Rules / cases / mutations in a harness | A count over the harness's own table or registry, not the prose that describes it |
| Kinds, variants, enum members | The schema or type definition — count the branches (`anyOf`, enum members), because the implementation and the spec can disagree |
| Grammar productions | A count over the grammar file's production separators |
| Documents in a state ("twelve Accepted RFCs") | The linter or index that already computes it |

3. **Treat a reported wrong number as a sample, not the defect.** When one
   claim is stale, verify the rest in the same pass — the mechanism that let one
   drift (no test asserts it) applies to all of them equally.
4. **Fix the source of drift where the number is load-bearing**: assert it in
   the suite, or generate the line from the artifact
   ([qa-deliverables-generated-artifacts-as-deliverable-source]).
5. **Record the date and commit the numbers were computed at** in the document,
   so the next reader can tell freshness from a glance instead of re-deriving.

## Edge cases

| Case | Then |
|------|------|
| The count is non-deterministic across runs (parallel collection, generated cases) | State it as the run's reported value with the command, or state a floor ("1200+"); a bare exact number that moves between runs cannot be verified by anyone |
| The spec and the implementation give different counts for the same concept | Publish the one matching the artifact the sentence is about, and name which — a README sentence about the schema counts schema branches, not implementation branches |
| The number appears in more than one document (README, its translation, a landing page) | Fix every copy in the same change; a translated README drifts independently and is the copy most often missed |
| Verifying a claim requires a build that does not run on this machine | Mark the claim with the environment it was measured in rather than dropping it, and say what is untested here |
| The document is generated | Re-run the generator instead of editing the number ([qa-deliverables-generated-artifacts-as-deliverable-source]) |
| The number is decorative ("dozens of tests") | Leave it; the rule covers claims a reader could check and find false |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Correct the one stale number that was reported and publish | Enumerate and recompute every number in the document in the same pass | Counts drift silently because no test asserts them; the reported one is the one someone happened to check, not the only one wrong |
| Take a number from an adjacent document or an earlier session's summary | Recompute from the source now | The adjacent document has the same drift mechanism and no check, so two documents agreeing is not corroboration |
| Sum per-file test counts to get a suite total | Read the suite runner's own summary line | Per-file sums miss collection errors, skips, and dynamically generated cases |
| Publish "N tests" as a durable fact | Publish it with the command and date that produced it | An unattributed count cannot be re-verified and becomes stale the next commit |

## Sources

- https://google.github.io/styleguide/docguide/best_practices.html — "Dead docs are bad. They misinform, they slow down, they incite despair in engineers and laziness in team leads"; "Change your documentation in the same CL as the code change"
- https://www.writethedocs.org/guide/writing/docs-principles/ — sources of truth must be "clearly defined and disjoint" so the same fact is not maintained in parallel
- Field incident 2026-08-06 (`linkly`, pre-launch README audit): of nine quantitative claims, five were stale — tests 386→1209, harness mutations 53→77, IR node kinds 20→21 (counted as JSON Schema `anyOf` branches), EBNF productions 51→58, "Twelve Accepted" RFCs→13. One had been reported; the other four were found only because the whole document was swept. Re-checked on 2026-08-06: `grep -on '[0-9]\+ tests\|[0-9]\+ node kinds\|[0-9]\+ productions' README.md` returns the corrected 1209 / 21 / 58
- Field observation 2026-08-06 (same repo): back-to-back full-suite runs on one commit reported 1195 then 1209 tests — an exact published test count is only reproducible when the collection is deterministic
