---
id: qa-exploratory-override-control-pairs
domain: qa
category: exploratory
applies_to: [general]
confidence: verified
sources:
  - https://pydantic.dev/docs/validation/latest/concepts/models/
  - "Field reproduction (lnpl 0.2.0, 2026-08-05): 5-run override matrix flat under bare key names, exit 0, no warning; canonical dotted name flipped the guarded step — raw traces archived with the QA case"
last_verified: 2026-08-05
related: [qa-exploratory-guard-true-path-coverage, testing-quality-harness-reverse-controls, testing-quality-tests-that-cannot-fail, qa-exploratory-lowered-declaration-survival]
---

# A Control Pair Before Trusting a Value-Override Matrix

## When this applies

You are measuring branch/guard behavior by feeding a matrix of values through
name-based runtime injection — CLI `--field key=value`, environment overrides,
config overlays — into a consumer whose policy for unknown keys is "ignore".
Also whenever every variant in such a matrix returns identical observations.

## Do this

1. **Before running the matrix, run one control pair**: two runs whose injected
   values are chosen to flip a concrete observable (a guard fires in one and
   skips in the other). Require the flip. Until the flip is observed, no run of
   the matrix measures anything.
2. **Read uniform output across all variants as "lever not connected", not
   "behavior stable".** Ignore-unknown-keys is a common default — pydantic, for
   example: "By default, Pydantic models won't error when you provide extra
   data, and these values will simply be ignored" — so a mis-named key produces
   the default-value branch on every run, with exit 0 and no warning.
3. **Look up the canonical internal key name** (normalized dotted path, IR
   field id) from the tool's trace output, IR dump, or docs — not from the
   spelling you used in source. A bare name that normalizes differently lands
   in the "not compared" bucket silently.
4. **When the consumer offers a strict mode** (error/warn on unknown keys —
   pydantic `extra='forbid'`, schema `additionalProperties: false`), turn it on
   for the measurement run so a mis-named key fails loudly instead of
   defaulting.
5. **Do not count exit codes as evidence the values landed.** The failure mode
   is exit 0 across the whole matrix.

## Edge cases

| Case | Then |
|------|------|
| The tool's help text documents the ignore policy | The run is still silent — read the key-handling policy before building the matrix, and pick key names from the documented canonical form |
| The chosen observable is insensitive to the value (aggregate status, summary count) | Switch to an observable the value provably drives: executed-step list, trace line, emitted record — then re-run the control pair |
| No injected value flips anything observable | Instrument first (verbose/trace mode, debug output) before measuring; a matrix without any observable lever produces only noise |
| The control pair flips but a later matrix cell looks impossible | Re-run that cell's control neighbor — key handling can differ per field (compared vs non-compared fields) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Conclude "behavior is stable" from identical outputs across a value matrix | Run a control pair and require the observable to flip first | Silently ignored keys make misconfiguration masquerade as coverage — every run exercised the same default branch |
| Trust the key spelling you wrote in source files | Find the normalized internal name from trace/IR output | Normalized (dotted) and bare names diverge; the bare name is classified as a field the run does not compare on |
| Cite the matrix's uniform exit 0 as passing evidence | Cite the flipped observable from the control pair, then per-cell observations | Exit status stays 0 while the injection is ignored |

## Sources

- https://pydantic.dev/docs/validation/latest/concepts/models/ — "By default, Pydantic models won't error when you provide extra data, and these values will simply be ignored"; `ConfigDict(extra=...)` values `ignore` (default) / `allow` / `forbid` — the ignore-unknown default this page defends against
- Field reproduction (2026-08-05, lnpl 0.2.0 workflow runner): five `--field value=N` runs produced byte-identical step traces (guard always false, exit 0, no diagnostics); the tool's own help stated "Fields the workflow does not compare on are ignored"; switching to the canonical dotted name `measurement.value` flipped the guarded create step. Raw run outputs archived alongside the QA case
- [testing-quality-harness-reverse-controls] — the same principle applied to harnesses that *score* verification: a uniform verdict is a property of the instrument, proven otherwise only by a control run
