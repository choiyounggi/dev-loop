---
id: testing-quality-value-preserving-refactor-assertions
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://stryker-mutator.io/docs/mutation-testing-elements/equivalent-mutants/
  - https://pitest.org/quickstart/basic_concepts/
  - https://docs.pytest.org/en/stable/how-to/monkeypatch.html
  - https://docs.python.org/3/library/unittest.mock.html
last_verified: 2026-08-06
related: [testing-quality-tests-that-cannot-fail, testing-quality-harness-reverse-controls, testing-quality-behavior-not-implementation, testing-quality-minimum-case-set, testing-quality-unasserted-return-fields, testing-quality-checks-that-cannot-pass, backend-common-change-impact-call-site-enumeration]
---

# Regression Tests for a Value-Preserving Refactor

## When this applies

You replaced a hardcoded literal with a read from config, a constants module, or
another single source of truth (`"DB ×1.3"` → `"DB ×%s" % E.DB_MULT`), the
current config holds the same value the literal did, and you are adding the test
that stops the literal from coming back. Also when reviewing such a test.

## Do this

1. **Render the output under the current config and compare it byte-for-byte
   with the literal you removed, before writing any assertion.** When the two
   strings are equal, every assertion on that output passes on both the
   refactored code and the reverted-literal code: the refactor is a
   semantics-preserving change, and no observation of the output can separate
   the two versions. This is the equivalent-mutant condition — a change whose
   result "behaves in exactly the same way as the original", which Stryker
   documents as having "no definitive way … to find and ignore them".

2. **Choose the assertion target from that comparison:**

| Byte comparison of output vs. removed literal | Assert |
|---|---|
| Differs (the refactor changed the rendering) | The new output directly; the natural assertion already discriminates |
| Identical (the common case) | The *dependency*: substitute the source constant with a sentinel value no literal would produce, then require the output to carry the sentinel |
| Identical, and the constant is not reachable from the test process (remote config, build-time inlining) | Assert the read at the seam you control — a stub config object the code resolves at call time — and record the substitution as the test's subject |

3. **Pick the sentinel so that the reverted code fails loudly.** Use a value
   outside the plausible range and distinct in rendering (`DB_MULT = 9.9` when
   production is `1.3`), then assert the rendered sentinel (`"DB ×9.9"`) is
   present and the production literal (`"DB ×1.3"`) is absent. The absence half
   is what fails on the reverted version; the presence half proves the
   substitution reached the renderer.

4. **Restore the constant with the framework's scoped patcher rather than a
   hand-rolled `try/finally`.** pytest's `monkeypatch` states that "All
   modifications will be undone after the requesting test function or fixture
   has finished", and `monkeypatch.context()` applies a patch "only in a
   specific scope" — both survive an assertion failure mid-test, which a
   `finally` block only matches when every exit path runs through it.

5. **Patch the name the renderer looks up, not the name where the value is
   defined.** `patch()` "works by (temporarily) changing the object that a
   *name* points to", so "you must ensure that you patch the name used by the
   system under test". A module that copied the constant into a local at import
   time does not read your patch — assert the substitution took effect (the
   sentinel appears) before treating the test as proof.

6. **Prove the test reddens on the pre-refactor code once.** Restore the literal
   in a scratch copy, run the test, require red, then discard the copy
   ([testing-quality-tests-that-cannot-fail] for the restore mechanics).

## Edge cases

| Case | Then |
|------|------|
| The constant is one of several the output renders | Substitute one constant per test so a red run names which read regressed; a single test substituting all of them cannot localize the reversion |
| The value is a float and the rendering rounds it | Pick a sentinel that survives the rounding (differs in a kept digit), and assert the rendered form rather than the raw value |
| The refactor moved the literal into the same module's own constant, not a shared SSOT | The substitution test still applies and is the only thing that detects re-inlining; note in the test name that the source is module-local |
| The config value legitimately equals a magic number the output already contains for another reason | Assert the sentinel-substituted output only, and drop the "production literal absent" half — it would match the unrelated occurrence and redden on correct code |
| Several call sites were meant to switch to the SSOT and you tested one | Enumerate the call sites and give each its own substitution assertion — a passing test on one site says nothing about the others ([backend-common-change-impact-call-site-enumeration]) |
| Asserting the substitution looks like testing an internal, against "a behavior-preserving refactor keeps every test green" | State the assertion as the behavior it is — the rendered output is a function of the configured value — and drive it through the seam an operator controls (the config object), not a private field. Re-inlining the literal removes that configurability, so it is not a behavior-preserving change and the invariant in [testing-quality-behavior-not-implementation] holds |
| The test cannot substitute anything because the value is inlined at build time | Record the reversion risk as uncovered in the test file, and move the guard to a static check that greps for the literal outside the SSOT ([testing-quality-checks-that-cannot-pass] for authoring that gate) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Assert the rendered text (`assert "DB ×1.3" in out`) as the refactor's regression test | Substitute the constant with a sentinel and assert the output follows | The rendered text is identical before and after, so the assertion passes on the reverted literal too — it guards nothing it was written to guard |
| Read a green run plus coverage of the changed line as proof the SSOT read is enforced | Require a red run against a copy that has the literal restored | A value-preserving change leaves output-level observations unchanged by construction; only the substitution or a red control discriminates |
| Wrap the substitution in `try/finally` to restore the constant | Use the runner's scoped patch fixture (`monkeypatch`, `patch` as a context manager) | The fixture undoes the change on every exit path including collection errors, and needs no restore code to review |
| Skip the byte comparison and write whichever assertion looks natural | Compute the comparison first and let its result choose the assertion target | The comparison is what tells you whether the natural assertion can fail at all |

## Sources

- https://stryker-mutator.io/docs/mutation-testing-elements/equivalent-mutants/ — an equivalent mutant leaves the output identical, "There is no definitive way for Stryker to find and ignore them", and "the only solution is by finding these by hand" — the reason a value-preserving refactor cannot be detected by observing output
- https://pitest.org/quickstart/basic_concepts/ — equivalent mutations: "The resulting mutant behaves in exactly the same way as the original", so no correct test can distinguish it
- https://docs.pytest.org/en/stable/how-to/monkeypatch.html — "All modifications will be undone after the requesting test function or fixture has finished"; `monkeypatch.context()` applies patches "only in a specific scope"
- https://docs.python.org/3/library/unittest.mock.html — "Where to patch": `patch()` "works by (temporarily) changing the object that a *name* points to with another one … you must ensure that you patch the name used by the system under test"
- Field reproduction 2026-08-05 (manday report renderer): the removed literal `DB ×1.3` and `"DB ×%s" % E.DB_MULT` under the shipped config rendered byte-identical, computed before writing the test — so `assert "DB ×1.3" in out` passed on both the SSOT version and the restored-literal version. Substituting `E.DB_MULT` with a sentinel and asserting the rendered sentinel was the only form that reddened on the literal version
