---
id: testing-quality-synthetic-corpus-measurement-floor
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://en.wikipedia.org/wiki/Pigeonhole_principle
  - https://en.wikipedia.org/wiki/Scientific_control
last_verified: 2026-09-03
related: [testing-quality-harness-reverse-controls, qa-deliverables-quantitative-claims-in-a-published-document, testing-quality-stale-artifact-baselines]
---

# A Synthetic Corpus Whose Generator Parameters Set the Number You Report

## When this applies

You are measuring how a target degrades as N grows ("collisions at N=50",
"conflicts once the corpus reaches 1k") with a generator that draws from a
fixed, finite pool (nouns, ids, templates) and the resulting number is the
basis for a decision — writing an RFC, sizing a fix, ranking work. Also when a
reported number sits exactly on a value the generator's own parameters imply.

## Do this

1. **Before measuring, ask the control question**: "if the target property were
   entirely absent — X never a problem — would this generator produce a
   different number?" When the answer is no, the number is a property of the
   generator's parameters and measures nothing about X.
2. **Compute the arithmetic floor from the generator's parameters** and compare
   the observed value against it:

| Generator shape | Floor | Read the observation as |
|-----------------|-------|-------------------------|
| Sampling with replacement from a pool of size k | distinct ≤ k, so repeats ≥ N − k | A count at or near N − k is pigeonhole arithmetic, not X |
| Sampling without replacement from a pool of size k, N > k | The run cannot exist; the generator has already wrapped or failed | Fix the generator before reading any number |
| Templates combined from p × q parts | distinct ≤ p·q | The same rule with k = p·q |

3. **Run a negative control**: the same N under a condition where X is known
   to be fine (a target with the mechanism disabled, or a generator pool large
   enough that the floor is 0), and require the number to move. A number that
   holds still measures the generator ([testing-quality-harness-reverse-controls]).
4. **Publish the pool size and sampling distribution beside every reported
   number** so a reader can recompute the floor; state whether the observed
   value exceeds it and by how much.
5. **Size the pool so the floor sits below the effect you are looking for at
   every N you test**; a pool of 10 cannot say anything about N ≥ 20.

## Edge cases

| Case | Then |
|------|------|
| Two reported values both equal N − k exactly | Both are the floor; cite neither as evidence and re-run with a larger pool |
| No known-good target exists for the control | Report the analytic floor next to the number and treat only the excess over it as signal |
| The generator uses a real-world distribution (Zipf over names) | The floor is no longer N − k; compute the expected repeats under that distribution by simulation with X absent, and use that as the control |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Publish "N=50 → 40 collisions, so X breaks at scale" | Publish the pool size with it and show 40 exceeds N − k | A pool of 10 forces ≥ 40 repeats at N = 50 whether or not X works |
| Base an RFC's urgency on a synthetic count alone | Run the control with X absent and cite the difference between the two runs | A number that does not move when the failure mode is absent measures the generator |

## Sources

- https://en.wikipedia.org/wiki/Pigeonhole_principle — "if n items are put into m containers, with n > m, then at least one container must contain more than one item" (general reference)
- https://en.wikipedia.org/wiki/Scientific_control — a negative control that produces the same outcome as the treatment shows the treatment had no measurable effect (general reference)
- Reproduction 2026-09-03 (python3, in-memory): sampling with replacement from a fixed pool of k = 10 gave N = 30 → distinct 9, repeats 21 (floor 20); N = 50 → distinct 10, repeats 40 (floor 40) — `repeats = N − distinct ≥ N − k` holds regardless of the target
- Field evidence 2026-08-25 (linkly, task t117): a collision benchmark drew from a fixed pool of 10 nouns and reported N = 30 → 20 and N = 50 → 40 collision events — exactly N − 10 — and those numbers were the only basis for deciding whether to write an RFC
