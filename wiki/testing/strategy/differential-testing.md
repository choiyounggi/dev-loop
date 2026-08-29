---
id: testing-strategy-differential-testing
domain: testing
category: strategy
applies_to: [general]
confidence: verified
sources:
  - https://arxiv.org/pdf/2102.07498
  - https://handwiki.org/wiki/Differential_testing
  - https://arxiv.org/pdf/2212.01748
last_verified: 2026-08-29
related: [testing-strategy-test-level-choice, testing-quality-behavior-not-implementation, testing-quality-differential-run-agreement, testing-quality-minimum-case-set, qa-process-regression-scope]
---

# Verifying Two Implementations of One Specification Against Each Other

## When this applies

Two code paths are supposed to satisfy the same specification and you want the
one to act as the other's oracle: an interpreter and a compiled backend, a
rewritten service beside the one it replaces, v1 and v2 of an API, a fast path
beside a reference path, a cache beside its source of truth. Also when a
migration needs evidence beyond "the new one's own tests pass".

## Do this

1. **Write down the observable classes the contract requires to agree, and the
   ones it permits to differ, before writing the comparison.** The permitted
   list is the load-bearing half: a comparison that includes a permitted
   difference fails for reasons the contract allows, and the team learns to
   ignore the check.

| Class | Verdict |
|-------|-----------------|
| Externally visible result / outcome status | Must agree |
| Order of externally visible effects (calls, writes, emitted events) | Must agree when the spec orders them; otherwise compare as a set |
| Observability signals the contract names (emitted metrics, audit records, error codes) | Must agree |
| Redaction/masking of sensitive values | Must agree |
| Scheduling shape, memory placement, instruction or query selection, operation counts | May differ |
| Wall-clock time and resource usage | May differ — assert budgets separately, never by equality |

2. **Run both paths on the same input in one command and report per class**, so
   a failure names which class diverged rather than only that outputs differed.

3. **Prove the comparison can fail before trusting it**: feed it a seeded
   divergence (disable a rule in one path, change one field) and require a
   specific class to redden. A differential check that has only ever printed
   EQUIVALENT is unmeasured ([testing-quality-tests-that-cannot-fail]).

4. **Normalize only what the contract calls incidental**, and state each
   normalization next to the class table — timestamps, correlation ids,
   iteration order of unordered collections. Every additional normalization
   removes detection power, so each one needs the contract line that permits it.

5. **Generate inputs rather than hand-listing them once the pair is stable.**
   Differential testing's strength is that a second implementation is a much
   stronger oracle than a crash check, so it pays to feed it many inputs; keep a
   committed corpus of the cases that once diverged as the regression floor.

6. **Keep it running past the migration.** The pair is the only oracle that
   catches a change applied to one side; retire the check when you retire the
   second implementation, not when the migration ships.

## Edge cases

| Case | Then |
|------|------|
| The two paths legitimately differ on an input the spec leaves undefined | Add the input to an explicit exclusion list with the spec clause that leaves it open, rather than loosening the comparison for every input |
| One path is much slower, so full-corpus runs are impractical in CI | Run the fast subset per commit and the full corpus on a schedule; record which corpus a green run covered |
| Divergence is found but neither side is obviously wrong | The specification is ambiguous — resolve it in the spec first; a fix applied to whichever side was easier to change makes the pair agree on an undecided question |
| Only one implementation exists so far | The prior version of the same implementation can serve as the reference for behavior-preserving changes; record the reference build id with the results |
| The comparison needs both paths' internal state to line up | Compare at the boundary instead ([testing-quality-behavior-not-implementation]) — coupling the check to internals makes every refactor a false divergence |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Diff the two paths' full output blobs | Compare per declared class and report which class diverged | A blob diff mixes required agreement with permitted difference, so it fails on timings and ids and gets muted |
| Assert that both paths take similar time | Assert each path's own latency budget separately | The contract permits different performance; an equality check on time fails for allowed reasons |
| Declare equivalence from one golden input | Seed a divergence and require the check to catch it, then widen the corpus | A single agreeing case shows the harness ran, not that it discriminates |
| Delete the old implementation as soon as the new one passes its own tests | Keep both and run the differential check through the migration window | The old path is the only oracle that encodes behavior nobody wrote a test for |

## Sources

- https://arxiv.org/pdf/2102.07498 — Park et al., "JEST: N+1-version Differential Testing of Both JavaScript Engines and Specification" — N+1-version differential testing applied across JavaScript engines and the ECMAScript spec
- https://handwiki.org/wiki/Differential_testing — overview of differential testing as a verification method
- https://arxiv.org/pdf/2212.01748 — modern applications of differential testing in compiler and system software verification
