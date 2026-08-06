---
id: testing-quality-stale-artifact-baselines
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://slsa.dev/spec/v1.0/provenance
  - https://jestjs.io/docs/snapshot-testing
  - http://octopusinvitro.gitlab.io/blog/code-and-tech/approval-testing
  - https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/
last_verified: 2026-08-06
related: [testing-quality-differential-run-agreement, testing-quality-tests-that-cannot-fail, testing-quality-harness-reverse-controls, qa-deliverables-generated-artifacts-as-deliverable-source]
---

# A Previously Published Artifact as the "Before" Baseline

## When this applies

You are measuring what a code change did — blast radius, row deltas, a
regression report — and the "before" side is an output file produced by an
earlier run (`estimated.json`, a CSV export, an approved snapshot) rather than a
run of the current code. Also when that file's totals match the current run's
and you are about to treat the comparison as clean.

## Do this

1. **Establish the artifact's generation before comparing anything.** Check for
   schema fields the current code emits, and read their values: a field the
   current code always populates that is absent, or present-but-`None`, dates the
   file to a revision before that field existed. Provenance is "the verifiable
   information about software artifacts describing where, when and how something
   was produced" — an artifact carrying none has to be dated from its schema.

2. **Compare row by row, keyed on the row identity, and require every row to
   match — not the aggregate.** Summation is not injective: two different row
   sets produce the same total whenever their differences cancel. Exclusion and
   rollup rules make this likely rather than rare, because a row the aggregate
   already drops (a parent that rolls up, a cancelled record) can differ freely
   without moving any total.

3. **Read the outcome of that comparison as the decision about what the baseline
   may be used for:**

| Row-level comparison | Then |
|---|---|
| Every row matches and the schema generation matches the current code | Use the artifact as the before-baseline; cite it with its generation |
| Totals match but some rows differ | Discard it as the baseline — the differing rows are a foreign revision's output that would be counted as your change's effect |
| Rows differ only in fields your change is meant to alter | Still discard it: you cannot separate your change's effect from the intervening revisions' inside the same file |
| The artifact predates a field the comparison keys on | Discard it; a comparison keyed on a field one side never had reports every row as changed or every row as new |

4. **When the artifact is not usable, rebuild the before side from the current
   code with only the change under measurement reverted, in memory.** Re-run the
   pipeline on the same input with that one revert applied, and diff the two
   in-process results. This holds every other revision constant, which is the
   property the published file lacks.

5. **Keep the published artifact's headline numbers in a separate, labelled
   section of the report.** They are the record of what was previously
   communicated and are worth stating; merged into the delta table they
   attribute intervening revisions to your change. State the two as "previously
   published: X" and "this change: Y", each with its generation.

6. **Stamp new artifacts with their generation as you produce them** — the
   source revision, the config version, the run timestamp — so the next
   measurement dates the file by reading it rather than by inferring from
   schema. A build's provenance records "the specific git commit that the URI
   resolved to as a dependency"; the same field on a data artifact is what makes
   it reusable as a baseline.

## Edge cases

| Case | Then |
|------|------|
| The artifact is an approved snapshot in the suite (`.approved`, `.snap`) | Regenerating it to match current output is the deliberate act the tooling warns about — "we would need to fix the bug before re-generating snapshots to avoid recording snapshots of the buggy behavior"; review the diff row by row before approving |
| The row identity is not stable across generations (positional index, re-issued ids) | Key on a natural composite (entity id + period) and report rows whose key resolves in one side only as a separate class from rows whose values differ |
| Only aggregates are available (the rows were never published) | Report the aggregate comparison as an aggregate claim and state that row-level agreement was not evaluated — the number is real and its scope is narrow |
| Regenerating the before side is expensive (long pipeline, external data) | Regenerate on the subset the change can reach, chosen by the code paths the revert touches, and mark the rest untested rather than assuming |
| The published artifact and the current run disagree on rows the change cannot reach | Treat that as a finding about the intervening revisions and report it separately; it is evidence about the pipeline, not noise to reconcile away |
| Two implementations were compared and both sides were live runs | Different situation — asymmetric modelled state is the risk there ([testing-quality-differential-run-agreement]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Accept a matching total as evidence the published artifact is the right baseline | Compare row by row on the row key and require every row to match | Sums cancel: a row excluded from the aggregate (rollup parent, cancelled record) can differ freely while the total stays identical |
| Use the newest published artifact because it is the most recent one available | Date it by its schema fields, then rebuild the before side if the generation differs | Recency is not generation — an artifact published after a revision can still be the output of the code before it |
| Reconcile the differing rows by adjusting your delta table | Rebuild the baseline with only your change reverted and re-diff | Adjusting the table encodes another revision's effect as your change's, in the direction that makes the report look consistent |
| Drop the published numbers from the report once the baseline is rebuilt | Keep them in a labelled section beside the new delta | They are what was previously communicated; removing them hides a discrepancy readers already saw |

## Sources

- https://slsa.dev/spec/v1.0/provenance — provenance is "the verifiable information about software artifacts describing where, when and how something was produced", recorded so consumers "can verify that the artifact was built according to expectations"; a build records "the specific git commit that the URI resolved to as a dependency" — the generation stamp step 6 asks for
- https://jestjs.io/docs/snapshot-testing — "If we had any additional failing snapshot tests due to an unintentional bug, we would need to fix the bug before re-generating snapshots to avoid recording snapshots of the buggy behavior"; snapshots are to be committed and reviewed "as you would any other type of test or code in your project"
- http://octopusinvitro.gitlab.io/blog/code-and-tech/approval-testing — on the golden-master framing: "'Golden Master' is not a great name for the snapshot, as it implies that it will never change, and this is not always true"
- https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/ — the reachability–infection–propagation model: a difference is observable only where it propagates to the observed output, which is why a difference confined to an aggregate-excluded row leaves the total unchanged
- Field reproduction 2026-08-05 (manday engine, impact measurement of one regex change): `estimated.json`'s counted-SP total was 211.48, matching the current HEAD run exactly, so the file read as a clean baseline. A row-level comparison found NEWRTB-2182 differing (분석조사/0.19 in the file vs 인프라/0.56 on HEAD). The file was generated before the classifier's lookbehind change — its `dead` field being `None`, which current code always populates, dated it — and the issue was a rollup parent excluded from the counted total, which is why the totals agreed while a row did not
