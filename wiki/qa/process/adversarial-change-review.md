---
id: qa-process-adversarial-change-review
domain: qa
category: process
applies_to: [general]
confidence: field-tested
sources:
  - https://github.com/EveryInc/compound-engineering-plugin
  - https://cwe.mitre.org/data/definitions/88.html
  - https://doc.rust-lang.org/cargo/commands/cargo-test.html
  - https://doc.rust-lang.org/cargo/reference/config.html
last_verified: 2026-09-04
related: [qa-process-evaluating-review-feedback, qa-process-regression-scope, qa-process-post-release-verification]
---

# Constructing Failure Scenarios for a High-Risk Diff

## When this applies

Reviewing a diff that is large (≥50 changed lines) or touches auth, payments,
data migrations, or external-API consumption; a checklist review returned
nothing on a change whose blast radius is high; deciding how deep a review
must go before merge.

## Do this

1. Set the depth from the diff, before reviewing:

| Diff | Review depth |
|------|--------------|
| <50 changed lines, no high-risk domain | Standard checklist review only |
| 50–199 lines, or one minor risk signal | Techniques 1–2 below |
| ≥200 lines, or any auth/payment/migration/money path | All four techniques, with multi-step traces |

2. Construct scenarios with the four techniques — each produces concrete
   inputs traced through the code, not pattern labels:

| Technique | Construct |
|-----------|-----------|
| 1. Assumption violation | List the diff's data-shape, timing, ordering, and value-range assumptions; build one violating input per assumption and trace it through |
| 2. Composition failure | Pair components that are correct alone: contract mismatches at their boundary, shared state mutated without coordination, thrower/catcher error-type divergence |
| 3. Cascade construction | Chain failures across steps: timeout → retry → added load → more timeouts; partial write → wrong downstream decision → compounding corruption; recovery that fails (a retry duplicating a side effect, a rollback stranding state, a circuit breaker blocking its own recovery probe) |
| 4. Abuse cases | Legitimate-looking misuse: the 1000th identical submission, a request landing mid-deploy or mid-cache-invalidation, two actors racing one resource, inputs walking the exact boundary (max size, exactly at the rate limit) |

3. Name each finding as a scenario — input/state → consequence ("payment
   timeout triggers unbounded retry loop") — a scenario can be checked and
   reproduced; a pattern label cannot.
4. Route adversarial findings to human judgment rather than autofix, and
   confirm a scenario (run it, or trace it with line references) before it
   blocks a merge; label unconfirmed scenarios with their confidence.

## Edge cases

| Case | Then |
|------|------|
| A scenario needs prod-only conditions to trigger | Record it as a post-release monitoring item with the signal to watch ([qa-process-post-release-verification]) |
| All four techniques return nothing on a high-risk diff | State the null result with what was searched (techniques × assumptions listed) — a stated null and an omitted one read the same to the merge decision, so state it |
| The diff is high-risk and also very large | Partition by risk surface (auth paths first, then money paths) and run the techniques per partition, so depth lands where the blast radius is |
| Per-task lens reviews all passed on a diff that builds a command, query, path, or argv from user input through an allowlist | Task an integration-level review explicitly with technique 4 (abuse cases): construct a string that satisfies the allowlist while doing something the allowlist should have forbidden. The coordinator, not the reviewer, then reproduces the candidate string directly against the real validator before treating it as a finding — a contract gap (e.g. no rule for a trailing or extra token) passes every task-scoped review because each task correctly implemented its own contract; construction-and-reproduction, not reading the code, is what surfaces the gap |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Clear a payment/auth diff with a style-and-correctness checklist alone | Run the four techniques at the depth the table sets | Checklists find known single-point patterns; constructed scenarios find interactions between correct-looking parts |
| Report "potential race condition" as a finding | Construct the interleaving: which two operations, which shared state, what wrong outcome | An unconstructed finding cannot be verified, prioritized, or fixed |
| Accept "all task-scoped lenses passed" as clearance for an allowlist, argv-builder, or path-assembly merge | Task the integration review with constructing a bypass string, then reproduce that exact string yourself against the real validator | Task review checks "built to contract"; an allowlist's gap is a hole in the contract itself, which a faithful per-task implementation still carries and which construction plus reproduction exposes |
| Hand a reviewer's proposed bypass string straight to a worker as a confirmed defect | Reproduce it yourself first; reject examples that fail reproduction | A reviewer's attack string can itself be wrong (e.g. it violates the sink's own syntax) — un-reproduced, it sends a worker chasing a threat that does not exist |

## Sources

- https://github.com/EveryInc/compound-engineering-plugin — adversarial-reviewer persona: depth calibration by size/risk, the four scenario-construction techniques, scenario-oriented finding titles, advisory-to-human routing; field-tested in the plugin's shipped review workflow
- https://cwe.mitre.org/data/definitions/88.html — CWE-88, "Improper Neutralization of Argument Delimiters in a Command ('Argument Injection')": untrusted argument-delimiting input gains the command unintended arguments
- https://doc.rust-lang.org/cargo/commands/cargo-test.html — `--manifest-path` selects the package defined by that manifest, so an out-of-repo manifest path redirects package selection there
- https://doc.rust-lang.org/cargo/reference/build-scripts.html — Cargo compiles a package's build script "just before a package is built" and "will then run the script" — `cargo test` runs `build.rs` for the selected package
- https://doc.rust-lang.org/cargo/reference/config.html — `--config KEY=VALUE`: "The argument should be in TOML syntax"; an unquoted bare value is not valid TOML, which is why a naive second bypass attempt using an unquoted path fails reproduction
- Field evidence 2026-08-31 (measured in a linkly-crew orchestration run): after 4/4 task-scoped lens reviews passed, an integration review proposed `cargo test --manifest-path=<path outside the repo>`; the coordinator reproduced it directly — the string passed the allowlist's `vet()`, exited 0 (definition-of-done "passed"), and ran the out-of-repo `build.rs`. The reviewer's second example, `--config build.rustc=/path`, failed reproduction (TOML requires quoting the value; the allowed character set excludes `"`) and was rejected rather than escalated
