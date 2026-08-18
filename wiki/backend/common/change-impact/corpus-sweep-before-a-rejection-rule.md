---
id: backend-common-change-impact-corpus-sweep-before-a-rejection-rule
domain: backend
category: change-impact
applies_to: [general]
confidence: verified
sources:
  - https://github.com/AriPerkkio/eslint-remote-tester
  - https://github.com/rust-lang/rust-clippy/blob/master/lintcheck/README.md
  - https://github.com/rust-lang/crater
last_verified: 2026-08-07
related: [backend-common-change-impact-call-site-enumeration, backend-common-api-design-unenforced-declarations, testing-quality-guard-shape-vs-consequence, qa-process-regression-scope]
---

# Bounding a New Rejection Rule Against the Existing Corpus

## When this applies

You are adding a rule to a compiler, linter, parser, schema validator, or repo
gate that will start rejecting input the tool has been accepting silently, and
the existing corpus — repo sources, fixtures, shipped examples, downstream
configs — has to keep passing. Also when such a rule landed and turned red on
inputs nobody had classified as defective.

Deciding whether unimplemented declarative input should reject, warn, or be
ignored at all → [backend-common-api-design-unenforced-declarations]. A shape
guard that is already red on one legitimate artifact →
[testing-quality-guard-shape-vs-consequence].

## Do this

1. **Implement the accept/reject predicate once as a throwaway script, outside
   the production tree.** Thirty to eighty lines that read one input and print a
   verdict. It needs neither the real IR, the real diagnostic plumbing, nor the
   real config surface — only the same decision.

2. **Run it over every input the shipped rule will meet, and put two things in
   the plan: the reject count and the full list of rejected paths.** The list is
   the reviewable artifact; a bare count cannot be checked by anyone.

3. **Require that list to equal the set already known to be defective before
   writing production code.** An extra entry is a false positive and the rule's
   boundary is wrong. A missing entry means the rule does not cover the case
   that motivated it. Both verdicts are cheap while no production code exists.

4. **State the enumeration method next to the count** — "148 sources (40 `.lnpl`
   files + 108 triple-quoted inline programs under `tests/`)". An unstated basis
   is what makes a partial index invisible
   ([backend-common-change-impact-call-site-enumeration]).

5. **Re-run the same script after the production rule lands and require the two
   verdict sets to agree.** A divergence there is a wiring defect in the real
   rule, not a rule-boundary question, and the sweep is what separates them.

| Case | Do |
|------|----|
| The rule has several independent clauses | Sweep each clause as its own pass and report per-clause counts; one aggregate number hides both a clause that matches nothing and a clause that matches everything |
| Corpus inputs exist in more than one form (files on disk, strings embedded in tests, generated fixtures) | Enumerate each form as a separate pass with its own count — a single-form sweep is a partial index |
| The corpus is not yours (published configs, downstream repos, a package registry) | Sweep a sample with the same predicate, report the sample size, and ship the rule as a warning level first |
| The rejected set is legitimate and large | The change is a narrowing you cannot land at once: put the rule behind an opt-in strictness level and migrate the corpus under it |

## Edge cases

| Case | Then |
|------|------|
| Inputs are assembled at runtime (concatenation, `.replace()`, templating) rather than stored literally | A text sweep cannot index them — enumerate the assembly sites by hand, verify each one individually, and record them in the plan as the sweep's stated blind spot |
| The sweep rejects zero inputs | Treat it as unproven, not clean: feed it one input you know the rule must reject and require a reject before believing the zero ([testing-quality-checks-that-cannot-pass]) |
| The corpus contains the bug's own reproduction case | It is supposed to be rejected — list it in the plan as an expected reject instead of exempting it |
| The tool's own suite carries deliberately invalid inputs | Exclude negative-test fixtures by location and name the excluded directory next to the count |
| The throwaway predicate and the landed rule disagree on an input | Re-run both on that input and fix whichever one contradicts the accepted list in the plan; the plan's list is the decision of record |
| The corpus is large enough that a full pass is slow | Keep a cheap textual prefilter and run the real predicate only on what it matched — the reported set is still the full-corpus answer |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Implement the rule in the production tree and let the test suite report what breaks | Sweep with a throwaway predicate and settle the boundary before writing production code | A red suite does not say whether the rule is wrong or the input was always defective — and once the code exists, the cheap resolution is to loosen the rule |
| Cite "the suite is still green" as evidence the rule is non-breaking | Cite the reject count and the rejected-path list from a full-corpus sweep | The suite exercises the inputs it happens to carry; the corpus is the set the rule will actually meet |
| Sample a few representative inputs | Run every input through the predicate | Boundaries fail on the unusual input, which is the one sampling drops |
| Add an exemption for the legitimate input the rule rejected | Narrow the rule's condition until the reject list matches the known-defective set | An exemption list is the rule conceding its boundary is wrong, one input at a time ([testing-quality-guard-shape-vs-consequence]) |

## Sources

- https://github.com/AriPerkkio/eslint-remote-tester — the questions a corpus run answers are "Does the rule report the intended patterns? Does the rule falsely mark valid patterns as errors?", and "the AST of Javascript and Typescript can cause very unexpected results it is not enough to test the rule only against unit tests and a small amount of repositories"; its comparison mode reports "the exact changes in ESLint reports their code changes introduced"
- https://github.com/rust-lang/rust-clippy/blob/master/lintcheck/README.md — lintcheck "Runs Clippy on a fixed set of crates read from `lintcheck/lintcheck_crates.toml` and saves logs of the lint warnings into the repo. We can then check the diff and spot new or disappearing warnings" — the recorded, diffed verdict list is the deliverable, not the count
- https://github.com/rust-lang/crater — "Crater is a tool to run experiments across parts of the Rust ecosystem. Its primary purpose is to detect regressions in the Rust compiler, and it does this by building a large number of crates, running their test suites and comparing the results between two versions of the Rust compiler" — the same measurement at ecosystem scale, run before a potentially breaking change lands
- Field evidence 2026-08-07 (`linkly` #53, Python): three draft rejection rules for a DSL compiler were implemented first as a throwaway `sweep.py` and run over 148 sources (40 `.lnpl` files plus 108 triple-quoted inline programs in tests) → 2 rejects, both the QA probes the issue had named. The sweep caught a false positive in the first draft at plan time: it rejected the legitimate case where a guard owns its own block. Fixtures assembled with `.replace()` were invisible to the text sweep, so those 5 sites were confirmed by hand — the blind spot from the edge-case table, observed rather than hypothesized
- The pre-implementation ordering (throwaway predicate before production code) is the field-tested refinement of this page; the corpus-sweep-and-diff method itself is the practice the three tools above implement
